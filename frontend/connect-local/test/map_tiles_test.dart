import 'package:connect_local/features/shared/map_tiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default map tiles need no API key and carry the required credit', () {
    expect(MapTiles.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(MapTiles.urlTemplate, isNot(contains('cartocdn')), reason: 'CARTO now answers "API KEY REQUIRED"');
    expect(MapTiles.subdomains, isEmpty, reason: 'OpenStreetMap asks apps not to use a./b./c. hosts');
    expect(MapTiles.attribution, contains('OpenStreetMap contributors'));
    expect(MapTiles.userAgentPackageName, isNot(startsWith('com.example')), reason: 'OSM blocks com.example');
    expect(MapTiles.maxNativeZoom, 19);
  });
}
