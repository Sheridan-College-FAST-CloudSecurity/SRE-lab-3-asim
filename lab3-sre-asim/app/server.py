import boto3
import json
import os

# The code below is for retreiving a secret
def get_db_credentials():
    secret_name = os.environ.get("DB_SECRET_NAME")
    region_name = os.environ.get("AWS_REGION", "us-east-1")

    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=region_name)

    response = client.get_secret_value(SecretId=secret_name)
    secret_dict = json.loads(response["SecretString"])
    return secret_dict["username"], secret_dict["password"]