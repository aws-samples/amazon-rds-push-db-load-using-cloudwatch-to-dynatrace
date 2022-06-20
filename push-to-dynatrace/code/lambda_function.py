import time
import boto3
import logging
import os 

logger = logging.getLogger()
logger.setLevel(logging.INFO)
pi_client = boto3.client('pi')
rds_client = boto3.client('rds')
cw_client = boto3.client('cloudwatch')
ns = os.environ['PINamespace']
tagsFilterIn = os.environ.get('RDSFilterInTags')

def lambda_handler(event, context):
    pi_instances = get_pi_instances()
    for instance in pi_instances:
        pi_response = get_resource_metrics(instance)
        if pi_response:
            send_cloudwatch_data(pi_response)

    return {
        'statusCode': 200,
        'body': 'ok'
    }


def get_pi_instances():
    # check RDS tag filter
    # expected environment variable format is "env=dev,test"
    tagsDict = {}
    if not tagsFilterIn is None:
        tagsList = tagsFilterIn.split(';')
        for tagItem in tagsList:
            entry = tagItem.split("=")
            if len(entry) == 2:
                tagsDict[entry[0]] = entry[1]
    
    instances = rds_client.describe_db_instances()
    
    if len(tagsDict) == 0:
        return filter(
            lambda _: _.get('PerformanceInsightsEnabled', False),   
            instances['DBInstances']
        )        
    else:
        rdsInstances = []
        for instance in instances["DBInstances"]:
            # get database instance tags
            tags = rds_client.list_tags_for_resource(ResourceName=instance["DBInstanceArn"])
            for tag in tags['TagList']:
                # get tag value
                tagValues = tagsDict.get(tag['Key'])
                # does the tag exist in the input filter
                if not tagValues is None:
                    tagValuesList = tagValues.split(",")
                    # does the tag value match and the RDS instance setup for performance insights feature
                    if tag['Value'] in tagValuesList and instance.get('PerformanceInsightsEnabled'):
                        rdsInstances.append(instance)
                        break #move to the next rds instance

        return rdsInstances 

def get_metric_key_dimension(pi_response):
    for metric_response in pi_response['MetricList']:
        is_dim_value = 'Dimensions' in metric_response['Key']
        dbi_name = 'db_instance'
        dbi_value = pi_response['Identifier']
        if is_dim_value:
            dims = metric_response['Key']['Dimensions']
            if 'db.wait_event.name' in dims:
                dbi_name += '_waits' 
            elif 'db.sql_tokenized.statement' in dims:
                dbi_name += '_sql'
            else:
                raise NotImplementedError

            return dbi_name,dbi_value
    return None
       


def get_resource_metrics(instance):
    metric_queries = []
    metric_queries.append({'Metric': 'db.load.avg', 'GroupBy': {'Group':'db.wait_event'}})
    metric_queries.append({'Metric': 'db.load.avg', 'GroupBy': {'Group':'db.sql_tokenized'}})
    return pi_client.get_resource_metrics(
        ServiceType='RDS',
        Identifier=instance['DbiResourceId'],
        StartTime=time.time() - 300,
        EndTime=time.time(),
        PeriodInSeconds=60,
        MetricQueries=metric_queries
    )

def send_cloudwatch_data(pi_response):
    metric_data = []
    dbi_name = 'db'
    dbi_value = pi_response['Identifier']
    for metric_response in pi_response['MetricList']:
        cur_key = metric_response['Key']['Metric']
        is_dim_value = 'Dimensions' in metric_response['Key']
        dim_name = ''
        dim_value = ''
        wait_metric = False
        if is_dim_value:
            dims = metric_response['Key']['Dimensions']
            if 'db.wait_event.name' in dims:
                dim_name = 'wait_event_name'
                dim_value = dims['db.wait_event.name']
                wait_metric = True
            elif 'db.sql_tokenized.statement' in dims:
                dim_name = 'sql_statement' 
                dim_value = dims['db.sql_tokenized.statement']
            else:
                raise NotImplementedError
            dim_value = dim_value.replace(':','.')
                
        for datapoint in metric_response['DataPoints']:
            # We don't always have values from an instance
            value = datapoint.get('Value', None)

            if value:
                if is_dim_value:
                    metric_data.append({
                        'MetricName': cur_key,
                        'Dimensions': [{
                                'Name':dbi_name + ('_waits' if wait_metric else '_sql'),    
                                'Value':dbi_value
                            },
                            {
                                'Name':dim_name,    
                                'Value':dim_value
                            }],
                        'Timestamp': datapoint['Timestamp'],
                        'Value': datapoint['Value']
                    })
                   

    if metric_data:
        start = 0
        stop = 20

        while start < len(metric_data):
            cw_client.put_metric_data(
                Namespace=ns,
                MetricData= metric_data[start:stop]
            )
            start = stop
            stop = start + 20
