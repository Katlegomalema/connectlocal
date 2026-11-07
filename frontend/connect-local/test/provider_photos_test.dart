import 'package:connect_local/core/api_client.dart';
import 'package:connect_local/core/connect_local_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Customers must see the photos a provider uploads: business photos and service photos.
void main() {
  test('search: business photos (newest = profile picture) and service photos reach the customer', () {
    final repo = ConnectLocalRepository(ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    ));
    final provider = repo.providerFromJson({
      'id': 'p1',
      'business_name': 'Setla Mechanics',
      'photoUrl': 'https://cdn.test/new.jpg',
      'photos': [
        {'id': 'g2', 'url': 'https://cdn.test/new.jpg'},
        {'id': 'g1', 'url': 'https://cdn.test/workshop.jpg'},
      ],
      'services': [
        {
          'id': 's1',
          'service_name': 'Automotive',
          'base_price': 450,
          'active': true,
          'photos': [
            {'id': 'i1', 'url': 'https://cdn.test/engine.jpg'},
          ],
        },
      ],
    });

    expect(provider.avatar?.url, 'https://cdn.test/new.jpg');
    expect(provider.displayPhoto?.url, 'https://cdn.test/new.jpg');
    expect(provider.gallery.map((p) => p.url), ['https://cdn.test/new.jpg', 'https://cdn.test/workshop.jpg']);
    expect(provider.services.single.photos.single.url, 'https://cdn.test/engine.jpg');
    expect(provider.portfolio.map((p) => p.url),
        ['https://cdn.test/new.jpg', 'https://cdn.test/workshop.jpg', 'https://cdn.test/engine.jpg'],
        reason: 'the Portfolio strip shows business photos, then service photos, each once');
  });

  test('without a profile picture the first service photo is shown', () {
    final repo = ConnectLocalRepository(ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    ));
    final provider = repo.providerFromJson({
      'id': 'p2',
      'business_name': "BALI's NAIL BAR",
      'services': [
        {
          'id': 's2',
          'service_name': 'Buff and shine',
          'active': true,
          'photos': [
            {'url': 'https://cdn.test/nails.jpg'},
          ],
        },
      ],
    });
    expect(provider.avatar, isNull);
    expect(provider.displayPhoto?.url, 'https://cdn.test/nails.jpg');
  });
}
