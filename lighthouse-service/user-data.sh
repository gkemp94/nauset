#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
WORKING_DIR=/root/nauset/lighthouse-service

# Update & Install Dependencies
yum -y --security update
yum -y update aws-cli
yum -y install jq 

# Install & Launch Logs
aws configure set default.region $REGION
yum -y install awslogs
cp -av $WORKING_DIR/awslogs.conf /etc/awslogs/
sed -i "s|us-east-1|$REGION|g" /etc/awslogs/awscli.conf
sed -i "s|%CLOUDWATCHLOGSGROUP%|$CLOUDWATCHLOGSGROUP|g" /etc/awslogs/awslogs.conf
systemctl start awslogsd

# Install Chrome
curl https://intoli.com/install-google-chrome.sh | bash

# Install Node
curl --silent --location https://rpm.nodesource.com/setup_14.x | sudo bash -
yum install -y nodejs

# Install Lighthouse
npm install lighthouse -g

# Copy Bash Script to Bin
cp -av $WORKING_DIR/lighthouse-worker.sh /usr/local/bin

# Populate Worker Scripts w/ Variables
sed -i "s|%REGION%|$REGION|g" /usr/local/bin/lighthouse-worker.sh
sed -i "s|%SQSQUEUE%|$SQSQUEUE|g" /usr/local/bin/lighthouse-worker.sh


# TODO: This needs to be improved so if it fails/crashes it will recover
chmod +x /usr/local/bin/lighthouse-worker.sh
exec /usr/local/bin/lighthouse-worker.sh
