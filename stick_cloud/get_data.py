import json
import boto3
from boto3.dynamodb.conditions import Key
from datetime import datetime, timedelta

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = 'SensorDataTable'
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda handler to fetch GPS coordinates for a specific stick_code and date.
    """
    try:
        #print(event)
        stick_code = event.get('stick_code')
        date_str = event.get('date')  # Expected format: YYYY-MM-DD

        if not stick_code or not date_str:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': "Missing required parameters: 'stick_code' and/or 'date'"}),
                'headers': {'Content-Type': 'application/json'}
            }

        # Convert date to start and end timestamps (UTC)
        try:
            date_start = datetime.strptime(date_str, '%Y-%m-%d')
            date_end = date_start + timedelta(days=1)
        except ValueError:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': "Invalid date format. Use 'YYYY-MM-DD'"}),
                'headers': {'Content-Type': 'application/json'}
            }

        start_timestamp = int(date_start.timestamp() * 1000)
        end_timestamp = int(date_end.timestamp() * 1000)

        print(f"Start timestamp: {start_timestamp}; End timestamp: {end_timestamp}")

        # Query DynamoDB
        response = table.query(
            KeyConditionExpression=Key('stick_code').eq(stick_code) & Key('timestamp').between(start_timestamp, end_timestamp)
        )

        # Extract GPS data
        gps_data = []
        for item in response.get('Items', []):
            gps_data.append({
                'latitude': item['GPS_device']['latitude'],
                'longitude': item['GPS_device']['longitude'],
                'altitude': item['GPS_device'].get('altitude')  # Optional
            })
        
        print(f"GPS DATA found {gps_data}")

        # Return the GPS data
        return {
            'statusCode': 200,
            'body': json.dumps({'gps_data': gps_data}),
            'headers': {'Content-Type': 'application/json'}
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': f"Internal server error: {str(e)}"}),
            'headers': {'Content-Type': 'application/json'}
        }
