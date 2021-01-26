#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=%REGION%
# S3BUCKET=%S3BUCKET%
SQSQUEUE=%SQSQUEUE%
AUTOSCALINGGROUP=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=aws:autoscaling:groupName" | jq -r '.Tags[0].Value')

while sleep 5; do 

  JSON=$(aws sqs --output=json get-queue-attributes \
    --queue-url $SQSQUEUE \
    --attribute-names ApproximateNumberOfMessages)
  MESSAGES=$(echo "$JSON" | jq -r '.Attributes.ApproximateNumberOfMessages')

  if [ $MESSAGES -eq 0 ]; then
    continue
  fi
  
  $CURL_RESULT = curl -Isf http://169.254.169.254/latest/meta-data/spot/instance-action
  logger "Curl Result: $CURL_RESULT"
  
  # if [ -n $(curl -Isf http://169.254.169.254/latest/meta-data/spot/instance-action) ]; then
  #  logger "$0: Spot instance interruption notice detected."
  #  sleep 120
  #  continue
  # fi

  JSON=$(aws sqs --output=json receive-message --queue-url $SQSQUEUE --max-number-of-messages 1 --wait-time-seconds 10)
  RECEIPT=$(echo "$JSON" | jq -r '.Messages[] | .ReceiptHandle')
  BODY=$(echo "$JSON" | jq -r '.Messages[] | .Body')

  if [ -z "$RECEIPT" ]; then

    logger "$0: Empty receipt. Something went wrong."
    continue

  fi

  logger "$0: Found $MESSAGES messages in $SQSQUEUE. Details: JSON=$JSON, RECEIPT=$RECEIPT, BODY=$BODY"

  DOMAIN=$(echo "$BODY" | jq -r '.Records[0] | .domain')
  OBJECTID=$(echo "$BODY" | jq -r '.Records[0] | .objectId')
  CALLBACK=$(echo "$BODY" | jq -r '.Records[0] | .callback')

  logger "$0: Found work to convert. Details: INPUT=$INPUT, FNAME=$FNAME, FEXT=$FEXT"

  logger "$0: Running: aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALINGGROUP --protected-from-scale-in"

  aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALINGGROUP --protected-from-scale-in

  # Produce Lighthouse Report
  REPORT=$(lighthouse $DOMAIN --headless --no-sandbox --output=json)

  # Post to Callback URL
  curl -d $REPORT -H 'Content-Type: application/json' $CALLBACK

  logger "$0: Running: aws sqs --output=json delete-message --queue-url $SQSQUEUE --receipt-handle $RECEIPT"

  aws sqs --output=json delete-message --queue-url $SQSQUEUE --receipt-handle $RECEIPT

  logger "$0: Running: aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALINGGROUP --no-protected-from-scale-in"

  aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALINGGROUP --no-protected-from-scale-in

done