# AWS Serverless Learning Project: S3 → SQS → Lambda → DynamoDB

A small hands-on project built while learning core AWS serverless services and Terraform. It sets up a pipeline where uploading a file to S3 queues a processing event, which a Lambda function consumes to read the file and log its contents to DynamoDB.

This was built as a learning exercise — first manually through the AWS Console and CLI (S3 → Lambda directly), then evolved to include SQS as a buffering/retry layer, and rebuilt entirely with Terraform to mirror a real-world Infrastructure as Code workflow.

## What it does

1. A file is uploaded to an S3 bucket.
2. The upload event is sent to an SQS queue (instead of invoking Lambda directly).
3. A Lambda function polls the queue, receiving new messages in batches.
4. For each message, the Lambda unwraps the underlying S3 event, then reads the file's contents from S3.
5. Each line in the file is written as a separate record to a DynamoDB table, along with the source file name and a timestamp.
6. If processing a message fails repeatedly, it's routed to a Dead Letter Queue (DLQ) instead of being retried indefinitely.

## Architecture

```
S3 bucket --(ObjectCreated event)--> SQS queue --(polled by)--> Lambda function --(put_item)--> DynamoDB table
                                          |
                                          v
                                   Dead Letter Queue
                                (after repeated failures)
```

- **S3 bucket** — receives uploaded files and sends an event notification to SQS on every new object.
- **SQS queue** — buffers file-upload events between S3 and Lambda. Decouples ingestion from processing, smooths out bursts of uploads, and enables automatic retries if processing fails.
- **Dead Letter Queue (DLQ)** — a second SQS queue that catches messages which fail processing beyond a configured retry limit, so they can be inspected instead of retried forever or silently lost.
- **Lambda function** (Python 3.13) — triggered via an event source mapping that polls the SQS queue. For each message, it parses the SQS envelope to recover the original S3 event, downloads the file, splits it into lines, and writes each line as an item to DynamoDB.
- **DynamoDB table** — stores one item per line per file processed. Partition key: `file_key` (the S3 object key). Sort key: `line_id` (a composite of timestamp + line number), so the same file can be reprocessed multiple times without overwriting previous runs.
- **IAM role** — a dedicated Lambda execution role with managed policies attached: basic execution (CloudWatch Logs), S3 read-only access, DynamoDB full access, and SQS queue execution access (to receive/delete messages).

## Tech stack

- **Terraform** — all infrastructure (S3, SQS, Lambda, DynamoDB, IAM) is defined as code in the `infra/` directory.
- **Python (boto3)** — Lambda function logic lives in `lambda_src/`.
- **AWS CLI** — used for authentication setup and manual testing/verification alongside Terraform.

## Project structure

```
.
├── infra/                     # Terraform configuration
│   ├── main.tf                  # Provider configuration
│   ├── s3.tf                     # S3 bucket
│   ├── sqs.tf                     # SQS queue, DLQ, and queue access policy
│   ├── dynamo.tf                   # DynamoDB table
│   ├── iam.tf                       # Lambda execution role, policy attachments,
│   │                                 S3 bucket notification, event source mapping
│   └── lambda.tf                     # Lambda function definition
├── lambda_src/
│   └── lambda_function.py             # Lambda handler code
└── local_test/
    ├── run_local_test.py               # Script to invoke the Lambda handler locally
    └── test_event.json                  # Sample SQS-wrapped S3 event for local testing
```

## How it was built

This project started as a manual walkthrough (AWS Console, then AWS CLI) to understand what each piece of a serverless pipeline actually requires — IAM roles, resource policies, event notifications — before automating it with Terraform. SQS was added afterward, as a second learning pass: first wired up manually through the Console to understand the concept (queues, visibility timeout, dead-letter queues, event source mappings), then expressed properly as Terraform resources to replace the original direct S3 → Lambda trigger. The Console and CLI-only versions are not included here; this repo reflects the final Terraform-managed version.

A local test harness (`local_test/`) was also built along the way, to allow testing changes to the Lambda function's logic directly against real AWS resources (S3, DynamoDB) without needing to redeploy via Terraform for every small code change.

## Running this yourself

**Prerequisites:**
- An AWS account and an IAM user with permissions for S3, SQS, Lambda, DynamoDB, and IAM
- AWS CLI installed and configured (`aws configure`)
- Terraform installed

**Deploy:**
```bash
cd infra
terraform init
terraform plan
terraform apply
```

**Test end-to-end:**
```bash
aws s3 cp path/to/local/file.txt s3://<your-bucket-name>/file.txt
```

Then check the Lambda's CloudWatch Logs, inspect the SQS queue, or query the DynamoDB table, to confirm the file was processed.

**Test the Lambda logic locally (without deploying):**
```bash
cd local_test
python run_local_test.py
```

This invokes the Lambda handler directly using a sample SQS-wrapped event, still calling real AWS services (S3, DynamoDB) — useful for quick iteration on the Lambda code without a full Terraform deploy.

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
- The SQS event source mapping uses a batch size of 10 with no partial-batch-failure handling configured, so a failure partway through a batch can cause the whole batch to be retried.
