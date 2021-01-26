#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
WORKING_DIR=/root/nauset/lighthouse-service

yum -y --security update

yum -y update aws-cli

yum -y install \
  awslogs jq

# Install Google Chrome
curl https://intoli.com/install-google-chrome.sh | bash

# Install Node
curl --silent --location https://rpm.nodesource.com/setup_14.x | sudo bash -
sudo yum install -y nodejs

# Install Lighthouse Globally
npm install lighthouse -g

aws configure set default.region $REGION

# Copy Over Worker Services & Scripts to bin
cp -av $WORKING_DIR/awslogs.conf /etc/awslogs/
# cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.conf /etc/init/spot-instance-interruption-notice-handler.conf
cp -av $WORKING_DIR/convert-worker.conf /etc/init/convert-worker.conf
# cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.sh /usr/local/bin/
cp -av $WORKING_DIR/convert-worker.sh /usr/local/bin

chmod +x /usr/local/bin/spot-instance-interruption-notice-handler.sh
chmod +x /usr/local/bin/convert-worker.sh

# Populate Worker Scripts w/ Variables
sed -i "s|us-east-1|$REGION|g" /etc/awslogs/awscli.conf
sed -i "s|%CLOUDWATCHLOGSGROUP%|$CLOUDWATCHLOGSGROUP|g" /etc/awslogs/awslogs.conf
sed -i "s|%REGION%|$REGION|g" /usr/local/bin/convert-worker.sh
sed -i "s|%S3BUCKET%|$S3BUCKET|g" /usr/local/bin/convert-worker.sh
sed -i "s|%SQSQUEUE%|$SQSQUEUE|g" /usr/local/bin/convert-worker.sh

chkconfig awslogs on && service awslogs restart

# start spot-instance-interruption-notice-handler
start convert-worker
