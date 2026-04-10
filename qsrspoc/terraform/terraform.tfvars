aws_access_key = "" # This needs to be replaced
aws_secret_key = "" # This needs to be replaced
#bucket_name    = "qsrs-ocr-poc-dev1"
#bucket_name1   = "qsrs-ocr-poc-pdf-drop-location-dev1"
versioning_bucket_name = "qsrs-ocr-poc-dev1"
sagemaker_model = "biobert-model-custom-v6"
sagemaker_endpoint = "biobert-model-endpoint-custom-v6"
sagemaker_endpoint_config = "biobert-model-endpoint-custom-v6-config"
aws_ecr_repo_name	   = "qsrs-ocr-awsbatch-pe1-repo"
aws_batch_job_queue	=	"qsrs-ocr-env-pe1-ec2-awsbatch"
aws_batch_def	=	"batch-ec2-job-def"
aws_compute_env = "batch-ec2-compute-env"
aws_event_bus = "qsrs_ocr_event_bus"
aws_pattern_rule = "qsrs_ocr_pattern_rule"
aws_schedule_group = "qsrs_schedule_group"
aws_scheduled_event_files3copy = "qsrs_file_scheduler_copy"
aws_scheduled_event_oldfiledelete = "qsrs_file_delete_after_process"
file_scheduler_lambda = "s3-file-copy-scheduler"
file_scheduler_lambda_arn = "arn:aws:lambda:us-east-1:864981749938:function:s3-file-copy-scheduler"
delete_older_files_lambda = "delete-older-files-after-processing"
delete_older_files_lambda_arn = "arn:aws:lambda:us-east-1:864981749938:function:delete-older-files-after-processing"

topic_to_queues = {
  "ocr-process-completion-notification-1" = ["ocr-process-completion-queue-1"],
  "textract-jobcompletion-notification-1" = ["textract-jobcompletion-queue-1"]
}
