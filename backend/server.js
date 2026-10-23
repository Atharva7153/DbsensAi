import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import path from 'path'
import { fileURLToPath } from 'url'
import fs from 'fs'

// Import routes
import systemRoutes from './routes/systemRoutes.js'
import viewRoutes from './routes/viewRoutes.js'
import dbRoutes from './routes/dbRoutes.js'
import uploadRoutes from './routes/uploadRoutes.js'
import analysisRoutes from './routes/analysisRoutes.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

dotenv.config({ path: path.join(__dirname, '../.env') })
dotenv.config({ path: path.join(__dirname, '.env') })

const app = express()
let PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 5001

// Middleware
app.use(cors())
app.use(express.json())

// Mount API & System routes
app.use('/', systemRoutes)
app.use('/', viewRoutes)
app.use('/', dbRoutes)
app.use('/', uploadRoutes)
app.use('/', analysisRoutes)

// Serve Frontend Static Build if available (Unified Deployment)
const frontendDistPath = path.resolve(__dirname, '../frontend/dist')
if (fs.existsSync(frontendDistPath)) {
  console.log(`📦 Serving frontend static build from ${frontendDistPath}`)
  app.use(express.static(frontendDistPath))

  // SPA fallback for all HTML GET routes (React Router support)
  app.get('*', (req, res, next) => {
    // If it's an API route or ping, let it fall through
    if (req.path.startsWith('/api') || req.path === '/ping') {
      return next()
    }
    res.sendFile(path.join(frontendDistPath, 'index.html'))
  })
}

// 404 Handler for API routes or unhandled requests
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    method: req.method
  })
})

// Start Server with Automatic Port Fallback for macOS AirPlay (Port 5000 conflict)
function startListening(port) {
  const server = app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 DBSense Unified Server running at http://0.0.0.0:${port}`)
    console.log(`📊 Health check: http://0.0.0.0:${port}/api/health`)
    console.log(`🏓 Ping-pong check: http://0.0.0.0:${port}/ping`)
  })

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.warn(`⚠️ Port ${port} is in use (often by macOS AirPlay Receiver / ControlCenter). Retrying on port ${port + 1}...`)
      startListening(port + 1)
    } else {
      console.error('Server error:', err)
    }
  })
}

startListening(PORT)
