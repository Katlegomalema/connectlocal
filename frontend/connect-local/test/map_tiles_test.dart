import 'package:connect_local/features/shared/map_tiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default map tiles need no API key and carry the required credit', () {
    expect(MapTiles.urlTemplate, MapTiles.esriUrl);
    expect(MapTiles.urlTemplate, contains('{z}/{y}/{x}'), reason: 'Esri tiles are row (y) before column (x)');
    for (final blocked in ['cartocdn', 'tile.openstreetmap.org']) {
      expect(MapTiles.urlTemplate, isNot(contains(blocked)), reason: '$blocked shows a "key required"/"blocked" tile');
    }
    expect(MapTiles.subdomains, isEmpty);
    expect(MapTiles.attribution, allOf(contains('Esri'), contains('OpenStreetMap contributors')));
    expect(MapTiles.userAgentPackageName, isNot(startsWith('com.example')));
  });
}
