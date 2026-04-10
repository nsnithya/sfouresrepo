# Lambda Function 1 - qsrs-ocr-s3process-uploaded-documents
# Step 1 Lambda Creation
resource "aws_lambda_function" "qsrs-ocr-s3process-uploaded-documents" {
  function_name = "qsrs-ocr-s3process-uploaded-documents"
  role          = aws_iam_role.lambda_shared_role.arn
  handler       = "qsrs-ocr-s3process-uploaded-documents.lambda_handler"
  runtime       = "python3.9"
  filename      = "qsrs-ocr-s3process-uploaded-documents.zip"

   # Configuration Properties
  memory_size      = 2000                # Memory allocation (in MB)
  ephemeral_storage {
    size = 2048  # Size in MB (e.g., 2 GB)
  }
  timeout          = 900                 # Timeout in seconds
  description      = "qsrs-ocr-s3process-uploaded-documents function triggered by S3 events"
  publish          = true               # Publish a new version
  package_type     = "Zip"              # Use ZIP deployment
  architectures    = ["x86_64"]         # Architecture: x86_64 or arm64

  # Environment variables (optional)
  environment {
    variables = {
      ocr_configpath = "config/ocr/config.json",
      rolearn = "arn:aws:iam::302263058686:role/textract_execution_role"
      snstopicarn = "arn:aws:sns:us-east-1:302263058686:textract-jobcompletion-notification"
    }
  }

}

# Step 2 - Setup S3 event Notification to trigger LAmbda when there is an object created in landing folder
#Trigger S3 event notification for object creation event in landing/ folder 
resource "aws_s3_bucket_notification" "s3process-uploaded-documents_notification" {
  bucket = "qrsr-ocr-poc-dev"
  lambda_function {
    lambda_function_arn = "arn:aws:lambda:us-east-1:302263058686:function:qsrs-ocr-s3process-uploaded-documents"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "landing/"  # Optional, triggers for specific folder
  }
}

# Step 3 - grant permission of S3 to invoke lambda function
# Grant S3 permission to invoke the Lambda
resource "aws_lambda_permission" "allow_s3_to_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.qsrs-ocr-s3process-uploaded-documents.qsrs-ocr-s3process-uploaded-documents
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::qsrs-ocr-poc-dev"
}

# Step 4 - Create SNS notification topic 
#SNS
resource "aws_sns_topic" "textract-jobcompletion-notification" {
  name              = "textract-jobcompletion-notification"
  display_name      = "textract-jobcompletion-notification"
  policy            = jsonencode({
  "Version": "2008-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Sid": "__default_statement_ID",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "SNS:Publish",
        "SNS:RemovePermission",
        "SNS:SetTopicAttributes",
        "SNS:DeleteTopic",
        "SNS:ListSubscriptionsByTopic",
        "SNS:GetTopicAttributes",
        "SNS:AddPermission",
        "SNS:Subscribe"
      ],
      "Resource": "arn:aws:sns:us-east-1:302263058686:textract-jobcompletion-notification",
      "Condition": {
        "StringEquals": {
          "AWS:SourceOwner": "302263058686"
        }
      }
    }
  ]
})
delivery_policy = jsonencode({
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
})
  kms_master_key_id = "arn:aws:kms:us-east-1:302263058686:key/1dcb205b-5fde-4def-865a-750f169b60dc"
  fifo_topic = false
  content_based_deduplication = true

  subscription = [
    {
      protocol = "sqs"
      endpoint = aws_sqs_queue.example_queue.arn
    }  
  ]
}

#Step 4 Create SQS deadletter queue
# SQS Queue
resource "aws_sqs_queue" "textract-jobcompletion-deadletter-queue" {
  name = "textract-jobcompletion-deadletter-queue"
  visibility_timeout_seconds    = 60
  message_retention_seconds     = 345600  # 4 day
  delay_seconds                 = 0
  maximum_message_size          = 262144  # 256 KB
  receive_message_wait_time_seconds = 0
}

#Step 5 Create SQS primary queue
# SQS Queue
resource "aws_sqs_queue" "textract-jobcompletion-queue" {
  name = "textract-jobcompletion-queue"
  visibility_timeout_seconds    = 60
  message_retention_seconds     = 86400  # 1 day
  delay_seconds                 = 10
  maximum_message_size          = 262144  # 256 KB
  receive_message_wait_time_seconds = 20
  dead
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.textract-jobcompletion-deadletter-queue.arn
    maxReceiveCount     = 3
  })

  fifo_queue                  = false
  content_based_deduplication = true

  kms_master_key_id = "arn:aws:kms:us-west-2:123456789012:key/key-id"

}


