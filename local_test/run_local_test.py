import json
import sys
import os

with open('./test_event.json') as f:
    data = json.load(f)

this_dir = os.path.dirname(__file__)
lambda_src_path = os.path.join(this_dir, '..', 'lambda_src')
lambda_src_path = os.path.abspath(lambda_src_path)
sys.path.append(lambda_src_path)
from lambda_function import lambda_handler


lambda_handler(data,None)