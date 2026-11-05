import { toLatLng } from '../../src/utils/geo.js';

describe('toLatLng', () => {
  test('EWKB hex from PostgREST (geography column)', () => {
    const point = toLatLng('0101000020E61000009B3AF4CA5A313C40046C4BE11DBF39C0');
    expect(point.latitude).toBeCloseTo(-25.7465, 3);
    expect(point.longitude).toBeCloseTo(28.1928, 3);
  });
  test('GeoJSON and WKT', () => {
    expect(toLatLng({ type: 'Point', coordinates: [28.2, -25.7] })).toEqual({ latitude: -25.7, longitude: 28.2 });
    expect(toLatLng('SRID=4326;POINT(28.2 -25.7)')).toEqual({ latitude: -25.7, longitude: 28.2 });
  });
  test('garbage and empty values give null', () => {
    expect(toLatLng('zz')).toBeNull();
    expect(toLatLng(null)).toBeNull();
    expect(toLatLng('0102000020E6100000')).toBeNull(); // not a point
  });
});
