# vLLM Gateway with Monitoring

A FastAPI-based gateway for vLLM with comprehensive monitoring, metrics, and load testing.

## Quick Start

### 1. Start the Gateway
```bash
python main.py
# Gateway runs at http://127.0.0.1:9000
# Metrics at http://127.0.0.1:9000/metrics
```

### 2. Deploy Monitoring Stack
```bash
kubectl apply -f k8s/
```

### 3. Access Grafana
```bash
kubectl port-forward -n vllm-monitoring svc/grafana 3000:3000
# Login: admin/admin
# Import dashboard from dashboards/vllm-gateway.json
```

### 4. Run Load Tests
```bash
k6 run loadtests/baseline.js
```

## Project Structure

```
vllm-gateway/
├── main.py                      # FastAPI gateway with Prometheus metrics
├── k8s/                         # Kubernetes manifests
│   ├── namespace.yaml          # vllm-monitoring namespace
│   ├── prometheus/             # Prometheus monitoring
│   │   ├── rbac.yaml          # ServiceAccount, ClusterRole, Binding
│   │   ├── configmap.yaml     # Scrape configuration
│   │   ├── deployment.yaml    # Prometheus deployment
│   │   └── service.yaml       # NodePort service (30090)
│   ├── grafana/                # Grafana dashboards
│   │   ├── configmap.yaml     # Datasource configuration
│   │   ├── deployment.yaml    # Grafana deployment
│   │   └── service.yaml       # NodePort service (30300)
│   └── gpu-exporter/           # NVIDIA GPU metrics
│       └── daemonset.yaml     # GPU exporter DaemonSet
├── dashboards/
│   └── vllm-gateway.json       # Grafana dashboard (import this)
├── loadtests/
│   └── baseline.js             # k6 load test (10/50/100 concurrent)
└── docs/
    └── monitoring.md           # Complete documentation
```

## Metrics Collected

### Gateway Metrics
- **gateway_time_to_first_token_seconds** - TTFT histogram
- **gateway_tokens_per_second** - Throughput histogram  
- **gateway_requests_total** - Total requests counter
- **gateway_rps** - Requests per second
- **gateway_queue_depth** - In-flight requests gauge

### GPU Metrics (via nvidia_gpu_exporter)
- **nvidia_gpu_duty_cycle** - GPU utilization %
- **nvidia_gpu_memory_used_bytes** - VRAM usage
- **nvidia_gpu_memory_total_bytes** - Total VRAM
- **nvidia_gpu_temperature** - GPU temperature
- **nvidia_gpu_power_usage_milliwatts** - Power draw

## Endpoints

- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics
- `POST /chat` - Chat completion (streaming)

## Load Test Scenarios

The baseline test includes:
1. **10 concurrent users** - 2 minutes (0:00-2:00)
2. **50 concurrent users** - 2 minutes (2:30-4:30)
3. **100 concurrent users** - 2 minutes (5:00-7:00)

Total duration: ~7 minutes

## Documentation

For complete setup, configuration, and troubleshooting guide, see:
- [docs/monitoring.md](docs/monitoring.md)

## Requirements

- Python 3.8+
- FastAPI, httpx, prometheus-client, uvicorn
- Kubernetes cluster (minikube/k3s/etc)
- k6 for load testing
- NVIDIA GPUs with nvidia-smi

## Quick Commands

```bash
# Deploy everything
kubectl apply -f k8s/

# Check status
kubectl get pods -n vllm-monitoring

# Access Grafana
kubectl port-forward -n vllm-monitoring svc/grafana 3000:3000

# Access Prometheus
kubectl port-forward -n vllm-monitoring svc/prometheus 9090:9090

# Run load test
k6 run loadtests/baseline.js

# View metrics directly
curl http://127.0.0.1:9000/metrics

# Cleanup
kubectl delete namespace vllm-monitoring
```

## Default Credentials

- **Grafana**: admin / admin
- **Prometheus**: No authentication

## Notes

- Gateway expects vLLM backend at `http://127.0.0.1:8000`
- Prometheus scrapes gateway at `http://host.docker.internal:9000/metrics`
- GPU UUIDs in dashboard are for RTX 3090s (update if different)
- All services use NodePort for easy access on local clusters

# Pasting ts cuz im lazy

# Activate venv

source venv/bin/activate

# Run uvicorn fastapi

cd vx/vllm* && python main.py

# TinyLlama deployment api server deployment

MODEL="TinyLlama/TinyLlama-1.1B-Chat-v1.0"
CUDA_VISIBLE_DEVICES=0 python -m vllm.entrypoints.openai.api_server \
  --model $MODEL \
  --gpu-memory-utilization 0.8 \
  --max-model-len 2048 \
  --host 127.0.0.1 --port 8000



# Keep track of in TMUX (4 panes)

# K3d Cluster Deployment -> Grafana port forward to port 3000 (after deployment script)
# fastapi gateway server (port 8000)
# run the model (tinyllama)
# prometheus deployment script ./deployment.yaml
