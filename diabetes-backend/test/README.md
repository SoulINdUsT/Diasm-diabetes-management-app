Backend session tests use Node's built-in test runner. No dependencies were added.

Run from `diabetes-backend`:

```text
npm test
npm run test:auth:mysql
```

The unit suite does not connect to a database. The MySQL suite is explicitly local:
it connects to `127.0.0.1:3306`, creates a randomly named
`diasm_auth_test_<24 hex digits>` database, loads the inspected schema fixture,
inserts only synthetic users, and drops that exact database during cleanup.
It never selects or copies data from the application database. The local user
needs CREATE/DROP DATABASE, table, and TRIGGER privileges.

Both suites bypass the workspace `.env`, disable email, generate ephemeral JWT
signing keys, and override the normal database host/name. Optional
`DIASM_TEST_DB_USER` and `DIASM_TEST_DB_PASSWORD` variables supply local test
credentials. Otherwise, the existing local defaults in `src/config/db.js` apply.
Deployment `DB_USER`/`DB_PASS` values are not inherited. Do not point a tunnel on
the local MySQL port at production.

`fixtures/auth-schema.sql` reflects the actual local MySQL schema inspected for
this change: InnoDB tables, a unique refresh-token hash index, a sessions-to-users
foreign key, DATETIME expiries, and active/blocked account status. This fixture
is for the disposable database only, not an application migration. Production
schema and deployment configuration were not inspected or changed.

The integration suite exercises real transactions and locking, HTTP controllers,
exact JWT-derived database expiry, rejection and account eligibility, rollback
after a trigger rejects replacement insertion, repeated single-session logout,
and the committed-response-loss limitation. The concurrency test synchronizes
two actual database transactions at their locking reads. Unit tests cover token
validation, unavailable connections, and transaction cleanup failures.

The refresh/logout error contract is `{ code, message }`:

| HTTP | Code | Meaning |
| --- | --- | --- |
| 400 | REFRESH_TOKEN_REQUIRED | Missing, empty, or non-string credential |
| 401 | REFRESH_TOKEN_INVALID | Invalid JWT or required refresh claims |
| 401 | REFRESH_TOKEN_EXPIRED | Expired refresh JWT |
| 401 | REFRESH_SESSION_INVALID | Missing, revoked, expired, or mismatched session |
| 403 | ACCOUNT_INACTIVE | Refresh refused for an inactive account |
| 403 | EMAIL_VERIFICATION_REQUIRED | Refresh requires email verification |
| 503 | AUTH_SERVICE_UNAVAILABLE | Database, signing, or unexpected service failure; no internal details returned |

`POST /api/v1/auth/logout` accepts `{ refreshToken }` and returns 204 for both an
initial revocation and a repeated request with the same still-valid refresh JWT.
It needs no access JWT. Extra `all`/`userId` fields cannot revoke other sessions.
Malformed or expired refresh JWTs are rejected. Logout revokes refresh capability;
already issued access JWTs remain valid until expiry under the existing middleware.

Transactions make revocation plus replacement atomic; they do not make response
delivery atomic. If rotation commits but its response is lost, the old refresh
token is revoked and retrying it returns 401/REFRESH_SESSION_INVALID. The new
session exists, but a client that never received its token cannot recover it and
must log in again when it needs to refresh. The previous access JWT can remain
usable until expiry. A lost COMMIT acknowledgment can also leave an ambiguous
outcome despite a 503. No replay grace period or idempotency recovery is implemented.
The test discards a committed result to exercise this state; it does not simulate
a physical network interruption.
