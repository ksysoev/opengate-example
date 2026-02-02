#!/bin/bash
# OpenGate Example - AWS Deployment Script
# This script deploys the OpenGate container to AWS Fargate using SAM CLI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="${STACK_NAME:-opengate-example}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Functions
print_info() {
	echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
	echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
	echo -e "${RED}✗${NC} $1"
}

print_header() {
	echo ""
	echo -e "${BLUE}========================================${NC}"
	echo -e "${BLUE}$1${NC}"
	echo -e "${BLUE}========================================${NC}"
	echo ""
}

check_prerequisites() {
	print_header "Checking Prerequisites"

	# Check AWS CLI
	if ! command -v aws &>/dev/null; then
		print_error "AWS CLI is not installed"
		echo "Please install AWS CLI: https://aws.amazon.com/cli/"
		exit 1
	fi
	print_success "AWS CLI found: $(aws --version)"

	# Check SAM CLI
	if ! command -v sam &>/dev/null; then
		print_error "SAM CLI is not installed"
		echo "Please install SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
		exit 1
	fi
	print_success "SAM CLI found: $(sam --version)"

	# Check AWS credentials
	if ! aws sts get-caller-identity &>/dev/null; then
		print_error "AWS credentials are not configured"
		echo "Please configure AWS credentials using 'aws configure'"
		exit 1
	fi
	print_success "AWS credentials configured"

	# Display AWS account info
	AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
	AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
	print_info "AWS Account: ${AWS_ACCOUNT}"
	print_info "AWS User/Role: ${AWS_USER}"
	print_info "AWS Region: ${AWS_REGION}"
}

validate_template() {
	print_header "Validating CloudFormation Template"

	if sam validate --lint; then
		print_success "Template validation passed"
	else
		print_error "Template validation failed"
		exit 1
	fi
}

deploy_stack() {
	print_header "Deploying to AWS"

	print_info "Stack Name: ${STACK_NAME}"
	print_info "Region: ${AWS_REGION}"
	echo ""

	if [ "$GUIDED" = true ]; then
		print_info "Running guided deployment..."
		sam deploy --guided --region "${AWS_REGION}"
	else
		print_info "Deploying with saved configuration..."
		sam deploy --region "${AWS_REGION}"
	fi

	if [ $? -eq 0 ]; then
		print_success "Deployment completed successfully"
	else
		print_error "Deployment failed"
		exit 1
	fi
}

get_outputs() {
	print_header "Deployment Outputs"

	# Get CloudFormation outputs
	OUTPUTS=$(aws cloudformation describe-stacks \
		--stack-name "${STACK_NAME}" \
		--region "${AWS_REGION}" \
		--query 'Stacks[0].Outputs' \
		--output json 2>/dev/null)

	if [ $? -eq 0 ] && [ "$OUTPUTS" != "null" ]; then
		echo "$OUTPUTS" | jq -r '.[] | "\(.OutputKey): \(.OutputValue)"'
		echo ""

		# Extract and display the ALB URL
		ALB_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="LoadBalancerURL") | .OutputValue')
		if [ -n "$ALB_URL" ] && [ "$ALB_URL" != "null" ]; then
			print_success "Application Load Balancer URL:"
			echo "  ${ALB_URL}"
			echo ""
			print_info "Test endpoints:"
			echo "  ${ALB_URL}/posts"
			echo "  ${ALB_URL}/users"
			echo "  ${ALB_URL}/comments"
		fi
	else
		print_warning "Could not retrieve stack outputs"
	fi
}

