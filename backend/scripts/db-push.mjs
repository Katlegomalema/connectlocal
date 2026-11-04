/**
 * Apply supabase/migrations to the remote database with the Supabase CLI.
 *
 *   npm run db:push:dry          # show which migrations would run (changes nothing)
 *   npm run db:push -- --yes     # apply them (--yes is the confirmation; output is filtered, so the
 *                                # CLI cannot ask interactively)
 *
 * - Connects over the Session pooler (DATABASE_URL in backend/.env), never the IPv6-only direct host.
 * - TLS is verify-full against the Supabase root CA (DB_SSL_CA, default certs/supabase-ca.crt).
 * - The connection string and password are never printed.
 */

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const backendDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repoDir = path.resolve(backendDir, '..');

const fail = (message) => {
  console.error(`db-push: ${message}`);
  process.exit(1);
};

if (!process.env.DATABASE_URL) fail('DATABASE_URL is not set in backend/.env (use the Session pooler string).');

let url;
try {
  url = new URL(process.env.DATABASE_URL);
} catch {
  fail('DATABASE_URL is not a valid URL.');
}
if (!url.hostname.endsWith('.pooler.supabase.com')) {
  fail('DATABASE_URL must be the Session pooler (…pooler.supabase.com); the direct host is IPv6-only.');
}

const caPath = path.resolve(backendDir, process.env.DB_SSL_CA || 'certs/supabase-ca.crt');
if (!existsSync(caPath)) fail(`Supabase CA certificate not found at ${caPath}.`);

url.searchParams.set('sslmode', 'verify-full');
url.searchParams.set('sslrootcert', caPath);

const extraArgs = process.argv.slice(2);
const result = spawnSync(
  'npx',
  ['-y', 'supabase@3.0.0', 'db', 'push', '--db-url', url.toString(), '--include-all', ...extraArgs],
  { cwd: repoDir, encoding: 'utf8', input: 'y\n' }
);

const secrets = [url.toString(), process.env.DATABASE_URL, decodeURIComponent(url.password)].filter(Boolean);
const redact = (text = '') => secrets.reduce((out, secret) => out.split(secret).join('<redacted>'), text)
  .split('\n')
  .filter((line) => !line.includes('--db-url is deprecated'))
  .join('\n');

process.stdout.write(redact(result.stdout));
process.stderr.write(redact(result.stderr));
if (result.error) fail(result.error.message);
process.exit(result.status ?? 1);
