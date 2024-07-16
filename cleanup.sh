#!/bin/bash

# Variables
REGION="us-east-1"
KEY_NAME="my-key-pair" # Replace with your key pair name

# Function to delete EC2 instances
delete_instances() {
  echo "Fetching instance IDs..."
  INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Kubernetes-Instance-*" --query "Reservations[].Instances[].InstanceId" --region $REGION --output text)
  
  if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
    echo "Instances terminated."
  else
    echo "No instances found."
  fi
}

# Function to delete security group
delete_security_group() {
  echo "Fetching security group ID..."
  SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=k8s-security-group" --query "SecurityGroups[0].GroupId" --region $REGION --output text)
  
  if [ -n "$SECURITY_GROUP_ID" ]; then
    echo "Deleting security group: $SECURITY_GROUP_ID"
    aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID --region $REGION
    echo "Security group deleted."
  else
    echo "No security group found."
  fi
}

# Function to delete route table
delete_route_table() {
  echo "Fetching route table ID..."
  ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main==`false`].RouteTableId" --region $REGION --output text)
  
  if [ -n "$ROUTE_TABLE_ID" ]; then
    echo "Deleting route table: $ROUTE_TABLE_ID"
    aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID --region $REGION
    echo "Route table deleted."
  else
    echo "No route table found."
  fi
}

# Function to detach and delete internet gateway
delete_internet_gateway() {
  echo "Fetching internet gateway ID..."
  IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --region $REGION --output text)
  
  if [ -n "$IGW_ID" ]; then
    echo "Detaching and deleting internet gateway: $IGW_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION
    echo "Internet gateway deleted."
  else
    echo "No internet gateway found."
  fi
}

# Function to delete subnets
delete_subnets() {
  echo "Fetching subnet IDs..."
  SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --region $REGION --output text)
  
  if [ -n "$SUBNET_IDS" ]; then
    for SUBNET_ID in $SUBNET_IDS; do
      echo "Deleting subnet: $SUBNET_ID"
      aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION
    done
    echo "Subnets deleted."
  else
    echo "No subnets found."
  fi
}

# Function to delete VPC
delete_vpc() {
  echo "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
  echo "VPC deleted."
}

# Main cleanup function
cleanup() {
  # Terminate instances
  delete_instances

  # Delete security group
  delete_security_group

  # Delete route table
  delete_route_table

  # Detach and delete internet gateway
  delete_internet_gateway

  # Delete subnets
  delete_subnets

  # Delete VPC
  delete_vpc

  echo "Cleanup completed."
}

# Fetch VPC ID based on CIDR block
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=cidr,Values=$VPC_CIDR" --query "Vpcs[0].VpcId" --region $REGION --output text)

if [ -n "$VPC_ID" ]; then
  cleanup
else
  echo "No VPC found with CIDR $VPC_CIDR"
fi
