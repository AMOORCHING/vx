#!/bin/bash
# Quick test script for vLLM Gateway

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

GATEWAY_URL="${GATEWAY_URL:-http://127.0.0.1:8000}"

echo -e "${GREEN}Testing vLLM Gateway at $GATEWAY_URL${NC}"
echo ""

# Test 1: Health check
echo -e "${YELLOW}[1/3]${NC} Testing health endpoint..."
if curl -s -f "$GATEWAY_URL/health" > /dev/null; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
    exit 1
fi

# Test 2: Metrics endpoint
echo -e "${YELLOW}[2/3]${NC} Testing metrics endpoint..."
if curl -s -f "$GATEWAY_URL/metrics" | grep -q "gateway_requests_total"; then
    echo -e "${GREEN}✓ Metrics endpoint working${NC}"
else
    echo -e "${RED}✗ Metrics endpoint failed${NC}"
    exit 1
fi

# Test 3: Chat endpoint
echo -e "${YELLOW}[3/3]${NC} Testing chat endpoint..."
response=$(curl -s -X POST "$GATEWAY_URL/chat" \
    -H "Content-Type: application/json" \
    -d '{
        "messages": [{"role": "user", "content": "Say hello"}],
        "max_tokens": 10
    }' | head -c 100)

if [ -n "$response" ]; then
    echo -e "${GREEN}✓ Chat endpoint working${NC}"
    echo "  Sample response: ${response:0:80}..."
else
    echo -e "${RED}✗ Chat endpoint failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All tests passed! Gateway is working correctly.${NC}"

