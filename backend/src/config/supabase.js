/**
 * Supabase Configuration
 * Initializes the Supabase client for database, auth, and storage operations
 */

import { createClient } from '@supabase/supabase-js';
import logger from '../utils/logger.js';

const supabaseUrl = process.env.SUPABASE_URL
  || process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY
  || process.env.SUPABASE_ANON_KEY
  || process.env.SUPABASE_PUBLISHABLE_KEY
  || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
  || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY
  || process.env.SUPABASE_SECRET_KEY
  || process.env.SUPABASE_ADMIN_KEY
  || process.env.NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY;
const jwksUrl = process.env.SUPABASE_JWKS_URL || `${supabaseUrl}/auth/v1/.well-known/jwks.json`;

if (!supabaseUrl || !supabaseKey) {
  logger.error('Missing Supabase configuration (URL or key). Set SUPABASE_URL and SUPABASE_KEY, or NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY.');
  process.exit(1);
}

if (!serviceRoleKey) {
  logger.warn('Missing SUPABASE service-role/secret key; admin client will fall back to the anon client until it is provided.');
}

// Client for general use (respects RLS policies)
export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false
  },
  global: {
    headers: {
      ...(jwksUrl ? { 'x-jwks-url': jwksUrl } : {})
    }
  }
});

// Admin client (bypasses RLS policies). Fallback to the anon client until the service-role key is supplied.
export const supabaseAdmin = serviceRoleKey ? createClient(supabaseUrl, serviceRoleKey) : supabase;

export default supabase;
