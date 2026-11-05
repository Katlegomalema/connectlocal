/**
 * Admin Repository
 * Administrative queries against documented platform tables
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError, NotFoundError } from '../utils/errors.js';

const APPLICATION_COLUMNS = [
  'id', 'user_id', 'business_name', 'business_description', 'business_registration_number',
  'primary_category_id', 'city', 'province', 'street_address', 'suburb', 'postal_code', 'location',
  'verification_status', 'rejection_reason', 'submitted_at', 'reviewed_at', 'created_at',
  'category:service_categories(id, name)',
  'applicant:users!providers_user_id_fkey(id, full_name, email, phone_number, phone_verified, email_verified)'
].join(', ');

/** Applications in a status. For 'pending', only the ones actually submitted (oldest first). */
export const listProvidersByVerificationStatus = async (status, page, limit) => {
  const offset = (page - 1) * limit;
  let query = supabase
    .from('providers')
    .select(APPLICATION_COLUMNS, { count: 'exact' })
    .eq('verification_status', status);
  if (status === 'pending') query = query.not('submitted_at', 'is', null);
  const { data, error, count } = await query
    .order(status === 'pending' ? 'submitted_at' : 'reviewed_at', { ascending: status === 'pending' })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return {
    providers: data || [], total: count || 0, page, pages: Math.ceil((count || 0) / limit)
  };
};

export const listProviderDocuments = async (providerIds) => {
  if (providerIds.length === 0) return [];
  const { data, error } = await supabase
    .from('provider_documents')
    .select('id, provider_id, document_type, document_url, storage_path, approval_status, rejection_reason, uploaded_at')
    .in('provider_id', providerIds)
    .order('uploaded_at', { ascending: false });

  if (error) throw error;
  return data || [];
};

/** Change the status only if it is still [currentStatus] (two admins cannot both decide). */
export const setProviderVerificationStatus = async (providerId, currentStatus, status, extra = {}) => {
  const { data, error } = await supabase
    .from('providers')
    .update({ verification_status: status, ...extra })
    .eq('id', providerId)
    .eq('verification_status', currentStatus)
    .not('submitted_at', 'is', null)
    .select('id, user_id, business_name, verification_status, rejection_reason, reviewed_at, reviewed_by')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new ConflictError('Provider verification status changed; reload and try again');
  return data;
};

export const setProviderDocumentsStatus = async (providerId, status, reviewerId, reason = null) => {
  const { error } = await supabase
    .from('provider_documents')
    .update({
      approval_status: status,
      reviewed_by: reviewerId,
      reviewed_at: new Date().toISOString(),
      rejection_reason: status === 'rejected' ? reason : null
    })
    .eq('provider_id', providerId);

  if (error) throw error;
};

export const listGalleryForProviders = async (providerIds) => {
  if (!providerIds.length) return [];
  const { data, error } = await supabase
    .from('provider_gallery')
    .select('id, provider_id, image_url, caption')
    .in('provider_id', providerIds)
    .order('sort_order', { ascending: true });

  if (error) throw error;
  return data || [];
};

export const updateUserAccount = async (userId, status) => {
  const updates = {
    is_active: status === 'active',
    deleted_at: status === 'deactivated' ? new Date().toISOString() : null
  };
  const { data, error } = await supabase
    .from('users')
    .update(updates)
    .eq('id', userId)
    .select('id, role, is_active, deleted_at')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('User not found');
  return { ...data, status };
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
    .select('rating_average')
    .eq('verification_status', 'verified');

  if (error) throw error;
  if (!data?.length) return 0;
  const totalRating = data.reduce((sum, provider) => sum + Number(provider.rating_average || 0), 0);
  return Math.round((totalRating / data.length) * 10) / 10;
};

export const getPaidRevenue = async () => {
  let total = 0;
  let offset = 0;
  const batchSize = 1000;
  while (true) {
    // eslint-disable-next-line no-await-in-loop -- paging: each batch depends on the previous one
    const { data, error } = await supabase
      .from('payments')
      .select('amount')
      .eq('payment_status', 'paid')
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
    .select('id, email, full_name, role, is_active, deleted_at, created_at')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('User not found');
  return data;
};

export const listDisputes = async ({ status, page, limit }) => {
  let query = supabase
    .from('disputes')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false });
  if (status) query = query.eq('status', status);
  else query = query.in('status', ['open', 'under_review']);

  const offset = (page - 1) * limit;
  const { data, error, count } = await query.range(offset, offset + limit - 1);
  if (error) throw error;
  return {
    disputes: data || [],
    total: count || 0,
    page,
    pages: Math.ceil((count || 0) / limit)
  };
};

export const updateDispute = async (disputeId, status, resolutionNotes, adminId) => {
  const terminal = ['resolved', 'rejected'].includes(status);
  const updates = {
    status,
    resolved_by: terminal ? adminId : null,
    resolved_at: terminal ? new Date().toISOString() : null
  };
  if (resolutionNotes !== undefined) updates.resolution_notes = resolutionNotes || null;
  const { data, error } = await supabase
    .from('disputes')
    .update(updates)
    .eq('id', disputeId)
    .in('status', ['open', 'under_review'])
    .select('*')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new ConflictError('Dispute is missing or no longer active');
  return data;
};

export default {
  listProvidersByVerificationStatus,
  listProviderDocuments,
  setProviderVerificationStatus,
  setProviderDocumentsStatus,
  listGalleryForProviders,
  updateUserAccount,
  countRows,
  getAverageProviderRating,
  getPaidRevenue,
  getUserById,
  listDisputes,
  updateDispute
};
