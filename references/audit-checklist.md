# Audit Checklist

Use this checklist for active reviews. Mark each item as pass, finding, not applicable, or needs runtime/dashboard verification.

## Identity And Authorization

- Server Components, Server Actions, Route Handlers, and DAL code use `supabase.auth.getUser()` or equivalent server-verified auth, not `getSession()` as the authority.
- Middleware/Proxy is used only as a soft gate for redirects/session refresh; protected actions and routes re-check auth and resource ownership.
- Every mutation checks both authentication and object/tenant/team authorization.
- Client-side role flags, local storage, `searchParams`, route params, cookies, and `user_metadata` are not trusted for authorization.
- Admin/service-role paths are server-only, least-privileged, and gated by explicit authorization.

## Supabase Auth And OAuth

- `/auth/callback` exchanges code through the expected PKCE flow and handles errors safely.
- `next`, `returnTo`, `redirect`, and `redirectTo` values allow only same-origin relative paths or a strict origin allowlist.
- Supabase dashboard redirect URLs are narrow and environment-specific.
- `VERCEL_URL` is not used as the canonical auth redirect origin.
- Sensitive account changes consider stale JWT claims, session revocation, or token refresh.

## Supabase Database And RLS

- Every exposed table has RLS enabled.
- Policies combine `to authenticated` with row-level ownership, membership, tenant, or role predicates.
- UPDATE policies include both `using` and `with check`.
- Columns used by RLS predicates are indexed.
- Views use `security_invoker = true` on Postgres 15+ or are hidden from public roles.
- `security definer` functions are private-schema, search-path-pinned, identity-checking, and execution-revoked by default.
- App tables do not expose `auth.users` directly; public profile data lives in an application-owned table such as `public.profiles`.

## Supabase Realtime, Storage, And Webhooks

- Realtime `postgres_changes` subscriptions rely on RLS-protected tables and are tested with wrong-user subscriptions.
- Broadcast and presence channels do not assume table RLS; authorization uses Realtime authorization policies or server-side checks.
- Presence payloads do not expose email, IP address, access tokens, provider IDs, or other sensitive profile data.
- Private files are in private buckets with object path policies tied to user/tenant ownership.
- Uploads validate size, MIME/content, extension, and object key format.
- Supabase Database Webhook receivers verify the signature header before trusting the body.

## Next.js Runtime Surfaces

- Server Actions validate runtime input, re-authenticate, authorize, and return minimal DTOs.
- Route Handlers validate methods, content type, body, params, query strings, origin/CORS, and auth.
- User-specific data is not stored in static/shared cache entries.
- `unstable_cache`, `use cache`, tags, and revalidation include user/tenant-specific keys for private data.
- Redirect targets are validated against same-origin relative paths or strict allowlists.
- File paths and outbound fetch URLs cannot be controlled by attackers without allowlists.

## Vercel And Deployment

- Secrets are not in `NEXT_PUBLIC_*`, client bundles, source maps, logs, or committed `.env*`.
- Preview deployments that touch real data are protected.
- Production browser source maps are disabled or protected.
- Cron routes verify `Authorization: Bearer ${CRON_SECRET}`.
- Auth, OTP, invite, file upload, webhook, and AI/LLM routes have rate limiting or Vercel Firewall rules.
- Security headers are set and tested with Supabase Auth, Storage, Realtime, Edge Functions, analytics, and uploads.

## Evidence

- For every finding, capture file/line evidence and the exploit class.
- For every fix, capture the verification command, SQL assertion, or manual probe.
