# Location & Provider Discovery API

## Overview

The Flutter client renders maps and obtains the selected/current coordinates. The API stores provider coordinates and performs nearby-provider search with PostGIS; it does not call Google Maps, geocode addresses, or return route/travel-time estimates.

All routes use the `/api/v1` prefix and JSON responses.

## Provider location

Provider onboarding uses `POST /providers` (provider role). The `location` field is required and uses WGS84 latitude/longitude:

```json
{
  "businessName": "Mokoena Plumbing Services",
  "category": "Plumbing",
  "description": "Residential plumbing services.",
  "serviceAreaRadiusKm": 15,
  "location": { "lat": -26.2041, "lng": 28.0473 }
}
```

`category` is matched to an active `service_categories.name`; alternatively, send `categoryId`. Optional address fields are `streetAddress`, `suburb`, `city`, `province`, and `postalCode`. Provider profile updates accept the same `location` shape at `PATCH /providers/me`.

The PostGIS migration adds a provider `location` geography point and the provider's primary category reference. Existing providers remain without a searchable location until they update their profile.

## Nearby search

### `GET /search/nearby`

Public endpoint. Parameters:

| Parameter | Required | Rules |
|---|---:|---|
| `latitude` | yes | -90 through 90 |
| `longitude` | yes | -180 through 180 |
| `radius` | no | 1 through 50 km; default 50 |
| `category` | no | Active category name or UUID |
| `minRating` | no | 0 through 5 |
| `maxPrice` | no | Non-negative service price |

Example:

```http
GET /api/v1/search/nearby?latitude=-26.2041&longitude=28.0473&radius=15
```

The response contains provider coordinates and `distance_km` for map markers and distance labels:

```json
{
  "success": true,
  "data": {
    "providers": [
      {
        "id": "c3e1a9f0-...",
        "business_name": "Mokoena Plumbing Services",
        "latitude": -26.2041,
        "longitude": 28.0473,
        "distance_km": 0.42
      }
    ],
    "count": 1,
    "searchCenter": { "latitude": -26.2041, "longitude": 28.0473 },
    "radiusKm": 15
  }
}
```

The database query filters to active, verified providers and applies the lower of the requested radius and each provider's service radius. No map-tile URL, map SDK key, or geocoding service is required by the backend.

## Saved providers

- `POST /search/saved` — customer-only; JSON body `{ "providerId": "<uuid>" }`.
- `GET /search/saved` — lists the caller's active, verified saved providers.
- `DELETE /search/saved/:providerId` — removes a saved provider.

## Migration

Set `DATABASE_URL` to the Supabase PostgreSQL connection string and run `npm run migrate` from `backend/`. The migration runner records applied SQL migrations in `public.schema_migrations`.
