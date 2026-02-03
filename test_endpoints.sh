#!/bin/bash

# Test script for OpenGate Example endpoints
# This script verifies all configured endpoints are working correctly

set -e

GATEWAY_URL="${GATEWAY_URL:-http://localhost:8080}"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Testing OpenGate Example Endpoints${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Gateway URL: $GATEWAY_URL"
echo ""

# Counter for passed/failed tests
PASSED=0
FAILED=0

# Function to test an endpoint
test_endpoint() {
	local method=$1
	local path=$2
	local expected_status=$3
	local description=$4
	local data=$5

	echo -n "Testing: ${description}... "

	if [ -n "$data" ]; then
		response=$(curl -s -w "\n%{http_code}" -X "${method}" "${GATEWAY_URL}${path}" \
			-H "Content-Type: application/json" -d "$data" 2>&1)
	else
		response=$(curl -s -w "\n%{http_code}" -X "${method}" "${GATEWAY_URL}${path}" 2>&1)
	fi

	status_code=$(echo "$response" | tail -n 1)

	if [ "$status_code" = "$expected_status" ]; then
		echo -e "${GREEN}✓ PASS${NC} (Status: $status_code)"
		PASSED=$((PASSED + 1))
	else
		echo -e "${RED}✗ FAIL${NC} (Expected: $expected_status, Got: $status_code)"
		FAILED=$((FAILED + 1))
	fi
}

# Wait for gateway to be ready
echo -e "${YELLOW}Waiting for gateway to be ready...${NC}"
for i in {1..30}; do
	if curl -s -f "${GATEWAY_URL}/posts" >/dev/null 2>&1; then
		echo -e "${GREEN}Gateway is ready!${NC}"
		echo ""
		break
	fi
	if [ $i -eq 30 ]; then
		echo -e "${RED}Gateway failed to start after 30 seconds${NC}"
		echo "Please ensure the gateway is running: docker compose up -d"
		exit 1
	fi
	sleep 1
done

# Run tests
echo -e "${BLUE}Running endpoint tests...${NC}"
echo ""

test_endpoint "GET" "/posts" "200" "GET /posts (list all posts)"
test_endpoint "GET" "/posts/1" "200" "GET /posts/1 (get specific post)"
test_endpoint "POST" "/posts" "201" "POST /posts (create post)" '{"title":"Test","body":"Content","userId":1}'
test_endpoint "GET" "/users" "200" "GET /users (list all users)"
test_endpoint "GET" "/users/1" "200" "GET /users/1 (get specific user)"
test_endpoint "GET" "/comments?postId=1" "200" "GET /comments?postId=1 (get comments)"

# Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Test Results${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
	echo -e "${GREEN}All tests passed! ✓${NC}"
	echo ""
	exit 0
else
	echo -e "${RED}Some tests failed. Please check the output above.${NC}"
	echo ""
	exit 1
fi
