import 'dotenv/config';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { getPool, closePool } from '../src/config/database.js';
import logger from '../src/utils/logger.js';

const migrationsDirectory = path.dirname(fileURLToPath(import.meta.url));

export const runMigrations = async () => {
  const client = await getPool().connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS public.schema_migrations (
        name text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `);

    const files = (await readdir(migrationsDirectory))
      .filter((file) => /^\d.*\.sql$/.test(file))
      .sort();

    for (const file of files) {
      const { rowCount } = await client.query(
        'SELECT 1 FROM public.schema_migrations WHERE name = $1',
        [file]
      );
      if (rowCount) continue;

      const migration = await readFile(path.join(migrationsDirectory, file), 'utf8');
      await client.query('BEGIN');
      try {
        await client.query(migration);
        await client.query(
          'INSERT INTO public.schema_migrations (name) VALUES ($1)',
          [file]
        );
        await client.query('COMMIT');
        logger.info({ migration: file }, 'Database migration applied');
      } catch (error) {
        await client.query('ROLLBACK');
        throw new Error(`Database migration failed: ${file}`, { cause: error });
      }
    }
  } finally {
    client.release();
    await closePool();
  }
};

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runMigrations().catch((error) => {
    logger.error({ err: error }, 'Database migration failed');
    process.exitCode = 1;
  });
}

export default runMigrations;
