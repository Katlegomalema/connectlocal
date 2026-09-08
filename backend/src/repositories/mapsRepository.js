const supabase = require("../config/supabase");


async function saveProviderLocation(
    providerId,
    latitude,
    longitude
) {

    const { data, error } =
        await supabase
            .from("provider_locations")
            .upsert({
                provider_id: providerId,
                latitude,
                longitude
            })
            .select()
            .single();

    if (error) {
        throw error;
    }

    return data;
}


async function getProviderLocations() {

    const { data, error } =
        await supabase
            .from("provider_locations")
            .select("*");

    if (error) {
        throw error;
    }

    return data;
}


module.exports = {
    saveProviderLocation,
    getProviderLocations
};
