/**
 * PostGIS points -> { latitude, longitude }.
 *
 * PostgREST returns a geography column as EWKB hex (e.g. "0101000020E6100000..."); RPCs and older code paths
 * may give GeoJSON ({ type: 'Point', coordinates: [lng, lat] }) or WKT ("SRID=4326;POINT(lng lat)").
 * All three are handled here so every endpoint answers in the same simple shape.
 */

const EWKB_SRID_FLAG = 0x20000000;
const WKB_POINT = 1;

const fromEwkbHex = (hex) => {
  if (!/^[0-9a-f]+$/i.test(hex) || hex.length < 42) return null;
  const bytes = Buffer.from(hex, 'hex');
  const littleEndian = bytes[0] === 1;
  const readUInt32 = (offset) => (littleEndian ? bytes.readUInt32LE(offset) : bytes.readUInt32BE(offset));
  const readDouble = (offset) => (littleEndian ? bytes.readDoubleLE(offset) : bytes.readDoubleBE(offset));

  const type = readUInt32(1);
  // eslint-disable-next-line no-bitwise
  if ((type & 0xffff) !== WKB_POINT) return null;
  // eslint-disable-next-line no-bitwise
  const offset = 5 + (type & EWKB_SRID_FLAG ? 4 : 0);
  if (bytes.length < offset + 16) return null;
  return { longitude: readDouble(offset), latitude: readDouble(offset + 8) };
};

const NUMBER = '-?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:e[+-]?\\d+)?';
const WKT_POINT = new RegExp(`POINT\\s*\\(\\s*(${NUMBER})\\s+(${NUMBER})\\s*\\)`, 'i');

/** { latitude, longitude } or null. */
export const toLatLng = (value) => {
  if (!value) return null;
  if (typeof value === 'object' && Array.isArray(value.coordinates) && value.coordinates.length >= 2) {
    return { latitude: Number(value.coordinates[1]), longitude: Number(value.coordinates[0]) };
  }
  if (typeof value === 'object' && Number.isFinite(Number(value.latitude)) && Number.isFinite(Number(value.longitude))) {
    return { latitude: Number(value.latitude), longitude: Number(value.longitude) };
  }
  if (typeof value === 'string') {
    const point = value.match(WKT_POINT);
    if (point) return { latitude: Number(point[2]), longitude: Number(point[1]) };
    return fromEwkbHex(value);
  }
  return null;
};

export default { toLatLng };
