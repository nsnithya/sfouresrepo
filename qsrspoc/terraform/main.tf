# Configuring Terraform to use S3 as a backend for storing the state file.
# TODO: Enable versioning in the backend bucket
# TODO: Specify versions for the AWS providers
# TODO: Create the bucket if it doesn't exist 

/*-------------------------------
terraform {
  backend "s3" {
    bucket = "sfouresbucket" # pass as parameter
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

resource "aws_s3_bucket" "raw_bucket" {
  bucket   = var.raw_bucket_name
  acl    = "private"
  tags = {
   Name        = var.raw_bucket_name
   Environment = var.env
  }
}

resource "aws_s3_bucket" "stage_bucket" {
  bucket   = var.stage_bucket_name
  acl    = "private"
  tags = {
   Name        = var.stage_bucket_name
   Environment = var.env
  }
}

resource "aws_s3_bucket" "clean_bucket" {
  bucket   = var.clean_bucket_name
  acl    = "private"
  tags = {
   Name        = var.clean_bucket_name
   Environment = var.env
  }
}

resource "aws_s3_bucket" "public_bucket" {
  bucket   = var.public_bucket_name
  acl    = "private"
  tags = {
   Name        = var.public_bucket_name
   Environment = var.env
  }
}

############################################
# CREATING SUB FOLDERS UNDER S3 Bucket - RAW
#############################################

resource "aws_s3_bucket_object" "ep724-data" {
  bucket = aws_s3_bucket.raw_bucket.bucket
  key    = "ep724-data/"  
}

resource "aws_s3_bucket_object" "ep711-data" {
  bucket = aws_s3_bucket.raw_bucket.bucket
  key    = "ep711-data/"  
}

resource "aws_s3_bucket_object" "rcaf-data" {
  bucket = aws_s3_bucket.raw_bucket.bucket
  key    = "rcaf-data/"  
}

resource "aws_s3_bucket_object" "employment-data" {
  bucket = aws_s3_bucket.raw_bucket.bucket
  key    = "employment-data/"  
}

############################################
# CREATING SUB FOLDERS UNDER S3 Bucket - Stage
#############################################

resource "aws_s3_bucket_object" "ep724-data-stage" {
  bucket = aws_s3_bucket.stage_bucket.bucket
  key    = "ep724-data/"  
}

resource "aws_s3_bucket_object" "ep711-data-stage" {
  bucket = aws_s3_bucket.stage_bucket.bucket
  key    = "ep711-data/"  
}

resource "aws_s3_bucket_object" "rcaf-data-stage" {
  bucket = aws_s3_bucket.stage_bucket.bucket
  key    = "rcaf-data/"  
}

resource "aws_s3_bucket_object" "employment-data-stage" {
  bucket = aws_s3_bucket.stage_bucket.bucket
  key    = "employment-data/"  
}

############################################
# CREATING SUB FOLDERS UNDER S3 Bucket - Clean
#############################################

resource "aws_s3_bucket_object" "ep724-data-clean" {
  bucket = aws_s3_bucket.clean_bucket.bucket
  key    = "ep724-data/"  
}

resource "aws_s3_bucket_object" "ep711-data-clean" {
  bucket = aws_s3_bucket.clean_bucket.bucket
  key    = "ep711-data/"  
}

resource "aws_s3_bucket_object" "rcaf-data-clean" {
  bucket = aws_s3_bucket.clean_bucket.bucket
  key    = "rcaf-data/"  
}

resource "aws_s3_bucket_object" "employment-data-clean" {
  bucket = aws_s3_bucket.clean_bucket.bucket
  key    = "employment-data/"  
}

############################################
# CREATING SUB FOLDERS UNDER S3 Bucket - Public
#############################################

resource "aws_s3_bucket_object" "ep724-data-public" {
  bucket = aws_s3_bucket.public_bucket.bucket
  key    = "ep724-data/"  
}

resource "aws_s3_bucket_object" "ep711-data-public" {
  bucket = aws_s3_bucket.public_bucket.bucket
  key    = "ep711-data/"  
}

resource "aws_s3_bucket_object" "rcaf-data-public" {
  bucket = aws_s3_bucket.public_bucket.bucket
  key    = "rcaf-data/"  
}

resource "aws_s3_bucket_object" "employment-data-public" {
  bucket = aws_s3_bucket.public_bucket.bucket
  key    = "employment-data/"  
}
