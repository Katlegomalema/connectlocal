import 'package:connect_local/features/community/models/models.dart';
import 'package:connect_local/features/community/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app has the 10 ConnectLocal categories, "Other" last', () {
    expect(AppState.kCategories, [
      'Beauty & Health',
      'Healthcare',
      'Plumbing',
      'Cleaning Services',
      'Education & Tutoring',
      'Automotive Services',
      'Electrical Services',
      'Events & Photography',
      'Home Maintenance',
      'Other',
    ]);
  });

  test('server categories are shown in the app order; unknown ones go just before "Other"', () {
    // The server sorts by name.
    final fromServer = ['Automotive Services', 'Gardening', 'Other', 'plumbing', 'Beauty & Health'];
    expect(AppState.sortCategories(fromServer),
        ['Beauty & Health', 'plumbing', 'Automotive Services', 'Gardening', 'Other']);
  });

  test('"Visit the business" needs the provider to allow it and a findable location', () {
    ProviderModel provider({bool visit = true, String address = '', double? lat}) => ProviderModel(
          id: 'p1',
          name: 'Salon',
          rating: 0,
          reviews: 0,
          distanceKm: 0,
          services: [],
          offersVisit: visit,
          address: address,
          latitude: lat,
          longitude: lat,
        );

    expect(provider(address: '1 Main Rd, Soweto').canBeVisited, isTrue);
    expect(provider(lat: -26.2).canBeVisited, isTrue);
    expect(provider().canBeVisited, isFalse, reason: 'no address and no map pin');
    expect(provider(visit: false, address: '1 Main Rd').canBeVisited, isFalse, reason: 'provider switched it off');
  });
}
