/**
 * Database Configuration
 * Placeholder for advanced database configuration options
 */

export const dbConfig = {
  // Connection pooling settings
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,

  // Query settings
  query_timeout: 60000,

  // Retry settings
  max_retries: 3,
  retry_delay: 1000
};

export default dbConfig;
