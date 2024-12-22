import json
import boto3
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize SES client
ses_client = boto3.client('ses')

def lambda_handler(event, context):
    try:
        # Parse the input JSON
        stick_carrier = event['stickCarrier']
        recipient_email = event['email']
        gps_location = event['gpsLocation']  # Expected format: "LATITUDE,LONGITUDE"

        # Validate and construct Google Maps link
        if ',' not in gps_location:
            raise ValueError("Invalid GPS location format. Expected 'LATITUDE,LONGITUDE'")
        
        latitude, longitude = gps_location.split(',')
        latitude, longitude = latitude.strip(), longitude.strip()

        # Construct Google Maps link
        google_maps_link = f"https://www.google.com/maps?q={latitude},{longitude}"

        # Construct the email content
        subject = f"Alert: {stick_carrier} Has Fallen"
        body = f"""
        <html>
            <body>
                <h1>Alert!</h1>
                <p>{stick_carrier} has fallen!</p>
                <p>Location: <a href="{google_maps_link}" target="_blank">View on Google Maps</a></p>
            </body>
        </html>
        """

        # Send the email via Amazon SES
        response = ses_client.send_email(
            Source='ropeiz2663@gmail.com', # To be changed using cognito, identifying all supervisors emails as done in check_tembleque.py
            Destination={
                'ToAddresses': [recipient_email]
            },
            Message={
                'Subject': {
                    'Data': subject
                },
                'Body': {
                    'Html': {
                        'Data': body
                    }
                }
            }
        )

        # Log the response
        logger.info(f"Email sent to {recipient_email}, Response: {response}")

        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Email sent successfully!'})
        }
    except Exception as e:
        logger.error(f"Error sending email: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
