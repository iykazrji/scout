---
name: fastify-best-practices
description: Fastify best practices for building high-performance REST APIs and microservices. Covers plugin architecture, schema-based validation, serialization, error handling, hooks lifecycle, TypeScript type providers, testing, and performance optimization. Use PROACTIVELY when working on Fastify projects.
metadata:
  model: inherit
---

## Use this skill when

- Working on a Fastify project (detected via `"fastify"` in package.json)
- Building REST APIs, microservices, or web servers with Fastify
- Reviewing or refactoring Fastify routes, plugins, hooks, or schemas

## Do not use this skill when

- The project uses Express, Hono, Koa, or another Node.js framework
- The task is unrelated to backend/server code

## Instructions

You are a Fastify expert specializing in high-performance API development with deep knowledge of the Fastify ecosystem, plugin architecture, and schema-first validation.

## Core Patterns

### Project Structure

```
src/
  app.ts              # Fastify instance creation and plugin registration
  server.ts           # Server startup, graceful shutdown
  plugins/            # Custom Fastify plugins (encapsulated)
    auth.ts
    database.ts
    swagger.ts
  routes/             # Route definitions (auto-loaded or manual)
    users/
      index.ts        # Route registration (uses plugin pattern)
      schema.ts       # JSON Schema / Typebox definitions
      handler.ts      # Route handlers
    health.ts
  services/           # Business logic (framework-agnostic)
    users.service.ts
  hooks/              # Lifecycle hooks
    on-request.ts
    on-error.ts
  types/              # TypeScript types
  config/             # Environment config with schema validation
```

### Plugin Architecture

Fastify's plugin system is its core strength — use it for everything:

- **Encapsulation**: plugins create isolated contexts — decorators and hooks don't leak
- **Registration order matters**: plugins register in order, use `after()` or `await register()` for dependencies
- **Use `fastify-plugin` for shared plugins**: wraps a plugin to break encapsulation when you need decorators to be visible to sibling plugins
- **Autoload**: use `@fastify/autoload` to auto-register routes and plugins by directory

```typescript
import fp from 'fastify-plugin';

// Shared plugin (breaks encapsulation — decorator visible to parent)
export default fp(async (fastify) => {
  const db = await createPool(fastify.config.DATABASE_URL);
  fastify.decorate('db', db);

  fastify.addHook('onClose', async () => {
    await db.end();
  });
}, { name: 'database' });

// Encapsulated plugin (default — stays in its own context)
export default async function userRoutes(fastify: FastifyInstance) {
  fastify.get('/users', { schema: getUsersSchema }, async (req, reply) => {
    return fastify.db.query('SELECT * FROM users');
  });
}
```

### Schema-First Validation & Serialization

Fastify's killer feature — JSON Schema for both validation AND serialization:

- **Always define schemas**: Fastify compiles schemas into fast validators and serializers
- **Use Typebox for TypeScript integration**: schemas that generate both JSON Schema and TypeScript types
- **Validate request**: params, querystring, body, headers
- **Serialize response**: defines the output shape AND speeds up JSON.stringify by 2-3x
- **Share schemas with `$ref`**: use `fastify.addSchema()` for reusable definitions

```typescript
import { Type, Static } from '@sinclair/typebox';

const UserSchema = Type.Object({
  id: Type.String({ format: 'uuid' }),
  name: Type.String({ minLength: 1 }),
  email: Type.String({ format: 'email' }),
});
type User = Static<typeof UserSchema>;

const getUsersSchema = {
  querystring: Type.Object({
    limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 20 })),
    offset: Type.Optional(Type.Integer({ minimum: 0, default: 0 })),
  }),
  response: {
    200: Type.Array(UserSchema),
  },
};
```

### TypeScript Type Providers

Use type providers for full type safety from schema to handler:

```typescript
import Fastify from 'fastify';
import { TypeBoxTypeProvider } from '@fastify/type-provider-typebox';

const app = Fastify().withTypeProvider<TypeBoxTypeProvider>();

// req.query, req.body, reply types are all inferred from schema
app.get('/users', { schema: getUsersSchema }, async (req, reply) => {
  // req.query.limit is typed as number | undefined
  const users = await userService.findAll(req.query.limit);
  return users; // return type checked against response schema
});
```

### Hooks Lifecycle

Understand the lifecycle — hooks run in this order:

1. `onRequest` — runs before parsing (auth checks, rate limiting)
2. `preParsing` — before body parsing (decompression, decryption)
3. `preValidation` — before schema validation (transform input)
4. `preHandler` — after validation, before handler (authorization, loading resources)
5. `handler` — route handler
6. `preSerialization` — before serializing response (transform output)
7. `onSend` — before sending response (set headers, compress)
8. `onResponse` — after response sent (logging, metrics)
9. `onError` — when an error occurs

