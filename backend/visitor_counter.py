import boto3
import os
import json

dynamodb = boto3.resource("dynamodb")
table_name = os.environ["TABLE_NAME"]
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    # Use a fixed ID for the single visitor counter
    counter_id = "visitors"

    # Increment the counter
    response = table.update_item(
        Key={"id": counter_id},
        UpdateExpression="ADD visitor_count :inc",
        ExpressionAttributeValues={":inc": 1},
        ReturnValues="UPDATED_NEW"
    )

    count = response["Attributes"]["visitor_count"]

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "https://wilsonwongcloud.com",  # allow domain
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "*"
        },
        "body": json.dumps({"visitor_count": int(count)})
    }