# Lambda Function 2 - qsrs-ocr-extraction-process-completion
# Step 6 - Creation of Lambda function name "qsrs-ocr-extraction-process-completion" to trigger AWS batch job to extract content 
resource "aws_lambda_function" "qsrs-ocr-extraction-process-completion" {
  function_name = "qsrs-ocr-extraction-process-completion"
  role          = aws_iam_role.lambda_shared_role.arn
  handler       = "qsrs-ocr-extraction-process-completion.lambda_handler"
  runtime       = "python3.9"
  filename      = "qsrs-ocr-extraction-process-completion.zip"

   # Configuration Properties
  memory_size      = 10000                # Memory allocation (in MB)
  ephemeral_storage {
    size = 10000  # Size in MB (e.g., 2 GB)
  }
  timeout          = 900                 # Timeout in seconds
  description      = "qsrs-ocr-extraction-process-completion function triggered by SQS events"
  publish          = true               # Publish a new version
  package_type     = "Zip"              # Use ZIP deployment
  architectures    = ["x86_64"]         # Architecture: x86_64 or arm64

  # Environment variables (optional)
  environment {
    variables = {
      ocr_configpath = "config/ocr/config.json",
      snstopicarn = "arn:aws:sns:us-east-1:302263058686:ocr-process-completion-notification"
    }
  }

}

# SQS Lambda trigger
# Step 7 - Create an SQS Lambda trigger for lambda qsrs-ocr-extraction-process-completion
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.textract-jobcompletion-queue.arn
  function_name    = aws_lambda_function.qsrs-ocr-extraction-process-completion.arn

  batch_size = 10 # Number of messages to send to the Lambda function in a single batch
  enabled    = true
}


# Step 8 - Create SNS notification topic for archiving the file from landing folder 
#SNS
resource "aws_sns_topic" "ocr-process-completion-notification" {
  name              = "ocr-process-completion-notification"
  display_name      = "ocr-process-completion-notification"
  policy            = jsonencode({
  "Version": "2008-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Sid": "__default_statement_ID",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "SNS:Publish",
        "SNS:RemovePermission",
        "SNS:SetTopicAttributes",
        "SNS:DeleteTopic",
        "SNS:ListSubscriptionsByTopic",
        "SNS:GetTopicAttributes",
        "SNS:AddPermission",
        "SNS:Subscribe"
      ],
      "Resource": "arn:aws:sns:us-east-1:302263058686:ocr-process-completion-notification",
      "Condition": {
        "StringEquals": {
          "AWS:SourceOwner": "302263058686"
        }
      }
    }
  ]
})
delivery_policy = jsonencode({
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
})
  kms_master_key_id = "arn:aws:kms:us-east-1:302263058686:key/1dcb205b-5fde-4def-865a-750f169b60dc"
  fifo_topic = false
  content_based_deduplication = true

  subscription = [
    {
      protocol = "sqs"
      endpoint = aws_sqs_queue.example_queue.arn
    }  
  ]
}


#----------------------
#Step 4 Create SQS deadletter queue
# SQS Queue
resource "aws_sqs_queue" "textract-jobcompletion-deadletter-queue" {
  name = "textract-jobcompletion-deadletter-queue"
  visibility_timeout_seconds    = 60
  message_retention_seconds     = 345600  # 4 day
  delay_seconds                 = 0
  maximum_message_size          = 262144  # 256 KB
  receive_message_wait_time_seconds = 0
}

#Step 5 Create SQS primary queue
# SQS Queue
resource "aws_sqs_queue" "textract-jobcompletion-queue" {
  name = "textract-jobcompletion-queue"
  visibility_timeout_seconds    = 60
  message_retention_seconds     = 86400  # 1 day
  delay_seconds                 = 10
  maximum_message_size          = 262144  # 256 KB
  receive_message_wait_time_seconds = 20
  dead
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.textract-jobcompletion-deadletter-queue.arn
    maxReceiveCount     = 3
  })

  fifo_queue                  = false
  content_based_deduplication = true

  kms_master_key_id = "arn:aws:kms:us-west-2:123456789012:key/key-id"

}


# Lambda Function 2 - qsrs-ocr-extraction-process-completion
# Step 6 - Creation of Lambda function name "qsrs-ocr-extraction-process-completion" to trigger AWS batch job to extract content 
resource "aws_lambda_function" "qsrs-ocr-extraction-process-completion" {
  function_name = "qsrs-ocr-extraction-process-completion"
  role          = aws_iam_role.lambda_shared_role.arn
  handler       = "qsrs-ocr-extraction-process-completion.lambda_handler"
  runtime       = "python3.9"
  filename      = "qsrs-ocr-extraction-process-completion.zip"

   # Configuration Properties
  memory_size      = 10000                # Memory allocation (in MB)
  ephemeral_storage {
    size = 10000  # Size in MB (e.g., 2 GB)
  }
  timeout          = 900                 # Timeout in seconds
  description      = "qsrs-ocr-extraction-process-completion function triggered by SQS events"
  publish          = true               # Publish a new version
  package_type     = "Zip"              # Use ZIP deployment
  architectures    = ["x86_64"]         # Architecture: x86_64 or arm64

  # Environment variables (optional)
  environment {
    variables = {
      ocr_configpath = "config/ocr/config.json",
      snstopicarn = "arn:aws:sns:us-east-1:302263058686:ocr-process-completion-notification"
    }
  }

}

# SQS Lambda trigger
# Step 7 - Create an SQS Lambda trigger for lambda qsrs-ocr-extraction-process-completion
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.textract-jobcompletion-queue.arn
  function_name    = aws_lambda_function.qsrs-ocr-extraction-process-completion.arn

  batch_size = 10 # Number of messages to send to the Lambda function in a single batch
  enabled    = true
}