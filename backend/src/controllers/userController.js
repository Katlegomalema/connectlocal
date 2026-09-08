const userService = require("../services/userService");


async function register(req, res) {

    try {

        const result =
            await userService.registerUser(req.body);

        res.status(201).json({
            message: "User registered successfully",
            ...result
        });

    } catch (error) {

        res.status(400).json({
            message: error.message
        });
    }
}


async function login(req, res) {

    try {

        const { email, password } = req.body;

        const result =
            await userService.loginUser(
                email,
                password
            );

        res.status(200).json({
            message: "Login successful",
            ...result
        });

    } catch (error) {

        res.status(401).json({
            message: "Invalid email or password"
        });
    }
}


async function getUser(req, res) {

    try {

        const user =
            await userService.getUser(
                req.params.id
            );

        res.status(200).json(user);

    } catch (error) {

        res.status(404).json({
            message: "User not found"
        });
    }
}


async function updateUser(req, res) {

    try {

        const user =
            await userService.updateUser(
                req.params.id,
                req.body
            );

        res.status(200).json({
            message: "User updated successfully",
            user
        });

    } catch (error) {

        res.status(400).json({
            message: error.message
        });
    }
}


async function deleteUser(req, res) {

    try {

        await userService.deleteUser(
            req.params.id
        );

        res.status(200).json({
            message: "User deleted successfully"
        });

    } catch (error) {

        res.status(400).json({
            message: error.message
        });
    }
}


async function logout(req, res) {

    try {

        const result =
            await userService.logoutUser();

        res.status(200).json(result);

    } catch (error) {

        res.status(400).json({
            message: error.message
        });
    }
}


module.exports = {
    register,
    login,
    getUser,
    updateUser,
    deleteUser,
    logout
};
