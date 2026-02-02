# AWS Deployment Guide for OpenGate Example

This guide explains how to deploy the OpenGate API Gateway to AWS using AWS SAM (Serverless Application Model) with ECS Fargate and an Application Load Balancer.

## Architecture

The deployment creates the following AWS infrastructure:

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                        │ │
│  │                                                              │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                │ │
│  │  │ Public Subnet 1  │  │ Public Subnet 2  │                │ │
│  │  │  10.0.1.0/24     │  │  10.0.2.0/24     │                │ │
│  │  │                  │  │                  │                │ │
│  │  │  ┌────────────┐  │  │                  │                │ │
│  │  │  │    ALB     │◄─┼──┼──────────────────┼─── Internet   │ │
│  │  │  │ (HTTP:80)  │  │  │                  │                │ │
│  │  │  └─────┬──────┘  │  │                  │                │ │
│  │  │        │         │  │                  │                │ │
│  │  │  ┌─────▼──────┐  │  │                  │                │ │
│  │  │  │ NAT Gateway│  │  │                  │                │ │
│  │  │  └────────────┘  │  │                  │                │ │
│  │  └──────────────────┘  └──────────────────┘                │ │
│  │           │                     │                           │ │
│  │  ┌────────▼─────────┐  ┌───────▼──────────┐                │ │
│  │  │ Private Subnet 1 │  │ Private Subnet 2 │                │ │
│  │  │  10.0.11.0/24    │  │  10.0.12.0/24    │                │ │
│  │  │                  │  │                  │                │ │
│  │  │  ┌────────────┐  │  │  ┌────────────┐  │                │ │
│  │  │  │  Fargate   │  │  │  │  Fargate   │  │                │ │
│  │  │  │  Task(s)   │  │  │  │  Task(s)   │  │                │ │
│  │  │  │  :8080     │  │  │  │  :8080     │  │                │ │
│  │  │  └────────────┘  │  │  └────────────┘  │                │ │
│  │  └──────────────────┘  └──────────────────┘                │ │
│  │                                                              │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │  ECS Cluster     │  │ CloudWatch Logs  │                     │
│  │  (Fargate)       │  │ (/ecs/stack)     │                     │
│  └──────────────────┘  └──────────────────┘                     │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### Components

**Networking:**
- **VPC**: Isolated virtual network (10.0.0.0/16)
- **Public Subnets**: 2 subnets in different AZs for the ALB
- **Private Subnets**: 2 subnets in different AZs for Fargate tasks
- **Internet Gateway**: Allows public internet access to the ALB
- **NAT Gateway**: Allows Fargate tasks to access the internet (for pulling container images and reaching backend APIs)

**Security:**
- **ALB Security Group**: Allows HTTP (port 80) from anywhere (0.0.0.0/0)
- **Container Security Group**: Allows traffic only from ALB on port 8080
- **Private Network**: Fargate tasks run in private subnets with no direct internet access

**Load Balancing:**
- **Application Load Balancer**: Internet-facing, distributes traffic across Fargate tasks
- **Target Group**: Health checks on `/posts` endpoint every 30 seconds
- **SSL Termination**: Currently HTTP only (HTTPS requires ACM certificate with custom domain)

**Compute:**
- **ECS Cluster**: Manages Fargate tasks
- **ECS Service**: Maintains desired count of running tasks
- **Fargate Tasks**: Run OpenGate containers (0.5 vCPU, 1 GB memory by default)
- **Container Image**: `ghcr.io/ksysoev/opengate-example:latest`

**Monitoring:**
- **CloudWatch Logs**: Container logs stored for 7 days
- **Container Insights**: Enabled for cluster metrics

## Prerequisites

### Required Tools

1. **AWS CLI** (v2.x or later)
   - Installation: https://aws.amazon.com/cli/
   - Verify: `aws --version`

2. **AWS SAM CLI** (v1.x or later)
   - Installation: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html
   - Verify: `sam --version`

3. **jq** (optional, for pretty JSON output)
   - Installation: `brew install jq` (macOS) or `apt-get install jq` (Linux)

### AWS Configuration

1. **AWS Account**: You need an AWS account with appropriate permissions

2. **AWS Credentials**: Configure your AWS credentials using one of these methods:

   ```bash
   # Option 1: Use AWS CLI configure
   aws configure
   
   # Option 2: Set environment variables
   export AWS_ACCESS_KEY_ID=your-access-key
   export AWS_SECRET_ACCESS_KEY=your-secret-key
   export AWS_DEFAULT_REGION=us-east-1
   
   # Option 3: Use AWS profiles
   export AWS_PROFILE=your-profile-name
   ```

