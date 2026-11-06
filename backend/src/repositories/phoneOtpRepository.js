/**
 * Phone OTP Repository
 * Only HMAC hashes of codes are stored (see utils/secureCodes.js). Table: public.phone_otps (API only).
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { ConflictError } from '../utils/errors.js';

const COLUMNS = 'id, user_id, phone_number, code_hash, attempts, expires_at, consumed_at, created_at';

export const countCodesSince = async (userId, sinceIso) => {
  const { count, error } = await supabase
    .from('phone_otps')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', sinceIso);

  if (error) throw error;
  return count || 0;
};

/** Close any open code (single use: at most one open code per user, enforced by a unique index). */
export const closeOpenCodes = async (userId) => {
  const { error } = await supabase
    .from('phone_otps')
    .update({ consumed_at: new Date().toISOString() })
    .eq('user_id', userId)
    .is('consumed_at', null);

  if (error) throw error;
};

export const createCode = async ({
  userId, phoneNumber, codeHash, expiresAt
}) => {
  const { data, error } = await supabase
    .from('phone_otps')
    .insert({
      user_id: userId, phone_number: phoneNumber, code_hash: codeHash, expires_at: expiresAt
    })
    .select('id, expires_at')
    .single();

  if (error?.code === '23505') throw new ConflictError('A code was just sent; please try again');
  if (error) throw error;
  return data;
};

export const getOpenCode = async (userId) => {
  const { data, error } = await supabase
    .from('phone_otps')
    .select(COLUMNS)
    .eq('user_id', userId)
    .is('consumed_at', null)
    .maybeSingle();

  if (error) throw error;
  return data;
};

/** Count a wrong guess; the current attempt count is part of the condition (no lost updates). */
export const recordFailedAttempt = async (codeId, currentAttempts) => {
  const { data, error } = await supabase
    .from('phone_otps')
    .update({ attempts: currentAttempts + 1 })
    .eq('id', codeId)
    .eq('attempts', currentAttempts)
    .is('consumed_at', null)
    .select('attempts')
    .maybeSingle();

  if (error) throw error;
  return data;
};

/** Mark the code used. Returns null if it was already used (e.g. a parallel request). */
export const consumeCode = async (codeId) => {
  const { data, error } = await supabase
    .from('phone_otps')
    .update({ consumed_at: new Date().toISOString() })
    .eq('id', codeId)
    .is('consumed_at', null)
    .select('id')
    .maybeSingle();

  if (error) throw error;
  return data;
};

export const findUserByPhone = async (phoneNumber) => {
  const { data, error } = await supabase
    .from('users')
    .select('id')
    .eq('phone_number', phoneNumber)
    .maybeSingle();

  if (error) throw error;
  return data;
};

export default {
  countCodesSince,
  closeOpenCodes,
  createCode,
  getOpenCode,
  recordFailedAttempt,
  consumeCode,
  findUserByPhone
};
