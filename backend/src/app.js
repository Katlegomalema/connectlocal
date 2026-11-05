/**
 * Express Application Setup
 * Configures middleware, routes, and error handling
 */

import express from 'express';
import cors from 'cors';
import pinoHttp from 'pino-http';
import logger from './utils/logger.js';
import { buildCorsOptions } from './config/cors.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';

// Route imports (to be implemented)
import healthRoutes from './routes/health.js';
import authRoutes from './routes/auth.js';
import userRoutes from './routes/user.js';
import providerRoutes from './routes/provider.js';
import searchRoutes from './routes/search.js';
import bookingRoutes from './routes/booking.js';
import messageRoutes from './routes/message.js';
import reviewRoutes from './routes/review.js';
import paymentRoutes from './routes/payment.js';
import adminRoutes from './routes/admin.js';
import notificationRoutes from './routes/notification.js';
import uploadRoutes from './routes/uploads.js';

const app = express();

// Middleware: Logging
// Short request logs: method, path (no query string, it can carry tokens), status, time.
// No headers, so no Authorization tokens, cookies or IP addresses end up in the logs.
app.use(pinoHttp({
  logger,
  serializers: {
    req: (req) => ({ id: req.id, method: req.method, path: req.url.split('?')[0] }),
    res: (res) => ({ statusCode: res.statusCode })
  },
  // For 5xx, pino-http invents an Error ("failed with status code 500") with a useless stack.
  // The real error is already logged by errorHandler, so keep this line short.
  customErrorMessage: (req, res) => `request failed with status ${res.statusCode}`,
  customErrorObject: (req, res, err, val) => ({ req: val.req, res: val.res, responseTime: val.responseTime }),
  customLogLevel: (req, res, err) => {
    if (err || res.statusCode >= 500) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  }
}));

// Middleware: CORS (allowed origins: see src/config/cors.js)
app.use(cors(buildCorsOptions()));

// Middleware: Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Health checks: /health (process up) and /health/db (one tiny DB query)
app.use('/health', healthRoutes);

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
app.use('/api/v1/notifications', notificationRoutes);
app.use('/api/v1/uploads', uploadRoutes);

// Middleware: 404 handler
app.use(notFoundHandler);

// Middleware: Error handler (must be last)
app.use(errorHandler);

export default app;
