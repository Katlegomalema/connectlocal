/**
 * User Service
 * Profile and account lifecycle operations
 */

import * as userRepository from '../repositories/userRepository.js';
import * as bookingRepository from '../repositories/bookingRepository.js';
import { AuthorizationError, ValidationError } from '../utils/errors.js';

const publicProfileFields = [
  'id',
  'full_name',
    'profile_image',
  'role',
  'created_at'
];

const assertCanManageUser = (actor, userId) => {
  if (!actor || (actor.id !== userId && actor.role !== 'admin')) {
    throw new AuthorizationError('You cannot modify this account');
  }
};

export const getUserProfile = async (userId) => {
  const user = await userRepository.getUserById(userId);
  return Object.fromEntries(publicProfileFields.map((field) => [field, user[field] ?? null]));
};

export const updateUserProfile = async (actor, userId, input) => {
  assertCanManageUser(actor, userId);
  const updates = {};

  if (input.fullName !== undefined) {
    const fullName = input.fullName.trim();
    if (fullName.length < 2 || fullName.length > 150) {
      throw new ValidationError('fullName must contain between 2 and 150 characters');
    }
    updates.full_name = fullName;
  }

  if (input.phoneNumber !== undefined) {
    const phoneNumber = input.phoneNumber.trim();
    if (phoneNumber && !/^\+[1-9]\d{7,14}$/.test(phoneNumber)) {
      throw new ValidationError('phoneNumber must use E.164 format');
    }
    updates.phone_number = phoneNumber || null;
  }

  if (input.address !== undefined) {
    const address = input.address.trim();
    if (address.length > 500) throw new ValidationError('address cannot exceed 500 characters');
    updates.address = address || null;
  }

  if (input.profilePhotoUrl !== undefined) {
    if (input.profilePhotoUrl && !/^https:\/\//i.test(input.profilePhotoUrl)) {
      throw new ValidationError('profilePhotoUrl must use HTTPS');
    }
      updates.profile_image = input.profilePhotoUrl || null;
  }

  if (Object.keys(updates).length === 0) {
    throw new ValidationError('At least one editable profile field is required');
  }

  const user = await userRepository.updateUser(userId, updates);
  return getUserProfile(user.id);
};

export const getUserBookings = async (actor, userId, pageValue = 1, limitValue = 20) => {
  assertCanManageUser(actor, userId);
  const page = Number.parseInt(pageValue, 10);
  const limit = Number.parseInt(limitValue, 10);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new ValidationError('page must be positive and limit must be between 1 and 100');
  }
  return bookingRepository.listBookings({ customerId: userId, page, limit });
};

export const updateAvatar = async (actor, userId, avatarUrl) => updateUserProfile(actor, userId, {
  profilePhotoUrl: avatarUrl
});

export const deleteUserProfile = async (actor, userId) => {
  assertCanManageUser(actor, userId);
  return userRepository.deleteUser(userId);
};

export default {
  getUserProfile,
  updateUserProfile,
  getUserBookings,
  updateAvatar,
  deleteUserProfile
};