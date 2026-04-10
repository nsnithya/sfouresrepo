# Configuring Terraform to use S3 as a backend for storing the state file.
# TODO: Enable versioning in the backend bucket
# TODO: Specify versions for the AWS providers
# TODO: Create the bucket if it doesn't exist 

/*-------------------------------
terraform {
  backend "s3" {
    bucket = "ahrq-terraform-ocr" # pass as parameter
    key    = "terraform.tfstate" # pass as parameter
	region = "us-east-1" # pass as parameter

  }
}

--------------------------------*/

# Define the provider and AWS credentials
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

########################################
# S3 Bucket CREATION
###################################

resource "aws_s3_bucket" "my_bucket" {
  bucket   = var.bucket_name
  acl    = "private"
  tags = {
   Name        = var.bucket_name
   Environment = "Dev"
  }
}

resource "aws_s3_bucket" "my_bucket1" {
  bucket   = var.bucket_name1
  acl    = "private"
  tags = {
   Name        = var.bucket_name1
   Environment = "Dev"
  }
}


###################################
# CREATING SUB FOLDERS UNDER S3 Buckets
###################################

resource "aws_s3_bucket_object" "landing" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "landing/"  
}

resource "aws_s3_bucket_object" "processed" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "processed/"  
}
resource "aws_s3_bucket_object" "ocr-results" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ocr-results/"  
}
resource "aws_s3_bucket_object" "ai-ml" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ai-ml/"  
}
resource "aws_s3_bucket_object" "config" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "config/"  
}
resource "aws_s3_bucket_object" "cleaned-data" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "cleaned-data/"  
}
resource "aws_s3_bucket_object" "structured-data" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "structured-data/"  
}
resource "aws_s3_bucket_object" "data-segments" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "data-segments/"  
}
resource "aws_s3_bucket_object" "folder9" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "logs/"  
}

resource "aws_s3_bucket_object" "ocr-pdf-preprocess" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ocr-pdf-preprocess/"  
}

resource "aws_s3_bucket_object" "ocr-pdf-split-results" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ocr-pdf-split-results/"  
}

resource "aws_s3_bucket_object" "question-embedding-input" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "question-embedding-input/"  
}

resource "aws_s3_bucket_object" "question-embedding-output" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "question-embedding-output/"  
}


###################################
# CREATING FOLDERS UNDER SUB FOLDERS
###################################

resource "aws_s3_bucket_object" "code" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ai-ml/code/"  
}

resource "aws_s3_bucket_object" "biobert-model" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ai-ml/biobert-model/"  
}
resource "aws_s3_bucket_object" "llm-output" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ai-ml/llm-output/"  
}
resource "aws_s3_bucket_object" "page-embeddings" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ai-ml/page-embeddings/"  
}

resource "aws_s3_bucket_object" "deploy" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ai-ml/deploy/"  
}

resource "aws_s3_bucket_object" "passed-step-function-data" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "ai-ml/passed-step-function-data/"  
}

resource "aws_s3_bucket_object" "ocr" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "config/ocr/"  
}

resource "aws_s3_bucket_object" "folder10" {
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "config/ai-ml/"  
}

##################################################################
#    SQS MODULE
##################################################################
/*------------
module "sqs_module" {
  source = "./modules/sqs"
  sqs_queue_name                  = var.sqs_queue_name
  sqs_delay_seconds               = var.sqs_delay_seconds
  sqs_max_message_size            = var.sqs_max_message_size
  sqs_message_retention_seconds   = var.sqs_message_retention_seconds
  sqs_receive_wait_time_seconds   = var.sqs_receive_wait_time_seconds
  sqs_visibility_timeout_seconds  = var.sqs_visibility_timeout_seconds
}
--------*/
##################################################################
#    SNS MODULE
##################################################################
module "sns" {
  for_each = var.topic_to_queues
  source   = "./modules/sns"
  topic_name       = each.key
  sqs_queue_names  = { for q in each.value : q => {} }
}

##################################################################
#    BEGIN AWS BATCH MODULE
##################################################################

