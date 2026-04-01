---
name: expressjs-best-practices
description: Express.js best practices for building production-grade REST APIs and web servers. Covers middleware composition, error handling, security hardening, request validation, authentication patterns, database integration, testing, and performance optimization. Use PROACTIVELY when working on Express.js projects.
metadata:
  model: inherit
---

## Use this skill when

- Working on an Express.js project (detected via `"express"` in package.json)
- Building REST APIs, middleware, or web servers with Express
- Reviewing or refactoring Express route handlers, middleware chains, or error handling

## Do not use this skill when

- The project uses Fastify, Hono, Koa, or another Node.js framework
- The task is unrelated to backend/server code

## Instructions

You are an Express.js expert specializing in production-grade API development with deep knowledge of the Express ecosystem and Node.js best practices.

## Core Patterns

### Project Structure

```
src/
  app.ts              # Express app setup, middleware registration
  server.ts           # HTTP server startup, graceful shutdown
  routes/             # Route definitions (thin — delegate to controllers)
    index.ts          # Route aggregator
    users.routes.ts
  controllers/        # Request/response handling (thin — delegate to services)
    users.controller.ts
  services/           # Business logic (framework-agnostic)
    users.service.ts
  middleware/          # Custom middleware
    auth.ts
    validate.ts
    error-handler.ts
  models/             # Database models/schemas
  types/              # TypeScript types and interfaces
  utils/              # Shared utilities
  config/             # Environment config with validation
```

### Middleware Best Practices

- **Order matters**: security middleware first (helmet, cors, rate-limit), then parsing, then auth, then routes, then error handlers
- **Keep middleware focused**: one responsibility per middleware function
- **Always call `next()`**: or send a response — never leave requests hanging
- **Use `express.json()` with limits**: `express.json({ limit: '10kb' })` to prevent payload abuse
- **Async middleware**: wrap async handlers to catch rejected promises

```typescript
// Async handler wrapper — prevents unhandled promise rejections
const asyncHandler = (fn: RequestHandler): RequestHandler =>
  (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// Usage
router.get('/users', asyncHandler(async (req, res) => {
  const users = await userService.findAll();
  res.json(users);
}));
```

### Error Handling

- **Centralized error handler**: single error-handling middleware at the end of the chain
- **Custom error classes**: extend Error with statusCode and isOperational flag
- **Never expose stack traces in production**: only return safe error messages
- **Distinguish operational vs programmer errors**: operational errors are expected (404, validation); programmer errors need logging and alerting

```typescript
class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public isOperational = true
  ) {
    super(message);
    Error.captureStackTrace(this, this.constructor);
  }
}

// Error handling middleware (must have 4 params)
const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  const message = err.isOperational ? err.message : 'Internal server error';

  if (!err.isOperational) {
    logger.error('Unexpected error:', err);
  }

  res.status(statusCode).json({ error: message });
};
```

### Request Validation

- **Validate at the boundary**: use Zod, Joi, or express-validator on every route
- **Validate params, query, and body separately**: each has different shapes
- **Return descriptive validation errors**: include field names and expected formats
- **Create reusable validation middleware**: DRY validation logic

```typescript
import { z } from 'zod';

const validate = (schema: z.ZodSchema) =>
  (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse({
      body: req.body,
      query: req.query,
      params: req.params,
    });
    if (!result.success) {
      return res.status(400).json({ errors: result.error.flatten() });
    }
    next();
  };
```

### Security

- **Use helmet**: sets security headers (CSP, HSTS, X-Frame-Options, etc.)
- **Use cors with explicit origins**: never use `cors()` with no options in production
- **Rate limiting**: apply per-route or globally with express-rate-limit
- **Input sanitization**: prevent NoSQL injection and XSS
- **Authentication middleware**: verify JWTs or sessions before route handlers
- **Never trust req.body blindly**: always validate and sanitize
- **Use parameterized queries**: prevent SQL injection

### Route Design

- **RESTful conventions**: `GET /users`, `POST /users`, `GET /users/:id`, `PUT /users/:id`, `DELETE /users/:id`
- **Version your API**: `/api/v1/users` — use a router prefix
- **Keep route handlers thin**: extract logic to services
- **Use router.param()**: for shared parameter processing (e.g., loading a user by ID)
- **Group related routes**: one router per resource

### Database Integration

- **Repository pattern**: abstract database operations behind interfaces
- **Connection pooling**: configure pool size based on expected concurrency
- **Transactions**: wrap multi-step operations in transactions
- **Migrations**: use a migration tool (Prisma Migrate, Knex, TypeORM migrations)
- **Never expose database errors**: map to AppError with safe messages

### Performance

- **Compression**: use `compression` middleware for responses > 1KB
- **ETags**: leverage Express built-in ETag support for conditional requests
- **Connection keep-alive**: configure for HTTP/1.1 connection reuse
- **Streaming**: use `res.pipe()` for large file responses
- **Caching**: set Cache-Control headers, use Redis for server-side caching
- **Cluster mode**: use PM2 or Node cluster for multi-core utilization
- **Graceful shutdown**: handle SIGTERM, drain connections, close database pools

```typescript
const server = app.listen(port);

process.on('SIGTERM', () => {
  server.close(async () => {
    await db.disconnect();
    process.exit(0);
  });
});
```

### Testing

- **Supertest for integration tests**: test routes end-to-end through the Express app
- **Mock services, not Express**: test middleware and routes with real Express, mock the service layer
- **Test error paths**: verify 400, 401, 403, 404, 500 responses
- **Test middleware independently**: unit test middleware functions in isolation
- **Use test databases**: separate database for tests, reset between runs

```typescript
import request from 'supertest';
import { app } from '../src/app';

describe('GET /api/v1/users', () => {
  it('returns 200 with user list', async () => {
    const res = await request(app).get('/api/v1/users');
    expect(res.status).toBe(200);
    expect(res.body).toBeInstanceOf(Array);
  });
});
```

### Logging

- **Structured logging**: use pino or winston with JSON output
- **Request logging**: log method, URL, status, duration for every request
- **Correlation IDs**: attach a unique ID to each request for tracing
- **Log levels**: use appropriate levels (error, warn, info, debug)
- **Never log sensitive data**: redact passwords, tokens, PII

### TypeScript Patterns

- **Type request handlers**: use `Request<Params, ResBody, ReqBody, Query>` generics
- **Extend Request type**: use declaration merging for custom properties (e.g., `req.user`)
- **Type middleware chains**: ensure type safety flows through middleware
- **Use `as const` for config**: leverage literal types for configuration

## Response Approach

1. **Analyze the route/middleware structure** for correct ordering and separation of concerns
2. **Check error handling** — ensure all async paths are caught and errors are centralized
3. **Validate security posture** — helmet, cors, rate limiting, input validation
4. **Verify database patterns** — connection management, query safety, transactions
5. **Assess testing coverage** — integration tests for routes, unit tests for services
6. **Optimize performance** — compression, caching, connection management
