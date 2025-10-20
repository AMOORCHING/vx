# vx
Building an inference optimizer

## Components

### vLLM Gateway
FastAPI-based gateway for vLLM with comprehensive monitoring, metrics, and load testing capabilities.

Features:
- Prometheus metrics (TTFT, tokens/sec, RPS, queue depth)
- Grafana dashboards
- GPU utilization monitoring
- k6 load testing (10/50/100 concurrent users)

See [vllm-gateway/README.md](vllm-gateway/README.md) for details.
