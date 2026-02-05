import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const ttftMetric = new Trend('ttft_ms', true);
const tokensPerSecondMetric = new Trend('tokens_per_second', true);
const streamChunksMetric = new Counter('stream_chunks');
const failedRequestsRate = new Rate('failed_requests');

// Test configuration
export const options = {
  scenarios: {
    baseline_10_concurrent: {
      executor: 'constant-vus',
      vus: 10,
      duration: '2m',
      startTime: '0s',
      tags: { scenario: '10_concurrent' },
    },
    baseline_50_concurrent: {
      executor: 'constant-vus',
      vus: 50,
      duration: '2m',
      startTime: '2m30s',
      tags: { scenario: '50_concurrent' },
    },
    baseline_100_concurrent: {
      executor: 'constant-vus',
      vus: 100,
      duration: '2m',
      startTime: '5m',
      tags: { scenario: '100_concurrent' },
    },
  },
  thresholds: {
    'http_req_duration': ['p(95)<5000', 'p(99)<10000'], // 95% under 5s, 99% under 10s
    'ttft_ms': ['p(95)<2000', 'p(99)<3000'], // TTFT under 2s for p95
    'tokens_per_second': ['avg>30'], // Average at least 30 tokens/sec
    'failed_requests': ['rate<0.05'], // Less than 5% failure rate
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

// Test configuration
const GATEWAY_URL = __ENV.GATEWAY_URL || 'http://127.0.0.1:8000';
const CHAT_ENDPOINT = `${GATEWAY_URL}/chat`;

// Sample prompts for variety
const prompts = [
  'Write a short poem about artificial intelligence.',
  'Explain quantum computing in simple terms.',
  'What are the benefits of exercise?',
  'Describe the water cycle.',
  'Tell me about the history of the internet.',
  'What is machine learning?',
  'Explain photosynthesis.',
  'How do computers work?',
  'What is blockchain technology?',
  'Describe the solar system.',
];

function getRandomPrompt() {
  return prompts[Math.floor(Math.random() * prompts.length)];
}

export default function () {
  const prompt = getRandomPrompt();
  
  const payload = JSON.stringify({
    model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0',
    messages: [
      {
        role: 'user',
        content: prompt,
      },
    ],
    stream: true,
    max_tokens: 150,
    temperature: 0.7,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '60s',
    tags: {
      name: 'chat_completion',
    },
  };

  const startTime = Date.now();
  let firstTokenTime = null;
  let chunkCount = 0;
  let tokenCount = 0;

  const res = http.post(CHAT_ENDPOINT, payload, params);

  // Check response status
  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response has content': (r) => r.body && r.body.length > 0,
    'content-type is SSE': (r) => r.headers['Content-Type']?.includes('text/event-stream'),
  });

  if (!success) {
    failedRequestsRate.add(1);
    console.error(`Request failed with status ${res.status}: ${res.body?.substring(0, 200)}`);
  } else {
    failedRequestsRate.add(0);

    // Parse SSE stream to extract metrics
    const lines = res.body.split('\n');
    
    for (const line of lines) {
      if (line.startsWith('data: ')) {
        chunkCount++;
        
        // Estimate TTFT from first chunk
        if (firstTokenTime === null) {
          firstTokenTime = Date.now();
          const ttft = firstTokenTime - startTime;
          ttftMetric.add(ttft);
        }

        // Count tokens (approximate by counting "delta" or "content" fields)
        if (line.includes('"delta"') || line.includes('"content"')) {
          tokenCount++;
        }
      }
    }

    streamChunksMetric.add(chunkCount);

    // Calculate tokens per second
    if (firstTokenTime !== null && tokenCount > 0) {
      const streamDuration = (Date.now() - firstTokenTime) / 1000; // seconds
      if (streamDuration > 0) {
        const tokensPerSecond = tokenCount / streamDuration;
        tokensPerSecondMetric.add(tokensPerSecond);
      }
    }
  }

  // Small delay between requests per VU
  sleep(1);
}

export function handleSummary(data) {
  const timestamp = new Date().toISOString();
  
  console.log('='.repeat(80));
  console.log(`Load Test Summary - ${timestamp}`);
  console.log('='.repeat(80));
  
  // Extract key metrics
  const scenarios = data.root_group.groups || {};
  
  for (const [scenarioName, scenarioData] of Object.entries(scenarios)) {
    console.log(`\n${scenarioName}:`);
    
    const metrics = scenarioData.checks || {};
    const httpDuration = data.metrics.http_req_duration;
    const ttft = data.metrics.ttft_ms;
    const tps = data.metrics.tokens_per_second;
    
    if (httpDuration) {
      console.log(`  HTTP Request Duration:`);
      console.log(`    avg: ${httpDuration.values.avg?.toFixed(2)}ms`);
      console.log(`    p95: ${httpDuration.values['p(95)']?.toFixed(2)}ms`);
      console.log(`    p99: ${httpDuration.values['p(99)']?.toFixed(2)}ms`);
    }
    
    if (ttft) {
      console.log(`  Time to First Token:`);
      console.log(`    avg: ${ttft.values.avg?.toFixed(2)}ms`);
      console.log(`    p95: ${ttft.values['p(95)']?.toFixed(2)}ms`);
      console.log(`    p99: ${ttft.values['p(99)']?.toFixed(2)}ms`);
    }
    
    if (tps) {
      console.log(`  Tokens per Second:`);
      console.log(`    avg: ${tps.values.avg?.toFixed(2)}`);
      console.log(`    p95: ${tps.values['p(95)']?.toFixed(2)}`);
    }
  }
  
  console.log('\n' + '='.repeat(80));
  
  return {
    'stdout': '',
    'summary.json': JSON.stringify(data, null, 2),
  };
}

