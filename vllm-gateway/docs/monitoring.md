# vLLM Gateway Monitoring & Load Testing Guide

This guide covers the complete monitoring and load testing setup for the vLLM gateway, including Prometheus, Grafana, GPU metrics, and k6 load tests.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Deployment](#deployment)
- [Accessing Services](#accessing-services)
- [Grafana Dashboard](#grafana-dashboard)
- [Running Load Tests](#running-load-tests)
- [Interpreting Metrics](#interpreting-metrics)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- Kubernetes cluster (minikube, k3s, or full cluster)
- `kubectl` configured and connected to your cluster
- k6 installed for load testing: `https://k6.io/docs/get-started/installation/`
- vLLM gateway running at `http://127.0.0.1:9000`
- NVIDIA GPUs with nvidia-smi available

## Architecture Overview

The monitoring stack consists of:

```
┌─────────────────┐
│  vLLM Gateway   │ :9000/metrics
│   (main.py)     │
└────────┬────────┘
         │
         │ scrape
         ▼
┌─────────────────┐     ┌──────────────┐
│   Prometheus    │────▶│   Grafana    │
│     :9090       │     │    :3000     │
└────────┬────────┘     └──────────────┘
         │
         │ scrape
         ▼
┌─────────────────┐
│  GPU Exporter   │ :9835/metrics
│  (nvidia-smi)   │
└─────────────────┘
```

### Metrics Collected

1. **Gateway Metrics** (from `main.py`):
   - `gateway_time_to_first_token_seconds` - Time to first token histogram
   - `gateway_tokens_per_second` - Tokens/sec throughput histogram
   - `gateway_requests_total` - Total request counter
   - `gateway_rps` - Requests per second counter
   - `gateway_queue_depth` - In-flight requests gauge

2. **GPU Metrics** (from nvidia_gpu_exporter):
   - `nvidia_gpu_duty_cycle` - GPU utilization percentage (0-100)
   - `nvidia_gpu_memory_used_bytes` - GPU memory used
   - `nvidia_gpu_memory_total_bytes` - Total GPU memory
   - `nvidia_gpu_temperature` - GPU temperature in Celsius
   - `nvidia_gpu_power_usage_milliwatts` - Power consumption

## Deployment

### Step 1: Deploy the Monitoring Stack

Deploy all Kubernetes resources in order:

```bash
# Navigate to the project directory
cd /home/amoorching/vx/vllm-gateway

# Deploy namespace
kubectl apply -f k8s/namespace.yaml

# Deploy Prometheus
kubectl apply -f k8s/prometheus/rbac.yaml
kubectl apply -f k8s/prometheus/configmap.yaml
kubectl apply -f k8s/prometheus/deployment.yaml
kubectl apply -f k8s/prometheus/service.yaml

# Deploy Grafana
kubectl apply -f k8s/grafana/configmap.yaml
kubectl apply -f k8s/grafana/deployment.yaml
kubectl apply -f k8s/grafana/service.yaml

# Deploy GPU Exporter
kubectl apply -f k8s/gpu-exporter/daemonset.yaml
```

Or deploy everything at once:

```bash
kubectl apply -f k8s/
```

### Step 2: Verify Deployment

Check that all pods are running:

```bash
kubectl get pods -n vllm-monitoring

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# prometheus-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# grafana-xxxxxxxxxx-xxxxx      1/1     Running   0          2m
# gpu-exporter-xxxxx            1/1     Running   0          2m
```

Check services:

```bash
kubectl get svc -n vllm-monitoring

# Expected output:
# NAME         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
# prometheus   NodePort   10.x.x.x        <none>        9090:30090/TCP   2m
# grafana      NodePort   10.x.x.x        <none>        3000:30300/TCP   2m
```

### Step 3: Start the vLLM Gateway

Ensure your vLLM gateway is running:

```bash
cd /home/amoorching/vx/vllm-gateway
python main.py
```

The gateway should be accessible at `http://127.0.0.1:9000` with metrics at `http://127.0.0.1:9000/metrics`.

## Accessing Services

### Prometheus

**Option 1: NodePort (if using minikube/k3s)**
```bash
# Access at http://<node-ip>:30090
# For minikube:
minikube service prometheus -n vllm-monitoring
```

**Option 2: Port Forward**
```bash
kubectl port-forward -n vllm-monitoring svc/prometheus 9090:9090
# Access at http://localhost:9090
```

### Grafana

**Option 1: NodePort**
```bash
# Access at http://<node-ip>:30300
# For minikube:
minikube service grafana -n vllm-monitoring
```

**Option 2: Port Forward**
```bash
kubectl port-forward -n vllm-monitoring svc/grafana 3000:3000
# Access at http://localhost:3000
```

**Default Credentials:**
- Username: `admin`
- Password: `admin`

## Grafana Dashboard

### Import the Dashboard

1. Log into Grafana at `http://localhost:3000`
2. Navigate to **Dashboards** → **Import**
3. Upload the dashboard file: `dashboards/vllm-gateway.json`
4. Select the **Prometheus** datasource
5. Click **Import**

### Dashboard Panels

The dashboard includes the following panels:

1. **Time to First Token (TTFT)** - p50, p95, p99 latencies
2. **Tokens per Second** - Throughput distribution
3. **Requests per Second** - Request rate over time
4. **Queue Depth** - Current in-flight requests
5. **GPU Utilization** - Usage % for both RTX 3090s
6. **GPU Memory Usage** - Memory consumption per GPU
7. **Total Requests** - Cumulative request counter
8. **Average TTFT** - Rolling 5-minute average
9. **Average Throughput** - Rolling 5-minute average tokens/sec
10. **Current Queue Depth** - Real-time queue status

### Dashboard Features

- **Auto-refresh**: Updates every 5 seconds
- **Time range**: Last 15 minutes by default
- **Alerts**: GPU utilization alert at 90%
- **Annotations**: Automatic detection of load changes

## Running Load Tests

### Prerequisites

Install k6 if not already installed:

```bash
# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# macOS
brew install k6
```

### Run Baseline Load Test

The baseline test includes three scenarios:
- **10 concurrent users** for 2 minutes (starts at 0s)
- **50 concurrent users** for 2 minutes (starts at 2m30s)
- **100 concurrent users** for 2 minutes (starts at 5m)

Run the test:

```bash
cd /home/amoorching/vx/vllm-gateway

# Basic run
k6 run loadtests/baseline.js

# Run with custom gateway URL
GATEWAY_URL=http://localhost:9000 k6 run loadtests/baseline.js

# Run with detailed output
k6 run --out json=results.json loadtests/baseline.js

# Run with cloud results (requires k6 cloud account)
k6 run --out cloud loadtests/baseline.js
```

### Understanding Test Output

The test will output:

```
scenarios: (100.00%) 3 scenarios, 100 max VUs, 7m30s max duration
  ✓ status is 200
  ✓ response has content
  ✓ content-type is SSE

  checks.........................: 100.00% ✓ 12000  ✗ 0
  failed_requests................: 0.00%   ✓ 0      ✗ 12000
  http_req_duration..............: avg=1.2s    p(95)=2.5s   p(99)=4.2s
  ttft_ms........................: avg=450ms   p(95)=850ms  p(99)=1200ms
  tokens_per_second..............: avg=75.5    p(95)=120.2
```

### Performance Thresholds

The test defines success criteria:
- **HTTP Duration**: p95 < 5s, p99 < 10s
- **TTFT**: p95 < 2s, p99 < 3s
- **Throughput**: avg > 30 tokens/sec
- **Failure Rate**: < 5%

## Interpreting Metrics

### Time to First Token (TTFT)

**What it means**: Time from request submission to receiving the first token.

**Good values**:
- p50: < 300ms (excellent), < 500ms (good)
- p95: < 1s (excellent), < 2s (acceptable)
- p99: < 2s (excellent), < 3s (acceptable)

**If high**:
- Check queue depth - may be queuing due to overload
- Check GPU utilization - may be under-utilized
- Review model loading time
- Consider batching optimizations

### Tokens per Second

**What it means**: Generation throughput per request.

**Good values**:
- For TinyLlama-1.1B: 50-150 tokens/sec typical
- Lower for larger models (7B, 13B, etc.)

**If low**:
- Check GPU utilization - should be high during generation
- Review batch size configuration in vLLM
- Check for CPU bottlenecks
- Verify PCIe bandwidth (for multi-GPU)

### Requests per Second (RPS)

**What it means**: System throughput in requests handled per second.

**Interpretation**:
- Baseline for capacity planning
- Should remain stable under constant load
- Drops indicate saturation or failures

### Queue Depth

**What it means**: Number of concurrent requests being processed.

**Interpretation**:
- Low queue depth + low RPS = insufficient load
- High queue depth + high TTFT = system overloaded
- Stable queue depth = healthy operation
- Growing queue depth = approaching saturation

### GPU Utilization

**What it means**: Percentage of GPU compute being used.

**Target values**:
- During inference: 70-95% (good utilization)
- Idle: < 5%
- 100% sustained: May indicate bottleneck

**If low during load**:
- CPU or network bottleneck
- Insufficient batch size
- Memory bandwidth limitation

### GPU Memory Usage

**What it means**: VRAM consumption on each GPU.

**Monitoring**:
- Should be stable after model loading
- RTX 3090 has 24GB VRAM
- TinyLlama-1.1B uses ~2-4GB
- Larger models may use 12-20GB

**If high**:
- Reduce max batch size
- Reduce max context length
- Consider model quantization (4-bit, 8-bit)

## Baseline Performance Guidelines

After running the load tests, establish your baselines:

### 10 Concurrent Users
- **Expected RPS**: 8-10
- **Expected TTFT p95**: < 500ms
- **Expected GPU Util**: 30-50%
- **Expected Queue**: 1-3

### 50 Concurrent Users
- **Expected RPS**: 30-45
- **Expected TTFT p95**: < 1.5s
- **Expected GPU Util**: 70-90%
- **Expected Queue**: 5-15

### 100 Concurrent Users
- **Expected RPS**: 40-60 (may saturate)
- **Expected TTFT p95**: 2-5s (queuing effects)
- **Expected GPU Util**: 85-98%
- **Expected Queue**: 20-50

**Note**: These are estimates for TinyLlama-1.1B on RTX 3090. Actual values will vary based on:
- Model size and quantization
- Max sequence length
- Batch size configuration
- Hardware specifications

## Troubleshooting

### Prometheus Not Scraping Gateway

Check connectivity from Prometheus pod:

```bash
POD=$(kubectl get pod -n vllm-monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vllm-monitoring $POD -- wget -O- http://host.docker.internal:9000/metrics
```

If failing, ensure `hostNetwork: true` is set in Prometheus deployment.

### GPU Metrics Not Appearing

Check GPU exporter logs:

```bash
kubectl logs -n vllm-monitoring -l app=gpu-exporter
```

Verify nvidia-smi is accessible:

```bash
POD=$(kubectl get pod -n vllm-monitoring -l app=gpu-exporter -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vllm-monitoring $POD -- nvidia-smi
```

### Grafana Dashboard Empty

1. Verify Prometheus is receiving data:
   - Go to Prometheus UI → Status → Targets
   - Ensure `vllm-gateway` target is UP
   - Run query: `gateway_requests_total`

2. Check Grafana datasource:
   - Go to Configuration → Data Sources
   - Test the Prometheus connection
   - Verify URL is `http://prometheus:9090`

### Load Test Failures

If k6 tests show high failure rates:

1. **Check gateway is running**:
   ```bash
   curl http://127.0.0.1:9000/health
   ```

2. **Check vLLM backend**:
   ```bash
   curl http://127.0.0.1:8000/health
   ```

3. **Review gateway logs** for errors

4. **Reduce load**: Start with fewer VUs to establish baseline

### High Latency Under Load

1. **Check GPU temperature**: High temp → thermal throttling
2. **Check CPU usage**: May need more workers
3. **Check network latency**: Between gateway and vLLM
4. **Review vLLM configuration**: Adjust batch size, max tokens

## Next Steps

After establishing baselines:

1. **Tune vLLM parameters** based on metrics
2. **Set up alerts** in Grafana for critical thresholds
3. **Run longer tests** (30+ minutes) for stability
4. **Test with production-like prompts** and workloads
5. **Experiment with different models** and compare metrics
6. **Scale testing**: Test with multiple gateway instances
7. **Optimize batching**: Find optimal batch size for throughput

## Additional Resources

- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
- [k6 Documentation](https://k6.io/docs/)
- [vLLM Performance Tuning](https://docs.vllm.ai/en/latest/performance/tuning.html)

