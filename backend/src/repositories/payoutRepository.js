/**
 * Payout Repository: provider bank details (encrypted account number) and payout records.
 * Both tables are API-only (no client RLS policies).
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';

const DETAILS_COLUMNS = 'provider_id, bank_name, account_holder_name, account_type, branch_code, account_last4, '
  + 'account_number_encrypted, updated_at';

export const getPayoutDetails = async (providerId) => {
  const { data, error } = await supabase
    .from('provider_payout_details')
    .select(DETAILS_COLUMNS)
    .eq('provider_id', providerId)
    .maybeSingle();

  if (error) throw error;
  return data;
};

/** One row per provider (unique provider_id): insert or replace. */
export const savePayoutDetails = async (providerId, values) => {
  const { data, error } = await supabase
    .from('provider_payout_details')
    .upsert({ provider_id: providerId, ...values }, { onConflict: 'provider_id' })
    .select(DETAILS_COLUMNS)
    .single();

  if (error) throw error;
  return data;
};

const PAYOUT_COLUMNS = 'id, booking_id, provider_id, gross_amount, commission_rate, commission_amount, '
  + 'cash_collected_amount, payout_amount, status, payout_reference, failure_reason, paid_at, created_at, '
  + 'booking:bookings(service:services(service_name), scheduled_start)';

export const listPayoutsForProvider = async (providerId, limit = 100) => {
  const { data, error } = await supabase
    .from('payouts')
    .select(PAYOUT_COLUMNS)
    .eq('provider_id', providerId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data || [];
};

export const listPendingPayouts = async (limit = 50) => {
  const { data, error } = await supabase
    .from('payouts')
    .select('id, booking_id, provider_id, payout_amount, status, failure_reason')
    .eq('status', 'pending')
    .order('created_at', { ascending: true })
    .limit(limit);

  if (error) throw error;
  return data || [];
};

/** Moves a payout on only if it is still in [fromStatus] (so two runs never pay twice). Null if it moved. */
export const updatePayoutIf = async (payoutId, fromStatus, updates) => {
  const { data, error } = await supabase
    .from('payouts')
    .update(updates)
    .eq('id', payoutId)
    .eq('status', fromStatus)
    .select('id, provider_id, payout_amount, status, payout_reference')
    .maybeSingle();

  if (error) throw error;
  return data;
};

/** Puts payouts that stayed in 'processing' since before [beforeIso] back to 'pending'. Returns their ids. */
export const resetStuckProcessing = async (beforeIso) => {
  const { data, error } = await supabase
    .from('payouts')
    .update({ status: 'pending', failure_reason: 'Retried after an interrupted transfer' })
    .eq('status', 'processing')
    .lt('updated_at', beforeIso)
    .select('id');

  if (error) throw error;
  return data || [];
};

export const getProviderOwner = async (providerId) => {
  const { data, error } = await supabase
    .from('providers')
    .select('id, user_id')
    .eq('id', providerId)
    .maybeSingle();

  if (error) throw error;
  return data;
};

export default {
  getPayoutDetails,
  savePayoutDetails,
  listPayoutsForProvider,
  listPendingPayouts,
  updatePayoutIf,
  resetStuckProcessing,
  getProviderOwner
};
