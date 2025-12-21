# Text-to-SQL Platform - AWS Enterprise Architecture

[![Terraform](https://img.shields.io/badge/Terraform-1.0%2B-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Multi--Service-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ECS](https://img.shields.io/badge/ECS-Fargate-orange)](https://aws.amazon.com/ecs/)
[![Bedrock](https://img.shields.io/badge/Amazon-Bedrock-blueviolet)](https://aws.amazon.com/bedrock/)

A production-ready, enterprise-grade Text-to-SQL platform built on AWS using infrastructure as code. This solution leverages AWS Bedrock AI agents with knowledge bases, containerized microservices on ECS, RDS MySQL database, and comprehensive security controls including Cognito authentication and Guardrails.

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           Internet Gateway                                │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
          ┌─────────▼──────┐       ┌─────────▼──────┐
          │  Frontend ALB  │       │  Backend ALB   │
          │   (Port 80)    │       │   (Port 80)    │
          └─────────┬──────┘       └─────────┬──────┘
                    │                        │
          ┌─────────▼──────┐       ┌─────────▼──────┐
          │  ECS Frontend  │◄──────┤  ECS Backend   │
          │   (React/Next) │       │   (FastAPI)    │
          │   Port 3000    │       │   Port 80      │
          └────────┬───────┘       └────────┬───────┘
                   │                        │
                   │              ┌─────────▼──────────┐
                   │              │   RDS MySQL 8.0    │
                   │              │   Multi-AZ         │
                   │              │   (Private Subnet) │
                   │              └────────────────────┘
                   │
          ┌────────▼─────────────────────────────────────┐
          │           AWS Bedrock Integration            │
          ├──────────────────────────────────────────────┤
          │  • Claude v4 Foundation Model                │
          │  • Knowledge Base (Pinecone Vector DB)       │
          │  • Guardrails (Content & PII Filtering)      │
          │  • S3 Data Source                            │
          └──────────────────────────────────────────────┘
                   │
          ┌────────▼──────────┐
          │  Amazon Cognito   │
          │  User Pool        │
          │  (Authentication) │
          └───────────────────┘
```

### Infrastructure Components

```
VPC (10.0.0.0/16)
├── Public Subnets (3 AZs)
│   ├── Internet Gateway
│   ├── NAT Gateway
│   ├── Frontend ALB
│   └── Backend ALB
│
├── Private Subnets (3 AZs)
│   ├── ECS Frontend Service (Fargate + EC2)
│   ├── ECS Backend Service (Fargate + EC2)
│   └── RDS MySQL (Multi-AZ)
│
├── Security Groups
│   ├── Frontend LB SG (80, 443)
│   ├── Backend LB SG (80, 443)
│   ├── ECS Frontend SG (3000)
│   ├── ECS Backend SG (80)
│   └── RDS SG (3306)
│
└── Supporting Services
    ├── ECR Repositories (Frontend, Backend)
    ├── S3 Buckets (Bedrock Data, ALB Logs)
    ├── Secrets Manager (RDS, Pinecone)
    ├── CloudWatch Logs (Firehose)
    └── Cognito User Pool
```

## ✨ Features

### Infrastructure
- **High Availability**: Multi-AZ deployment across 3 availability zones
- **Auto Scaling**: ECS with Fargate and EC2 capacity providers
- **Load Balancing**: Application Load Balancers with health checks
- **Container Orchestration**: Amazon ECS with mixed capacity strategies
- **Centralized Logging**: Fluent Bit + Kinesis Firehose integration

### Security
- **Network Isolation**: Private subnets for compute and database
- **Authentication**: Amazon Cognito with email verification
- **Secret Management**: AWS Secrets Manager + HashiCorp Vault integration
- **Database Security**: RDS encryption, Multi-AZ, automated backups
- **AI Guardrails**: Content filtering, PII protection, topic restrictions

### AI/ML Capabilities
- **Bedrock Agent**: Claude v4 foundation model for SQL generation
- **Knowledge Base**: Vector search with Pinecone integration
- **Embeddings**: Amazon Titan Embed Text v2
- **Content Filtering**: Hate speech, profanity, sensitive information
- **PII Protection**: Automatic detection and anonymization

### Database
- **RDS MySQL 8.0**: Multi-AZ with automated failover
- **Performance Insights**: 7-day retention
- **Automated Backups**: 35-day retention with PITR
- **CloudWatch Logs**: Audit, error, general, slow query logs
- **Connection Pooling**: Optimized with 1000 max connections

## 📋 Prerequisites

### Required Software
- **Terraform**: >= 1.0
- **AWS CLI**: >= 2.0, configured with credentials
- **Docker**: For local container builds
- **HashiCorp Vault**: For secrets management
- **Node.js**: >= 18 (for frontend)
- **Python**: >= 3.9 (for backend)

### AWS Services Access
- ECS, ECR, RDS, VPC, ALB, S3
- Bedrock (with Claude v4 model access)
- Cognito, Secrets Manager
- CloudWatch Logs, Kinesis Firehose
- IAM permissions for resource creation

### External Services
- **Pinecone Account**: Vector database for knowledge base
- **Vault Server**: For secure secret storage

### Required Vault Secrets

```bash
# Store RDS credentials
vault kv put secret/rds username="admin" password="YourSecurePassword123!"

# Store Pinecone API key
vault kv put secret/pinecone api_key="your-pinecone-api-key"
```

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd <repository-directory>

# Directory structure
project-root/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
└── src/
    ├── frontend/
    │   ├── Dockerfile
    │   └── artifact_push.sh
    └── backend/
        ├── Dockerfile
        └── artifact_push.sh
```

### 2. Configure Vault Access

```bash
# Set Vault environment variables
export VAULT_ADDR="https://your-vault-server:8200"
export VAULT_TOKEN="your-vault-token"

# Verify access
vault kv get secret/rds
vault kv get secret/pinecone
```

### 3. Create Terraform Variables

Create `terraform.tfvars`:

```hcl
# AWS Configuration
region = "us-east-1"

# Network Configuration
azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
```

### 4. Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review deployment plan
terraform plan

# Deploy infrastructure
terraform apply

# Expected deployment time: 15-20 minutes
```

### 5. Retrieve Outputs

```bash
# Get frontend URL
terraform output frontend_url

# Get backend URL
terraform output backend_url

# Get Cognito details
terraform output cognito_user_pool_id
terraform output cognito_client_id

# Get RDS endpoint
terraform output rds_endpoint
```

### 6. Access the Application

```bash
# Frontend URL
http://<frontend-alb-dns>/

# Backend API
http://<backend-alb-dns>/docs  # API documentation

# Cognito login
http://<frontend-alb-dns>/auth/signin
```

## 🔧 Configuration

### Input Variables

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `region` | AWS region for deployment | `string` | Yes | `us-east-1` |
| `azs` | List of availability zones | `list(string)` | Yes | - |
| `public_subnets` | CIDR blocks for public subnets | `list(string)` | Yes | - |
| `private_subnets` | CIDR blocks for private subnets | `list(string)` | Yes | - |

### ECS Configuration

#### Frontend Service
```hcl
CPU:      1024 (1 vCPU)
Memory:   4096 MB (4 GB)
Port:     3000
Protocol: HTTP
Container: React/Next.js application
Logging:  Fluent Bit + Firehose
```

#### Backend Service
```hcl
CPU:      1024 (1 vCPU)
Memory:   4096 MB (4 GB)
Port:     80
Protocol: HTTP
Container: FastAPI application
Logging:  Fluent Bit + Firehose
```

### Capacity Provider Strategy

```hcl
Fargate:      50% weight, 20 base tasks
Fargate Spot: 50% weight
EC2 ASG:      50% weight, 20 base tasks
```

### RDS Configuration

```hcl
Engine:           MySQL 8.0
Instance Class:   db.t3.medium
Storage:          20 GB (auto-scaling to 40 GB)
Multi-AZ:         Enabled
Backup Retention: 35 days
Performance:      Insights enabled (7 days)
Parameters:
  - max_connections: 1000
  - innodb_buffer_pool_size: 75% of memory
  - slow_query_log: enabled
```

### Bedrock Configuration

```hcl
Foundation Model:  anthropic.claude-v4
Embedding Model:   amazon.titan-embed-text-v2:0
Vector DB:         Pinecone
Knowledge Base:    S3-backed data source
Session TTL:       500 seconds
```

## 🔐 Security Architecture

### Network Security

**VPC Isolation**
- Public subnets: Load balancers only
- Private subnets: ECS tasks and RDS
- NAT Gateway: Outbound internet for private subnets
- No direct internet access to compute/database

**Security Group Rules**

| Resource | Inbound | Outbound | Source/Destination |
|----------|---------|----------|-------------------|
| Frontend ALB | 80, 443 | All | 0.0.0.0/0 |
| Backend ALB | 80, 443 | All | 0.0.0.0/0 |
| ECS Frontend | 3000 | All | Frontend ALB SG |
| ECS Backend | 80 | All | Backend ALB SG |
| RDS MySQL | 3306 | All | ECS Backend SG |

### Authentication & Authorization

**Amazon Cognito**
- Email-based authentication
- Password policy: 8+ chars, uppercase, lowercase, numbers, symbols
- Email verification required
- OAuth 2.0 flows: Authorization Code, Implicit
- Scopes: email, openid

**User Pool Configuration**
```hcl
Username Attributes: email
Auto-Verified:       email
MFA:                 Optional (configurable)
Password Policy:     Strong requirements
Token Validity:      Configurable (default: 1 hour)
```

### Secrets Management

**AWS Secrets Manager**
- RDS credentials rotation
- Pinecone API key storage
- Automatic encryption at rest
- IAM policy-based access control

**HashiCorp Vault Integration**
- Source of truth for secrets
- Terraform data source for retrieval
- Centralized secret management
- Audit logging

### AI Guardrails

**Content Policy**
```hcl
Filters:
  - Hate Speech (Medium strength)
  - Profanity (Managed word lists)
Tier: STANDARD
```

**Sensitive Information Policy**
```hcl
PII Entities:
  - NAME: Block input, Anonymize output
  - Custom Regex: SSN pattern (XXX-XX-XXXX)
```

**Topic Policy**
```hcl
Denied Topics:
  - Investment advice
  - Financial recommendations
Action: DENY with custom messaging
```

## 📊 Monitoring & Logging

### CloudWatch Logs

**ECS Application Logs**
```bash
# Frontend logs via Firehose
aws logs tail ecs-frontend-stream --follow

# Backend logs via Firehose
aws logs tail ecs-backend-stream --follow

# Fluent Bit system logs
aws logs tail /aws/ecs/text-to-sql-cluster --follow
```

**RDS Logs**
```bash
# Error logs
aws logs tail /aws/rds/instance/db/error --follow

# Slow query logs
aws logs tail /aws/rds/instance/db/slowquery --follow

# General query logs
aws logs tail /aws/rds/instance/db/general --follow

# Audit logs
aws logs tail /aws/rds/instance/db/audit --follow
```

**ALB Access Logs**

Stored in S3 buckets:
- `s3://frontend-lb-logs/AWSLogs/{account-id}/elasticloadbalancing/`
- `s3://backend-lb-logs/AWSLogs/{account-id}/elasticloadbalancing/`

### Key Metrics

**ECS Metrics**
```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=ecs_frontend \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=ecs_backend \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**RDS Metrics**
```bash
# Database connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

**ALB Metrics**
| Metric | Description |
|--------|-------------|
| `TargetResponseTime` | Backend latency |
| `RequestCount` | Total requests |
| `HTTPCode_Target_2XX_Count` | Successful responses |
| `HTTPCode_Target_5XX_Count` | Server errors |
| `UnHealthyHostCount` | Failed health checks |
| `HealthyHostCount` | Active targets |

### Performance Insights

**RDS Performance Insights**
```bash
# View top SQL statements
aws pi get-resource-metrics \
  --service-type RDS \
  --identifier db-XXXXXXXXXXXXX \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --period-in-seconds 300 \
  --metric-queries '{"Metric":"db.load.avg"}'
```

## 🚀 CI/CD Pipeline

### GitHub Actions Example

```yaml
name: Deploy Text-to-SQL Platform

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: 1.5.0

jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}
      
      - name: Terraform Init
        run: |
          cd terraform
          terraform init
      
      - name: Terraform Validate
        run: |
          cd terraform
          terraform validate
      
      - name: Terraform Plan
        run: |
          cd terraform
          terraform plan -out=tfplan
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          cd terraform
          terraform apply tfplan

  build-frontend:
    name: Build & Push Frontend
    runs-on: ubuntu-latest
    needs: terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push frontend
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: frontend-td
          IMAGE_TAG: ${{ github.sha }}
        run: |
          cd src/frontend
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
      
      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster text-to-sql-cluster \
            --service ecs_frontend \
            --force-new-deployment

  build-backend:
    name: Build & Push Backend
    runs-on: ubuntu-latest
    needs: terraform
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push backend
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: backend-td
          IMAGE_TAG: ${{ github.sha }}
        run: |
          cd src/backend
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
      
      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster text-to-sql-cluster \
            --service ecs_backend \
            --force-new-deployment
```

## 💰 Cost Estimation

### Monthly Cost Breakdown (Approximate)

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| **ECS Fargate** | 2 services, avg 4 tasks | $150-200 |
| **ECS EC2** | t3.medium ASG (2-5 instances) | $60-150 |
| **RDS MySQL** | db.t3.medium Multi-AZ | $120-140 |
| **Application Load Balancers** | 2 ALBs | $35-40 |
| **NAT Gateway** | 1 gateway + data transfer | $40-80 |
| **S3 Storage** | Logs + Bedrock data | $5-15 |
| **ECR** | 2 repositories, ~10GB | $1-2 |
| **Secrets Manager** | 2 secrets | $1 |
| **Bedrock** | Claude v4 API calls (variable) | $50-500+ |
| **Pinecone** | Vector DB (external) | $70+ |
| **CloudWatch Logs** | Ingestion + storage | $10-30 |
| **Data Transfer** | Inter-AZ + Internet | $20-50 |
| **Total** | | **$562-1,208/month** |

### Cost Optimization Strategies

1. **Use Fargate Spot** (currently 50% allocation)
   - Potential savings: 70% on Fargate costs
   - Best for: Stateless, fault-tolerant workloads

2. **RDS Reserved Instances**
   - 1-year partial upfront: ~35% savings ($78/month vs $120)
   - 3-year all upfront: ~60% savings

3. **S3 Lifecycle Policies**
   ```hcl
   # Transition logs to IA after 30 days, delete after 90
   lifecycle_rule {
     enabled = true
     transition {
       days          = 30
       storage_class = "STANDARD_IA"
     }
     expiration {
       days = 90
     }
   }
   ```

4. **Optimize Bedrock Usage**
   - Implement caching for common queries
   - Use prompt engineering to reduce token usage
   - Monitor and set budget alerts

5. **Right-Size Resources**
   ```bash
   # Monitor resource utilization
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ECS \
     --metric-name CPUUtilization,MemoryUtilization
   
   # Adjust task definitions based on actual usage
   ```

6. **Single NAT Gateway**
   - Already configured (saves $32/month per AZ)
   - Trade-off: Reduced availability if NAT fails

## 🐛 Troubleshooting

### ECS Task Failures

**Issue**: Tasks fail to start or keep restarting

**Diagnosis**:
```bash
# Check task status
aws ecs describe-tasks \
  --cluster text-to-sql-cluster \
  --tasks $(aws ecs list-tasks --cluster text-to-sql-cluster --service-name ecs_frontend --query 'taskArns[0]' --output text)

# View logs
aws logs tail /aws/ecs/text-to-sql-cluster --follow

# Check stopped tasks
aws ecs list-tasks \
  --cluster text-to-sql-cluster \
  --desired-status STOPPED \
  --max-results 10
```

**Common Solutions**:
- Verify ECR image exists and is accessible
- Check IAM role permissions for task execution
- Ensure security groups allow required traffic
- Verify environment variables are set correctly
- Check health check endpoint returns 200 OK

### RDS Connection Issues

**Issue**: Backend cannot connect to database

**Diagnosis**:
```bash
# Test connectivity from ECS task
aws ecs execute-command \
  --cluster text-to-sql-cluster \
  --task <task-id> \
  --container ecs_backend \
  --interactive \
  --command "mysql -h <rds-endpoint> -u admin -p"

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <rds-sg-id> \
  --query 'SecurityGroups[0].IpPermissions'

# Verify RDS status
aws rds describe-db-instances \
  --db-instance-identifier db \
  --query 'DBInstances[0].DBInstanceStatus'
```

**Solutions**:
- Verify security group allows traffic from ECS backend SG
- Check RDS endpoint in environment variables
- Ensure database credentials are correct in Secrets Manager
- Verify database is in available state
- Check VPC peering/routing if applicable

### Bedrock Agent Errors

**Issue**: AI queries fail or return errors

**Diagnosis**:
```bash
# Check agent status
aws bedrock-agent get-agent \
  --agent-id <agent-id>

# List knowledge base sync jobs
aws bedrock-agent list-data-sources \
  --knowledge-base-id <kb-id>

# Test knowledge base query
aws bedrock-agent-runtime retrieve-and-generate \
  --input '{"text":"test query"}' \
  --retrieve-and-generate-configuration '{"type":"KNOWLEDGE_BASE","knowledgeBaseConfiguration":{"knowledgeBaseId":"<kb-id>","modelArn":"arn:aws:bedrock:us-west-2::foundation-model/amazon.titan-embed-text-v2:0"}}'
```

**Solutions**:
- Verify Bedrock model access in AWS account
- Check S3 bucket has data for knowledge base
- Ensure Pinecone credentials are correct
- Sync knowledge base data source
- Review guardrail policies for blocking rules
- Check IAM role permissions for Bedrock

### Load Balancer 5xx Errors

**Issue**: ALB returning 500/502/503 errors

**Diagnosis**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# View ALB access logs in S3
aws s3 cp s3://frontend-lb-logs/AWSLogs/<account-id>/elasticloadbalancing/ . --recursive

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=app/frontend-lb/xxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```

**Solutions**:
- Check ECS tasks are healthy and running
- Verify application health check endpoint
- Ensure security groups allow ALB → ECS traffic
- Check for resource constraints (CPU/memory)
- Review application logs for errors
- Adjust health check thresholds if too strict

### Cognito Authentication Issues

**Issue**: Users cannot sign in or register

**Diagnosis**:
```bash
# Check user pool status
aws cognito-idp describe-user-pool \
  --user-pool-id <user-pool-id>

# List users
aws cognito-idp list-users \
  --user-pool-id <user-pool-id>

# Check app client settings
aws cognito-idp describe-user-pool-client \
  --user-pool-id <user-pool-id> \
  --client-id <client-id>
```

**Solutions**:
- Verify callback URLs match frontend ALB URL
- Check email verification settings
- Ensure OAuth flows are enabled
- Verify user pool domain is configured
- Check password policy requirements
- Review CloudWatch logs for Cognito events

### Vault Integration Issues

**Issue**: Terraform cannot retrieve secrets from Vault

**Diagnosis**:
```bash
# Test Vault connectivity
vault status

# Verify token
vault token lookup

# Check secret exists
vault kv get secret/rds
vault kv get secret/pinecone
```

**Solutions**:
- Ensure VAULT_ADDR is set correctly
- Verify VAULT_TOKEN has valid permissions
- Check Vault policies allow read access to secrets
- Ensure secrets exist at specified paths
- Verify network connectivity to Vault server

## 🔄 Disaster Recovery

### Backup Strategy

**RDS Automated Backups**
```hcl
Frequency:    Daily automatic snapshots
Retention:    35 days
Backup Window: 03:00-06:00 UTC
PITR:         Yes (up to 35 days)
```

**Manual Snapshot**
```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier db \
  --db-snapshot-identifier db-manual-snapshot-$(date +%Y%m%d)

# Copy snapshot to another region
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:us-east-1:account:snapshot:db-manual-snapshot-20241220 \
  --target-db-snapshot-identifier db-dr-snapshot-20241220 \
  --region us-west-2
```

**S3 Bucket Versioning**
- Enabled on all S3 buckets
- Allows recovery of deleted/overwritten objects
- 35-day retention aligned with RDS backups

### Recovery Procedures

**RDS Restore from Snapshot**
```bash
# Restore to new instance
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier db-restored \
  --db-snapshot-identifier db-manual-snapshot-20241220 \
  --db-instance-class db.t3.medium \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name rds_subnet_group

# Update backend environment variable
aws ecs update-service \
  --cluster text-to-sql-cluster \
  --service ecs_backend \
  --force-new-deployment
```

**Point-in-Time Recovery**
```bash
# Restore to specific time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier db \
  --target-db-instance-identifier db-pitr-restored \
  --restore-time 2024-12-20T10:00:00Z \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name rds_subnet_group
```

**ECS Service Recovery**
```bash
# Force new deployment to recover from failures
aws ecs update-service \
  --cluster text-to-sql-cluster \
  --service ecs_frontend \
  --force-new-deployment

# Scale up to recover from incidents
aws ecs update-service \
  --cluster text-to-sql-cluster \
  --service ecs_backend \
  --desired-count 6
```

### Multi-Region Failover

**Prerequisites**:
1. Deploy infrastructure in DR region (e.g., us-west-2)
2. Setup RDS cross-region read replica
3. Configure Route53 health checks and failover routing
4. Replicate ECR images to DR region

**Failover Procedure**:
```bash
# 1. Promote read replica to standalone DB
aws rds promote-read-replica \
  --db-instance-identifier db-replica-us-west-2

# 2. Update Route53 to point to DR region ALBs
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://failover-dns.json

# 3. Scale up ECS services in DR region
aws ecs update-service \
  --cluster text-to-sql-cluster-dr \
  --service ecs_frontend \
  --desired-count 4 \
  --region us-west-2
```

## 🧪 Testing

### Unit Testing

**Backend (FastAPI)**
```bash
cd src/backend
pytest tests/ --cov=app --cov-report=html
```

**Frontend (React/Next.js)**
```bash
cd src/frontend
npm test -- --coverage
```

### Integration Testing

**Database Connectivity**
```bash
# Test from ECS task
aws ecs execute-command \
  --cluster text-to-sql-cluster \
  --task <task-id> \
  --container ecs_backend \
  --interactive \
  --command "python -c 'import mysql.connector; conn = mysql.connector.connect(host=\"<rds-endpoint>\", user=\"admin\", password=\"<password>\", database=\"db\"); print(conn.is_connected())'"
```

**Bedrock Agent**
```bash
# Test knowledge base query
aws bedrock-agent-runtime retrieve-and-generate \
  --input '{"text":"What is the schema of the users table?"}' \
  --retrieve-and-generate-configuration '{
    "type":"KNOWLEDGE_BASE",
    "knowledgeBaseConfiguration":{
      "knowledgeBaseId":"<kb-id>",
      "modelArn":"arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v4"
    }
  }'
```

### Load Testing

**Artillery Configuration**
```yaml
# artillery-config.yml
config:
  target: "http://<frontend-alb-dns>"
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 300
      arrivalRate: 50
      name: "Sustained load"
    - duration: 120
      arrivalRate: 100
      name: "Peak load"

scenarios:
  - name: "User flow"
    flow:
      - get:
          url: "/auth/signin"
      - post:
          url: "/api/query"
          json:
            query: "SELECT * FROM users WHERE active = true"
```

Run load test:
```bash
artillery run artillery-config.yml --output report.json
artillery report report.json
```

## 🧹 Cleanup

### Destroy Infrastructure

```bash
cd terraform

# Preview resources to be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm when prompted
```

### Manual Cleanup Steps

Some resources may need manual cleanup:

**1. RDS Final Snapshot (if deletion_protection = true)**
```bash
# Create final snapshot before destroy
aws rds create-db-snapshot \
  --db-instance-identifier db \
  --db-snapshot-identifier db-final-snapshot-$(date +%Y%m%d)

# Delete snapshots after verification
aws rds delete-db-snapshot \
  --db-snapshot-identifier db-final-snapshot-20241220
```

**2. S3 Buckets (if force_destroy = false)**
```bash
# Empty buckets
aws s3 rm s3://bedrock-knowledge-base-data-source --recursive
aws s3 rm s3://frontend-lb-logs --recursive
aws s3 rm s3://backend-lb-logs --recursive

# Delete buckets
aws s3 rb s3://bedrock-knowledge-base-data-source
aws s3 rb s3://frontend-lb-logs
aws s3 rb s3://backend-lb-logs
```

**3. ECR Images**
```bash
# Delete all images in repositories
aws ecr batch-delete-image \
  --repository-name frontend-td \
  --image-ids "$(aws ecr list-images --repository-name frontend-td --query 'imageIds[*]' --output json)"

aws ecr batch-delete-image \
  --repository-name backend-td \
  --image-ids "$(aws ecr list-images --repository-name backend-td --query 'imageIds[*]' --output json)"
```

**4. CloudWatch Log Groups**
```bash
# Delete log groups
aws logs delete-log-group --log-group-name /aws/ecs/text-to-sql-cluster
aws logs delete-log-group --log-group-name /aws/rds/instance/db/error
```

**5. Cognito Users (if needed)**
```bash
# Delete all users before destroying user pool
aws cognito-idp list-users --user-pool-id <user-pool-id> \
  --query 'Users[*].Username' --output text | \
  xargs -I {} aws cognito-idp admin-delete-user \
  --user-pool-id <user-pool-id> --username {}
```

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly in a separate AWS account
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Standards

- **Terraform**: Follow HashiCorp style guide
- **Python**: PEP 8 compliance, type hints
- **JavaScript/TypeScript**: ESLint + Prettier
- **Documentation**: Update README for new features
- **Testing**: Include unit/integration tests

### Pull Request Checklist

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] Documentation updated
- [ ] No security vulnerabilities introduced
- [ ] Terraform validate passes
- [ ] Changes tested in isolated environment
- [ ] Cost impact analyzed
- [ ] Breaking changes documented

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 References

### AWS Documentation
- [Amazon ECS](https://docs.aws.amazon.com/ecs/)
- [Amazon RDS for MySQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/)
- [AWS Bedrock](https://docs.aws.amazon.com/bedrock/)
- [Amazon Cognito](https://docs.aws.amazon.com/cognito/)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

### Terraform Resources
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ECS Module](https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws/latest)
- [ALB Module](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest)

### External Services
- [Pinecone Vector Database](https://docs.pinecone.io/)
- [HashiCorp Vault](https://www.vaultproject.io/docs)
- [Fluent Bit](https://docs.fluentbit.io/)

### Best Practices
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [Container Security](https://aws.amazon.com/blogs/containers/aws-container-security-best-practices/)

## 📧 Support

### Getting Help

- **GitHub Issues**: Report bugs or request features
- **Discussions**: Ask questions and share ideas
- **AWS Support**: For service-specific issues
- **Security Issues**: Email security@yourcompany.com

### Community

- Join our Slack channel: [#text-to-sql-platform](https://yourworkspace.slack.com)
- Monthly community calls: First Tuesday of each month
- Contributing guide: [CONTRIBUTING.md](CONTRIBUTING.md)

## 🎯 Roadmap

### Q1 2025
- [ ] Implement AWS X-Ray distributed tracing
- [ ] Add Prometheus metrics exporter
- [ ] Setup Grafana dashboards
- [ ] Implement canary deployments

### Q2 2025
- [ ] Multi-region active-active architecture
- [ ] Enhanced AI model fine-tuning
- [ ] GraphQL API gateway
- [ ] Mobile application support

### Q3 2025
- [ ] Kubernetes migration option (EKS)
- [ ] Real-time collaboration features
- [ ] Advanced analytics dashboard
- [ ] Cost optimization recommendations engine

### Q4 2025
- [ ] On-premises deployment option
- [ ] SAML/SSO integration
- [ ] Custom AI model training pipeline
- [ ] Compliance certifications (SOC 2, ISO 27001)

---

## ⚠️ Important Notes

**Production Checklist**:
- [ ] Enable RDS deletion protection before production use
- [ ] Implement automated backup testing procedures
- [ ] Setup CloudWatch alarms for critical metrics
- [ ] Configure AWS Config rules for compliance
- [ ] Enable AWS CloudTrail in all regions
- [ ] Implement cost budgets and alerts
- [ ] Setup incident response procedures
- [ ] Configure VPC Flow Logs
- [ ] Enable GuardDuty for threat detection
- [ ] Implement least privilege IAM policies
- [ ] Setup AWS WAF rules on ALBs
- [ ] Configure AWS Shield for DDoS protection
- [ ] Implement secrets rotation policies
- [ ] Setup cross-region disaster recovery
- [ ] Document runbooks for common operations

**Security Reminders**:
- Never commit secrets to version control
- Rotate credentials regularly (90 days)
- Use IAM roles instead of access keys where possible
- Enable MFA for all privileged accounts
- Regularly review security group rules
- Keep all dependencies updated
- Conduct regular security audits
- Monitor for compliance violations
- Implement network segmentation
- Use encrypted connections everywhere

**Cost Reminders**:
- Monitor daily spend in Cost Explorer
- Set up billing alarms
- Review and clean up unused resources monthly
- Consider Reserved Instances for stable workloads
- Use Compute Savings Plans for flexibility
- Implement auto-scaling policies
- Review Trusted Advisor recommendations
- Optimize data transfer patterns
- Use S3 Intelligent-Tiering
- Regularly review and optimize Bedrock API usage
