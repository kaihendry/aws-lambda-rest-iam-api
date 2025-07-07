.PHONY: build clean deploy destroy test test-api test-api-with-temp-creds local-start local-invoke help api-url curl-examples

# Default target
help:
	@echo "Available commands:"
	@echo "  build                    - Build the Go Lambda function"
	@echo "  clean                    - Clean build artifacts"
	@echo "  deploy                   - Deploy the SAM application"
	@echo "  destroy                  - Delete the SAM application"
	@echo "  test                     - Run Go tests"
	@echo "  test-api                 - Test deployed API (requires awscurl)"
	@echo "  test-api-with-temp-creds - Test API with temporary credentials (for SSO)"
	@echo "  local-start              - Start API Gateway locally"
	@echo "  local-invoke             - Invoke function locally"
	@echo "  deps                     - Download Go dependencies"
	@echo "  api-url                  - Show deployed API URL"
	@echo "  curl-examples            - Show example curl commands"

# Build the Go Lambda function for SAM
build-ApiFunction:
	@echo "Building Go Lambda function for SAM..."
	@echo "Current directory: $$(pwd)"
	@echo "Building with: GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap ../../cmd/api/main.go"
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap ../../cmd/api/main.go

# Build the Go Lambda function
build:
	@echo "Building Go Lambda function..."
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o cmd/api/bootstrap cmd/api/main.go
	sam build

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .aws-sam/
	rm -f cmd/api/bootstrap
	go clean

# Deploy the SAM application
deploy: build
	@echo "Deploying SAM application..."
	sam deploy --guided --capabilities CAPABILITY_IAM

# Deploy without prompts (for CI/CD)
deploy-ci: build
	@echo "Deploying SAM application (CI mode)..."
	sam deploy --no-confirm-changeset --no-fail-on-empty-changeset --capabilities CAPABILITY_IAM

# Delete the SAM application
destroy:
	@echo "Deleting SAM application..."
	sam delete

# Run Go tests
test:
	@echo "Running Go tests..."
	go test -v ./...

# Download Go dependencies
deps:
	@echo "Downloading Go dependencies..."
	go mod download
	go mod tidy

# Start API Gateway locally for development
local-start: build
	@echo "Starting API Gateway locally..."
	sam local start-api

# Invoke function locally
local-invoke: build
	@echo "Invoking function locally..."
	sam local invoke ApiFunction

# Generate sample events for testing
generate-event:
	@echo "Generating sample API Gateway event..."
	sam local generate-event apigateway aws-proxy > events/sample-event.json

# Validate SAM template
validate:
	@echo "Validating SAM template..."
	sam validate

# Package for deployment
package: build
	@echo "Packaging SAM application..."
	sam package --s3-bucket $(if $(S3_BUCKET),$(S3_BUCKET),$(error S3_BUCKET is required))

# Show stack outputs
outputs:
	@echo "Getting stack outputs..."
	aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs' --output table

# Show API URL
api-url:
	@aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' --output text

# Show API Access Role ARN
role-arn:
	@aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs[?OutputKey==`ApiAccessRoleArn`].OutputValue' --output text

# Test the deployed API with awscurl and AWS SigV4
test-api:
	@echo "=== Testing AWS Lambda REST API with IAM Authentication ==="
	@API_URL=$$(make api-url); \
	AWS_REGION=$$(aws configure get region 2>/dev/null || echo "eu-west-2"); \
	echo "API URL: $$API_URL"; \
	echo "Region: $$AWS_REGION"; \
	echo ""; \
	echo "1. Testing Health Check (GET /health)"; \
	awscurl --service execute-api --region $$AWS_REGION "$$API_URL/health" | jq .; \
	echo ""; \
	echo "2. Testing Root Endpoint (GET /)"; \
	awscurl --service execute-api --region $$AWS_REGION "$$API_URL/" | jq .; \
	echo ""; \
	echo "3. Testing Get Data (GET /data)"; \
	awscurl --service execute-api --region $$AWS_REGION "$$API_URL/data" | jq .; \
	echo ""; \
	echo "4. Testing Post Data (POST /data)"; \
	awscurl --service execute-api --region $$AWS_REGION -X POST -H 'Content-Type: application/json' -d '{"message":"Test from Makefile","timestamp":"'$$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' "$$API_URL/data" | jq .; \
	echo ""; \
	echo "5. Testing 404 Error (GET /nonexistent)"; \
	awscurl --service execute-api --region $$AWS_REGION "$$API_URL/nonexistent" | jq .; \
	echo ""; \
	echo "6. Testing Unauthenticated Request (should fail)"; \
	echo "   curl (without auth): $$API_URL/health"; \
	curl -s "$$API_URL/health" | jq .; \
	echo ""; \
	echo "=== API Testing Complete ==="

# Test with temporary credentials (for SSO users)
test-api-with-temp-creds:
	@echo "Getting temporary credentials for API testing..."
	@API_URL=$$(make api-url); \
	AWS_REGION=$$(aws configure get region 2>/dev/null || echo "eu-west-2"); \
	echo "API URL: $$API_URL"; \
	echo "Region: $$AWS_REGION"; \
	echo ""; \
	echo "Getting temporary credentials..."; \
	CREDS=$$(aws sts get-session-token --output json); \
	export AWS_ACCESS_KEY_ID=$$(echo $$CREDS | jq -r '.Credentials.AccessKeyId'); \
	export AWS_SECRET_ACCESS_KEY=$$(echo $$CREDS | jq -r '.Credentials.SecretAccessKey'); \
	export AWS_SESSION_TOKEN=$$(echo $$CREDS | jq -r '.Credentials.SessionToken'); \
	echo "Testing health endpoint with temporary credentials:"; \
	curl --aws-sigv4 "aws:amz:$$AWS_REGION:execute-api" \
		--user "$$AWS_ACCESS_KEY_ID:$$AWS_SECRET_ACCESS_KEY" \
		-H "X-Amz-Security-Token: $$AWS_SESSION_TOKEN" \
		"$$API_URL/health" | jq .

# Show example awscurl commands
curl-examples:
	@echo "=== Example awscurl Commands ==="
	@API_URL=$$(make api-url); \
	AWS_REGION=$$(aws configure get region 2>/dev/null || echo "eu-west-2"); \
	echo "API URL: $$API_URL"; \
	echo "Region: $$AWS_REGION"; \
	echo ""; \
	echo "Health check:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_URL/health'"; \
	echo ""; \
	echo "Get root:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_URL/'"; \
	echo ""; \
	echo "Get data:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_URL/data'"; \
	echo ""; \
	echo "Post data:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION \\"; \
	echo "        -X POST -H 'Content-Type: application/json' \\"; \
	echo "        -d '{\"message\":\"Hello World\"}' \\"; \
	echo "        '$$API_URL/data'"; \
	echo ""; \
	echo "Test without authentication (should fail):"; \
	echo "curl '$$API_URL/health'"