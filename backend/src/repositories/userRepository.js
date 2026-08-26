/**
 * User Repository
 * Database operations for user profiles
 */

import { supabase } from '../config/supabase.js';
import logger from '../utils/logger.js';
import { NotFoundError } from '../utils/errors.js';

/**
 * Fetch user by ID
 */
export const getUserById = async (userId) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .single();

    if (error) {
      throw new NotFoundError('User not found');
    }

    return data;
  } catch (error) {
    logger.error('Error fetching user:', error);
    throw error;
  }
};

/**
 * Create new user profile
 */
export const createUser = async (userData) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .insert([userData])
      .select()
      .single();

    if (error) {
      throw error;
    }

    return data;
  } catch (error) {
    logger.error('Error creating user:', error);
    throw error;
  }
};

/**
 * Update user profile
 */
export const updateUser = async (userId, updates) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .update(updates)
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return data;
  } catch (error) {
    logger.error('Error updating user:', error);
    throw error;
  }
};

/**
 * Delete user profile
 */
export const deleteUser = async (userId) => {
  try {
    const { error } = await supabase
      .from('users')
      .delete()
      .eq('id', userId);

    if (error) {
      throw error;
    }

    return { success: true };
  } catch (error) {
    logger.error('Error deleting user:', error);
    throw error;
  }
};

/**
 * Fetch user by email
 */
export const getUserByEmail = async (email) => {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .single();

    if (error) {
      return null;
    }

    return data;
  } catch (error) {
    logger.error('Error fetching user by email:', error);
    throw error;
  }
};

/**
 * List users with pagination and filtering
 */
export const listUsers = async (filters = {}, page = 1, limit = 20) => {
  try {
    let query = supabase.from('users').select('*', { count: 'exact' });

    if (filters.role) {
      query = query.eq('role', filters.role);
    }

    if (filters.status) {
      query = query.eq('status', filters.status);
    }

    const offset = (page - 1) * limit;
    const { data, error, count } = await query
      .range(offset, offset + limit - 1);

    if (error) {
      throw error;
    }

    return {
      data,
      total: count,
      page,
      pages: Math.ceil(count / limit)
    };
  } catch (error) {
    logger.error('Error listing users:', error);
    throw error;
  }
};

export default {
  getUserById,
  createUser,
  updateUser,
  deleteUser,
  getUserByEmail,
  listUsers
};