test_endpoints() {
	print_header "Testing Endpoints"

	# Get ALB URL
	ALB_URL=$(aws cloudformation describe-stacks \
		--stack-name "${STACK_NAME}" \
		--region "${AWS_REGION}" \
		--query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
		--output text 2>/dev/null)

	if [ -z "$ALB_URL" ] || [ "$ALB_URL" = "None" ]; then
		print_warning "Could not retrieve ALB URL. Skipping endpoint tests."
		return
	fi

	print_info "Waiting for service to be ready (this may take a few minutes)..."
	sleep 30

	# Test /posts endpoint
	print_info "Testing GET ${ALB_URL}/posts"
	if curl -s -f -m 10 "${ALB_URL}/posts" >/dev/null; then
		print_success "GET /posts - OK"
	else
		print_warning "GET /posts - Failed (service may still be starting)"
	fi

	# Test /users endpoint
	print_info "Testing GET ${ALB_URL}/users"
	if curl -s -f -m 10 "${ALB_URL}/users" >/dev/null; then
		print_success "GET /users - OK"
	else
		print_warning "GET /users - Failed (service may still be starting)"
	fi

	print_info "Note: If tests failed, wait a few minutes for the service to fully start"
}

print_cleanup_instructions() {
	print_header "Cleanup Instructions"

	echo "To delete the stack and all AWS resources:"
	echo "  sam delete --stack-name ${STACK_NAME} --region ${AWS_REGION}"
	echo ""
	echo "Or using AWS CLI:"
	echo "  aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${AWS_REGION}"
}

show_logs() {
	print_header "Viewing Logs"

	LOG_GROUP="/ecs/${STACK_NAME}"

	print_info "Log Group: ${LOG_GROUP}"
	print_info "Use the following command to view logs:"
	echo "  sam logs --stack-name ${STACK_NAME} --region ${AWS_REGION}"
	echo ""
	echo "Or use AWS CLI:"
	echo "  aws logs tail ${LOG_GROUP} --follow --region ${AWS_REGION}"
}

show_usage() {
	cat <<EOF
OpenGate Example - AWS Deployment Script

Usage: $0 [OPTIONS]

Options:
    --guided            Run guided deployment (first time setup)
    --validate-only     Only validate the template, don't deploy
    --test              Run endpoint tests after deployment
    --logs              Show logs from the deployed service
    --region REGION     AWS region (default: us-east-1)
    --stack-name NAME   CloudFormation stack name (default: opengate-example)
    --help              Show this help message

Environment Variables:
    AWS_REGION          AWS region (default: us-east-1)
    STACK_NAME          CloudFormation stack name (default: opengate-example)

Examples:
    # First time deployment with guided setup
    $0 --guided

    # Deploy with default settings
    $0

    # Deploy to a different region
    $0 --region us-west-2

    # Validate template only
    $0 --validate-only

    # Deploy and test endpoints
    $0 --test

    # View logs
    $0 --logs

EOF
}

# Main script
main() {
	GUIDED=false
	VALIDATE_ONLY=false
	RUN_TESTS=false
	SHOW_LOGS=false

	# Parse command line arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		--guided)
			GUIDED=true
			shift
			;;
		--validate-only)
			VALIDATE_ONLY=true
			shift
			;;
		--test)
			RUN_TESTS=true
			shift
			;;
		--logs)
			SHOW_LOGS=true
			shift
			;;
		--region)
			AWS_REGION="$2"
			shift 2
			;;
		--stack-name)
			STACK_NAME="$2"
			shift 2
			;;
		--help)
			show_usage
			exit 0
			;;
		*)
			print_error "Unknown option: $1"
			show_usage
			exit 1
			;;
		esac
	done

	# Show header
	print_header "OpenGate Example - AWS Deployment"

	# Run selected operation
	if [ "$SHOW_LOGS" = true ]; then
		show_logs
		exit 0
	fi

	check_prerequisites
	validate_template

	if [ "$VALIDATE_ONLY" = true ]; then
		print_success "Validation complete. Exiting without deployment."
		exit 0
	fi

	deploy_stack
	get_outputs

	if [ "$RUN_TESTS" = true ]; then
		test_endpoints
	fi

	show_logs
	print_cleanup_instructions

	print_success "Deployment script completed!"
}

# Run main function
main "$@"
