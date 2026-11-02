/**
 * Database Configuration
 * Creates a Postgres connection pool for Supabase-managed PostgreSQL
 */

import pg from 'pg';

const { Pool } = pg;

const connectionString = process.env.DATABASE_URL || [
  'postgresql://',
  process.env.DB_USER || 'postgres',
  ':',
  process.env.DB_PASSWORD || '',
  '@',
  process.env.DB_HOST || 'db.fmizfdhuqygjpmimenfq.supabase.co',
  ':',
  process.env.DB_PORT || '5432',
  '/',
  process.env.DB_NAME || 'postgres'
].join('');

export const dbConfig = {
  connectionString,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: process.env.DB_SSL?.toLowerCase() === 'false' ? false : { rejectUnauthorized: true },
  query_timeout: 60000,
  max_retries: 3,
  retry_delay: 1000
};

export const pool = new Pool(dbConfig);

pool.on('error', (err) => {
  console.error('Unexpected database pool error:', err);
});

export default pool;
