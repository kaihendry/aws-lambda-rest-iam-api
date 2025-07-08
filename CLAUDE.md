# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an AWS Lambda REST API project with IAM integration, built using:
- **Go** as the primary programming language
- **AWS SAM (Serverless Application Model)** for infrastructure as code
- **GitHub Actions** for CI/CD pipeline

## Architecture

The project follows AWS SAM conventions for serverless applications:
- Lambda functions will be defined in `template.yaml` or `template.yml`
- Go handlers typically organized in separate directories (e.g., `cmd/`, `internal/`, or function-specific directories)
- IAM roles and policies defined in the SAM template
- REST API endpoints configured through AWS API Gateway

## Development Commands

Based on the GitHub Actions workflow, the primary commands are:

### Deployment
```bash
make deploy
```

### Local Development
AWS SAM provides local development capabilities:
```bash
sam build
sam local start-api
sam local invoke <function-name>
```

### Testing
```bash
go test ./...
go test -v ./...  # verbose output
```

### Build
```bash
go build ./...
sam build
```

## CI/CD Pipeline

The project uses GitHub Actions with:
- **Trigger**: Push to main branch or manual workflow dispatch
- **AWS Authentication**: OIDC with IAM role `arn:aws:iam::407461997746:role/github-actions-Role-56IHHM969DKJ`
- **Region**: eu-west-2
- **Deployment**: `make deploy` command

## Key Files to Expect

When implementing features, look for:
- `template.yaml` - SAM template defining Lambda functions and API Gateway
- `Makefile` - Build and deployment commands
- `go.mod` - Go module dependencies
- `samconfig.toml` - SAM configuration for different environments
- Function handlers in Go (likely in `cmd/` or named directories)

## Development Notes

- The project uses Go modules for dependency management
- Lambda functions should follow AWS Lambda Go runtime conventions
- API Gateway integration handles REST endpoint routing
- IAM policies should be defined in the SAM template for proper permissions
- Environment-specific configurations managed through SAM parameters

## IAM Authorization

The API Gateway is configured with **AWS_IAM** authentication, requiring AWS Signature Version 4 for all requests.

### Current Access Control
- Any AWS principal with valid credentials and `execute-api:Invoke` permission can access the API
- Authentication uses AWS SigV4, not API keys

### Restricting Access to Specific Roles

**Option 1: Resource-Based Policy**
Add to API Gateway in template.yaml:
```yaml
RestApi:
  Type: AWS::Serverless::Api
  Properties:
    Policy:
      Statement:
        - Effect: Allow
          Principal:
            AWS: 
              - "arn:aws:iam::ACCOUNT:role/AllowedRole"
          Action: execute-api:Invoke
          Resource: "*"
```

**Option 2: IAM Policies**
Grant `execute-api:Invoke` only to specific roles/users.

### Why Not API Keys?

AWS API Keys are designed for **usage tracking and throttling**, not authentication:
- API keys identify calling applications for billing/monitoring
- They don't verify the caller's identity or permissions
- Anyone with the key can use it (no user context)
- They're typically used alongside other auth methods (IAM, Cognito, etc.)
- For security, use IAM authentication which provides proper identity verification and access control