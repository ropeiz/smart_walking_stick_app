import json
import boto3
from botocore.exceptions import ClientError
from datetime import datetime
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = 'SensorDataTable'
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda handler to save sensor data into DynamoDB.
    """
    try:
        # Check if the payload is in the root of the event
        if 'stick_code' in event:
            body = event  # Payload is directly in the event
        elif 'body' in event and event['body']:  # Standard Proxy Integration
            body = json.loads(event['body'])
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': "Invalid request format."}),
                'headers': {
                    'Content-Type': 'application/json',
                }
            }

        # Generate current timestamp in milliseconds
        current_timestamp = int(datetime.utcnow().timestamp() * 1000)

        # Prepare the item to be saved in DynamoDB
        item = {
            'stick_code': body['stick_code'],  # Primary key
            'user': body['user'], 
            'GPS_device': body['GPS_device'],
            'IMU': body['IMU'],
            'pressure': body['pressure'],
            'battery': body['battery'],
            'timestamp': current_timestamp,  # Add generated timestamp
        }

        # Save the item into DynamoDB
        table.put_item(Item=item)

        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Data saved successfully!'}),
            'headers': {
                'Content-Type': 'application/json',
            }
        }

    except KeyError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f"Missing key: {str(e)}"}),
            'headers': {
                'Content-Type': 'application/json',
            }
        }
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f"DynamoDB error: {str(e)}"}),
            'headers': {
                'Content-Type': 'application/json',
            }
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f"Internal server error: {str(e)}"}),
            'headers': {
                'Content-Type': 'application/json',
            }
        }
