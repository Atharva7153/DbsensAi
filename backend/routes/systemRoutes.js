import express from 'express'
import axios from 'axios'

const router = express.Router()

// Health check endpoint for internal diagnostics / dashboard status
router.get('/api/health', async (req, res) => {
  let aiLayerStatus = 'offline';
  try {
    let aiLayerUrl = (process.env.AI_LAYER_URL || 'http://127.0.0.1:8000').replace(/\/$/, '');
    const response = await axios.get(`${aiLayerUrl}/health`, { timeout: 4000 });
    if (response.status === 200) aiLayerStatus = 'online';
  } catch (err) {
    console.error('AI layer health check failed:', err.message);
  }

  res.json({
    status: 'ok',
    backend: 'online',
    aiLayer: aiLayerStatus,
    timestamp: new Date().toISOString(),
    service: 'DBSense AI Unified Platform',
    version: '1.0.0'
  })
})

// Unified Ping-Pong endpoint for UptimeRobot (handles GET, HEAD, POST on /ping and /api/ping)
router.all(['/ping', '/api/ping'], (req, res) => {
  // Asynchronously trigger internal AI layer ping so the Python process stays awake too
  try {
    const aiLayerUrl = (process.env.AI_LAYER_URL || 'http://127.0.0.1:8000').replace(/\/$/, '');
    axios.get(`${aiLayerUrl}/ping`, { timeout: 2000 }).catch(() => {});
  } catch (_) {}

  res.status(200).send('pong')
})

export default router
