#!/usr/bin/env node

/**
 * ConnectLocal Backend Quick Start Guide
 * 
 * This script provides setup and common commands for backend development
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const packageJsonPath = path.join(__dirname, 'package.json');

const printBanner = () => {
  console.log(`
╔════════════════════════════════════════════════════════════════╗
║         ConnectLocal Backend - Quick Start Guide               ║
╚════════════════════════════════════════════════════════════════╝
  `);
};

const printSetupSteps = () => {
  console.log(`
📋 SETUP STEPS:
═════════════════════════════════════════════════════════════════

1. Install Dependencies
   npm install

2. Configure Environment
   cp .env.example .env
   # Edit .env with your configuration values

3. Start Development Server
   npm run dev
   # Server runs on http://localhost:3000

4. Run Tests
   npm run test
   # Run all tests with coverage
   npm run test:unit -- --coverage

5. Build for Production
   npm install
   npm run lint
   npm start


📦 AVAILABLE SCRIPTS:
═════════════════════════════════════════════════════════════════

Development:
  npm run dev              Start dev server with auto-reload
  npm start               Start production server
  npm run lint            Lint code with ESLint
  npm run lint --fix      Auto-fix linting issues

Testing:
  npm test                Run all tests
  npm run test:unit       Run unit tests only
  npm run test:integration Run integration tests only
  npm run test:watch      Run tests in watch mode

Database:
  npm run migrate         Run pending migrations


🗂️  PROJECT STRUCTURE:
═════════════════════════════════════════════════════════════════

backend/
├── src/
│   ├── app.js              Express app setup
│   ├── config/             Configuration (Supabase, database)
│   ├── controllers/        Request handlers
│   ├── services/           Business logic
│   ├── repositories/       Database access
│   ├── routes/             API endpoints
│   ├── middleware/         Auth, validation, error handling
│   ├── utils/              Helpers, loggers, validators
│   └── integrations/       External service clients
├── tests/                  Unit and integration tests
├── migrations/             Database migrations
├── package.json            Dependencies
├── .env.example            Environment template
└── server.js               Entry point


🔌 API ENDPOINTS:
═════════════════════════════════════════════════════════════════

Base URL: http://localhost:3000/api/v1

Authentication:
  POST   /auth/register           Register new user
  POST   /auth/login              Authenticate user
  POST   /auth/refresh            Refresh access token
  POST   /auth/logout             Logout user

Users:
  GET    /users/:id               Get user profile
  PUT    /users/:id               Update profile
  GET    /users/:id/bookings      List user bookings

Providers:
  GET    /providers/:id           Get provider profile
  PUT    /providers/:id           Update profile
  GET    /providers/:id/services  List provider services
  POST   /providers/:id/services  Create new service

Search:
  GET    /search/nearby           Find nearby providers
  GET    /search/providers        Search providers
  GET    /search/categories       Get service categories

Bookings:
  POST   /bookings                Create booking
  GET    /bookings/:id            Get booking details
  PUT    /bookings/:id            Update booking
  POST   /bookings/:id/accept     Accept booking
  POST   /bookings/:id/decline    Decline booking
  POST   /bookings/:id/cancel     Cancel booking
  POST   /bookings/:id/complete   Complete booking

Messages:
  POST   /messages                Send message
  GET    /messages/:conversationId Get conversation
  GET    /messages                List conversations

Reviews:
  POST   /reviews                 Create review
  GET    /reviews/:providerId     Get provider reviews
  POST   /reviews/:id/reply       Reply to review

Payments:
  POST   /payments/intent         Create payment
  POST   /payments/confirm        Confirm payment
  GET    /payments/:id            Get payment details
  POST   /payments/:id/refund     Request refund

Admin:
  GET    /admin/users             List users
  GET    /admin/providers/pending Pending verifications
  POST   /admin/providers/:id/verify Approve provider
  GET    /admin/analytics         Platform analytics


🔐 ENVIRONMENT VARIABLES:
═════════════════════════════════════════════════════════════════

Required:
  NODE_ENV                    development/production
  PORT                        3000
  SUPABASE_URL               Your Supabase project URL
  SUPABASE_KEY               Supabase public anon key
  SUPABASE_SERVICE_ROLE_KEY  Supabase service role key

Optional (for features):
  GOOGLE_MAPS_API_KEY        Google Maps API key
  PAYFAST_MERCHANT_ID        PayFast merchant ID
  FIREBASE_PROJECT_ID        Firebase project ID
  SENDGRID_API_KEY           SendGrid API key
  TWILIO_ACCOUNT_SID         Twilio account SID

See .env.example for complete list.


📚 DOCUMENTATION:
═════════════════════════════════════════════════════════════════

- Backend Structure: See BACKEND_STRUCTURE.md
- API Specifications: See docs/api-specs/
- Architecture: See docs/architecture/Backend-Architecture.md
- Database Schema: See docs/architecture/Database-Architecture.md
- Contributing: See CONTRIBUTING.md


🐛 TROUBLESHOOTING:
═════════════════════════════════════════════════════════════════

Issue: Module not found
  Solution: Run npm install to ensure dependencies are installed

Issue: Port 3000 already in use
  Solution: Change PORT in .env or kill process on port 3000

Issue: Supabase connection fails
  Solution: Verify SUPABASE_URL and SUPABASE_KEY in .env

Issue: Tests failing
  Solution: Ensure database migrations are run and .env.test is configured


🚀 DEPLOYMENT:
═════════════════════════════════════════════════════════════════

To Render.com:
  1. Push code to GitHub
  2. Create new Web Service on Render
  3. Select this GitHub repository
  4. Set environment variables in Render dashboard
  5. Deploy

View deployment logs and settings in Render dashboard.


💡 TIPS:
═════════════════════════════════════════════════════════════════

• Always run 'npm run lint' before committing
• Write tests for new features
• Check logs when debugging: npm run dev
• Use .env.local for local overrides (gitignored)
• Review CONTRIBUTING.md before contributing


📞 SUPPORT:
═════════════════════════════════════════════════════════════════

For issues or questions:
  1. Check documentation files in docs/
  2. Review existing issues on GitHub
  3. Ask in project communication channels

═════════════════════════════════════════════════════════════════
  `);
};

printBanner();
printSetupSteps();
