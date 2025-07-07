# AWS Lambda REST API with IAM Authentication

A serverless REST API built with AWS SAM and Go that uses IAM authentication for secure access.

## Features

- **IAM Authentication**: API endpoints protected with AWS IAM
- **Multiple Endpoints**: Root, health check, and data endpoints
- **AWS SigV4**: Access using curl with AWS Signature Version 4
- **CORS Enabled**: Cross-origin resource sharing configured
- **Go Lambda**: High-performance Go runtime

## API Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check endpoint
- `GET /data` - Retrieve data
- `POST /data` - Submit data

## Prerequisites

- AWS CLI configured with appropriate permissions
- AWS SAM CLI installed
- Go 1.21 or later
- curl with AWS SigV4 support

## Quick Start

### 1. Deploy the API

```bash
make deploy
```

### 2. Get API URL and Role ARN

```bash
# Get the API URL
make api-url

# Get the IAM role ARN for API access
make role-arn
```

### 3. Test with curl

```bash
# Health check
curl --aws-sigv4 'aws:amz:eu-west-2:execute-api' \
     --user 'YOUR_ACCESS_KEY:YOUR_SECRET_KEY' \
     'https://your-api-id.execute-api.eu-west-2.amazonaws.com/dev/health'

# Get data
curl --aws-sigv4 'aws:amz:eu-west-2:execute-api' \
     --user 'YOUR_ACCESS_KEY:YOUR_SECRET_KEY' \
     'https://your-api-id.execute-api.eu-west-2.amazonaws.com/dev/data'

# Post data
curl --aws-sigv4 'aws:amz:eu-west-2:execute-api' \
     --user 'YOUR_ACCESS_KEY:YOUR_SECRET_KEY' \
     -X POST -H 'Content-Type: application/json' \
     -d '{"message":"Hello World"}' \
     'https://your-api-id.execute-api.eu-west-2.amazonaws.com/dev/data'
```

## Available Commands

```bash
make help          # Show all available commands
make build         # Build the Go Lambda function
make deploy        # Deploy the SAM application
make test          # Run Go tests
make local-start   # Start API Gateway locally
make clean         # Clean build artifacts
make destroy       # Delete the SAM application
make curl-examples # Show example curl commands
```

## Local Development

Start the API locally for development:

```bash
make local-start
```

The API will be available at `http://localhost:3000`

## Authentication

The API uses AWS IAM for authentication. You need:

1. Valid AWS credentials (Access Key ID and Secret Access Key)
2. The credentials must have permission to invoke the API Gateway endpoints
3. Use AWS SigV4 signing with curl or AWS SDK

## Project Structure

```
.
├── cmd/api/main.go     # Lambda function handler
├── template.yaml       # SAM template
├── samconfig.toml     # SAM configuration
├── Makefile           # Build and deployment commands
└── go.mod             # Go module dependencies
```