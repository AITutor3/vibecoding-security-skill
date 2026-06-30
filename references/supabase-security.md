# Supabase Security Reference

Use for Supabase Auth, SSR clients, Postgres migrations, RLS policies, Storage, Edge Functions, Data API exposure, and service-role usage.

## Core Rules

- Enable RLS on every table in exposed schemas, including `public` by default.
- Grant only the roles and operations needed. Treat grants and RLS as separate controls.
- Never expose `service_role`, secret keys, database URLs, or admin JWTs to browser code or `NEXT_PUBLIC_*`.
- Do not use `raw_user_meta_data` or `user_metadata` for authorization. Use `app_metadata`, database tables, or RLS-backed membership tables.
- In server code, use `supabase.auth.getUser()` as the user authority. Do not use `getSession()` as proof of authentication in Server Components, Server Actions, Route Handlers, or DAL code.
- Remember JWT claims are not always fresh. Sensitive authorization changes may require token refresh, session revocation, or database-side checks.
- Treat views, functions, triggers, and storage policies as first-class attack surfaces.
- Keep application profile data in app-owned tables such as `public.profiles`; do not expose or join directly against `auth.users` from browser-reachable roles.

## Audit Patterns

Search:

```bash
rg -n "service_role|service-role|SUPABASE_SERVICE|createClient|createServerClient|getSession|getUser|exchangeCodeForSession|auth/callback|redirectTo|auth\.uid|auth\.jwt|raw_user_meta_data|user_metadata|app_metadata|auth\.users|enable row level security|disable row level security|create policy|alter policy|grant .* to anon|grant .* to authenticated|security definer|security_invoker|storage\.objects|bucket|postgres_changes|broadcast|presence|realtime|webhook|x-supabase-signature" .
```

Inspect migrations and SQL for:

- Tables in exposed schemas without `alter table ... enable row level security`.
- `grant all` or broad `grant select, insert, update, delete` to `anon` or `authenticated`.
- Policies with `to authenticated` but no ownership, tenant, membership, or role predicate.
- Update policies missing `with check`.
- Update operations that lack a matching select policy.
- `auth.role() = 'authenticated'` patterns, especially with anonymous sign-ins.
- Views without `security_invoker = true` on Postgres 15+.
- `security definer` functions in `public` or functions with default `EXECUTE` grants.
- Storage buckets or object policies that allow cross-user path access.
- Direct `auth.users` reads in app queries, views, or policies exposed to `anon` or `authenticated`.

## Auth Helpers In Next.js

Server-side code must not trust a locally read session as the final identity check.

Unsafe:

```ts
const {
  data: { session },
} = await supabase.auth.getSession()

if (!session) throw new Error('Unauthorized')
```

Safer:

```ts
const {
  data: { user },
  error,
} = await supabase.auth.getUser()

if (error || !user) throw new Error('Unauthorized')
```

Use `getUser()` in Server Components, Server Actions, Route Handlers, DAL modules, webhook-created user flows, and any service-role-adjacent path. `getUser()` validates the token with Supabase Auth before returning the user.

Use `getSession()` only for client-side UI convenience or non-authoritative session display, such as showing a logged-in shell before a server-verified request runs. Never use it to decide database access, ownership, role, billing, invites, admin state, or file access on the server.

## OAuth Callback And Redirect Safety

Audit every `app/auth/callback/route.ts`, `app/api/auth/callback/route.ts`, or equivalent route.

Required:

- Exchange the PKCE code with `exchangeCodeForSession(code)` before treating the request as logged in.
- Validate `next`, `returnTo`, `redirect`, and `redirectTo` before redirecting.
- Prefer same-origin relative paths. Reject protocol-relative URLs such as `//evil.example`.
- Keep Supabase Auth redirect URLs narrow and environment-specific in the dashboard.
- If using state, bind it to the original auth request and reject mismatches before redirecting.

Safe redirect helper:

```ts
function safeRelativePath(value: string | null) {
  if (!value) return '/'
  if (!value.startsWith('/') || value.startsWith('//')) return '/'
  return value
}
```

Callback sketch:

```ts
export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get('code')
  const next = safeRelativePath(url.searchParams.get('next'))

  if (!code) return NextResponse.redirect(new URL('/login', url.origin))

  const supabase = await createServerSupabase()
  const { error } = await supabase.auth.exchangeCodeForSession(code)
  if (error) return NextResponse.redirect(new URL('/login', url.origin))

  return NextResponse.redirect(new URL(next, url.origin))
}
```

## RLS Policy Patterns

Good owner policy:

```sql
alter table public.projects enable row level security;

create policy "projects_select_own"
on public.projects
for select
to authenticated
using ((select auth.uid()) = owner_id);

create policy "projects_update_own"
on public.projects
for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create index if not exists projects_owner_id_idx on public.projects(owner_id);
```

Good tenant membership policy:

```sql
create policy "bugs_select_team_members"
on public.bugs
for select
to authenticated
using (
  exists (
    select 1
    from public.project_members pm
    where pm.project_id = bugs.project_id
      and pm.user_id = (select auth.uid())
  )
);
```

