# Quick Start Guide

Get up and running with vLLM Gateway monitoring in 5 minutes.

## Prerequisites

- Python 3.8+ installed
- Kubernetes cluster running (minikube, k3s, or full cluster)
- kubectl configured
- k6 installed (optional, for load testing)

## Step 1: Install Python Dependencies

```bash
cd /home/amoorching/vx/vllm-gateway
pip install -r requirements.txt
```

## Step 2: Start vLLM Backend (if not alr running)

Ensure you have vLLM running at `http://127.0.0.1:8000`.

If you need to start it:
```bash
# Example with TinyLlama model
python -m vllm.entrypoints.openai.api_server \
    --model TinyLlama/TinyLlama-1.1B-Chat-v1.0 \
    --port 8000
```

## Step 3: Start the Gateway

```bash
python main.py
```

The gateway will start on `http://127.0.0.1:9000`

## Step 4: Test the Gateway

In a new terminal:
```bash
./test_gateway.sh
```

You should see all tests pass.

## Step 5: Deploy Monitoring Stack

```bash
./deploy.sh
```

This will deploy:
- Prometheus (metrics collection)
- Grafana (dashboards)
- GPU Exporter (NVIDIA GPU metrics)

Wait for all pods to be ready (the script will wait automatically).

## Step 6: Access Grafana

In a new terminal:
```bash
kubectl port-forward -n vllm-monitoring svc/grafana 3000:3000
```

Then open your browser to `http://localhost:3000`
- **Username**: admin
- **Password**: admin

## Step 7: Import Dashboard

1. In Grafana, click the **+** icon → **Import**
2. Click **Upload JSON file**
3. Select `dashboards/vllm-gateway.json`
4. Click **Import**

You should now see the vLLM Gateway Monitoring dashboard!

## Step 8: Run Load Test

In a new terminal:
```bash
k6 run loadtests/baseline.js
```

Watch the Grafana dashboard to see metrics in real-time:
- Time to First Token (TTFT)
- Tokens per Second
- Requests per Second
- Queue Depth
- GPU Utilization
- GPU Memory Usage

## Understanding the Load Test

The test runs 3 scenarios sequentially:
1. **10 concurrent users** (2 minutes) - Light load
2. **50 concurrent users** (2 minutes) - Medium load
3. **100 concurrent users** (2 minutes) - Heavy load

Total duration: ~7 minutes

## What to Watch

As the load test runs, observe:
- **TTFT increases** as load increases (queuing effect)
- **GPU utilization ramps up** to 80-95%
- **Queue depth grows** under 100 concurrent users
- **Throughput (tokens/sec)** remains relatively stable

## Cleanup

When done testing:
```bash
./cleanup.sh
```

This removes all Kubernetes resources.

## Troubleshooting

### Gateway won't start
- Check if vLLM backend is running: `curl http://127.0.0.1:8000/health`
- Check if port 9000 is available: `lsof -i :9000`

### No metrics in Grafana
- Verify Prometheus is scraping: Access Prometheus at `http://localhost:9090/targets`
- Check gateway metrics endpoint: `curl http://127.0.0.1:9000/metrics`

### GPU metrics not showing
- Verify GPU exporter pod is running: `kubectl get pods -n vllm-monitoring`
- Check nvidia-smi is accessible: `nvidia-smi`

### Load test fails
- Ensure gateway is running and accessible
- Reduce load: Edit `loadtests/baseline.js` to use fewer VUs
- Check vLLM backend has sufficient resources

## Next Steps

- Read the [full documentation](docs/monitoring.md)
- Experiment with different load patterns
- Tune vLLM parameters based on metrics
- Set up Grafana alerts for critical thresholds
- Export baseline metrics for comparison

## Useful Commands

```bash
# View gateway logs
tail -f gateway.log

# Check Kubernetes resources
kubectl get all -n vllm-monitoring

# View pod logs
kubectl logs -n vllm-monitoring -l app=prometheus
kubectl logs -n vllm-monitoring -l app=grafana
kubectl logs -n vllm-monitoring -l app=gpu-exporter

# Port forward Prometheus
kubectl port-forward -n vllm-monitoring svc/prometheus 9090:9090

# Restart a deployment
kubectl rollout restart deployment/grafana -n vllm-monitoring

# Scale GPU exporter (if needed)
kubectl scale daemonset/gpu-exporter -n vllm-monitoring --replicas=1
```

## Support

For detailed information, see:
- [README.md](README.md) - Project overview
- [docs/monitoring.md](docs/monitoring.md) - Complete documentation
- [k8s/](k8s/) - Kubernetes manifests
- [loadtests/baseline.js](loadtests/baseline.js) - Load test configuration

