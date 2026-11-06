import { jest } from '@jest/globals';

const repository = {
  registrationNumberInUse: jest.fn(async () => false),
  getProviderById: jest.fn(),
  getProviderByUserId: jest.fn(),
  createProvider: jest.fn(),
  getProviderServices: jest.fn(),
  createService: jest.fn(),
  getServiceCategoryByName: jest.fn(),
  getServiceCategoryById: jest.fn(),
  updateProvider: jest.fn(),
  updateService: jest.fn(),
  listProviderDocuments: jest.fn(),
  listGallery: jest.fn(),
  saveProviderDocument: jest.fn(),
  listAdminUserIds: jest.fn()
};
const storage = {
  BUCKETS: { documents: 'provider-documents', photos: 'provider-photos' },
  assertOwnUploadedFile: jest.fn(),
  removeFiles: jest.fn(),
  publicUrl: (path) => `https://cdn.test/${path}`,
  photoPathFromPublicUrl: jest.fn()
};
const notificationService = { sendInAppNotification: jest.fn() };

jest.unstable_mockModule('../../src/repositories/providerRepository.js', () => repository);
jest.unstable_mockModule('../../src/integrations/storage.js', () => storage);
jest.unstable_mockModule('../../src/services/notificationService.js', () => notificationService);
const providerService = await import('../../src/services/providerService.js');

