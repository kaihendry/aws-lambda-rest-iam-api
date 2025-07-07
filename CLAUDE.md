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