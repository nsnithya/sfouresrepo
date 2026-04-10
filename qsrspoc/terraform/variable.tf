# Define the variables
variable "aws_region" {
  description = "The AWS region where the S3 bucket will be created"
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "Your AWS access key"
}

variable "aws_secret_key" {
  description = "Your AWS secret key"
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
}

variable "bucket_name1" {
  description = "The name of the pdf drop location S3 bucket"
}

variable "aws_batch_job_queue" {
  description = "The name of the AWS Batch Job Queue used in this account"
}

variable "aws_batch_def" {
  description = "The name of the AWS Batch Definition used in this account"
}

variable "aws_compute_env" {
  description = "The name of the AWS Batch Compute Environment used in this account"
}

variable "aws_event_bus" {
  description = "The name of Event Bus for QSRS OCR"
}

variable "aws_pattern_rule" {
  description = "The name of Event Pattern Rule for QSRS OCR"
}

variable "aws_schedule_group" {
  description = "The name of Schedule Group for QSRS OCR"
}

variable "aws_scheduled_event_files3copy" {
  description = "The name of Schedule for S3 file Copy for QSRS OCR"
}

variable "aws_scheduled_event_oldfiledelete" {
  description = "The name of Schedule to delete old file from S3 after processing for QSRS OCR"
}

variable "aws_ecr_repo_name" {
  description = "The name of ECR Repository for the images to be pushed"
}

variable "sagemaker_model" {
  description = "The name of Sage Maker Model"
}

variable "sagemaker_endpoint" {
  description = "The name of Sage Maker Endpoint"
}

variable "sagemaker_endpoint_config" {
  description = "The name of Sage Maker Endpoint Configuration"
}

variable "file_scheduler_lambda" {
  description = "The name of S3 file schedule lambda"
}

variable "file_scheduler_lambda_arn" {
  description = "The name of S3 lambda function arn"
}

variable "delete_older_files_lambda" {
  description = "The name of lambda function which deletes files after processing"
}

variable "delete_older_files_lambda_arn" {
  description = "The name of delete files lambda function arn"
}

variable "versioning_bucket_name" {
  description = "The name of the versioning S3 bucket "
}

# SQS
variable sqs_queue_name {
  description = "The name of the SQS Queue"
  default = "qsrs-ocr-dev-queue"
}

variable sqs_delay_seconds {
  description = "SQS Delay Seconds"
  default = 60

}
variable sqs_max_message_size {
  description = "SQS Max Message Size"
  default = 15000
}
variable sqs_message_retention_seconds {
  description = "SQS Message Retention Seconds"
  default = 600
}
variable sqs_receive_wait_time_seconds {
  description = "Receive Wait Time Seconds"
  default = 10
}
variable sqs_visibility_timeout_seconds {
  description = "Visibility Timeout Seconds"
  default = 30
}

# SNS
variable "topic_to_queues" {
  description = "Map of SNS topic name to list of SQS queue names"
  type        = map(list(string))
}



# VPC
variable "aws_vpc_id" {
  description = "The VPC Id"
  default = "vpc-08bf02cf3769d9aea"
}