#############################
# IAM Role: EC2 instance role for ECS
#############################

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

#############################
# IAM Role: AWS Batch Service Role
#############################

resource "aws_iam_role" "batch_service_role" {
  name = "aws-batch-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "batch.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_service_role_policy" {
  role       = aws_iam_role.batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

#############################
# AWS Batch Compute Environment (EC2)
#############################

resource "aws_batch_compute_environment" "ec2_compute_env" {
  compute_environment_name = var.aws_compute_env #"batch-ec2-compute-env"
  type                     = "MANAGED"
  service_role             = aws_iam_role.batch_service_role.arn

  compute_resources {
    type              = "EC2"
    allocation_strategy = "BEST_FIT"
    instance_role     = aws_iam_instance_profile.ecs_instance_profile.arn
    instance_type    = ["inf1.2xlarge"]
    min_vcpus         = 0
    max_vcpus         = 4
    desired_vcpus     = 0
    subnets           = ["subnet-02730b985e1160a2a"] # Replace subnet-id with actual subnet-id
    security_group_ids = ["sg-09403737e61b5c2e8"] # Replace security-group-id-id with actual security-group-id
  }
}

#############################
# AWS Batch Job Queue
#############################

resource "aws_batch_job_queue" "job_queue" {
  name                 = var.aws_batch_job_queue
  state                = "ENABLED"
  priority             = 1
  compute_environments = [aws_batch_compute_environment.ec2_compute_env.arn]
}

#############################
# AWS Batch Job Definition
#############################

resource "aws_batch_job_definition" "qsrs_ocr_aiml_job" {
  name = var.aws_batch_def
  type = "container"

  container_properties = jsonencode({
    image: "amazonlinux",
    vcpus: 1,
    memory: 512,
    command: ["echo", "Hello from EC2 AWS Batch!"]
  })
}


##################################################################
#    ECR REPO
##################################################################
resource "aws_ecr_repository" "repo" {
  name = var.aws_ecr_repo_name
  image_tag_mutability = "MUTABLE"

  # Uncomment the below to enable repo scanning 
  image_scanning_configuration {
     scan_on_push = true
  }
}

##################################################################
#    BEGIN SageMaker Provisioning
##################################################################

############################
# IAM Role for SageMaker
############################
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "sagemaker.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_basic_permissions" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Attach full access to S3
resource "aws_iam_role_policy" "s3_full_access_policy" {
  name = "S3FullAccessForSageMaker"
  role = aws_iam_role.sagemaker_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:*"
        ],
        Resource = "*"
      }
    ]
  })
}

############################
# SageMaker Model
############################
resource "aws_sagemaker_model" "model" {
  name	= var.sagemaker_model
  execution_role_arn = aws_iam_role.sagemaker_execution_role.arn

  primary_container {
    image           = "763104351884.dkr.ecr.us-east-1.amazonaws.com/huggingface-pytorch-inference:1.10.2-transformers4.17.0-cpu-py38-ubuntu20.04"  # Change to your preferred image
    model_data_url  = "s3://ahrq-qsrs-ml-poc/deploy/model.tar.gz"             # Replace with your S3 path
    mode            = "SingleModel"
  }
}

############################
# SageMaker Endpoint Configuration
############################
resource "aws_sagemaker_endpoint_configuration" "endpoint_config" {
  name = var. sagemaker_endpoint_config

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.model.name
    initial_instance_count = 1
    instance_type          = "ml.m4.xlarge"  # Replace instance_type
  }
}

############################
# SageMaker Endpoint
############################
resource "aws_sagemaker_endpoint" "endpoint" {
  name                 = var.sagemaker_endpoint
  endpoint_config_name = aws_sagemaker_endpoint_configuration.endpoint_config.name
}


##############################################
# Lambda Function & IAM Role for Event bridge
##############################################

/*----------
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "my_lambda" {
  function_name = "delete-older-files-after-processing"
  handler       = "index.handler"
  runtime       = "python3.13"
  filename      = "delete-older-files-after-processing.zip" # Upload your zip file here
  role          = aws_iam_role.lambda_exec.arn
}
--------*/

