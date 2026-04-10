# IAM role definitions
resource "aws_iam_role" "lambda_shared_role" {
  name = "lambda_shared_execution_role"
  arn = "arn:aws:iam::302263058686:role/lambda_shared_execution_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})
}

# Create Managed Policy
resource "aws_iam_policy" "lambda_shared_policy" {
  name   = "lambda_shared_execution_policy "  # Policy name
  arn = "arn:aws:iam::302263058686:policy/lambda_shared_execution_policy"
  path   = "/"
  policy = jsonencode({
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "s3:*",
                "sqs:*",
                "sns:Publish",
                "comprehend:*",
                "comprehendmedical:*",
                "logs:CreateLogStream",
                "logs:CreateLogGroup",
                "logs:PutLogEvents",
                "ssm:DescribeDocumentParameters",
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter",
                "textract:StartDocumentTextDetection",
                "textract:StartDocumentAnalysis",
                "textract:GetDocumentTextDetection",
                "textract:GetDocumentAnalysis",
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface",
                "ec2:CreateTags",
                "ecr:CreateRepository",
                "bedrock:ListInferenceProfiles",
                "bedrock:InvokeModel",
                "sagemaker:InvokeEndpoint",
                "lambda:InvokeFunction",
                "batch:*",
                "lambda:InvokeFunction",
                "lambda:InvokeAsync",
                "cognito-identity:*",
                "cognito-idp:*",
                "cognito:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "kms:GetPublicKey",
                "kms:ListKeyPolicies",
                "kms:ListKeyRotations",
                "kms:ListRetirableGrants",
                "kms:GetKeyPolicy",
                "kms:ListResourceTags",
                "kms:ListGrants",
                "kms:GetParametersForImport",
                "kms:DescribeCustomKeyStores",
                "kms:ListKeys",
                "kms:GetKeyRotationStatus",
                "kms:ListAliases",
                "kms:DescribeKey",
                "kms:Decrypt"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ],
    "Version": "2012-10-17"
})
}


# Attach Managed Policy to IAM Role
resource "aws_iam_policy_attachment" "lambda_shared_role_policy_attachment" {
  name       = "example-attachment"
  roles      = [aws_iam_role.lambda_shared_role.name]  # Attach the policy to the role
  policy_arn = aws_iam_policy.lambda_shared_policy.arn  # Managed policy ARN
}