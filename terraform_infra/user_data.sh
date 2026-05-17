#!/bin/bash
set -e

apt-get update
apt-get upgrade -y

apt-get install -y docker.io docker-compose

systemctl start docker
systemctl enable docker

usermod -aG docker ubuntu

cd /home/ubuntu
git clone https://github.com/your-repo/containerized_Ecommerce_Microservices.git

cd containerized_Ecommerce_Microservices-main

docker-compose up -d

echo "Deployment completed successfully" > /var/log/deployment.log