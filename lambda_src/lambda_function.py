import json
import urllib.parse
import boto3
from datetime import datetime, timezone

s3 = boto3.client('s3')
dynamo = boto3.resource('dynamodb')
table = dynamo.Table('file-processing-log-tf')

def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        print('Bucket: %s, Key: %s' %(bucket, key))
        print('File downloaded successfully %s' %(bucket))
        response = s3.get_object(Bucket=bucket, Key=key)
        print('File %s' %(key))
        content = response['Body'].read().decode('utf-8')
        lines = content.splitlines()
        timestamp = datetime.now(timezone.utc).isoformat()

        for index, line in enumerate(lines):
            str  = f'{timestamp}{index+1}'
            table.put_item(
                Item={
                    'file_key': key,
                    'line_id': str,
                    'data': line
                } 
            )

    return {
        'statusCode': 200,
        'body': json.dumps('File Processed Successfully')
    }