#!/bin/bash
# vLLM Gateway Monitoring Stack Cleanup Script

set -e

NAMESPACE="vllm-monitoring"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   vLLM Gateway Monitoring Stack Cleanup               ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if namespace exists
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}Found namespace: $NAMESPACE${NC}"
    echo ""
    
    # Show what will be deleted
    echo "Resources to be deleted:"
    kubectl get all -n $NAMESPACE
    echo ""
    
    read -p "Are you sure you want to delete everything? (yes/no): " confirm
    
    if [ "$confirm" == "yes" ]; then
        echo ""
        echo -e "${YELLOW}Deleting namespace and all resources...${NC}"
        kubectl delete namespace $NAMESPACE
        echo ""
        echo -e "${GREEN}✓ Cleanup complete!${NC}"
        echo -e "${GREEN}All monitoring resources have been removed.${NC}"
    else
        echo ""
        echo -e "${RED}Cleanup cancelled.${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}Namespace $NAMESPACE does not exist. Nothing to clean up.${NC}"
fi

