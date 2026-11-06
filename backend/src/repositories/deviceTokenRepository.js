/**
 * Database operations for user device tokens
 */

import { supabaseAdmin as supabase } from '../config/supabase.js';
import { NotFoundError } from '../utils/errors.js';

export const registerDeviceToken = async (userId, token, platform) => {
  const { data, error } = await supabase
    .from('device_tokens')
    .upsert({
      user_id: userId,
      token,
      platform,
      updated_at: new Date().toISOString()
    }, { onConflict: 'token' })
    .select('id, user_id, platform, created_at, updated_at')
    .single();

  if (error) throw error;
  return data;
};

export const listDeviceTokens = async (userId) => {
  const { data, error } = await supabase
    .from('device_tokens')
    .select('id, token, platform')
    .eq('user_id', userId);

  if (error) throw error;
  return data || [];
};

export const deleteDeviceToken = async (userId, deviceTokenId) => {
  const { data, error } = await supabase
    .from('device_tokens')
    .delete()
    .eq('id', deviceTokenId)
    .eq('user_id', userId)
    .select('id')
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new NotFoundError('Device token not found');
  return { success: true };
};

export const deleteDeviceTokensByToken = async (userId, tokens) => {
  if (!tokens.length) return;
  const { error } = await supabase
    .from('device_tokens')
    .delete()
    .eq('user_id', userId)
    .in('token', tokens);

  if (error) throw error;
};

export default {
  registerDeviceToken,
  listDeviceTokens,
  deleteDeviceToken,
  deleteDeviceTokensByToken
};
