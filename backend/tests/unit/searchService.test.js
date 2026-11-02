import { jest } from '@jest/globals';

const repository = {
  searchProvidersByLocation: jest.fn(),
  listActiveServicesForProviders: jest.fn(),
  searchProvidersByText: jest.fn(),
  listCategories: jest.fn(),
  listFeaturedProviders: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/providerRepository.js', () => repository);
const searchService = await import('../../src/services/searchService.js');

describe('Search service', () => {
  beforeEach(() => jest.clearAllMocks());

  test('applies rating, category, and price filters to nearby providers', async () => {
    repository.searchProvidersByLocation.mockResolvedValue([
      { id: 'provider-1', average_rating: 4.8 },
      { id: 'provider-2', average_rating: 3.2 }
    ]);
    repository.listActiveServicesForProviders.mockResolvedValue([
      { id: 'service-1', provider_id: 'provider-1', category: 'Plumbing', price: 400 },
      { id: 'service-2', provider_id: 'provider-2', category: 'Plumbing', price: 200 }
    ]);

    const result = await searchService.searchNearby(-26.2, 28.0, 25, {
      category: 'Plumbing',
      minRating: 4,
      maxPrice: 500
    });

    expect(result.providers.map((provider) => provider.id)).toEqual(['provider-1']);
    expect(result.providers[0].services).toHaveLength(1);
  });

  test('rejects invalid coordinates before querying the repository', async () => {
    await expect(searchService.searchNearby(91, 28, 25)).rejects.toMatchObject({ statusCode: 400 });
    expect(repository.searchProvidersByLocation).not.toHaveBeenCalled();
  });
});