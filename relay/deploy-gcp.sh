#!/bin/bash

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
ZONE="us-central1-a"
INSTANCE_NAME="ms365-teams-relay"
FIREWALL_RULE="allow-relay-http"
STATIC_IP_NAME="ms365-relay-ip"
PORT=8080

echo "Using Project: $PROJECT_ID"
echo "Region: $REGION"

# 1. Reserve Static IP
echo "--- Reserving Static IP ---"
if gcloud compute addresses describe $STATIC_IP_NAME --region=$REGION > /dev/null 2>&1; then
    echo "IP $STATIC_IP_NAME already exists."
else
    gcloud compute addresses create $STATIC_IP_NAME --region=$REGION
fi

IP_ADDRESS=$(gcloud compute addresses describe $STATIC_IP_NAME --region=$REGION --format="value(address)")
echo "Static IP: $IP_ADDRESS"

# 2. Create Firewall Rule
echo "--- Creating Firewall Rule ---"
if gcloud compute firewall-rules describe $FIREWALL_RULE > /dev/null 2>&1; then
    echo "Firewall rule $FIREWALL_RULE already exists."
else
    gcloud compute firewall-rules create $FIREWALL_RULE \
        --allow tcp:$PORT \
        --target-tags=relay-server \
        --description="Allow incoming traffic on port $PORT for Teams Relay"
fi

# 3. Create VM Instance
echo "--- Creating VM Instance ---"
# We use a standard Ubuntu image and a startup script to install Docker
if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE > /dev/null 2>&1; then
    echo "Instance $INSTANCE_NAME already exists."
else
    gcloud compute instances create $INSTANCE_NAME \
        --zone=$ZONE \
        --machine-type=e2-micro \
        --image-family=ubuntu-2204-lts \
        --image-project=ubuntu-os-cloud \
        --address=$IP_ADDRESS \
        --tags=relay-server,http-server,https-server \
        --metadata=startup-script='#! /bin/bash
            apt-get update
            apt-get install -y docker.io git
            systemctl start docker
            systemctl enable docker
            usermod -aG docker $USER
        '
fi

echo "--- Deployment Prep Complete ---"
echo "VM '$INSTANCE_NAME' is running at $IP_ADDRESS"
echo ""
echo "Next Steps:"
echo "1. Build and copy your code to the VM:"
echo "   tar -czf relay.tar.gz src package.json tsconfig.json Dockerfile"
echo "   gcloud compute scp relay.tar.gz $INSTANCE_NAME:~ --zone=$ZONE"
echo ""
echo "2. SSH into the VM and run the container:"
echo "   gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "   # Inside VM:"
echo "   tar -xzf relay.tar.gz"
echo "   sudo docker build -t teams-relay ."
echo "   sudo docker run -d -p 8080:8080 --name relay teams-relay"
