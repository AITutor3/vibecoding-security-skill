# Supabase Security Reference

Use for Supabase Auth, SSR clients, Postgres migrations, RLS policies, Storage, Edge Functions, Data API exposure, and service-role usage.

## Core Rules

- Enable RLS on every table in exposed schemas, including `public` by default.
- Grant only the roles and operations needed. Treat grants and RLS as separate controls.
- Never expose `service_role`, secret keys, database URLs, or admin JWTs to browser code or `NEXT_PUBLIC_*`.
- Do not use `raw_user_meta_data` or `user_metadata` for authorization. Use `app_metadata`, database tables, or RLS-backed membership tables.
- Remember JWT claims are not always fresh. Sensitive authorization changes may require token refresh, session revocation, or database-side checks.
- Treat views, functions, triggers, and storage policies as first-class attack surfaces.

## Audit Patterns

Search:

```bash
rg -n "service_role|service-role|SUPABASE_SERVICE|createClient|createServerClient|auth\.uid|auth\.jwt|raw_user_meta_data|user_metadata|app_metadata|enable row level security|disable row level security|create policy|alter policy|grant .* to anon|grant .* to authenticated|security definer|security_invoker|storage\.objects|bucket" .
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

## Verification

- Run Supabase advisors or lint when available.
- Test three identities: unauthenticated, wrong authenticated user, correct authenticated user.
- For migrations, verify both grants and RLS policies.
- For storage, test forbidden object paths and replacement uploads.

## Sources To Recheck

- https://github.com/supabase/agent-skills
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/api/securing-your-api
- https://supabase.com/docs/guides/security/product-security
- https://supabase.com/docs/guides/security/npm-security
