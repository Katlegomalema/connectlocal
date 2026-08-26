/**
 * Sample Migration: Create Users Table
 * This is a template for database migrations
 */

import { supabaseAdmin } from '../src/config/supabase.js';

export const up = async () => {
  // Create users table
  const { error } = await supabaseAdmin
    .from('users')
    .insert([]);

  if (error) throw error;

  console.log('Created users table');
};

export const down = async () => {
  // Drop users table
  const { error } = await supabaseAdmin.rpc('drop_table_users');

  if (error) throw error;

  console.log('Dropped users table');
};
