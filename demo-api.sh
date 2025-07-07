#!/bin/bash

# Demo script for AWS Lambda REST API with IAM Authentication
# This script demonstrates how to use curl with AWS SigV4 to access the API endpoints

set -e

echo "=== AWS Lambda REST API Demo ==="
echo

# Get the API URL from CloudFormation stack outputs
API_URL=$(aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' --output text 2>/dev/null || echo "")

if [ -z "$API_URL" ]; then
    echo "ERROR: Could not find API URL. Make sure the stack is deployed."
    echo "Run: make deploy"
    exit 1
fi

echo "API URL: $API_URL"
echo

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Get AWS region
AWS_REGION=$(aws configure get region 2>/dev/null || echo "eu-west-2")

echo "Using AWS Region: $AWS_REGION"
echo

# Test endpoints
echo "=== Testing API Endpoints ==="
echo

echo "1. Health Check (GET /health)"
curl --aws-sigv4 "aws:amz:$AWS_REGION:execute-api" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     -s "$API_URL/health" | jq .
echo

echo "2. Root Endpoint (GET /)"
curl --aws-sigv4 "aws:amz:$AWS_REGION:execute-api" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     -s "$API_URL/" | jq .
echo

echo "3. Get Data (GET /data)"
curl --aws-sigv4 "aws:amz:$AWS_REGION:execute-api" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     -s "$API_URL/data" | jq .
echo

echo "4. Post Data (POST /data)"
curl --aws-sigv4 "aws:amz:$AWS_REGION:execute-api" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     -s -X POST -H "Content-Type: application/json" \
     -d '{"message":"Hello from demo script","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
     "$API_URL/data" | jq .
echo

echo "5. Test 404 (GET /nonexistent)"
curl --aws-sigv4 "aws:amz:$AWS_REGION:execute-api" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     -s "$API_URL/nonexistent" | jq .
echo

echo "=== Demo Complete ==="
echo
echo "You can now use these curl commands to interact with your API:"
echo "curl --aws-sigv4 'aws:amz:$AWS_REGION:execute-api' --user '\$AWS_ACCESS_KEY_ID:\$AWS_SECRET_ACCESS_KEY' '$API_URL/health'"