For performance, index columns used in RLS predicates. Wrap stable JWT helper calls as `(select auth.uid())` or `(select auth.jwt())` when the result does not depend on the row.

## Profiles And `auth.users`

Do not expose `auth.users` to `anon` or `authenticated`, and do not create API-facing views that join it into browser-readable results. Keep public or app-visible user fields in an app table:

```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text
);

alter table public.profiles enable row level security;

create policy "profiles_read_authenticated"
on public.profiles
for select
to authenticated
using (true);

create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);
```

Only copy fields that are intended for the app. Never mirror provider tokens, email verification internals, identities JSON, MFA factors, or private metadata.

## Service Role Rules

Allowed:

- Server-only admin workflows, migrations, background jobs, webhooks after signature verification, and internal maintenance.

Forbidden:

- Browser bundles, Client Components, `NEXT_PUBLIC_*`, local storage, API responses, logs, source maps, or any function callable without server-side authorization.

When service-role code handles user-triggered work:

1. Authenticate the user from trusted server-side session data.
2. Authorize the specific resource or tenant before the privileged query.
3. Validate user input before it reaches SQL, storage paths, or admin APIs.
4. Return a minimal DTO.

## Data API And Grants

- A table is reachable through the Data API only when roles have privileges, but existing projects may have broad default grants.
- Revoke default privileges for new public objects when the app should be opt-in.
- Prefer a dedicated exposed `api` schema when `public` contains internal tables or helper functions.
- If the app never uses REST/GraphQL generated endpoints, consider disabling the Data API.

## Views And Functions

- On Postgres 15+, create API-facing views with `with (security_invoker = true)`.
- On older Postgres versions, revoke access from `anon` and `authenticated`, or place views in an unexposed schema.
- Avoid `security definer` unless there is a clear reason to bypass RLS.
- If `security definer` is necessary, place the function in a private schema, set `search_path`, check `auth.uid()` inside the function, and revoke `execute` from `public`, `anon`, and roles that should not call it.

## Storage

Check:

- Private user files are not in public buckets.
- Object paths include a tenant/user prefix and policies enforce it.
- Upload routes validate size, MIME type, extension, and image processing assumptions.
- Upsert behavior has the required select/update/insert policy coverage.

Example path ownership policy:

```sql
create policy "users_manage_own_folder"
on storage.objects
for all
to authenticated
using (
  bucket_id = 'screenshots'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'screenshots'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
```

## Realtime

Realtime has multiple surfaces with different authorization behavior.

- For `postgres_changes`, make sure the underlying table has RLS enabled and policies tested with the subscribing role.
- Do not assume channel `broadcast` and `presence` events inherit table RLS. Authorize channel access with Realtime authorization policies or route broadcasts through server-side checks.
- Do not put sensitive data in presence payloads: email, IP address, exact location, provider IDs, access tokens, session IDs, or private metadata.
- Treat Realtime admin/service roles as privileged and keep them server-only.

Audit:

```bash
rg -n "postgres_changes|broadcast|presence|realtime\\.messages|channel\\(" app src supabase
```

Verification:

- Subscribe as user A to user B's project/channel and confirm no events arrive.
- Try broadcast/presence on a forbidden channel and confirm rejection.
- Inspect payloads for private profile fields.

## Database Webhooks

Supabase Database Webhooks can call a Next.js Route Handler when rows change. Treat the receiver as an internet-facing webhook:

- Verify the Supabase signature header or shared secret before trusting the body.
- Read the raw body for signature verification when the verification scheme requires it.
- Reject unexpected methods and content types.
- Make webhook handlers idempotent.
- Do not run service-role mutations from webhook input until the signature is verified.

Sketch:

```ts
export async function POST(request: Request) {
  const signature = request.headers.get('x-supabase-signature')
  const body = await request.text()

  if (!verifySupabaseWebhook(body, signature, process.env.SUPABASE_WEBHOOK_SECRET)) {
    return new Response('Unauthorized', { status: 401 })
  }

  const event = JSON.parse(body)
  // process verified event
}
```

## Verification

- Run Supabase advisors or lint when available.
- Test three identities: unauthenticated, wrong authenticated user, correct authenticated user.
- For migrations, verify both grants and RLS policies.
- For storage, test forbidden object paths and replacement uploads.
- For auth helpers, test that server code rejects a forged/stale local session and uses `getUser()`.
- For OAuth callbacks, test `?next=https://evil.example`, `?next=//evil.example`, and a valid relative path.
- For Realtime, test wrong-user subscription/broadcast/presence attempts.

## Sources To Recheck

- https://github.com/supabase/agent-skills
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/api/securing-your-api
- https://supabase.com/docs/guides/security/product-security
- https://supabase.com/docs/guides/security/npm-security
- https://supabase.com/docs/reference/javascript/auth-getuser
- https://supabase.com/docs/guides/auth/server-side/nextjs
- https://supabase.com/docs/guides/auth/redirect-urls
- https://supabase.com/docs/guides/realtime/authorization
- https://supabase.com/docs/guides/database/webhooks