########################################
# EventBridge Event Bus
########################################
/*----------
resource "aws_cloudwatch_event_bus" "custom_bus" {
  name = var.aws_event_bus
}
--*/

########################################
# EventBridge Rule - Pattern Based
########################################
/*----------
resource "aws_cloudwatch_event_rule" "event_pattern_rule" {
  name        = var.aws_pattern_rule
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name

  event_pattern = jsonencode({
    source = ["my.custom.source"]
  })
}

resource "aws_cloudwatch_event_target" "pattern_target" {
  rule      = aws_cloudwatch_event_rule.event_pattern_rule.name
  target_id = "lambdaTargetPattern"
  arn       = aws_lambda_function.my_lambda.arn
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name
}

resource "aws_lambda_permission" "allow_eventbridge_pattern" {
  statement_id  = "AllowExecutionFromEventBridgePattern"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_pattern_rule.arn
}
---*/

########################################
# EventBridge Schedule Group
########################################
/*----------
resource "aws_scheduler_schedule_group" "my_schedule_group" {
  name = var.aws_schedule_group
}
--------*/
########################################
# EventBridge Rule - Scheduled
########################################
/*----------
resource "aws_scheduler_schedule" "s3_file_copy" {
  name             = var.aws_scheduled_event_files3copy
  group_name       = aws_scheduler_schedule_group.my_schedule_group.name
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "rate(5 minutes)"

  target {
    arn      = aws_lambda_function.my_lambda.arn
    role_arn = aws_iam_role.lambda_exec.arn
    input    = jsonencode({ "message": "Hello from schedule for S3 FileCopy" })
  }
}

resource "aws_scheduler_schedule" "s3_delete_old_file" {
  name             = var.aws_scheduled_event_oldfiledelete
  group_name       = aws_scheduler_schedule_group.my_schedule_group.name
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "rate(1 days)"

  target {
    arn      = aws_lambda_function.my_lambda.arn
    role_arn = aws_iam_role.lambda_exec.arn
    input    = jsonencode({ "message": "Hello from schedule for file deletion after process" })
  }
}
--------*/


############################
# Reference Existing Lambda Functions
############################
data "aws_lambda_function" "lambda_one" {
  function_name = var.file_scheduler_lambda #"my-existing-lambda-1"  # Replace with your Lambda name
}

data "aws_lambda_function" "lambda_two" {
  function_name = var.delete_older_files_lambda #"my-existing-lambda-2"  # Replace with your Lambda name
}

############################
# IAM Role for Scheduler to Invoke Lambdas
############################
resource "aws_iam_role" "scheduler_invoke_role" {
  name = "scheduler-invoke-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "scheduler.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_lambda_policy" {
  name = "scheduler-invoke-lambdas-policy"
  role = aws_iam_role.scheduler_invoke_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "lambda:InvokeFunction",
        Resource = [
          data.aws_lambda_function.lambda_one.arn,
          data.aws_lambda_function.lambda_two.arn
        ]
      }
    ]
  })
}

############################
# EventBridge Schedule #1
############################
resource "aws_scheduler_schedule" "schedule_lambda_one" {
  name                = var.file_scheduler_lambda
  schedule_expression = "rate(5 minutes)"  # Adjust as needed

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = data.aws_lambda_function.lambda_one.arn
    role_arn = aws_iam_role.scheduler_invoke_role.arn
    input    = jsonencode({ "source": "schedule-1", "message": "Hello from Schedule 1" })
  }
}

############################
# EventBridge Schedule #2
############################
resource "aws_scheduler_schedule" "schedule_lambda_two" {
  name                = var.delete_older_files_lambda
  schedule_expression = "cron(0 12 * * ? *)"  # Run every day at 12:00 UTC

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = data.aws_lambda_function.lambda_two.arn
    role_arn = aws_iam_role.scheduler_invoke_role.arn
    input    = jsonencode({ "source": "schedule-2", "message": "Hello from Schedule 2" })
  }
}
