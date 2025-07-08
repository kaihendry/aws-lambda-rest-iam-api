.PHONY: build clean deploy destroy test test-api test-api-a test-api-b test-api-b-with-role test-api-with-temp-creds assume-role assume-role-export local-start local-invoke help api-url api-a-url api-b-url curl-examples

# Default target
help:
	@echo "Available commands:"
	@echo "  build                    - Build the Go Lambda function"
	@echo "  clean                    - Clean build artifacts"
	@echo "  deploy                   - Deploy the SAM application"
	@echo "  destroy                  - Delete the SAM application"
	@echo "  test                     - Run Go tests"
	@echo "  test-api                 - Test both APIs (requires awscurl)"
	@echo "  test-api-a               - Test API A (open access)"
	@echo "  test-api-b               - Test API B (restricted access)"
	@echo "  test-api-b-with-role     - Test API B with automatic role assumption"
	@echo "  assume-role              - Assume restricted role and export credentials"
	@echo "  test-api-with-temp-creds - Test API with temporary credentials (for SSO)"
	@echo "  local-start              - Start API Gateway locally"
	@echo "  local-invoke             - Invoke function locally"
	@echo "  deps                     - Download Go dependencies"
	@echo "  api-url                  - Show deployed API URLs"
	@echo "  api-a-url                - Show API A URL"
	@echo "  api-b-url                - Show API B URL"
	@echo "  curl-examples            - Show example curl commands"

# Build the Go Lambda function for SAM
build-ApiFunction:
	@echo "Building Go Lambda function for SAM..."
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o ${ARTIFACTS_DIR}/bootstrap .

# Build the Go Lambda function
build:
	@echo "Building Go Lambda function..."
	sam build

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .aws-sam/
	rm -f bootstrap
	go clean

# Deploy the SAM application
deploy: build
	@echo "Deploying SAM application..."
	sam deploy --guided --capabilities CAPABILITY_IAM

# Deploy without prompts (for CI/CD)
deploy-ci: build
	@echo "Deploying SAM application (CI mode)..."
	sam deploy --no-confirm-changeset --no-fail-on-empty-changeset --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

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

# Show API URLs
api-url:
	@echo "=== API URLs ==="
	@echo "API A (open access):"
	@aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs[?OutputKey==`ApiAUrl`].OutputValue' --output text
	@echo "API B (restricted access):"
	@aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs[?OutputKey==`ApiBUrl`].OutputValue' --output text

# Show API A URL
api-a-url:
	@aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs[?OutputKey==`ApiAUrl`].OutputValue' --output text

# Show API B URL
api-b-url:
	@aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs[?OutputKey==`ApiBUrl`].OutputValue' --output text

# Show API B Restricted Role ARN
role-arn:
	@aws cloudformation describe-stacks --stack-name aws-lambda-rest-iam-api --query 'Stacks[0].Outputs[?OutputKey==`ApiBRestrictedRoleArn`].OutputValue' --output text

# Assume the restricted role and show export commands
assume-role:
	@echo "=== Assuming Restricted Role ==="
	@ROLE_ARN=$$(make role-arn); \
	echo "Role ARN: $$ROLE_ARN"; \
	echo ""; \
	echo "Getting temporary credentials..."; \
	CREDS=$$(aws sts assume-role --role-arn $$ROLE_ARN --role-session-name makefile-session --output json); \
	ACCESS_KEY=$$(echo $$CREDS | jq -r '.Credentials.AccessKeyId'); \
	SECRET_KEY=$$(echo $$CREDS | jq -r '.Credentials.SecretAccessKey'); \
	SESSION_TOKEN=$$(echo $$CREDS | jq -r '.Credentials.SessionToken'); \
	echo ""; \
	echo "=== Export these credentials in your shell: ==="; \
	echo "export AWS_ACCESS_KEY_ID=$$ACCESS_KEY"; \
	echo "export AWS_SECRET_ACCESS_KEY=$$SECRET_KEY"; \
	echo "export AWS_SESSION_TOKEN=$$SESSION_TOKEN"; \
	echo ""; \
	echo "=== Or run this command to export automatically: ==="; \
	echo 'eval $$(make assume-role-export)'

# Export assume-role credentials (for use with eval)
assume-role-export:
	@ROLE_ARN=$$(make role-arn); \
	CREDS=$$(aws sts assume-role --role-arn $$ROLE_ARN --role-session-name makefile-session --output json); \
	ACCESS_KEY=$$(echo $$CREDS | jq -r '.Credentials.AccessKeyId'); \
	SECRET_KEY=$$(echo $$CREDS | jq -r '.Credentials.SecretAccessKey'); \
	SESSION_TOKEN=$$(echo $$CREDS | jq -r '.Credentials.SessionToken'); \
	echo "export AWS_ACCESS_KEY_ID=$$ACCESS_KEY"; \
	echo "export AWS_SECRET_ACCESS_KEY=$$SECRET_KEY"; \
	echo "export AWS_SESSION_TOKEN=$$SESSION_TOKEN"

# Test both APIs
test-api:
	@echo "=== Testing Both APIs ==="
	@make test-api-a
	@echo ""
	@make test-api-b
	@echo "=== Both API Tests Complete ==="

# Test API A (open access)
test-api-a:
	@echo "=== Testing API A (Open Access) ==="
	@API_URL=$$(make api-a-url); \
	AWS_REGION=$$(aws configure get region 2>/dev/null || echo "eu-west-2"); \
	echo "API A URL: $$API_URL"; \
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
	echo "=== API A Testing Complete ==="

