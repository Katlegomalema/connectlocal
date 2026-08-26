/**
 * Supabase Configuration
 * Initializes the Supabase client for database, auth, and storage operations
 */

import { createClient } from '@supabase/supabase-js';
import logger from '../utils/logger.js';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  logger.error('Missing Supabase configuration (SUPABASE_URL or SUPABASE_KEY)');
  process.exit(1);
}

// Client for general use (respects RLS policies)
export const supabase = createClient(supabaseUrl, supabaseKey);

// Admin client (bypasses RLS policies)
export const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

export default supabase;
