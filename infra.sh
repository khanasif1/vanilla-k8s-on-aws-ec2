#!/bin/bash

# Variables
REGION="us-west-2"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"
SECURITY_GROUP_NAME="k8s-security-group"
SECURITY_GROUP_DESC="Security group for Kubernetes cluster"
KEY_NAME="k8s-kp-x" # Replace with your key pair name
AMI_ID="ami-0577a6ec46b349644" # Ubuntu 20.04 LTS in us-east-1
INSTANCE_TYPE="t2.medium"

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --output json | jq -r '.Vpc.VpcId')
echo "VPC ID '$VPC_ID' created."

# Enable DNS support and DNS hostname
output=$(aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}" --region $REGION)
output=$(aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION)

# Create Public Subnet
echo "Creating Public Subnet..."
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUBLIC_SUBNET_CIDR --region $REGION --output json | jq -r '.Subnet.SubnetId')
echo "Public Subnet ID '$PUBLIC_SUBNET_ID' created."

# Create Private Subnet
echo "Creating Private Subnet..."
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIVATE_SUBNET_CIDR --region $REGION --output json | jq -r '.Subnet.SubnetId')
echo "Private Subnet ID '$PRIVATE_SUBNET_ID' created."

# Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --output json | jq -r '.InternetGateway.InternetGatewayId')
echo "Internet Gateway ID '$IGW_ID' created."

# Attach Internet Gateway to VPC
echo "Attaching Internet Gateway to VPC..."
output=$(aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION)

# Create Route Table
echo "Creating Route Table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --output json | jq -r '.RouteTable.RouteTableId')
echo "Route Table ID '$ROUTE_TABLE_ID' created."

# Create Route to Internet Gateway
echo "Creating Route to Internet Gateway..."
output=$(aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION)

# Associate Route Table with Public Subnet
echo "Associating Route Table with Public Subnet..."
output=$(aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $PUBLIC_SUBNET_ID --region $REGION)

# Modify Public Subnet to Auto-assign Public IPs
echo "Modifying Public Subnet to Auto-assign Public IPs..."
output=$(aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_ID --map-public-ip-on-launch --region $REGION)

# Create Security Group
echo "Creating Security Group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "$SECURITY_GROUP_DESC" --vpc-id $VPC_ID --region $REGION --output json | jq -r '.GroupId')
echo "Security Group ID '$SECURITY_GROUP_ID' created."

# Add Rules to Security Group
echo "Adding Rules to Security Group..."

# Allow SSH
output=$(aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr $VPC_CIDR  --region $REGION)

# Allow Kubernetes API Server
output=$(aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 6443 --cidr $VPC_CIDR  --region $REGION)

# Allow etcd
output=$(aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 2379-2380 --cidr $VPC_CIDR  --region $REGION)

# Allow Kubelet API
output=$(aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 10250 --cidr $VPC_CIDR  --region $REGION)

# Allow kube-scheduler
output=$(aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 10251 --cidr $VPC_CIDR  --region $REGION)

# Allow kube-controller-manager
output=$(aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 10252 --cidr $VPC_CIDR  --region $REGION)

# Allow NodePort Services
output=$(aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 30000-32767 --cidr $VPC_CIDR  --region $REGION)

# Launch EC2 Instances
echo "Launching EC2 Instances..."

for i in 1 2
do
# SECURITY_GROUP_ID=sg-01e9fb4ca4de52be2
# PUBLIC_SUBNET_ID=subnet-03ab483f5a244ea61

  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $PUBLIC_SUBNET_ID \
    --associate-public-ip-address \
    --region $REGION \
    --output json | jq -r '.Instances[0].InstanceId')
  echo "Instance ID '$INSTANCE_ID' launched."

  # Tag the instance
  output=$(aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=Kubernetes-Instance-$i --region $REGION)
done

# Output Results
echo "VPC ID: $VPC_ID"
echo "Public Subnet ID: $PUBLIC_SUBNET_ID"
echo "Private Subnet ID: $PRIVATE_SUBNET_ID"
echo "Internet Gateway ID: $IGW_ID"
echo "Route Table ID: $ROUTE_TABLE_ID"
echo "Security Group ID: $SECURITY_GROUP_ID"

echo "All resources created and instances launched successfully."
