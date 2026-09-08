const mapsService =
    require("../services/mapsService");


async function saveLocation(req, res) {

    try {

        const {
            providerId,
            latitude,
            longitude
        } = req.body;

        const result =
            await mapsService.saveLocation(
                providerId,
                latitude,
                longitude
            );

        res.status(201).json({
            message:
                "Provider location saved",
            location: result
        });

    } catch (error) {

        res.status(400).json({
            message: error.message
        });
    }
}


async function nearbyProviders(req, res) {

    try {

        const {
            latitude,
            longitude,
            radiusKm = 10
        } = req.body;

        const providers =
            await mapsService.findNearbyProviders(
                latitude,
                longitude,
                radiusKm
            );

        res.status(200).json({
            radius_km: radiusKm,
            count: providers.length,
            providers
        });

    } catch (error) {

        res.status(400).json({
            message: error.message
        });
    }
}


function distance(req, res) {

    try {

        const {
            latitude1,
            longitude1,
            latitude2,
            longitude2
        } = req.query;

        const result =
            mapsService.getDistance(
                Number(latitude1),
                Number(longitude1),
                Number(latitude2),
                Number(longitude2)
            );

        res.status(200).json({
            distance_km: result
        });

    } catch (error) {

        res.status(400).json({
            message: error.message
        });
    }
}


module.exports = {
    saveLocation,
    nearbyProviders,
    distance
};
