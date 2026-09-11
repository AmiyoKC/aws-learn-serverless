import json
import urllib.parse
import boto3

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # TODO implement
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        print('Bucket: %s, Key: %s' %(bucket, key))
        print('File downloaded successfully %s' %(bucket))
    return {
        'statusCode': 200,
        'body': json.dumps('File Processed Successfully')
    }