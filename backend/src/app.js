/**
 * Express Application Setup
 * Configures middleware, routes, and error handling
 */

import express from 'express';
import cors from 'cors';
import pinoHttp from 'pino-http';
import logger from './utils/logger.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';

// Route imports (to be implemented)
import authRoutes from './routes/auth.js';
import userRoutes from './routes/user.js';
import providerRoutes from './routes/provider.js';
import searchRoutes from './routes/search.js';
import bookingRoutes from './routes/booking.js';
import messageRoutes from './routes/message.js';
import reviewRoutes from './routes/review.js';
import paymentRoutes from './routes/payment.js';
import adminRoutes from './routes/admin.js';

const app = express();

// Middleware: Logging
app.use(pinoHttp({ logger }));

// Middleware: CORS
app.use(cors({
  origin: [
    process.env.FRONTEND_URL || 'http://localhost:3001',
    process.env.ADMIN_URL || 'http://localhost:3002'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Middleware: Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV
  });
});

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/providers', providerRoutes);
app.use('/api/v1/search', searchRoutes);
app.use('/api/v1/bookings', bookingRoutes);
app.use('/api/v1/messages', messageRoutes);
app.use('/api/v1/reviews', reviewRoutes);
app.use('/api/v1/payments', paymentRoutes);
app.use('/api/v1/admin', adminRoutes);

// Middleware: 404 handler
app.use(notFoundHandler);

// Middleware: Error handler (must be last)
app.use(errorHandler);

export default app;
