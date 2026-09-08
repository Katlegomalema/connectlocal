function calculateDistance(
    latitude1,
    longitude1,
    latitude2,
    longitude2
) {

    const earthRadius = 6371;

    const toRadians =
        degrees => degrees * Math.PI / 180;

    const lat1 = toRadians(latitude1);
    const lat2 = toRadians(latitude2);

    const deltaLatitude =
        toRadians(latitude2 - latitude1);

    const deltaLongitude =
        toRadians(longitude2 - longitude1);

    const a =
        Math.sin(deltaLatitude / 2) ** 2 +
        Math.cos(lat1) *
        Math.cos(lat2) *
        Math.sin(deltaLongitude / 2) ** 2;

    const c =
        2 * Math.atan2(
            Math.sqrt(a),
            Math.sqrt(1 - a)
        );

    return earthRadius * c;
}

module.exports = calculateDistance;
