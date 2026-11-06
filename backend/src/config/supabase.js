/**
 * Supabase Configuration
 *
 * - supabase:      publishable/anon key, respects RLS. Used for auth calls (sign-in, token checks).
 * - supabaseAdmin: service-role/secret key, BYPASSES RLS. Used by every repository, so the backend
 *                  itself must enforce ownership and roles.
 *
 * Both keys are required. We fail fast at startup instead of silently falling back to the anon key,
 * which would make every repository query run under RLS with no user (empty results / permission errors).
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
  || process.env.SUPABASE_SECRET_KEY;

const missing = [
  !supabaseUrl && 'SUPABASE_URL',
  !supabaseKey && 'SUPABASE_KEY',
  !serviceRoleKey && 'SUPABASE_SERVICE_ROLE_KEY'
].filter(Boolean);

if (missing.length) {
  const message = `Missing Supabase configuration: ${missing.join(', ')}. Set them in backend/.env.`;
  logger.fatal(message);
  throw new Error(message);
}

if (serviceRoleKey === supabaseKey) {
  const message = 'SUPABASE_SERVICE_ROLE_KEY is the same as SUPABASE_KEY. Use the service-role/secret key.';
  logger.fatal(message);
  throw new Error(message);
}

const serverAuthOptions = {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false
  }
};

// Client for general use (respects RLS policies)
export const supabase = createClient(supabaseUrl, supabaseKey, serverAuthOptions);

// Admin client (bypasses RLS policies). Server-side only, never expose this key.
export const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, serverAuthOptions);

export default supabase;
