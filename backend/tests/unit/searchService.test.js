import { jest } from '@jest/globals';

const repository = {
  searchProvidersByLocation: jest.fn(),
  listActiveServicesForProviders: jest.fn(),
  listGallery: jest.fn(),
  listServiceImages: jest.fn(),
  searchProvidersByText: jest.fn(),
  listCategories: jest.fn(),
  listFeaturedProviders: jest.fn(),
  getProviderById: jest.fn(),
  addFavorite: jest.fn(),
  listFavorites: jest.fn(),
  removeFavorite: jest.fn()
};

jest.unstable_mockModule('../../src/repositories/providerRepository.js', () => repository);
const searchService = await import('../../src/services/searchService.js');

describe('Search service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    repository.listGallery.mockResolvedValue([]);
    repository.listServiceImages.mockResolvedValue([]);
  });

  test('applies rating, category, and price filters to nearby providers', async () => {
    repository.searchProvidersByLocation.mockResolvedValue([
      { id: 'provider-1', rating_average: 4.8 },
      { id: 'provider-2', rating_average: 3.2 }
    ]);
    repository.listActiveServicesForProviders.mockResolvedValue([
      { id: 'service-1', provider_id: 'provider-1', category_id: 'category-1', base_price: 400 },
      { id: 'service-2', provider_id: 'provider-2', category_id: 'category-1', base_price: 200 }
    ]);
    repository.listCategories.mockResolvedValue([{ id: 'category-1', name: 'Plumbing' }]);

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

  test('saves only public providers to a customer favorites list', async () => {
    repository.getProviderById.mockResolvedValue({
      id: '00000000-0000-4000-8000-000000000001',
      is_active: true,
      verification_status: 'verified'
    });
    repository.addFavorite.mockResolvedValue({ user_id: 'customer-1', provider_id: '00000000-0000-4000-8000-000000000001' });

    await searchService.saveProvider(
      { id: 'customer-1', role: 'customer' },
      '00000000-0000-4000-8000-000000000001'
    );

    expect(repository.addFavorite).toHaveBeenCalledWith(
      'customer-1',
      '00000000-0000-4000-8000-000000000001'
    );
  });

  test('text search returns listing details: services with active packages, photo, coordinates', async () => {
    repository.searchProvidersByText.mockResolvedValue({
      providers: [{ id: 'p1', business_name: 'Drain Repair', location: { type: 'Point', coordinates: [28.04, -26.2] } }],
      total: 1,
      page: 1,
      pages: 1
    });
    repository.listActiveServicesForProviders.mockResolvedValue([{
      id: 's1',
      provider_id: 'p1',
      service_name: 'CCTV',
      pricing_type: 'package',
      packages: [{ name: '1 camera', price: 1200, is_active: true }, { name: 'old', price: 1, is_active: false }]
    }]);
    repository.listGallery.mockResolvedValue([{ provider_id: 'p1', image_url: 'https://cdn.test/a.jpg' }]);

    const result = await searchService.searchProviders('drain', undefined, 1, 20);

    expect(result.providers[0]).toMatchObject({
      id: 'p1', latitude: -26.2, longitude: 28.04, photoUrl: 'https://cdn.test/a.jpg', verified: true
    });
    expect(result.providers[0]).not.toHaveProperty('location');
    expect(result.providers[0].services[0].packages).toEqual([{ name: '1 camera', price: 1200, is_active: true }]);
  });

  test('customers get every business photo (newest = profile picture) and each service\'s photos', async () => {
    repository.searchProvidersByText.mockResolvedValue({
      providers: [{ id: 'p1', business_name: 'Setla Mechanics', latitude: -25.7, longitude: 28.2 }], total: 1, page: 1, pages: 1
    });
    repository.listActiveServicesForProviders.mockResolvedValue([{ id: 's1', provider_id: 'p1', service_name: 'Service' }]);
    repository.listGallery.mockResolvedValue([
      { id: 'g1', provider_id: 'p1', image_url: 'https://cdn.test/old.jpg', created_at: '2026-11-01T10:00:00Z' },
      { id: 'g2', provider_id: 'p1', image_url: 'https://cdn.test/new.jpg', created_at: '2026-11-06T10:00:00Z' }
    ]);
    repository.listServiceImages.mockResolvedValue([
      { id: 'i1', service_id: 's1', image_url: 'https://cdn.test/engine.jpg', sort_order: 0 }
    ]);

    const [provider] = (await searchService.searchProviders('', undefined, 1, 20)).providers;

    expect(provider.photoUrl).toBe('https://cdn.test/new.jpg');
    expect(provider.photos.map((photo) => photo.url)).toEqual(['https://cdn.test/new.jpg', 'https://cdn.test/old.jpg']);
    expect(provider.services[0].photos).toEqual([{ id: 'i1', url: 'https://cdn.test/engine.jpg' }]);
  });
});