# Test API B (restricted access)
test-api-b:
	@echo "=== Testing API B (Restricted Access - Same Endpoints) ==="
	@API_URL=$$(make api-b-url); \
	AWS_REGION=$$(aws configure get region 2>/dev/null || echo "eu-west-2"); \
	ROLE_ARN=$$(make role-arn); \
	echo "API B URL: $$API_URL"; \
	echo "Region: $$AWS_REGION"; \
	echo "Restricted Role ARN: $$ROLE_ARN"; \
	echo ""; \
	echo "NOTE: You must assume the restricted role to access API B"; \
	echo "To test API B, first run: aws sts assume-role --role-arn $$ROLE_ARN --role-session-name test-session"; \
	echo "Then export the credentials and run these commands:"; \
	echo ""; \
	echo "1. Testing Health Check (GET /health)"; \
	echo "awscurl --service execute-api --region $$AWS_REGION \"$$API_URL/health\""; \
	echo ""; \
	echo "2. Testing Root Endpoint (GET /)"; \
	echo "awscurl --service execute-api --region $$AWS_REGION \"$$API_URL/\""; \
	echo ""; \
	echo "3. Testing Get Data (GET /data)"; \
	echo "awscurl --service execute-api --region $$AWS_REGION \"$$API_URL/data\""; \
	echo ""; \
	echo "4. Testing Post Data (POST /data)"; \
	echo "awscurl --service execute-api --region $$AWS_REGION -X POST -H 'Content-Type: application/json' -d '{\"message\":\"Restricted test\"}' \"$$API_URL/data\""; \
	echo ""; \
	echo "=== API B Testing Info Complete ==="

# Test API B with automatic role assumption
test-api-b-with-role:
	@echo "=== Testing API B with Automatic Role Assumption ==="
	@API_URL=$$(make api-b-url); \
	AWS_REGION=$$(aws configure get region 2>/dev/null || echo "eu-west-2"); \
	ROLE_ARN=$$(make role-arn); \
	echo "API B URL: $$API_URL"; \
	echo "Region: $$AWS_REGION"; \
	echo "Restricted Role ARN: $$ROLE_ARN"; \
	echo ""; \
	echo "Assuming role and getting credentials..."; \
	CREDS=$$(aws sts assume-role --role-arn $$ROLE_ARN --role-session-name makefile-test --output json); \
	ACCESS_KEY=$$(echo $$CREDS | jq -r '.Credentials.AccessKeyId'); \
	SECRET_KEY=$$(echo $$CREDS | jq -r '.Credentials.SecretAccessKey'); \
	SESSION_TOKEN=$$(echo $$CREDS | jq -r '.Credentials.SessionToken'); \
	echo ""; \
	echo "1. Testing Health Check (GET /health)"; \
	AWS_ACCESS_KEY_ID=$$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$$SECRET_KEY AWS_SESSION_TOKEN=$$SESSION_TOKEN awscurl --service execute-api --region $$AWS_REGION "$$API_URL/health" | jq .; \
	echo ""; \
	echo "2. Testing Root Endpoint (GET /)"; \
	AWS_ACCESS_KEY_ID=$$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$$SECRET_KEY AWS_SESSION_TOKEN=$$SESSION_TOKEN awscurl --service execute-api --region $$AWS_REGION "$$API_URL/" | jq .; \
	echo ""; \
	echo "3. Testing Get Data (GET /data)"; \
	AWS_ACCESS_KEY_ID=$$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$$SECRET_KEY AWS_SESSION_TOKEN=$$SESSION_TOKEN awscurl --service execute-api --region $$AWS_REGION "$$API_URL/data" | jq .; \
	echo ""; \
	echo "4. Testing Post Data (POST /data)"; \
	AWS_ACCESS_KEY_ID=$$ACCESS_KEY AWS_SECRET_ACCESS_KEY=$$SECRET_KEY AWS_SESSION_TOKEN=$$SESSION_TOKEN awscurl --service execute-api --region $$AWS_REGION -X POST -H 'Content-Type: application/json' -d '{"message":"Restricted test via role assumption","timestamp":"'$$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' "$$API_URL/data" | jq .; \
	echo ""; \
	echo "=== API B Automatic Testing Complete ==="

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
	@API_A_URL=$$(make api-a-url); \
	API_B_URL=$$(make api-b-url); \
	AWS_REGION=$$(aws configure get region 2>/dev/null || echo "eu-west-2"); \
	echo "API A URL: $$API_A_URL"; \
	echo "API B URL: $$API_B_URL"; \
	echo "Region: $$AWS_REGION"; \
	echo ""; \
	echo "=== API A Commands (Open Access) ==="; \
	echo "Health check:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_A_URL/health'"; \
	echo ""; \
	echo "Get root:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_A_URL/'"; \
	echo ""; \
	echo "Get data:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_A_URL/data'"; \
	echo ""; \
	echo "Post data:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION \\"; \
	echo "        -X POST -H 'Content-Type: application/json' \\"; \
	echo "        -d '{\"message\":\"Hello World\"}' \\"; \
	echo "        '$$API_A_URL/data'"; \
	echo ""; \
	echo "=== API B Commands (Restricted Access - Same Endpoints) ==="; \
	echo "NOTE: First assume the restricted role:"; \
	echo "aws sts assume-role --role-arn $$(make role-arn) --role-session-name test-session"; \
	echo ""; \
	echo "Health check:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_B_URL/health'"; \
	echo ""; \
	echo "Root endpoint:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_B_URL/'"; \
	echo ""; \
	echo "Data endpoint:"; \
	echo "awscurl --service execute-api --region $$AWS_REGION '$$API_B_URL/data'"; \
	echo ""; \
	echo "=== Test without authentication (should fail) ==="; \
	echo "curl '$$API_A_URL/health'"