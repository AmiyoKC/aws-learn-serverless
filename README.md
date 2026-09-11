# AWS Serverless Learning Project: S3 → Lambda → DynamoDB

A small hands-on project built while learning core AWS serverless services and Terraform. It sets up a pipeline where uploading a file to S3 automatically triggers a Lambda function, which processes the file and logs data to DynamoDB.

This was built as a learning exercise — first manually through the AWS Console and CLI, then rebuilt entirely with Terraform to mirror a real-world Infrastructure as Code workflow.

## What it does

1. A file is uploaded to an S3 bucket.
2. The upload event automatically triggers a Lambda function.
3. The Lambda function reads the file's contents from S3.
4. Each line in the file is written as a separate record to a DynamoDB table, along with the source file name and a timestamp.

## Architecture

```
S3 bucket  --(ObjectCreated event)-->  Lambda function  --(put_item)-->  DynamoDB table
```

- **S3 bucket** — receives uploaded files and emits an event notification on every new object.
- **Lambda function** (Python 3.13) — triggered by the S3 event; downloads the file, splits it into lines, and writes each line as an item to DynamoDB.
- **DynamoDB table** — stores one item per line per file processed. Partition key: `file_key` (the S3 object key). Sort key: `line_id` (a composite of timestamp + line number), so the same file can be reprocessed multiple times without overwriting previous runs.
- **IAM role** — a dedicated Lambda execution role with least-needed managed policies attached: basic execution (CloudWatch Logs), S3 read-only access, and DynamoDB full access.

## Tech stack

- **Terraform** — all infrastructure (S3, Lambda, DynamoDB, IAM) is defined as code in the `infra/` directory.
- **Python (boto3)** — Lambda function logic lives in `lambda_src/`.
- **AWS CLI** — used for authentication setup and manual testing/verification alongside Terraform.

## Project structure

```
.
├── infra/                  # Terraform configuration
│   ├── main.tf              # Provider configuration
│   ├── s3.tf                 # S3 bucket
│   ├── dynamo.tf              # DynamoDB table
│   ├── iam.tf                  # Lambda execution role + policy attachments
│   └── lambda.tf                # Lambda function, S3 trigger permission, bucket notification
└── lambda_src/
    └── lambda_function.py       # Lambda handler code
```

## How it was built

This project started as a manual walkthrough (AWS Console, then AWS CLI) to understand what each piece of a serverless pipeline actually requires — IAM roles, resource policies, event notifications — before automating all of it with Terraform. The Console and CLI versions are not included here; this repo reflects the final Terraform-managed version.

## Running this yourself

**Prerequisites:**
- An AWS account and an IAM user with permissions for S3, Lambda, DynamoDB, and IAM
- AWS CLI installed and configured (`aws configure`)
- Terraform installed

**Deploy:**
```bash
cd infra
terraform init
terraform plan
terraform apply
```

**Test:**
```bash
aws s3 cp path/to/local/file.txt s3://<your-bucket-name>/file.txt
```

Then check the Lambda's CloudWatch Logs, or query the DynamoDB table, to confirm the file was processed.

**Tear down:**
```bash
cd infra
terraform destroy
```

## Notes

This is a learning/demo project, not a production setup. A few simplifications worth knowing if you build on this:
- IAM policies used here are broad AWS-managed policies (e.g. `AmazonS3ReadOnlyAccess`, `AmazonDynamoDBFullAccess`) rather than tightly scoped custom policies.
- Terraform state is stored locally rather than in a remote backend (e.g. S3 + DynamoDB locking), which is what a team setup would typically use.
- There's no CI/CD pipeline — deployments are run manually via `terraform apply` from a local machine.