3. **Required IAM Permissions**: Your AWS user/role needs permissions for:
   - CloudFormation (create/update/delete stacks)
   - EC2 (VPC, subnets, security groups, NAT gateway)
   - ECS (cluster, service, task definition)
   - Elastic Load Balancing (ALB, target groups, listeners)
   - IAM (create roles and policies)
   - CloudWatch Logs (create log groups)
   - S3 (for SAM artifacts)

## Quick Start

### Option 1: Using the Deploy Script (Recommended)

The easiest way to deploy is using the included `deploy.sh` script:

```bash
# First time deployment with guided setup
./deploy.sh --guided

# Subsequent deployments
./deploy.sh

# Deploy and test endpoints
./deploy.sh --test
```

### Option 2: Using SAM CLI Directly

If you prefer to use SAM CLI commands directly:

```bash
# Validate the template
sam validate --lint

# Deploy (first time - guided)
sam deploy --guided

# Deploy (subsequent times)
sam deploy
```

## Deployment Steps

### Step 1: Prepare for Deployment

```bash
# Clone the repository (if you haven't already)
git clone https://github.com/ksysoev/opengate-example.git
cd opengate-example

# Ensure the deploy script is executable
chmod +x deploy.sh
```

### Step 2: First-Time Deployment (Guided)

For your first deployment, use the guided mode to configure all parameters:

```bash
./deploy.sh --guided
```

You'll be prompted for:
- **Stack Name**: Name for the CloudFormation stack (default: `opengate-example`)
- **AWS Region**: AWS region to deploy to (default: `us-east-1`)
- **Parameters**: Accept defaults or customize:
  - Environment: production/staging/development
  - Task Count: Number of Fargate tasks (default: 1)
  - Container Image: Docker image URL (default: `ghcr.io/ksysoev/opengate-example:latest`)
  - Container Port: Port the container listens on (default: 8080)
  - Task CPU: vCPU allocation (default: 512 = 0.5 vCPU)
  - Task Memory: Memory allocation (default: 1024 MB)
  - Health Check Path: Endpoint for health checks (default: `/posts`)

The deployment process will:
1. Validate the CloudFormation template
2. Create an S3 bucket for SAM artifacts (if needed)
3. Package and upload the template
4. Create a CloudFormation change set
5. Show you the changes to be made
6. Ask for confirmation
7. Deploy the infrastructure (takes ~5-10 minutes)

### Step 3: Monitor Deployment

Watch the deployment progress:

```bash
# In the AWS Console
# Navigate to: CloudFormation > Stacks > opengate-example

# Or use AWS CLI
aws cloudformation describe-stack-events \
  --stack-name opengate-example \
  --region us-east-1 \
  --max-items 10
```

### Step 4: Get Deployment Outputs

After successful deployment, retrieve the ALB URL:

```bash
# The deploy script shows outputs automatically
# Or retrieve manually:
aws cloudformation describe-stacks \
  --stack-name opengate-example \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

Example output:
```json
[
  {
    "OutputKey": "LoadBalancerURL",
    "OutputValue": "http://opengate-example-alb-123456789.us-east-1.elb.amazonaws.com"
  },
  {
    "OutputKey": "LoadBalancerDNS",
    "OutputValue": "opengate-example-alb-123456789.us-east-1.elb.amazonaws.com"
  },
  {
    "OutputKey": "ClusterName",
    "OutputValue": "opengate-example-cluster"
  },
  {
    "OutputKey": "ServiceName",
    "OutputValue": "opengate-example-service"
  }
]
```

### Step 5: Test the Deployment

Test the endpoints using the ALB URL:

```bash
# Get the ALB URL
ALB_URL=$(aws cloudformation describe-stacks \
  --stack-name opengate-example \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text)

# Test endpoints
curl "${ALB_URL}/posts"
curl "${ALB_URL}/users"
curl "${ALB_URL}/comments?postId=1"
curl "${ALB_URL}/posts/1"
```

Or use the deploy script:

```bash
./deploy.sh --test
```

## Configuration

### Customizing Parameters

#### Method 1: Edit samconfig.toml

Edit the `samconfig.toml` file to change default parameters:

```toml
[default.deploy.parameters]
parameter_overrides = [
  "Environment=staging",
  "TaskCount=2",
  "TaskCpu=1024",
  "TaskMemory=2048"
]
```

Then deploy:
```bash
sam deploy
```

#### Method 2: Override via Command Line

```bash
sam deploy \
  --parameter-overrides \
    Environment=staging \
    TaskCount=2 \
    TaskCpu=1024 \
    TaskMemory=2048
