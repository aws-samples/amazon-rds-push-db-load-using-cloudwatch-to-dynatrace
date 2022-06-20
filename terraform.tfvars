AWSAccountID = ""
AWSRegion = "us-west-2"
PINamespace = "pins"
FirehoseHttpDeliveryEndpoint="https://aws.cloud.dynatrace.com/metrics"
DynatraceEnvironmentUrl=""
DynatraceApiKey=""
DynatraceMetricStreamNamespaceList = [
  "AWS/ApiGateway",
  "AWS/Lambda",
  "AWS/SNS",
  "AWS/SQS"
]
RDSFilterInTags={
  # you can specify zero, one, or more tag names in this map; a tag's value can have one or more values in it seperated by a comma
  # tag1 = "value1,value2"
  # e.g., if tag is called environment and we need to pull all RDS databases having an environment tagged with a value of dev or canary use 
  # environment = "dev,canary"
}