import { buildAllowedOrigins, isOriginAllowed } from '../../src/config/cors.js';

const allowedFor = (env) => {
  const allowed = buildAllowedOrigins(env);
  return (origin) => isOriginAllowed(origin, allowed);
};

describe('CORS origins', () => {
  const codespaceEnv = {
    NODE_ENV: 'development',
    FRONTEND_URL: 'http://localhost:3001',
    ADMIN_URL: 'http://localhost:3002',
    CORS_ORIGINS: 'https://connect-local.netlify.app/, https://connect-local-admin.netlify.app',
    CODESPACE_NAME: 'moonlit-owl-abc',
    GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN: 'app.github.dev'
  };

  test('allows requests without an Origin (curl, mobile app, PayFast server)', () => {
    expect(allowedFor(codespaceEnv)(undefined)).toBe(true);
  });

  test('allows configured origins, ignoring trailing slash', () => {
    const allowed = allowedFor(codespaceEnv);
    expect(allowed('https://connect-local.netlify.app')).toBe(true);
    expect(allowed('https://connect-local-admin.netlify.app')).toBe(true);
  });

  test('allows ports of this Codespace only', () => {
    const allowed = allowedFor(codespaceEnv);
    expect(allowed('https://moonlit-owl-abc-8080.app.github.dev')).toBe(true);
    expect(allowed('https://someone-else-8080.app.github.dev')).toBe(false);
    expect(allowed('https://moonlit-owl-abc-8080.app.github.dev.evil.com')).toBe(false);
  });

  test('blocks other netlify sites and random origins', () => {
    const allowed = allowedFor(codespaceEnv);
    expect(allowed('https://evil.netlify.app')).toBe(false);
    expect(allowed('https://example.com')).toBe(false);
  });

  test('allows any localhost port in development but not in production', () => {
    expect(allowedFor(codespaceEnv)('http://localhost:53123')).toBe(true);
    const prod = allowedFor({ NODE_ENV: 'production', CORS_ORIGINS: 'https://connect-local.netlify.app' });
    expect(prod('http://localhost:53123')).toBe(false);
    expect(prod('https://connect-local.netlify.app')).toBe(true);
  });

  test('FRONTEND_URL may hold several origins (app + admin on Netlify)', () => {
    const allowed = allowedFor({
      NODE_ENV: 'production',
      FRONTEND_URL: 'https://connect-local.netlify.app, https://connect-local-admin.netlify.app/'
    });
    expect(allowed('https://connect-local.netlify.app')).toBe(true);
    expect(allowed('https://connect-local-admin.netlify.app')).toBe(true);
  });

  test('ALLOW_LOCALHOST_ORIGINS lets local Flutter web reach a production API', () => {
    expect(allowedFor({ NODE_ENV: 'production', ALLOW_LOCALHOST_ORIGINS: 'true' })('http://localhost:61234')).toBe(true);
  });
});