```

#### Method 3: Environment Variables in Deploy Script

```bash
STACK_NAME=my-custom-stack AWS_REGION=us-west-2 ./deploy.sh
```

### Available Parameters

| Parameter | Description | Default | Valid Values |
|-----------|-------------|---------|--------------|
| `Environment` | Environment name | `production` | development, staging, production |
| `TaskCount` | Number of tasks | `1` | 1-10 |
| `ContainerImage` | Docker image | `ghcr.io/ksysoev/opengate-example:latest` | Any valid image URL |
| `ContainerPort` | Container port | `8080` | Any valid port |
| `TaskCpu` | CPU units | `512` (0.5 vCPU) | 256, 512, 1024, 2048, 4096 |
| `TaskMemory` | Memory in MB | `1024` | 512, 1024, 2048, 4096, 8192 |
| `HealthCheckPath` | Health check path | `/posts` | Any valid path |

### Resource Sizing

#### CPU and Memory Combinations

Fargate requires specific CPU/memory combinations:

| CPU (vCPU) | Memory Options (GB) |
|------------|---------------------|
| 0.25 | 0.5, 1, 2 |
| 0.5 | 1, 2, 3, 4 |
| 1 | 2, 3, 4, 5, 6, 7, 8 |
| 2 | 4-16 (in 1 GB increments) |
| 4 | 8-30 (in 1 GB increments) |

## Managing the Deployment

### View Logs

#### Option 1: Using SAM CLI

```bash
# Tail logs in real-time
sam logs --stack-name opengate-example --tail

# View recent logs
sam logs --stack-name opengate-example
```

#### Option 2: Using AWS CLI

```bash
# Get the log group name
LOG_GROUP="/ecs/opengate-example"

# Tail logs
aws logs tail ${LOG_GROUP} --follow --region us-east-1

# View specific time range
aws logs tail ${LOG_GROUP} \
  --since 1h \
  --region us-east-1
```

#### Option 3: AWS Console

Navigate to: CloudWatch > Log Groups > `/ecs/opengate-example`

### Update the Deployment

To update the deployment with changes:

```bash
# Make changes to template.yaml or parameters
# Then deploy:
sam deploy

# Or with the deploy script:
./deploy.sh
```

### Scale the Service

#### Temporarily (will reset on next deployment)

```bash
aws ecs update-service \
  --cluster opengate-example-cluster \
  --service opengate-example-service \
  --desired-count 3 \
  --region us-east-1
```

#### Permanently

Update `samconfig.toml`:
```toml
parameter_overrides = [
  "TaskCount=3"
]
```

Then redeploy:
```bash
sam deploy
```

### Monitor the Service

#### Check Service Status

```bash
aws ecs describe-services \
  --cluster opengate-example-cluster \
  --services opengate-example-service \
  --region us-east-1
```

#### Check Task Status

```bash
aws ecs list-tasks \
  --cluster opengate-example-cluster \
  --service-name opengate-example-service \
  --region us-east-1
```

#### Check ALB Target Health

```bash
# Get target group ARN
TG_ARN=$(aws cloudformation describe-stack-resources \
  --stack-name opengate-example \
  --region us-east-1 \
  --query 'StackResources[?LogicalResourceId==`ALBTargetGroup`].PhysicalResourceId' \
  --output text)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn ${TG_ARN} \
  --region us-east-1
```

## Troubleshooting

### Deployment Fails

#### Issue: CloudFormation stack creation fails

**Solution:**
1. Check the CloudFormation events for error details:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name opengate-example \
     --region us-east-1 \
     --max-items 20
   ```

2. Common issues:
   - **Insufficient permissions**: Ensure your IAM user/role has required permissions
   - **Service limits**: Check AWS service quotas (VPCs, Elastic IPs, etc.)
   - **Invalid parameters**: Verify CPU/memory combinations are valid

#### Issue: Tasks fail to start

**Solution:**
1. Check ECS service events:
   ```bash
   aws ecs describe-services \
     --cluster opengate-example-cluster \
     --services opengate-example-service \
     --region us-east-1 \
     --query 'services[0].events[:5]'
   ```

