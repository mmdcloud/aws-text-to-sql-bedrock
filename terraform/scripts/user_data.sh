#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y
# Installing Nginx
sudo apt-get install -y nginx
# Installing Node.js
curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt install nodejs -y
# Installing PM2
sudo npm i -g pm2
cd /home/ubuntu
mkdir app
# Checking out from Version Control
git clone https://github.com/mmdcloud/aws-mediaconvert
cd aws-mediaconvert/frontend
cp -r . /home/ubuntu/app/
cd /home/ubuntu/app/
# Copying Nginx config
cp /home/ubuntu/aws-mediaconvert/terraform/scripts/default /etc/nginx/sites-available/
# Installing dependencies
sudo npm i
sudo chmod 755 /home/ubuntu
# Building the project
sudo npm run build
sudo service nginx restart

# Installing AWS CloudWatch Agent
sudo apt-get update
sudo apt-get install -y wget curl unzip
wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
sudo apt-get install -f
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent
sudo systemctl status amazon-cloudwatch-agent
echo "CloudWatch agent installation completed"