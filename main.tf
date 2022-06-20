/*
Declare input variables that will be collected and passed to sub-modules
*/
variable "AWSAccountID" {
  description = "AWS account ID"
  type = string  
}
variable "AWSRegion" {
  description = "Name of region for deployment"
  type = string  
}
variable "PINamespace" {
  description = "CloudWatch metrics namespace to be created/used by Lambda function for PI metrics"
  type = string  
}
variable "FirehoseHttpDeliveryEndpoint" {
  description = "URL to which Firehose will deliver stream"
  type = string  
  default = "https://aws.cloud.dynatrace.com/metrics"
}
variable "DynatraceEnvironmentUrl" {
  description = "URL to Dynatrace environment"
  type = string  
}
variable "DynatraceApiKey" {
  description = "Dynatrace API key"
  type = string  
}

variable "DynatraceMetricStreamNamespaceList" {
  description = "List of additional AWS service namespace metrics to be delivered as part of this metric stream"
  type    = list(string)
}

variable "RequireValidCertificate"{
  type = string
  default = true
}

variable "RDSFilterInTags"{
  description="Map of Amazon RDS database tags used as a filter for Performance Insights metrics"
  type = map(string)
  default = {
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "${var.AWSRegion}"
}

module "push-to-dynatrace"{
    source = "./push-to-dynatrace"
    AWSAccountID = "${var.AWSAccountID}"
    AWSRegion = "${var.AWSRegion}"
    PINamespace = "${var.PINamespace}"
    FirehoseHttpDeliveryEndpoint = "${var.FirehoseHttpDeliveryEndpoint}"
    DynatraceEnvironmentUrl = "${var.DynatraceEnvironmentUrl}"
    DynatraceApiKey = "${var.DynatraceApiKey}"
    DynatraceMetricStreamNamespaceList ="${var.DynatraceMetricStreamNamespaceList}"
    RequireValidCertificate = "${var.RequireValidCertificate}"
    RDSFilterInTags = "${var.RDSFilterInTags}"
}