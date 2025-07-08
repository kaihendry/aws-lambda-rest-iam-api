# AWS Lambda REST API with IAM Authentication

This project demonstrates AWS Lambda REST API with IAM authentication using two different access patterns:
- **API A**: Open access (any authenticated AWS user)
- **API B**: Restricted access (only specific IAM role)

Built using:
- **Go** as the primary programming language
- **AWS SAM (Serverless Application Model)** for infrastructure as code
- **GitHub Actions** for CI/CD pipeline

## Architecture

The project implements two separate API Gateways with different access controls but identical endpoints:

### API A (Open Access)
- **Endpoints**: `/`, `/health`, `/data`
- **Access**: Any authenticated AWS user
- **Authentication**: AWS SigV4
- **Use Case**: General API access for any user in the account

### API B (Restricted Access)
- **Endpoints**: `/`, `/health`, `/data` (same as API A)
- **Access**: Only users who can assume the restricted IAM role
- **Authentication**: AWS SigV4 with restricted role assumption
- **Use Case**: Same functionality as API A but with restricted access

Both APIs use the same Lambda function and endpoints - the only difference is the access control at the API Gateway level.

## Development Commands

### Deployment
```bash
make deploy
```

### Testing APIs
```bash
# Test both APIs
make test-api

# Test API A (open access)
make test-api-a

# Test API B (restricted access) - shows instructions
make test-api-b
```

### Get API URLs
```bash
# Show both API URLs
make api-url

# Show specific API URLs
make api-a-url
make api-b-url

# Show restricted role ARN
make role-arn
```

### Local Development
```bash
sam build
sam local start-api
sam local invoke ApiFunction
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

Both APIs use **AWS_IAM** authentication, requiring AWS Signature Version 4 for all requests.

### API A (Open Access)
- Any AWS principal with valid credentials and `execute-api:Invoke` permission can access
- Authentication uses AWS SigV4

### API B (Restricted Access)
- Only accessible by users who can assume the restricted IAM role
- Resource-based policy restricts access to the specific role
- Requires role assumption before API calls

## Using the Restricted API B

To access API B, you must first assume the restricted role:

1. **Get the role ARN:**
   ```bash
   make role-arn
   ```

2. **Assume the role:**
   ```bash
   aws sts assume-role \
     --role-arn arn:aws:iam::ACCOUNT:role/STACK-NAME-api-b-restricted-role \
     --role-session-name test-session
   ```

3. **Export the temporary credentials:**
   ```bash
   export AWS_ACCESS_KEY_ID=ASIA...
   export AWS_SECRET_ACCESS_KEY=...
   export AWS_SESSION_TOKEN=...
   ```

4. **Test the restricted API:**
   ```bash
   API_B_URL=$(make api-b-url)
   awscurl --service execute-api --region eu-west-2 "$API_B_URL/health"
   ```

## Example Usage

### API A Examples
```bash
# Get API A URL
API_A_URL=$(make api-a-url)

# Test health endpoint
awscurl --service execute-api --region eu-west-2 "$API_A_URL/health"

# Test data endpoint
awscurl --service execute-api --region eu-west-2 "$API_A_URL/data"
```

### API B Examples (after assuming role)
```bash
# Get API B URL
API_B_URL=$(make api-b-url)

# Test health endpoint (same as API A)
awscurl --service execute-api --region eu-west-2 "$API_B_URL/health"

# Test data endpoint (same as API A)
awscurl --service execute-api --region eu-west-2 "$API_B_URL/data"
```

## Security Implementation

The project demonstrates two access control patterns:

### Resource-Based Policy (API B)
```yaml
RestApiB:
  Type: AWS::Serverless::Api
  Properties:
    Policy:
      Statement:
        - Effect: Allow
          Principal:
            AWS: !GetAtt ApiBRestrictedRole.Arn
          Action: execute-api:Invoke
          Resource: "*"
```

### IAM Role with Specific Permissions
```yaml
ApiBRestrictedRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Statement:
        - Effect: Allow
          Principal:
            AWS: !Sub "arn:aws:iam::${AWS::AccountId}:root"
          Action: sts:AssumeRole
    Policies:
      - PolicyName: ApiBAccessPolicy
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action: execute-api:Invoke
              Resource: !Sub "arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${RestApiB}/*"
```