import { jest } from '@jest/globals';

const adminRepository = {
  updateUserAccount: jest.fn(),
  listProvidersByVerificationStatus: jest.fn(),
  listProviderDocuments: jest.fn(),
  listGalleryForProviders: jest.fn(),
  setProviderVerificationStatus: jest.fn(),
  setProviderDocumentsStatus: jest.fn(),
  listDisputes: jest.fn(),
  updateDispute: jest.fn()
};
const userRepository = { listUsers: jest.fn() };
const reviewRepository = { hideReview: jest.fn(), refreshProviderRating: jest.fn() };
const reviewService = { listReviewsForModeration: jest.fn() };

jest.unstable_mockModule('../../src/repositories/adminRepository.js', () => adminRepository);
jest.unstable_mockModule('../../src/repositories/userRepository.js', () => userRepository);
jest.unstable_mockModule('../../src/repositories/reviewRepository.js', () => reviewRepository);
const storage = {
  BUCKETS: { documents: 'provider-documents', photos: 'provider-photos' },
  signedViewUrl: jest.fn(async (bucket, path) => `https://signed.test/${bucket}/${path}?token=t`)
};
const notificationService = { sendInAppNotification: jest.fn() };
jest.unstable_mockModule('../../src/services/reviewService.js', () => reviewService);
jest.unstable_mockModule('../../src/integrations/storage.js', () => storage);
jest.unstable_mockModule('../../src/services/notificationService.js', () => notificationService);
const adminService = await import('../../src/services/adminService.js');

describe('Admin service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('maps account status onto live user fields', async () => {
    adminRepository.updateUserAccount.mockResolvedValue({
      id: 'user-2',
      role: 'customer',
      status: 'suspended',
      is_active: false
    });

    await expect(adminService.updateUserAccount(
      { id: 'admin-1', role: 'admin' },
      'user-2',
      'suspended'
    )).resolves.toEqual({
      id: 'user-2',
      role: 'customer',
      status: 'suspended',
      is_active: false
    });
    expect(adminRepository.updateUserAccount).toHaveBeenCalledWith('user-2', 'suspended');
  });

  test('pending applications carry short-lived signed links to private documents (no paths)', async () => {
    adminRepository.listProvidersByVerificationStatus.mockResolvedValue({
      providers: [{
        id: 'provider-1',
        business_name: 'Local Services',
        business_registration_number: '2019/123456/07',
        category: { name: 'Plumbing' },
        applicant: { id: 'u1', full_name: 'Pat Doe', email: 'pat@example.test' }
      }],
      total: 1,
      page: 1,
      pages: 1
    });
    adminRepository.listProviderDocuments.mockResolvedValue([
      { id: 'document-1', provider_id: 'provider-1', document_type: 'id_document', storage_path: 'u1/documents/id.pdf' }
    ]);
    adminRepository.listGalleryForProviders.mockResolvedValue([]);

    const result = await adminService.listPendingProviders({ role: 'admin' });

    const [application] = result.providers;
    expect(application).toMatchObject({ businessName: 'Local Services', registrationNumber: '2019/123456/07', category: 'Plumbing' });
    expect(application.applicant.email).toBe('pat@example.test');
    expect(application.documents[0].url).toBe('https://signed.test/provider-documents/u1/documents/id.pdf?token=t');
    expect(JSON.stringify(application)).not.toContain('storage_path');
  });

  test('rejecting needs a reason for the applicant', async () => {
    await expect(adminService.decideProviderVerification({ id: 'admin-1', role: 'admin' }, 'provider-1', 'reject', ''))
      .rejects.toMatchObject({ statusCode: 400 });
    expect(adminRepository.setProviderVerificationStatus).not.toHaveBeenCalled();
  });

  test('approving records who decided, approves the documents and notifies the provider', async () => {
    adminRepository.setProviderVerificationStatus.mockResolvedValue({ id: 'provider-1', user_id: 'u1', business_name: 'Local Services' });
    await adminService.decideProviderVerification({ id: 'admin-1', role: 'admin' }, 'provider-1', 'approve');
    expect(adminRepository.setProviderVerificationStatus).toHaveBeenCalledWith('provider-1', 'pending', 'verified', expect.objectContaining({
      reviewed_by: 'admin-1', rejection_reason: null
    }));
    expect(adminRepository.setProviderDocumentsStatus).toHaveBeenCalledWith('provider-1', 'approved', 'admin-1', '');
    expect(notificationService.sendInAppNotification).toHaveBeenCalledWith('u1', expect.objectContaining({ title: 'Your business is approved' }));
  });

  test('a failed notification does not undo the decision', async () => {
    adminRepository.setProviderVerificationStatus.mockResolvedValue({ id: 'provider-1', user_id: 'u1', business_name: 'X' });
    notificationService.sendInAppNotification.mockRejectedValueOnce(new Error('push down'));
    await expect(adminService.decideProviderVerification({ id: 'admin-1', role: 'admin' }, 'provider-1', 'reject', 'ID photo unreadable'))
      .resolves.toMatchObject({ id: 'provider-1' });
  });

  test('only admins can decide', async () => {
    await expect(adminService.decideProviderVerification({ id: 'x', role: 'provider' }, 'provider-1', 'approve'))
      .rejects.toMatchObject({ statusCode: 403 });
  });

  test('requires a resolution note for terminal dispute decisions', async () => {
    await expect(adminService.resolveDispute(
      { id: 'admin-1', role: 'admin' },
      'dispute-1',
      { status: 'resolved' }
    )).rejects.toMatchObject({ statusCode: 400 });
    expect(adminRepository.updateDispute).not.toHaveBeenCalled();
  });

  test('records an authorized dispute decision', async () => {
    adminRepository.updateDispute.mockResolvedValue({ id: 'dispute-1', status: 'resolved' });

    await adminService.resolveDispute(
      { id: 'admin-1', role: 'admin' },
      'dispute-1',
      { status: 'resolved', resolutionNotes: 'Refund issued' }
    );

    expect(adminRepository.updateDispute).toHaveBeenCalledWith(
      'dispute-1',
      'resolved',
      'Refund issued',
      'admin-1'
    );
  });
});
