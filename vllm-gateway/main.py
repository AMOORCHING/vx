
import time, asyncio, math
from typing import AsyncGenerator
import httpx
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, JSONResponse
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from prometheus_client import REGISTRY
import uvicorn

VLLM_URL = "http://127.0.0.1:9000/v1/chat/completions"

app = FastAPI()
request_queue_depth = Gauge("gateway_queue_depth", "In-flight requests at the gateway")
req_counter = Counter("gateway_requests_total", "Total requests", ["route"])
ttft_hist = Histogram("gateway_time_to_first_token_seconds", "TTFT seconds")
tokrate_hist = Histogram("gateway_tokens_per_second", "Tokens/sec over stream")
rps_counter = Counter("gateway_rps", "Requests per second counter tick")  # you can roll up in PromQL

# simple queue-depth tracking
_inflight = 0
_inflight_lock = asyncio.Lock()

async def _inc():
    global _inflight
    async with _inflight_lock:
        _inflight += 1
        request_queue_depth.set(_inflight)

async def _dec():
    global _inflight
    async with _inflight_lock:
        _inflight = max(0, _inflight - 1)
        request_queue_depth.set(_inflight)

@app.get("/health")
async def health():
    return {"ok": True}

@app.get("/metrics")
async def metrics():
    return JSONResponse(content=generate_latest(REGISTRY).decode("utf-8"),
                        media_type=CONTENT_TYPE_LATEST)

@app.post("/chat")
async def chat(request: Request):
    await _inc()
    req_counter.labels(route="/chat").inc()
    rps_counter.inc()
    payload = await request.json()
    # force streaming for TTFT + tokens/sec
    payload.setdefault("stream", True)
    payload.setdefault("model", "TinyLlama/TinyLlama-1.1B-Chat-v1.0")
    payload.setdefault("messages", [{"role":"user","content":"Say hello"}])

    started = time.perf_counter()
    first_token_time = None
    token_count = 0

    async def gen() -> AsyncGenerator[bytes, None]:
        nonlocal first_token_time, token_count
        async with httpx.AsyncClient(timeout=None) as client:
            async with client.stream("POST", VLLM_URL, json=payload) as r:
                async for chunk in r.aiter_bytes():
                    if first_token_time is None:
                        first_token_time = time.perf_counter()
                        ttft_hist.observe(first_token_time - started)
                    # crude token counting: count "delta" occurrences in SSE chunks
                    token_count += chunk.count(b'"delta"')
                    yield chunk
        # finalize tokens/sec
        if first_token_time is not None:
            dur = max(1e-6, time.perf_counter() - first_token_time)
            tokrate_hist.observe(token_count / dur)

    try:
        return StreamingResponse(gen(), media_type="text/event-stream")
    finally:
        await _dec()

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
