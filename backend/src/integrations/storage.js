/**
 * Supabase Storage (server side only, service role).
 *
 * Buckets (created by supabase/migrations/20261105090000_provider_applications_storage.sql):
 *   provider-documents  PRIVATE  registration certificate, ID document. Admin views via short signed URLs.
 *   provider-photos     PUBLIC   logo, portfolio, service photos.
 *
 * Clients never get Storage keys. They ask the API for a one-time signed upload URL for a path inside their
 * own folder ("<user id>/<kind>/<random>.<ext>"), PUT the file there, then tell the API the path. The API
 * checks the path belongs to them and that the file exists before saving it.
 */

import { randomUUID } from 'node:crypto';
import { supabaseAdmin } from '../config/supabase.js';
import { ExternalServiceError, ValidationError } from '../utils/errors.js';

export const BUCKETS = {
  documents: 'provider-documents',
  photos: 'provider-photos'
};

/** What can be uploaded, per purpose. Bucket size/type limits are enforced again by Storage itself. */
export const UPLOAD_PURPOSES = {
  provider_document: {
    bucket: BUCKETS.documents,
    folder: 'documents',
    types: {
      'application/pdf': 'pdf', 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp'
    },
    maxBytes: 10 * 1024 * 1024
  },
  provider_photo: {
    bucket: BUCKETS.photos,
    folder: 'photos',
    types: { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' },
    maxBytes: 5 * 1024 * 1024
  }
};

const SIGNED_VIEW_SECONDS = 10 * 60;

const storageError = (error, action) => {
  const wrapped = new ExternalServiceError(`File storage error while trying to ${action}`, 'storage');
  wrapped.cause = error;
  return wrapped;
};

export const publicUrl = (path) => supabaseAdmin.storage.from(BUCKETS.photos).getPublicUrl(path).data.publicUrl;

/** Signed upload URL for a new file in the caller's own folder. */
export const createUploadUrl = async (userId, purpose, contentType) => {
  const config = UPLOAD_PURPOSES[purpose];
  if (!config) throw new ValidationError(`purpose must be one of: ${Object.keys(UPLOAD_PURPOSES).join(', ')}`);
  const extension = config.types[contentType];
  if (!extension) {
    throw new ValidationError(`File type not allowed. Use: ${Object.keys(config.types).join(', ')}`);
  }

  const path = `${userId}/${config.folder}/${randomUUID()}.${extension}`;
  const { data, error } = await supabaseAdmin.storage.from(config.bucket).createSignedUploadUrl(path);
  if (error) throw storageError(error, 'prepare the upload');

  return {
    bucket: config.bucket,
    path,
    uploadUrl: data.signedUrl,
    method: 'PUT',
    headers: { 'Content-Type': contentType },
    maxBytes: config.maxBytes,
    ...(config.bucket === BUCKETS.photos ? { publicUrl: publicUrl(path) } : {})
  };
};

/**
 * Throws unless [path] is a file in [userId]'s own [folder] that really exists in [bucket].
 * Stops people from attaching someone else's file, or a path that was never uploaded.
 */
export const assertOwnUploadedFile = async (bucket, userId, folder, path) => {
  const pattern = new RegExp(`^${userId}/${folder}/[A-Za-z0-9._-]{1,200}$`);
  if (typeof path !== 'string' || !pattern.test(path)) {
    throw new ValidationError('That file does not belong to your account');
  }
  const { data, error } = await supabaseAdmin.storage.from(bucket).exists(path);
  if (error && error.status !== 400 && error.statusCode !== '404') throw storageError(error, 'check the file');
  if (!data) throw new ValidationError('The file was not uploaded yet. Please upload it again.');
};

/** Short-lived link for the admin to view a private document. */
export const signedViewUrl = async (bucket, path, seconds = SIGNED_VIEW_SECONDS) => {
  const { data, error } = await supabaseAdmin.storage.from(bucket).createSignedUrl(path, seconds);
  if (error) throw storageError(error, 'open the document');
  return data.signedUrl;
};

/** Path of a photo from its public URL (to delete the file when the photo is removed). */
export const photoPathFromPublicUrl = (url) => {
  const marker = `/object/public/${BUCKETS.photos}/`;
  const index = typeof url === 'string' ? url.indexOf(marker) : -1;
  return index === -1 ? null : decodeURIComponent(url.slice(index + marker.length));
};

/** Best effort: a leftover file is not worth failing the request for. */
export const removeFiles = async (bucket, paths) => {
  const list = paths.filter(Boolean);
  if (!list.length) return;
  await supabaseAdmin.storage.from(bucket).remove(list).catch(() => {});
};

export default {
  BUCKETS,
  UPLOAD_PURPOSES,
  createUploadUrl,
  assertOwnUploadedFile,
  signedViewUrl,
  publicUrl,
  photoPathFromPublicUrl,
  removeFiles
};
