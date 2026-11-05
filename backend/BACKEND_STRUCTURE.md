/**
 * Backend Structure Documentation
 * Overview of backend folder organization and key files
 */

# Backend File Structure Guide

## Overview
The ConnectLocal backend is a modular Node.js/Express REST API following a layered architecture pattern. This ensures clear separation of concerns, testability, and maintainability.

## Folder Structure

```
backend/
├── migrations/              # Database schema migrations
│   ├── 001_create_users_table.js
│   └── run.js              # Migration runner
│
├── src/
│   ├── app.js              # Express app configuration
│   ├── config/             # Configuration files
│   │   ├── database.js     # Database configuration
│   │   └── supabase.js     # Supabase client setup
│   │
│   ├── controllers/        # Request handlers (thin layer)
│   │   └── authController.js
│   │
│   ├── services/           # Business logic layer
│   │   ├── authService.js
│   │   ├── bookingService.js
│   │   ├── messageService.js
│   │   ├── searchService.js
│   │   ├── reviewService.js
│   │   ├── paymentService.js
│   │   └── notificationService.js
│   │
│   ├── repositories/       # Database access layer
│   │   ├── userRepository.js
│   │   ├── bookingRepository.js
│   │   └── providerRepository.js
│   │
│   ├── routes/             # API endpoint definitions
│   │   ├── auth.js         # /api/v1/auth routes
│   │   ├── user.js         # /api/v1/users routes
│   │   ├── provider.js     # /api/v1/providers routes
│   │   ├── search.js       # /api/v1/search routes
│   │   ├── booking.js      # /api/v1/bookings routes
│   │   ├── message.js      # /api/v1/messages routes
│   │   ├── review.js       # /api/v1/reviews routes
│   │   ├── payment.js      # /api/v1/payments routes
│   │   └── admin.js        # /api/v1/admin routes
│   │
│   ├── middleware/         # Middleware functions
│   │   ├── auth.js         # Authentication/authorization
│   │   ├── errorHandler.js # Error handling
│   │   └── validation.js   # Request validation
│   │
│   ├── utils/              # Utility functions
│   │   ├── errors.js       # Custom error classes
│   │   ├── helpers.js      # Common utilities
│   │   ├── logger.js       # Structured logging
│   │   └── validators.js   # Zod validation schemas
│   │
│   └── integrations/       # External service integrations
│       ├── payfast.js      # PayFast API
│       ├── payfast.js      # PayFast payment gateway
│       ├── firebase.js     # Push notifications
│       └── sendgrid.js     # Email service
│
├── tests/
│   ├── setup.js            # Test configuration
│   ├── unit/               # Unit tests
│   │   ├── authService.test.js
│   │   ├── userRepository.test.js
│   │   └── validators.test.js
│   └── integration/        # Integration tests
│       ├── authApi.test.js
│       └── userApi.test.js
│
├── .env.example            # Environment variables template
├── .eslintrc.json          # ESLint configuration
├── .gitignore              # Git ignore rules
├── jest.config.js          # Jest test configuration
├── package.json            # Dependencies and scripts
└── server.js               # Application entry point
```

## Layer Descriptions

### Routes Layer (`src/routes/`)
- Defines HTTP endpoints and routes
- Minimal logic; delegates to controllers
- Applies route-specific middleware
- Handles request/response formatting

### Controllers Layer (`src/controllers/`)
- Receives HTTP requests
- Delegates to services
- Returns formatted responses
- Should be thin; avoid business logic here

### Services Layer (`src/services/`)
- Contains core business logic
- Orchestrates repository and integration calls
- Handles validation and data transformation
- Independent of HTTP layer

### Repositories Layer (`src/repositories/`)
- Database access abstraction
- Encapsulates Supabase queries
- Enables easy testing and future database changes
- Maps database records to domain objects

### Middleware (`src/middleware/`)
- **auth.js**: JWT verification, role-based access control
- **errorHandler.js**: Centralized error handling
- **validation.js**: Request payload validation

### Utilities (`src/utils/`)
- **logger.js**: Structured logging with Pino
- **errors.js**: Custom error classes for consistent error handling
- **validators.js**: Reusable Zod validation schemas
- **helpers.js**: Pure utility functions (distance calculation, formatting, etc.)

## Key Design Patterns

### 1. Error Handling
- Custom error classes in `utils/errors.js`
- Centralized handler in middleware
- Consistent API error responses

### 2. Validation
- Zod schemas in `utils/validators.js`
- Applied via middleware
- Declarative validation

### 3. Logging
- Pino structured logging
- Context included in logs
- Level-based filtering

### 4. Database Access
- Repository pattern for data access
- Supabase clients (regular + admin)
- RLS policies enforced

### 5. Service Modules
Each service module handles a specific domain:
- **Auth Service**: User authentication and token management
- **Booking Service**: Booking lifecycle management
- **Messaging Service**: Real-time messaging
- **Search Service**: Location-based provider discovery
- **Review Service**: Ratings and feedback
- **Payment Service**: Transaction processing
- **Notification Service**: Push/email/in-app notifications

## Configuration

### Environment Variables (`.env`)
```
NODE_ENV=development
PORT=3000

# Supabase
SUPABASE_URL=...
SUPABASE_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...

# External APIs
PAYFAST_MERCHANT_ID=...
FIREBASE_PROJECT_ID=...
```

See `.env.example` for complete list.

## Running the Application

```bash
# Install dependencies
npm install

# Start development server (with auto-reload)
npm run dev

# Start production server
npm start

# Run all tests
npm run test

# Run with coverage
npm run test:unit -- --coverage

# Lint code
npm run lint

# Run migrations
npm run migrate
```

## Testing Strategy

- **Unit Tests**: Service and utility functions
- **Integration Tests**: API endpoints with mock/test database
- **Test Files**: Match source structure under `tests/`
- **Coverage Target**: 80%+ for services and repositories

## Best Practices

1. **Error Handling**: Always throw or return appropriate error types
2. **Logging**: Log significant operations; avoid logging secrets
3. **Validation**: Validate at the route/service boundary
4. **Database**: Use repositories; never directly query in routes
5. **Async/Await**: Prefer async/await over callbacks
6. **Comments**: Document complex logic; explain "why" not "what"
7. **Testing**: Write tests alongside features
8. **Security**: Verify authentication before sensitive operations
9. **Pagination**: Always implement for list endpoints
10. **Documentation**: Keep README and JSDoc comments current

## Common Tasks

### Adding a New Endpoint
1. Create route in `src/routes/[module].js`
2. Implement service logic in `src/services/[module]Service.js`
3. Create repository method if database query needed
4. Add validation schema in route or `src/utils/validators.js`
5. Write tests in `tests/integration/[module]Api.test.js`
6. Document in API spec (see `docs/api-specs/`)

### Adding a Service Integration
1. Create new file in `src/integrations/[service].js`
2. Implement client initialization and methods
3. Add error handling for service failures
4. Call from appropriate service (e.g., `paymentService.js`)
5. Add environment variables to `.env.example`

### Database Migration
1. Create migration file in `migrations/`
2. Implement `up()` and `down()` functions
3. Run: `npm run migrate`
4. Test both up and down

## Deployment

- Backend hosted on Render
- Environment variables configured in Render dashboard
- GitHub Actions CI/CD (see `.github/workflows/`)
- Database managed by Supabase
- CDN for static assets (if needed)

## Support & Documentation

- API Documentation: See `docs/api-specs/`
- Architecture: See `docs/architecture/Backend-Architecture.md`
- Contributing: See `CONTRIBUTING.md`
