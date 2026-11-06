CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

ALTER TABLE public.providers
  ADD COLUMN IF NOT EXISTS location extensions.geography(Point, 4326),
  ADD COLUMN IF NOT EXISTS primary_category_id uuid
    REFERENCES public.service_categories(id);

CREATE INDEX IF NOT EXISTS providers_location_gist_idx
  ON public.providers USING GIST (location);

CREATE OR REPLACE FUNCTION public.search_nearby_providers(
  search_latitude double precision,
  search_longitude double precision,
  search_radius_km double precision
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  business_name varchar,
  business_description text,
  city varchar,
  province varchar,
  service_radius_km integer,
  rating_average numeric,
  rating_count integer,
  latitude double precision,
  longitude double precision,
  distance_km double precision
)
LANGUAGE sql
STABLE
SET search_path = public, extensions
AS $function$
  SELECT
    provider.id,
    provider.user_id,
    provider.business_name,
    provider.business_description,
    provider.city,
    provider.province,
    provider.service_radius_km,
    provider.rating_average,
    provider.rating_count,
    extensions.ST_Y(provider.location::extensions.geometry) AS latitude,
    extensions.ST_X(provider.location::extensions.geometry) AS longitude,
    extensions.ST_Distance(
      provider.location,
      extensions.ST_SetSRID(
        extensions.ST_MakePoint(search_longitude, search_latitude),
        4326
      )::extensions.geography
    ) / 1000 AS distance_km
  FROM public.providers AS provider
  WHERE provider.is_active
    AND provider.verification_status = 'verified'
    AND provider.location IS NOT NULL
    AND extensions.ST_DWithin(
      provider.location,
      extensions.ST_SetSRID(
        extensions.ST_MakePoint(search_longitude, search_latitude),
        4326
      )::extensions.geography,
      LEAST(search_radius_km, COALESCE(provider.service_radius_km, search_radius_km)) * 1000
    )
  ORDER BY distance_km, provider.id
$function$;

REVOKE ALL ON FUNCTION public.search_nearby_providers(double precision, double precision, double precision)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.search_nearby_providers(double precision, double precision, double precision)
  TO service_role;