describe('Provider service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates services with provider ID and database-shaped fields', async () => {
    repository.getProviderById.mockResolvedValue({ id: 'provider-1', user_id: 'user-1', verification_status: 'verified' });
    repository.getServiceCategoryByName.mockResolvedValue({ id: 'category-1', name: 'Plumbing' });
    repository.createService.mockImplementation(async (service) => ({ id: 'service-1', ...service }));

    const service = await providerService.createService(
      { id: 'user-1', role: 'provider' },
      'provider-1',
      { title: 'Drain repair', category: 'Plumbing', price: '450', durationMinutes: '60' }
    );

    expect(service).toMatchObject({
      provider_id: 'provider-1',
      service_name: 'Drain repair',
      category_id: 'category-1',
      base_price: 450,
      duration_minutes: 60
    });
  });

  test('registers a provider with PostGIS coordinates and its primary category', async () => {
    repository.getProviderByUserId.mockResolvedValue(null);
    repository.getServiceCategoryByName.mockResolvedValue({ id: 'category-1', name: 'Plumbing' });
    repository.createProvider.mockImplementation(async (provider) => provider);

    await providerService.registerProvider(
      { id: 'user-1', role: 'provider' },
      {
        businessName: 'Drain Repair',
        registrationNumber: '2019/123456/07',
        category: 'Plumbing',
        serviceAreaRadiusKm: 15,
        location: { lat: -26.2041, lng: 28.0473 }
      }
    );

    expect(repository.createProvider).toHaveBeenCalledWith(expect.objectContaining({
      user_id: 'user-1',
      primary_category_id: 'category-1',
      location: 'SRID=4326;POINT(28.0473 -26.2041)',
      service_radius_km: 15,
      business_registration_number: '2019/123456/07'
    }));
  });

  test('rejects a registration number in the wrong format', async () => {
    repository.getProviderByUserId.mockResolvedValue(null);
    repository.getServiceCategoryByName.mockResolvedValue({ id: 'category-1', name: 'Plumbing' });
    await expect(providerService.registerProvider({ id: 'user-1', role: 'provider' }, {
      businessName: 'Drain Repair', registrationNumber: '2019-123456-07', category: 'Plumbing'
    })).rejects.toThrow('YYYY/NNNNNN/TT');
    expect(repository.createProvider).not.toHaveBeenCalled();
  });

  test('a registration number another business already applied with is refused', async () => {
    repository.getProviderByUserId.mockResolvedValue(null);
    repository.getServiceCategoryByName.mockResolvedValue({ id: 'category-1', name: 'Plumbing' });
    repository.registrationNumberInUse.mockResolvedValueOnce(true);
    await expect(providerService.registerProvider({ id: 'user-1', role: 'provider' }, {
      businessName: 'Drain Repair', registrationNumber: '2019/123456/07', category: 'Plumbing'
    })).rejects.toThrow('already applied');
    expect(repository.registrationNumberInUse).toHaveBeenCalledWith('2019/123456/07', null);
    expect(repository.createProvider).not.toHaveBeenCalled();
  });

  test('location is optional (text search still finds the business)', async () => {
    repository.getProviderByUserId.mockResolvedValue(null);
    repository.getServiceCategoryByName.mockResolvedValue({ id: 'category-1', name: 'Plumbing' });
    repository.createProvider.mockImplementation(async (provider) => provider);
    const created = await providerService.registerProvider({ id: 'user-1', role: 'provider' }, {
      businessName: 'Drain Repair', registrationNumber: '2019/123456/07', category: 'Plumbing'
    });
    expect(created.location).toBeNull();
  });

  describe('application', () => {
    const actor = { id: 'user-1', role: 'provider' };
    const draft = {
      id: 'provider-1', user_id: 'user-1', business_name: 'Drain Repair', verification_status: 'pending',
      submitted_at: null, business_registration_number: '2019/123456/07'
    };

    test('documents must be a file the provider uploaded to their own folder', async () => {
      repository.getProviderById.mockResolvedValue(draft);
      storage.assertOwnUploadedFile.mockRejectedValue(new Error('That file does not belong to your account'));
      await expect(providerService.attachDocument(actor, 'provider-1', {
        documentType: 'id_document', storagePath: 'someone-else/documents/x.pdf'
      })).rejects.toThrow('does not belong');
      expect(repository.saveProviderDocument).not.toHaveBeenCalled();
    });

    test('re-uploading a document replaces the old file', async () => {
      repository.getProviderById.mockResolvedValue(draft);
      storage.assertOwnUploadedFile.mockResolvedValue();
      repository.saveProviderDocument.mockResolvedValue({
        document: { id: 'd1', document_type: 'id_document', approval_status: 'pending', uploaded_at: 'now' },
        replacedPath: 'user-1/documents/old.pdf'
      });
      const document = await providerService.attachDocument(actor, 'provider-1', {
        documentType: 'id_document', storagePath: 'user-1/documents/new.pdf'
      });
      expect(storage.removeFiles).toHaveBeenCalledWith('provider-documents', ['user-1/documents/old.pdf']);
      expect(document).not.toHaveProperty('storage_path'); // paths never go to the app
    });

    test('cannot submit while the ID document is missing', async () => {
      repository.getProviderByUserId.mockResolvedValue(draft);
      repository.listProviderDocuments.mockResolvedValue([{ document_type: 'registration_certificate' }]);
      repository.listGallery.mockResolvedValue([]);
      await expect(providerService.submitApplication(actor)).rejects.toThrow('Still missing: ID document');
      expect(repository.updateProvider).not.toHaveBeenCalled();
    });

    test('a complete application is submitted and admins are notified', async () => {
      repository.getProviderByUserId.mockResolvedValue(draft);
      repository.listProviderDocuments.mockResolvedValue([
        { document_type: 'registration_certificate' }, { document_type: 'id_document' }
      ]);
      repository.listGallery.mockResolvedValue([]);
      repository.listAdminUserIds.mockResolvedValue(['admin-1']);
      await providerService.submitApplication(actor);
      expect(repository.updateProvider).toHaveBeenCalledWith('provider-1', 'user-1', expect.objectContaining({
        verification_status: 'pending', submitted_at: expect.any(String), rejection_reason: null
      }));
      expect(notificationService.sendInAppNotification).toHaveBeenCalledWith('admin-1', expect.objectContaining({
        title: 'New provider application'
      }));
    });

    test('a rejected application can be fixed and submitted again', async () => {
      repository.getProviderByUserId.mockResolvedValue({ ...draft, verification_status: 'rejected', submitted_at: 'x', rejection_reason: 'Blurry ID' });
      repository.listProviderDocuments.mockResolvedValue([
        { document_type: 'registration_certificate' }, { document_type: 'id_document' }
      ]);
      repository.listGallery.mockResolvedValue([]);
      repository.listAdminUserIds.mockResolvedValue([]);
      await providerService.submitApplication(actor);
      expect(repository.updateProvider).toHaveBeenCalledWith('provider-1', 'user-1', expect.objectContaining({
        verification_status: 'pending', rejection_reason: null
      }));
    });

    test('an application already waiting cannot be submitted twice', async () => {
      repository.getProviderByUserId.mockResolvedValue({ ...draft, submitted_at: '2026-11-05T00:00:00Z' });
      await expect(providerService.submitApplication(actor)).rejects.toThrow('already waiting');
    });
  });

  test('rejects a provider user who does not own the provider profile', async () => {
    repository.getProviderById.mockResolvedValue({ id: 'provider-1', user_id: 'other-user', verification_status: 'verified' });

    await expect(providerService.updateProviderProfile(
      { id: 'user-1', role: 'provider' },
      'provider-1',
      { businessName: 'New name' }
    )).rejects.toMatchObject({ statusCode: 403 });
    expect(repository.updateProvider).not.toHaveBeenCalled();
  });

  test('does not expose unapproved providers publicly', async () => {
    repository.getProviderById.mockResolvedValue({ id: 'provider-1', verification_status: 'pending' });
    await expect(providerService.getPublicProvider('provider-1')).rejects.toMatchObject({ statusCode: 404 });
  });
});