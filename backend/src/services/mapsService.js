const {
    saveProviderLocation,
    getProviderLocations
} = require("../repositories/mapsRepository");

const calculateDistance =
    require("../utils/distance");


async function saveLocation(
    providerId,
    latitude,
    longitude
) {

    if (
        latitude < -90 ||
        latitude > 90
    ) {
        throw new Error(
            "Invalid latitude"
        );
    }

    if (
        longitude < -180 ||
        longitude > 180
    ) {
        throw new Error(
            "Invalid longitude"
        );
    }

    return await saveProviderLocation(
        providerId,
        latitude,
        longitude
    );
}


async function findNearbyProviders(
    latitude,
    longitude,
    radiusKm
) {

    const providers =
        await getProviderLocations();

    const nearbyProviders = [];

    for (const provider of providers) {

        const distance =
            calculateDistance(
                latitude,
                longitude,
                provider.latitude,
                provider.longitude
            );

        if (distance <= radiusKm) {

            nearbyProviders.push({
                provider_id:
                    provider.provider_id,

                latitude:
                    provider.latitude,

                longitude:
                    provider.longitude,

                distance_km:
                    Number(distance.toFixed(2))
            });
        }
    }

    nearbyProviders.sort(
        (a, b) =>
            a.distance_km -
            b.distance_km
    );

    return nearbyProviders;
}


function getDistance(
    latitude1,
    longitude1,
    latitude2,
    longitude2
) {

    const distance =
        calculateDistance(
            latitude1,
            longitude1,
            latitude2,
            longitude2
        );

    return Number(
        distance.toFixed(2)
    );
}


module.exports = {
    saveLocation,
    findNearbyProviders,
    getDistance
};