2. Common causes:
   - **Image pull error**: Container image not accessible
   - **Resource constraints**: Insufficient CPU/memory
   - **Health check failures**: Container not responding on health check endpoint

### Service is Unhealthy

#### Issue: ALB health checks failing

**Solution:**
1. Check target health:
   ```bash
   # Get target group ARN (see above)
   # Check health
   aws elbv2 describe-target-health --target-group-arn ${TG_ARN}
   ```

2. Check container logs:
   ```bash
   sam logs --stack-name opengate-example --tail
   ```

3. Common causes:
   - **Wrong health check path**: Verify `/posts` endpoint is accessible
   - **Container not listening**: Check container is listening on port 8080
   - **Security group issue**: Verify ALB can reach container on port 8080

### Cannot Access ALB

#### Issue: Cannot reach ALB URL from browser/curl

**Solution:**
1. Verify ALB is active:
   ```bash
   aws elbv2 describe-load-balancers \
     --region us-east-1 \
     --query 'LoadBalancers[?contains(LoadBalancerName, `opengate`)].State'
   ```

2. Check ALB security group allows port 80:
   ```bash
   aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=opengate-example-alb-sg" \
     --region us-east-1
   ```

3. Ensure at least one task is running and healthy

### High Costs

#### Issue: AWS bill is higher than expected

**Solution:**
1. Check running tasks:
   ```bash
   aws ecs list-tasks --cluster opengate-example-cluster
   ```

2. Primary cost drivers:
   - **NAT Gateway**: ~$32/month + data transfer (largest fixed cost)
   - **Fargate**: ~$15/month per task (0.5 vCPU, 1 GB)
   - **ALB**: ~$16-25/month + data transfer

3. Cost optimization options:
   - Use VPC endpoints instead of NAT Gateway (complex setup)
   - Reduce task count during non-peak hours
   - Delete stack when not in use

## Cost Estimation

### Monthly Costs (us-east-1)

**Base Infrastructure:**
- NAT Gateway: ~$32.40/month (0.045 per hour × 720 hours)
- NAT Gateway data: ~$0.045 per GB processed
- Elastic IP (NAT): $0 (when attached)

**Application Load Balancer:**
- ALB base: ~$16.20/month (0.0225 per hour × 720 hours)
- Load Balancer Capacity Units: Variable based on traffic

**Fargate (per task, 0.5 vCPU, 1 GB):**
- vCPU: ~$14.69/month (0.04048 per hour × 720 hours × 0.5)
- Memory: ~$1.61/month (0.004445 per hour × 720 hours × 1 GB)
- **Total per task**: ~$16.30/month

**CloudWatch Logs:**
- Ingestion: $0.50 per GB
- Storage: $0.03 per GB per month
- Expected: ~$1-5/month (depends on log volume)

**Total Estimated Monthly Cost:**
- 1 task: ~$65-75/month
- 2 tasks: ~$80-95/month
- 3 tasks: ~$95-115/month

**Cost Optimization Tips:**
- Delete the stack when not needed
- Use smaller task sizes for testing (0.25 vCPU, 512 MB)
- Consider VPC endpoints to eliminate NAT Gateway costs (requires more setup)

## Adding HTTPS Support

Currently, the deployment uses HTTP only. To add HTTPS:

### Prerequisites
1. Custom domain name
2. AWS Certificate Manager (ACM) certificate for your domain

### Steps

1. **Request ACM Certificate:**
   ```bash
   aws acm request-certificate \
     --domain-name yourdomain.com \
     --validation-method DNS \
     --region us-east-1
   ```

2. **Validate the certificate** using DNS records

3. **Update template.yaml** to add HTTPS listener:
   ```yaml
   ALBListenerHTTPS:
     Type: AWS::ElasticLoadBalancingV2::Listener
     Properties:
       LoadBalancerArn: !Ref ApplicationLoadBalancer
       Port: 443
       Protocol: HTTPS
       Certificates:
         - CertificateArn: !Ref CertificateArn
       DefaultActions:
         - Type: forward
           TargetGroupArn: !Ref ALBTargetGroup
   ```

4. **Add parameter for certificate:**
   ```yaml
   Parameters:
     CertificateArn:
       Type: String
       Description: ARN of ACM certificate for HTTPS
   ```

5. **Update security group** to allow port 443:
   ```yaml
   SecurityGroupIngress:
     - IpProtocol: tcp
       FromPort: 443
       ToPort: 443
       CidrIp: 0.0.0.0/0
   ```

