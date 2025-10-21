#!/bin/bash
# vLLM Gateway Monitoring Stack Deployment Script

set -e

# Change to script's parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."  # Go up to vllm-gateway/

NAMESPACE="vllm-monitoring"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   vLLM Gateway Monitoring Stack Deployment            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/6]${NC} Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl is available and connected${NC}"

# Deploy namespace
echo -e "\n${YELLOW}[2/6]${NC} Creating namespace..."
kubectl apply -f k8s/namespace.yaml
echo -e "${GREEN}✓ Namespace created${NC}"

# Deploy Prometheus
echo -e "\n${YELLOW}[3/6]${NC} Deploying Prometheus..."
kubectl apply -f k8s/prometheus/rbac.yaml
kubectl apply -f k8s/prometheus/configmap.yaml
kubectl apply -f k8s/prometheus/deployment.yaml
kubectl apply -f k8s/prometheus/service.yaml
echo -e "${GREEN}✓ Prometheus deployed${NC}"

# Deploy Grafana
echo -e "\n${YELLOW}[4/6]${NC} Deploying Grafana..."
kubectl apply -f k8s/grafana/configmap.yaml
kubectl apply -f k8s/grafana/deployment.yaml
kubectl apply -f k8s/grafana/service.yaml
echo -e "${GREEN}✓ Grafana deployed${NC}"

# Deploy GPU Exporter
echo -e "\n${YELLOW}[5/6]${NC} Deploying GPU Exporter..."
kubectl apply -f k8s/gpu-exporter/daemonset.yaml
echo -e "${GREEN}✓ GPU Exporter deployed${NC}"

# Wait for pods
echo -e "\n${YELLOW}[6/6]${NC} Waiting for pods to be ready..."
echo "This may take 1-2 minutes..."

kubectl wait --for=condition=ready pod -l app=prometheus -n $NAMESPACE --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠ Prometheus pod not ready yet${NC}"
kubectl wait --for=condition=ready pod -l app=grafana -n $NAMESPACE --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠ Grafana pod not ready yet${NC}"
kubectl wait --for=condition=ready pod -l app=gpu-exporter -n $NAMESPACE --timeout=120s 2>/dev/null || echo -e "${YELLOW}⚠ GPU Exporter pod not ready yet${NC}"

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo ""

# Show status
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment Summary${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"

echo ""
kubectl get pods -n $NAMESPACE

echo ""
kubectl get svc -n $NAMESPACE

# Access instructions
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Access Instructions${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Grafana:${NC}"
echo "  kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
echo "  Then open: http://localhost:3000"
echo "  Login: admin / admin"
echo "  Import dashboard from: dashboards/vllm-gateway.json"
echo ""
echo -e "${YELLOW}Prometheus:${NC}"
echo "  kubectl port-forward -n $NAMESPACE svc/prometheus 9090:9090"
echo "  Then open: http://localhost:9090"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Start the vLLM gateway: python main.py"
echo "  2. Access Grafana and import the dashboard"
echo "  3. Run load tests: k6 run loadtests/baseline.js"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"

