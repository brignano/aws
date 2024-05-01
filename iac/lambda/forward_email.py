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
    forward_to_email = os.environ['FORWARD_TO_EMAIL']

    # Parse the email body.
    mailobject = email.message_from_string(file_dict['file'].decode('utf-8'))

    logger.debug(f"Mail object: {json.dumps(mailobject, default=str)}")

    # Create a new subject line.
    subject = mailobject.get('Subject')
    from_email = mailobject.get('From')

    # Get the body from the mailobject.
    body = mailobject.get_payload().rstrip()
    logger.debug(f"Body: {body}")

    # Create a multipart/mixed parent container.
    msg = MIMEMultipart('mixed')
    msg['To'] = "hi@brignano.io"
    msg['From'] = from_email
    msg['Subject'] = subject
    # todo: add reply-to and cc/bcc
    msg.attach(MIMEText(body, 'plain', 'utf-8'))

    message = {
        "Source": from_email,
        "Destinations": forward_to_email,
        "Data": msg.as_string()
    }

    logger.debug(f"message: {message}")

    return message


def send_email(message):
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
        output = e.response['Error']['Message']
    else:
        output = "Email sent! Message ID: " + response['MessageId']

    return output


def lambda_handler(event, context):
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
    result = send_email(message)
    logger.info(result)