6. **Redeploy:**
   ```bash
   sam deploy --parameter-overrides CertificateArn=arn:aws:acm:...
   ```

## Cleanup

### Delete the Stack

To delete all AWS resources and stop incurring charges:

#### Option 1: Using SAM CLI

```bash
sam delete --stack-name opengate-example --region us-east-1
```

#### Option 2: Using AWS CLI

```bash
aws cloudformation delete-stack \
  --stack-name opengate-example \
  --region us-east-1

# Monitor deletion
aws cloudformation wait stack-delete-complete \
  --stack-name opengate-example \
  --region us-east-1
```

#### Option 3: AWS Console

1. Navigate to: CloudFormation > Stacks
2. Select `opengate-example`
3. Click "Delete"
4. Confirm deletion

### What Gets Deleted

The following resources will be deleted:
- VPC and all networking components (subnets, route tables, etc.)
- NAT Gateway and Elastic IP
- Internet Gateway
- Application Load Balancer and Target Group
- ECS Cluster, Service, and Task Definition
- Security Groups
- IAM Roles
- CloudWatch Log Group (logs will be deleted after retention period)

### Retained Resources

The following are NOT automatically deleted:
- S3 bucket used for SAM artifacts (delete manually if needed)
- CloudWatch Logs (if retention period hasn't expired)

## Advanced Topics

### Auto Scaling

To add auto-scaling based on CPU/memory utilization:

1. Add to `template.yaml`:
   ```yaml
   ScalableTarget:
     Type: AWS::ApplicationAutoScaling::ScalableTarget
     Properties:
       ServiceNamespace: ecs
       ResourceId: !Sub service/${ECSCluster}/${ECSService.Name}
       ScalableDimension: ecs:service:DesiredCount
       MinCapacity: 1
       MaxCapacity: 4
       RoleARN: !Sub arn:aws:iam::${AWS::AccountId}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService
   
   ScalingPolicy:
     Type: AWS::ApplicationAutoScaling::ScalingPolicy
     Properties:
       PolicyName: !Sub ${AWS::StackName}-scaling-policy
       PolicyType: TargetTrackingScaling
       ScalingTargetId: !Ref ScalableTarget
       TargetTrackingScalingPolicyConfiguration:
         TargetValue: 70.0
         PredefinedMetricSpecification:
           PredefinedMetricType: ECSServiceAverageCPUUtilization
   ```

### Custom Domain with Route53

1. Create hosted zone in Route53
2. Add ACM certificate (see HTTPS section above)
3. Add Route53 alias record:
   ```yaml
   DNSRecord:
     Type: AWS::Route53::RecordSet
     Properties:
       HostedZoneId: !Ref HostedZoneId
       Name: api.yourdomain.com
       Type: A
       AliasTarget:
         HostedZoneId: !GetAtt ApplicationLoadBalancer.CanonicalHostedZoneID
         DNSName: !GetAtt ApplicationLoadBalancer.DNSName
   ```

### Using Private Container Registry (ECR)

1. Create ECR repository:
   ```bash
   aws ecr create-repository \
     --repository-name opengate-example \
     --region us-east-1
   ```

2. Build and push image:
   ```bash
   # Authenticate Docker to ECR
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
   
   # Build and tag
   docker build -t opengate-example .
   docker tag opengate-example:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/opengate-example:latest
   
   # Push
   docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/opengate-example:latest
   ```

3. Update parameter:
   ```bash
   sam deploy --parameter-overrides \
     ContainerImage=<account-id>.dkr.ecr.us-east-1.amazonaws.com/opengate-example:latest
   ```

### Multi-Region Deployment

To deploy to multiple regions:

```bash
# Deploy to us-east-1
sam deploy --region us-east-1 --config-env production-us-east-1

# Deploy to eu-west-1
sam deploy --region eu-west-1 --config-env production-eu-west-1
```

Add environment-specific configurations in `samconfig.toml`:
```toml
[production-us-east-1.deploy.parameters]
stack_name = "opengate-example-us-east-1"
region = "us-east-1"

[production-eu-west-1.deploy.parameters]
stack_name = "opengate-example-eu-west-1"
region = "eu-west-1"
```

## Support

For issues with:
- **OpenGate**: https://github.com/ksysoev/opengate/issues
- **This example**: https://github.com/ksysoev/opengate-example/issues
- **AWS services**: AWS Support or AWS forums

## Additional Resources

- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [AWS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [OpenGate Documentation](https://github.com/ksysoev/opengate)
