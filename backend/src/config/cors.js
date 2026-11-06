/**
 * CORS configuration
 *
 * Allowed browser origins (exact match, no wildcards):
 *   - FRONTEND_URL, ADMIN_URL (each may be a comma-separated list, e.g. the Netlify app + admin sites)
 *   - CORS_ORIGINS: comma-separated extra origins, e.g. the Netlify site
 *       CORS_ORIGINS=https://connect-local.netlify.app,https://connect-local-admin.netlify.app
 *   - When running inside GitHub Codespaces: any forwarded port of *this* Codespace
 *       (https://<CODESPACE_NAME>-<port>.app.github.dev)
 *   - Outside production (or with ALLOW_LOCALHOST_ORIGINS=true): http://localhost:<any port> and
 *       http://127.0.0.1:<any port> (flutter run -d chrome picks a random port)
 *
 * Requests without an Origin header (curl, the Android/iOS app, PayFast's ITN server call) are not
 * browser cross-origin requests and are allowed through; auth is enforced by the routes, not CORS.
 * The API uses Bearer tokens, not cookies, so credentials are not enabled.
 */

const normalise = (origin) => origin.trim().replace(/\/+$/, '').toLowerCase();

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export const buildAllowedOrigins = (env = process.env) => {
  const exact = new Set(
    [env.FRONTEND_URL, env.ADMIN_URL, env.CORS_ORIGINS].flatMap((value) => (value || '').split(','))
      .filter((value) => value && value.trim())
      .map(normalise)
  );

  const patterns = [];
  if (env.CODESPACE_NAME && env.GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN) {
    patterns.push(new RegExp(
      `^https://${escapeRegex(env.CODESPACE_NAME.toLowerCase())}-\\d+\\.${escapeRegex(env.GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN.toLowerCase())}$`
    ));
  }
  if (env.NODE_ENV !== 'production' || env.ALLOW_LOCALHOST_ORIGINS === 'true') {
    patterns.push(/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/);
  }

  return { exact, patterns };
};

export const isOriginAllowed = (origin, allowed) => {
  if (!origin) return true;
  const value = normalise(origin);
  return allowed.exact.has(value) || allowed.patterns.some((pattern) => pattern.test(value));
};

export const buildCorsOptions = (env = process.env) => {
  const allowed = buildAllowedOrigins(env);
  return {
    // Not allowed -> no CORS headers, the browser blocks it. We don't throw (that would become a 500).
    origin: (origin, callback) => callback(null, isOriginAllowed(origin, allowed)),
    credentials: false,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Idempotency-Key'],
    maxAge: 600
  };
};

export default buildCorsOptions;
