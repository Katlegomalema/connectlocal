const express = require("express");

const controller =
    require("../controllers/mapsController");

const router = express.Router();


router.post(
    "/location",
    controller.saveLocation
);


router.post(
    "/providers/nearby",
    controller.nearbyProviders
);


router.get(
    "/distance",
    controller.distance
);


module.exports = router;
