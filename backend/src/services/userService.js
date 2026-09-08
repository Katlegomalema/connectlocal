const supabase = require("../config/supabase");

const {
    createUserProfile,
    getUserProfile,
    updateUserProfile,
    deleteUserProfile
} = require("../repositories/userRepository");


async function registerUser(userData) {

    if (!["customer", "provider"].includes(userData.role)) {
        throw new Error(
            "Role must be customer or provider"
        );
    }

    const { data, error } = await supabase.auth.signUp({
        email: userData.email,
        password: userData.password
    });

    if (error) {
        throw error;
    }

    const user = data.user;

    if (!user) {
        throw new Error("User registration failed");
    }

    const profile = await createUserProfile(
        user.id,
        userData
    );

    return {
        user: {
            id: user.id,
            email: user.email,
            name: profile.name,
            phone: profile.phone,
            role: profile.role
        },
        session: data.session
    };
}


async function loginUser(email, password) {

    const { data, error } =
        await supabase.auth.signInWithPassword({
            email,
            password
        });

    if (error) {
        throw error;
    }

    const profile = await getUserProfile(
        data.user.id
    );

    return {
        user: profile,
        session: data.session
    };
}


async function getUser(userId) {

    return await getUserProfile(userId);
}


async function updateUser(userId, updates) {

    return await updateUserProfile(
        userId,
        updates
    );
}


async function deleteUser(userId) {

    return await deleteUserProfile(userId);
}


async function logoutUser() {

    const { error } =
        await supabase.auth.signOut();

    if (error) {
        throw error;
    }

    return {
        message: "Logout successful"
    };
}


module.exports = {
    registerUser,
    loginUser,
    getUser,
    updateUser,
    deleteUser,
    logoutUser
};
