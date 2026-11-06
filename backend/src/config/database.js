/**
 * Direct Postgres connection (optional).
 *
 * The API itself talks to Supabase over HTTPS via supabase-js (see ./supabase.js) and does NOT need this.
 * This pool is only for tooling that needs raw SQL (e.g. migrations).
 *
 * DATABASE_URL must be the Supabase *Session pooler* string
 * (Dashboard -> Connect -> Session pooler), e.g.
 *   postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
 * The direct host db.<ref>.supabase.co is IPv6-only and fails from GitHub Codespaces (IPv4 only).
 *
 * The pool is created lazily, so importing this file never opens a connection.
 */

import { readFileSync } from 'node:fs';
import path from 'node:path';
import pg from 'pg';

const { Pool } = pg;

let pool;

const isDirectSupabaseHost = (connectionString) => {
  try {
    return /^db\.[a-z0-9]+\.supabase\.co$/i.test(new URL(connectionString).hostname);
  } catch {
    return false;
  }
};

/**
 * TLS is always verified. Supabase signs its database certificates with its own root CA, which is not
 * in Node's default trust store, so point DB_SSL_CA at that CA file:
 *   Dashboard -> Project Settings -> Database -> SSL Configuration -> Download certificate
 *   (save as backend/certs/supabase-ca.crt and set DB_SSL_CA=certs/supabase-ca.crt)
 */
const sslConfig = () => {
  const caPath = process.env.DB_SSL_CA;
  if (!caPath) return { rejectUnauthorized: true };
  return { rejectUnauthorized: true, ca: readFileSync(path.resolve(caPath), 'utf8') };
};

export const getPool = () => {
  if (pool) return pool;

  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL is not set. Use the Supabase Session pooler connection string.');
  }
  if (isDirectSupabaseHost(connectionString)) {
    throw new Error(
      'DATABASE_URL points to the direct host db.<ref>.supabase.co, which is IPv6-only and unreachable '
      + 'from Codespaces. Use the Session pooler string (aws-0-<region>.pooler.supabase.com, user postgres.<ref>).'
    );
  }

  pool = new Pool({
    connectionString,
    max: 5,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 15000,
    query_timeout: 60000,
    ssl: sslConfig()
  });

  pool.on('error', (err) => {
    // Idle client errors must be handled or they crash the process.
    // eslint-disable-next-line no-console
    console.error('Unexpected database pool error:', err.message);
  });

  return pool;
};

export const closePool = async () => {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
};

export default getPool;
