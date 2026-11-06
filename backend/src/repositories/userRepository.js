/**
 * User Repository
 * Database operations for user profiles
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { NotFoundError } from '../utils/errors.js';

/**
 * Fetch user by ID
 */
export const getUserById = async (userId) => {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .is('deleted_at', null)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('User not found');
  return data;
};

/**
 * Create new user profile
 */
export const createUser = async (userData) => {
  const { data, error } = await supabase
    .from('users')
    .insert(userData)
    .select()
    .single();

  if (error) throw error;
  return data;
};

/**
 * Update user profile
 */
export const updateUser = async (userId, updates) => {
  const { data, error } = await supabase
    .from('users')
    .update(updates)
    .eq('id', userId)
    .is('deleted_at', null)
    .select()
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('User not found');
  return data;
};

/**
 * Delete user profile
 */
export const deleteUser = async (userId) => updateUser(userId, {
  is_active: false,
  deleted_at: new Date().toISOString()
});

/**
 * Fetch user by email
 */
export const getUserByEmail = async (email) => {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('email', email)
    .is('deleted_at', null)
    .maybeSingle();

  if (error) throw error;
  return data;
};

/**
 * List users with pagination and filtering
 */
export const listUsers = async (filters = {}, page = 1, limit = 20) => {
  let query = supabase
    .from('users')
    .select('id, email, phone_number, full_name, role, is_active, created_at, deleted_at', { count: 'exact' });

  if (filters.role) query = query.eq('role', filters.role);
  if (filters.status === 'active') query = query.eq('is_active', true).is('deleted_at', null);
  if (filters.status === 'suspended') query = query.eq('is_active', false).is('deleted_at', null);
  if (filters.status === 'deactivated') query = query.not('deleted_at', 'is', null);

  const offset = (page - 1) * limit;
  const { data, error, count } = await query
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return {
    data: data || [],
    total: count || 0,
    page,
    pages: Math.ceil((count || 0) / limit)
  };
};

export default {
  getUserById,
  createUser,
  updateUser,
  deleteUser,
  getUserByEmail,
  listUsers
};
