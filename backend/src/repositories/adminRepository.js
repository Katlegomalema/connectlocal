/**
 * Admin Repository
 * Administrative queries against documented platform tables
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError, NotFoundError } from '../utils/errors.js';

export const listProvidersByVerificationStatus = async (status, page, limit) => {
  const offset = (page - 1) * limit;
  const { data, error, count } = await supabase
    .from('providers')
    .select('id, user_id, business_name, category, description, verification_status, verification_document_url, created_at', { count: 'exact' })
    .eq('verification_status', status)
    .is('deleted_at', null)
    .order('created_at', { ascending: true })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return { providers: data || [], total: count || 0, page, pages: Math.ceil((count || 0) / limit) };
};

export const setProviderVerificationStatus = async (providerId, currentStatus, status) => {
  const { data, error } = await supabase
    .from('providers')
    .update({ verification_status: status })
    .eq('id', providerId)
    .eq('verification_status', currentStatus)
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new ConflictError('Provider verification status changed; reload and try again');
  return data;
};

export const countRows = async (table, filters = {}) => {
  let query = supabase.from(table).select('id', { count: 'exact', head: true });
  for (const [field, value] of Object.entries(filters)) {
    if (value === null) query = query.is(field, null);
    else query = query.eq(field, value);
  }
  const { count, error } = await query;
  if (error) throw error;
  return count || 0;
};

export const getAverageProviderRating = async () => {
  const { data, error } = await supabase
    .from('providers')
    .select('average_rating')
    .eq('verification_status', 'approved')
    .is('deleted_at', null);

  if (error) throw error;
  if (!data?.length) return 0;
  return Math.round((data.reduce((sum, provider) => sum + Number(provider.average_rating || 0), 0) / data.length) * 10) / 10;
};

export const getPaidRevenue = async () => {
  let total = 0;
  let offset = 0;
  const batchSize = 1000;
  while (true) {
    const { data, error } = await supabase
      .from('payments')
      .select('amount')
      .eq('status', 'paid')
      .range(offset, offset + batchSize - 1);

    if (error) throw error;
    total += (data || []).reduce((sum, payment) => sum + Number(payment.amount || 0), 0);
    if (!data || data.length < batchSize) break;
    offset += batchSize;
  }
  return Math.round(total * 100) / 100;
};

export const getUserById = async (userId) => {
  const { data, error } = await supabase
    .from('users')
    .select('id, email, full_name, role, account_status, created_at')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('User not found');
  return data;
};

export default {
  listProvidersByVerificationStatus,
  setProviderVerificationStatus,
  countRows,
  getAverageProviderRating,
  getPaidRevenue,
  getUserById
};