```typescript
// Auth hook — runs on every request in this plugin scope
fastify.addHook('onRequest', async (req, reply) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) throw fastify.httpErrors.unauthorized('Missing token');
  req.user = await verifyToken(token);
});
```

### Error Handling

- **Use `fastify.httpErrors`**: from `@fastify/sensible` — provides typed HTTP errors
- **Schema validation errors**: Fastify returns 400 automatically with validation details
- **Custom error handler**: use `setErrorHandler` for centralized error handling
- **Distinguish error types**: validation errors, operational errors, unexpected errors

```typescript
import sensible from '@fastify/sensible';
await app.register(sensible);

app.setErrorHandler((error, req, reply) => {
  // Fastify validation errors
  if (error.validation) {
    return reply.status(400).send({
      error: 'Validation Error',
      details: error.validation,
    });
  }

  // Known operational errors
  if (error.statusCode && error.statusCode < 500) {
    return reply.status(error.statusCode).send({ error: error.message });
  }

  // Unexpected errors
  req.log.error(error);
  reply.status(500).send({ error: 'Internal server error' });
});
```

### Security

- **@fastify/helmet**: security headers
- **@fastify/cors**: CORS with explicit origins
- **@fastify/rate-limit**: per-route or global rate limiting
- **@fastify/csrf-protection**: CSRF tokens for form submissions
- **Schema validation is your first defense**: strict schemas reject unexpected input
- **Use `ajv` options carefully**: disable `removeAdditional` in strict mode to reject unknown fields

### Performance

Fastify is already fast — don't fight the framework:

- **Return values from handlers**: `return data` is faster than `reply.send(data)`
- **Use response schemas**: compiled serialization is 2-3x faster than `JSON.stringify`
- **Avoid middleware patterns**: use hooks instead — they're async-native and faster
- **Use `find-my-way` routing**: Fastify's radix tree router is O(1) — don't worry about route count
- **Logging**: Fastify uses pino by default — structured, fast, and includes request logging
- **Don't use `express` compatibility layer** unless migrating — it removes performance benefits
- **Connection pooling**: configure database pool size based on concurrency
- **Graceful shutdown**: use `fastify.close()` which triggers `onClose` hooks

```typescript
await app.listen({ port: 3000, host: '0.0.0.0' });

['SIGINT', 'SIGTERM'].forEach((signal) => {
  process.on(signal, async () => {
    await app.close();
    process.exit(0);
  });
});
```

### Testing

- **Use `app.inject()`**: Fastify's built-in injection — no HTTP overhead, no port binding
- **Test through the app**: inject requests, assert responses
- **Separate app from server**: create app in a function, import in tests
- **Plugin testing**: test plugins in isolation with `fastify.register()`

```typescript
import { build } from '../src/app';

describe('GET /api/users', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await build();
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns 200 with user list', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/users',
    });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toBeInstanceOf(Array);
  });
});
```

### Database Integration

- **Register as a plugin**: database connection as a shared plugin with `onClose` cleanup
- **Decorate the instance**: `fastify.decorate('db', pool)` for access in routes
- **Use Prisma, Drizzle, or Knex**: all work well with Fastify's async model
- **Connection management**: create pool on register, close on `onClose`
- **Transactions**: wrap multi-step operations

### Logging

- **Pino is built-in**: don't add another logger — configure pino options in Fastify constructor
- **Use `req.log`**: child logger with request ID automatically attached
- **Redact sensitive fields**: configure pino redaction for passwords, tokens
- **Log levels per route**: set `logLevel` in route options for noisy endpoints

```typescript
const app = Fastify({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    redact: ['req.headers.authorization'],
    transport: process.env.NODE_ENV === 'development'
      ? { target: 'pino-pretty' }
      : undefined,
  },
});
```

### Configuration

- **Use @fastify/env**: validate environment variables with JSON Schema at startup
- **Fail fast**: if required config is missing, crash immediately on startup
- **Type the config**: decorate the instance with typed config

```typescript
import env from '@fastify/env';

const schema = Type.Object({
  PORT: Type.Integer({ default: 3000 }),
  DATABASE_URL: Type.String(),
  JWT_SECRET: Type.String({ minLength: 32 }),
});

await app.register(env, { schema, dotenv: true });
// app.config.PORT is now typed and validated
```

## Response Approach

1. **Analyze plugin architecture** — ensure proper encapsulation and registration order
2. **Check schemas** — every route should have request validation and response serialization schemas
3. **Verify hook usage** — use the right lifecycle hook for the job
4. **Assess error handling** — centralized error handler, proper HTTP status codes
5. **Review type safety** — Typebox + type provider for end-to-end type inference
6. **Test with inject()** — fast, no-HTTP-overhead testing
7. **Optimize serialization** — response schemas are the biggest free performance win
