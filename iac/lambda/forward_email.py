# Copyright 2010 - 2019 Amazon.com, Inc.or its affiliates.All Rights Reserved.
#
# This file is licensed under the Apache License, Version 2.0(the "License").
# You may not use this file except in compliance with the License.A copy of the
# License is located at 
#
# http://aws.amazon.com/apache2.0/
#
# This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, either express or implied.See the License for the specific
# language governing permissions and limitations under the License.

"""
AWS Lambda Email Forwarding Function

This Lambda function is triggered by Amazon SES when an email is received at hi@brignano.io.
It retrieves the email from an S3 bucket, processes it, and forwards it to a personal email address.

Environment Variables Required:
    S3_BUCKET_NAME (str): The name of the S3 bucket where SES stores incoming emails
    S3_BUCKET_PREFIX (str): The prefix/folder path in the S3 bucket (typically "emails")
    FORWARD_TO_EMAIL (str): The destination email address to forward messages to
    REGION (str): The AWS region where resources are deployed
    LOG_LEVEL (str): Logging level (INFO, DEBUG, WARNING, ERROR)

Flow:
    1. SES receives email at hi@brignano.io
    2. SES stores raw email in S3 bucket
    3. SES triggers this Lambda function via receipt rule
    4. Lambda retrieves email from S3
    5. Lambda parses and reformats the email
    6. Lambda sends forwarded email via SES to personal email address
"""

import json
import os
import boto3
import email
import re
import logging
logger = logging.getLogger('forward_email')
logger.setLevel(os.environ['LOG_LEVEL'] or "INFO")

from botocore.exceptions import ClientError
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

region = os.environ['REGION']


def get_message_from_s3(message_id):
    """
    Retrieve an email message from S3 bucket.
    
    Args:
        message_id (str): The unique message ID provided by SES, used as the S3 object key
        
    Returns:
        dict: Dictionary containing the raw email file content and S3 console URL path
            {
                "file": bytes,  # Raw email content
                "path": str     # HTTPS URL to S3 console for the email object
            }
            
    Raises:
        ClientError: If S3 object retrieval fails
    """
    incoming_email_bucket = os.environ['S3_BUCKET_NAME']
    incoming_email_prefix = os.environ['S3_BUCKET_PREFIX']

    if incoming_email_prefix:
        object_path = (incoming_email_prefix + "/" + message_id)
    else:
        object_path = message_id

    object_https_path = (f"https://s3.console.aws.amazon.com/s3/object/{incoming_email_bucket}/{object_path}?region={region}")

    logger.debug(f"Getting email from {object_https_path}")

    # Create a new S3 client.
    client_s3 = boto3.client("s3")

    # Get the email object from the S3 bucket.
    object_s3 = client_s3.get_object(Bucket = incoming_email_bucket, Key = object_path)
    logger.debug(f"S3 object: {json.dumps(object_s3, default=str)}")
    
    # Read the content of the message.
    file = object_s3['Body'].read()
    logger.debug(f"Email content: {json.dumps(file, default=str)}")

    file_dict = {
        "file": file,
        "path": object_https_path
    }

    return file_dict


def create_message(file_dict):
    """
    Parse the raw email and construct a new message for forwarding.
    
    Args:
        file_dict (dict): Dictionary containing raw email file and path from get_message_from_s3()
        
    Returns:
        dict: Message dictionary ready for SES send_raw_email API
            {
                "Source": str,        # Original sender email
                "Destinations": str,  # Forward-to email address
                "Data": str          # Raw MIME message as string
            }
            
    Note:
        - Preserves original sender and subject
        - Sets To: header to hi@brignano.io
        - Extracts and logs Reply-To, CC, and BCC headers for debugging
        - Does not currently forward Reply-To, CC, or BCC headers (see TODO below)
    """
    forward_to_email = os.environ['FORWARD_TO_EMAIL']

    # Parse the email body.
    mailobject = email.message_from_string(file_dict['file'].decode('utf-8'))

    logger.debug(f"Mail object: {json.dumps(mailobject, default=str)}")

    # Extract email headers
    subject = mailobject.get('Subject')
    from_email = mailobject.get('From')
    reply_to = mailobject.get('Reply-To')
    cc = mailobject.get('Cc')
    bcc = mailobject.get('Bcc')
    
    # Log extracted headers for debugging and future implementation
    logger.info(f"Email headers - From: {from_email}, Subject: {subject}")
    if reply_to:
        logger.info(f"Reply-To header found: {reply_to}")
    if cc:
        logger.info(f"CC header found: {cc}")
    if bcc:
        logger.info(f"BCC header found: {bcc}")

    # Get the body from the mailobject.
    body = mailobject.get_payload().rstrip()
    logger.debug(f"Body: {body}")

    # Create a multipart/mixed parent container.
    msg = MIMEMultipart('mixed')
    msg['To'] = "hi@brignano.io"
    msg['From'] = from_email
    msg['Subject'] = subject
    # TODO: Preserve and forward Reply-To, CC, and BCC headers from original email
    # This would allow replying directly to original sender and maintaining email threads
    # Headers are now extracted and logged above for future implementation
    msg.attach(MIMEText(body, 'plain', 'utf-8'))

    message = {
        "Source": from_email,
        "Destinations": forward_to_email,
        "Data": msg.as_string()
    }

    logger.debug(f"Message: {message}")

    return message


def send_email(message) -> None:
    """
    Send the forwarded email using Amazon SES.
    
    Args:
        message (dict): Message dictionary from create_message() containing:
            - Source: Original sender email
            - Destinations: Forward-to email address
            - Data: Raw MIME message string
            
    Returns:
        None
        
    Raises:
        ClientError: If SES send_raw_email API call fails
        
    Note:
        Logs the SES MessageId upon successful delivery
    """
    # Create a new SES client.
    client_ses = boto3.client('ses', region)

    # Send the email.
    try:
        # Provide the contents of the email.
        response = client_ses.send_raw_email(
            Source = message['Source'],
            Destinations = [
                message['Destinations']
            ],
            RawMessage = {
                'Data': message['Data']
            }
        )

    # Display an error if something goes wrong.
    except ClientError as e:
        raise e
    else:
        logger.info(f"Email sent! Message ID: {response['MessageId']}")

def lambda_handler(event, context):
    """
    AWS Lambda handler function triggered by SES receipt rule.
    
    This is the main entry point for the Lambda function. It processes SES events,
    retrieves emails from S3, and forwards them to the configured destination.
    
    Args:
        event (dict): AWS Lambda event object from SES containing:
            - Records: List of SES receipt records
            - Records[n].ses.mail.messageId: Unique message identifier
        context (object): AWS Lambda context object (unused)
        
    Returns:
        None
        
    Raises:
        Exception: Any errors during processing are logged and re-raised
        
    Event Structure:
        {
            "Records": [{
                "ses": {
                    "mail": {
                        "messageId": "unique-message-id",
                        "source": "sender@example.com",
                        ...
                    }
                }
            }]
        }
    """
    try:
        # Get the unique ID of the message.This corresponds to the name of the file in S3.
        logger.debug(f"SES Records (len={len(event['Records'])}): {json.dumps(event['Records'])}")
        message_id = event['Records'][0]['ses']['mail']['messageId']
        logger.debug(f"Sample SES Event: {json.dumps(event['Records'][0])}")
        logger.info(f"Forwarding message ID {message_id}")

        # Retrieve the file from the S3 bucket.
        file_dict = get_message_from_s3(message_id)

        # Create the message.
        message = create_message(file_dict)

        # Send the email and log the result.
        send_email(message)
    except Exception as e:
        logger.error(str(e))
        raise e