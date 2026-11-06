/**
 * Health Routes
 * GET /health     -> process is up (no external calls)
 * GET /health/db  -> one tiny query against Supabase Postgres (via supabase-js over HTTPS, service role)
 */

import express from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import logger from '../utils/logger.js';

const router = express.Router();
const DB_CHECK_TIMEOUT_MS = 5000;

router.get('/', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV
  });
});

router.get('/db', async (req, res) => {
  const started = Date.now();
  try {
    const {
      count, error, status, statusText
    } = await supabaseAdmin
      .from('service_categories')
      .select('*', { count: 'exact', head: true })
      .abortSignal(AbortSignal.timeout(DB_CHECK_TIMEOUT_MS));

    if (error) throw Object.assign(error, { httpStatus: status, httpStatusText: statusText });

    return res.status(200).json({
      status: 'ok',
      database: 'connected',
      check: 'count(service_categories)',
      serviceCategories: count,
      latencyMs: Date.now() - started
    });
  } catch (err) {
    logger.error({ err }, 'Database health check failed');
    return res.status(503).json({
      status: 'error',
      database: 'not ok',
      check: 'count(service_categories)',
      // Only Postgres/PostgREST error details. No keys or connection strings are ever included here.
      error: {
        code: err.code || (err.httpStatus ? `HTTP_${err.httpStatus}` : err.name) || 'UNKNOWN',
        message: err.message || err.httpStatusText || 'Database check failed',
        hint: err.hint || (err.httpStatus === 401 ? 'Check SUPABASE_SERVICE_ROLE_KEY in backend/.env' : undefined)
      },
      latencyMs: Date.now() - started
    });
  }
});

export default router;
