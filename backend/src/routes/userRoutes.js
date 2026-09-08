const express = require("express");

const controller =
    require("../controllers/userController");

const router = express.Router();

router.post(
    "/register",
    controller.register
);

router.post(
    "/login",
    controller.login
);

router.get(
    "/:id",
    controller.getUser
);

router.put(
    "/:id",
    controller.updateUser
);

router.delete(
    "/:id",
    controller.deleteUser
);

router.post(
    "/logout",
    controller.logout
);

module.exports = router;
