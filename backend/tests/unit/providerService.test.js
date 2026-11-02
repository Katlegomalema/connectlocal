import { jest } from '@jest/globals';

const repository = {
  getProviderById: jest.fn(),
  getProviderServices: jest.fn(),
  createService: jest.fn(),
  updateProvider: jest.fn(),
  updateService: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/providerRepository.js', () => repository);
const providerService = await import('../../src/services/providerService.js');

describe('Provider service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('creates services with provider ID and database-shaped fields', async () => {
    repository.getProviderById.mockResolvedValue({ id: 'provider-1', user_id: 'user-1', verification_status: 'approved' });
    repository.createService.mockImplementation(async (service) => ({ id: 'service-1', ...service }));

    const service = await providerService.createService(
      { id: 'user-1', role: 'provider' },
      'provider-1',
      { title: 'Drain repair', category: 'Plumbing', price: '450', durationMinutes: '60' }
    );

    expect(service).toMatchObject({
      provider_id: 'provider-1',
      title: 'Drain repair',
      price: 450,
      duration_minutes: 60
    });
  });

  test('rejects a provider user who does not own the provider profile', async () => {
    repository.getProviderById.mockResolvedValue({ id: 'provider-1', user_id: 'other-user', verification_status: 'approved' });

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