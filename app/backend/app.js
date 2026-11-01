const express = require('express');
const redis = require('redis');
const os = require('os');
const promClient = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;
const REDIS_URL = process.env.REDIS_URL || 'redis://redis:6379';
const APP_VERSION = process.env.APP_VERSION || '1.0.0';

// Redis
const redisClient = redis.createClient({ url: REDIS_URL });
redisClient.on('error', (err) => console.error('Redis error:', err));
redisClient.connect().catch(console.error);

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// Routes
app.get('/health', (req, res) => {
  httpRequestsTotal.inc({ method: 'GET', route: '/health', status: 200 });
  res.json({ status: 'ok', uptime: Math.floor(process.uptime()) });
});

app.get('/info', (req, res) => {
  httpRequestsTotal.inc({ method: 'GET', route: '/info', status: 200 });
  res.json({
    hostname: os.hostname(),
    version: APP_VERSION,
    node: process.version,
  });
});

app.get('/api/hits', async (req, res) => {
  try {
    const hits = await redisClient.incr('hits');
    httpRequestsTotal.inc({ method: 'GET', route: '/api/hits', status: 200 });
    res.json({ hits: Number(hits) });
  } catch (err) {
    res.status(500).json({ error: 'Redis unavailable', detail: err.message });
  }
});

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(PORT, () => {
  console.log(`Backend v${APP_VERSION} running on port ${PORT}`);
});