import boto3
import pandas as pd
import numpy as np
import json
import os
from datetime import datetime, timedelta

# AWS Clients
dynamodb = boto3.client('dynamodb')
cognito = boto3.client('cognito-idp')
ses = boto3.client('ses')

# Environment Variables (set in Lambda)
TABLE_NAME = "SensorDataTable"
USER_POOL_ID = "eu-central-1_kAynkScAT"
SENDER_EMAIL = "ropeiz2663@gmail.com" # To be changed to the walkingstick company email

# Parameters for fall detection
window_size = 8
var_threshold = 0.5
delta_threshold = 0.6
duration_threshold = 3

def lambda_handler(event, context):
    print("Lambda execution started.")
    try:
        # Get the current time and 10 minutes ago in milliseconds
        now = int(datetime.utcnow().timestamp() * 1000)
        ten_min_ago = now - 10 * 60 * 1000  # 10 minutes in milliseconds

        print(f"Querying DynamoDB for items with timestamp between {ten_min_ago} and {now}...")

        # Scan the table with a FilterExpression
        response = dynamodb.scan(
            TableName=TABLE_NAME,
            FilterExpression="#ts BETWEEN :start_time AND :end_time",
            ExpressionAttributeNames={
                "#ts": "timestamp",  # Alias for reserved keyword
                "#sc": "stick_code",  # Alias for stick_code
                "#imu": "IMU"         # Alias for IMU
            },
            ExpressionAttributeValues={
                ":start_time": {"N": str(ten_min_ago)},
                ":end_time": {"N": str(now)}
            },
            ProjectionExpression="#ts, #sc, #imu"  # Include timestamp, stick_code, and IMU
        )

        # Group data by stick_code
        items = response.get('Items', [])
        print(f"Retrieved {len(items)} items from DynamoDB.")
        #print(items)

        stick_data = {}
        for item in items:
            # Extract values from the DynamoDB JSON format
            stick_code = item['stick_code']['S']  # Extract 'S' for string
            imu_data = json.dumps(item['IMU']['M'])  # Extract 'M' for map and convert to JSON string
            timest = int(item['timestamp']['N'])  # Extract 'N' for number
            
            # Group data by stick_code
            if stick_code not in stick_data:
                stick_data[stick_code] = []
            stick_data[stick_code].append({'IMU': imu_data, 'timestamp': timest})

        print(f"Data grouped by stick_code. Processing {len(stick_data)} unique stick codes.")


        # Process each stick_code's data
        for stick_code, data in stick_data.items():
            print(f"Processing data for stick_code: {stick_code}")
            df = pd.DataFrame(data)
            result, has_tembleque = process_imu_data(df)

            if has_tembleque:
                print(f"Possible fall detected for stick_code: {stick_code}")
                # Find user's email using Cognito
                emails = get_user_emails(stick_code)
                if emails:
                    for email in emails:
                        print(f"Email retrieved for stick_code {stick_code}: {email}")
                        # Send email notification
                        send_email_notification(email, stick_code)
                else:
                    print(f"No email found for stick_code {stick_code}.")
            else:
                print(f"No fall detected for stick_code: {stick_code}")

        print("Processing completed successfully.")
        return {"statusCode": 200, "body": "Processing completed successfully."}

    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": str(e)}

# Our algorithm to detect possible imbalances
def process_imu_data(data):
    print("Extracting and processing IMU data...")
    # Parse the IMU JSON
    def extract_imu_data(row):
        try:
            imu_data = json.loads(row['IMU'])
            accelerometer = imu_data["accelerometer"]["M"]
            return {
                "x": float(accelerometer["x"]["S"]),
                "y": float(accelerometer["y"]["S"]),
                "z": float(accelerometer["z"]["S"]),
            }
        except (KeyError, TypeError, json.JSONDecodeError):
            return {"x": None, "y": None, "z": None}
    
    imu_extracted = data.apply(extract_imu_data, axis=1)
    imu_df = pd.json_normalize(imu_extracted)
    data = pd.concat([data, imu_df], axis=1)

    data[['x', 'y', 'z']] = data[['x', 'y', 'z']].apply(pd.to_numeric, errors='coerce')
    data['accel_magnitude'] = np.sqrt(data['x']**2 + data['y']**2 + data['z']**2)
    data['accel_variance'] = data['accel_magnitude'].rolling(window=window_size).var()
    data['delta_accel_x'] = data['x'].diff().abs()
    data['delta_accel_y'] = data['y'].diff().abs()
    data['delta_accel_z'] = data['z'].diff().abs()

    data['is_tembleque'] = (
        (data['accel_variance'] > var_threshold) |
        ((data['delta_accel_x'] > delta_threshold).astype(int) +
         (data['delta_accel_y'] > delta_threshold).astype(int) +
         (data['delta_accel_z'] > delta_threshold).astype(int) >= 2)
    )

    data['tembleque_duration'] = (
        data['is_tembleque']
        .astype(int)
        .groupby((data['is_tembleque'] != data['is_tembleque'].shift()).cumsum())
        .transform('count') * data['is_tembleque']
    )

    has_tembleque = any(data['tembleque_duration'] >= duration_threshold)
    print("Processing complete for IMU data.")
    return data, has_tembleque

def get_user_emails(stick_code):
    print(f"Fetching user emails for stick_code: {stick_code} and type: Supervisor")
    try:
        users = []
        pagination_token = None

        # Loop to handle pagination
        while True:
            if pagination_token:
                response = cognito.list_users(
                    UserPoolId=USER_POOL_ID,
                    PaginationToken=pagination_token
                )
            else:
                response = cognito.list_users(
                    UserPoolId=USER_POOL_ID
                )

            # Add users from the current page
            users.extend(response.get('Users', []))

            # Check if there's a next page
            pagination_token = response.get('PaginationToken')
            if not pagination_token:
                break

        # Filter users manually by custom attributes
        emails = []
        for user in users:
            stick_code_match = False
            type_match = False
            email = None

            for attr in user['Attributes']:
                if attr['Name'] == 'custom:StickCode' and attr['Value'] == stick_code:
                    stick_code_match = True
                if attr['Name'] == 'custom:Type' and attr['Value'] == 'Supervisor':
                    type_match = True
                if attr['Name'] == 'email':
                    email = attr['Value']

            if stick_code_match and type_match and email:
                emails.append(email)

        if not emails:
            print(f"No emails found for stick_code {stick_code} and type Supervisor.")
        return emails
    except Exception as e:
        print(f"Error retrieving emails for stick_code {stick_code}: {str(e)}")
    return []

def send_email_notification(email, stick_code):
    print(f"Sending email notification to {email} for stick_code: {stick_code}")
    try:
        ses.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': [email]},
            Message={
                'Subject': {'Data': 'Fall Detected Alert'},
                'Body': {
                    'Text': {'Data': f"A potential fall has been detected for your stick with code {stick_code}. Please check on the user."}
                }
            }
        )
        print(f"Email sent successfully to {email}.")
    except Exception as e:
        print(f"Error sending email to {email}: {str(e)}")