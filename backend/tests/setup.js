/**
 * Test Setup
 * Configuration for Jest and common test utilities
 */

import dotenv from 'dotenv';

// Load test environment variables
dotenv.config({ path: '.env.test' });

// Set test environment
process.env.NODE_ENV = 'test';

// Mock external services if needed
global.testSetup = true;
