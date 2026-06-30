---
name: vibecoding-security-skill
description: Identify, review, and fix security vulnerabilities in vibecoded full-stack apps built with Next.js, Vercel, and Supabase. Use when auditing or patching projects that use the Next.js App Router, Server Components, Server Actions, Route Handlers, Middleware/Proxy, Vercel deployments/environment variables/protection settings/cron jobs, Supabase Auth, OAuth callbacks, Supabase SSR clients, Row Level Security policies, Realtime, Storage, Edge Functions, or Postgres migrations.
---

# Vibecoding Security Skill

## Purpose

Use this skill to find and fix security issues in Next.js + Vercel + Supabase apps, especially fast-built or AI-generated apps where auth, RLS, environment boundaries, and deployment settings are often incomplete.

## Operating Rules

1. Treat generated app code as untrusted until proven otherwise.
2. Prefer concrete evidence from code, migrations, configuration, and tests over generic advice.
3. Separate findings into: confirmed vulnerability, likely vulnerability, hardening gap, and false positive.
4. Patch the smallest secure boundary that actually closes the issue: database policy, server-only DAL, action validation, deployment setting, or secret rotation.
5. After a fix, verify with a build, test, SQL assertion, or a manual reproduction path. If verification is impossible locally, state the missing dependency and the exact check to run.

## Workflow

### 1. Map the App

Inspect the repository before judging risk:

- Package manager and framework version: `package.json`, lockfile, `next.config.*`.
- Next.js surfaces: `app/**/page.*`, `app/**/layout.*`, `app/**/route.*`, `app/**/actions.*`, `middleware.*` or `proxy.*`, client components, server-only libraries.
- Supabase usage: `createClient`, `createServerClient`, `getSession`, `getUser`, service-role clients, migrations, seed SQL, storage/realtime policies, auth callbacks.
- Vercel usage: `vercel.json`, `next.config.* headers`, environment variable names, source maps, cron routes, deployment protection assumptions.

Use `rg` patterns first:

```bash
rg -n "NEXT_PUBLIC_|SUPABASE|service_role|service-role|createClient|createServerClient|getSession|getUser|use server|middleware|proxy|auth\.uid|auth\.jwt|security definer|enable row level security|create policy|grant .* to anon|grant .* to authenticated|realtime|cron|vercel|headers\(" .
```

### 2. Load Focused References

Read only the reference files needed for the surface under review:

- Next.js data boundaries, Server Actions, Route Handlers, and client/server leakage: [references/nextjs-security.md](references/nextjs-security.md)
- Vercel environment, preview, deployment, and header risks: [references/vercel-security.md](references/vercel-security.md)
- Supabase Auth, RLS, Data API, service keys, Storage, functions, and migrations: [references/supabase-security.md](references/supabase-security.md)
- Checklist-mode audit pass across all surfaces: [references/audit-checklist.md](references/audit-checklist.md)
- Review output format and severity calibration: [references/reporting.md](references/reporting.md)

For a quick first pass, run [scripts/audit.sh](scripts/audit.sh) from the target project root when a POSIX shell is available. Treat output as leads, not proof.

For Supabase feature work, verify current docs or changelog before implementation when APIs or CLI behavior matter.

### 3. Prioritize High-Risk Vibecoding Failures

Check these first:

- Secret exposure: `SUPABASE_SERVICE_ROLE_KEY`, private API keys, JWT secrets, or database URLs in `NEXT_PUBLIC_*`, client components, logs, source maps, or committed `.env*`.
- Missing authorization: Server Actions, Route Handlers, or DAL methods that check login but not object ownership or role.
- Server-side Supabase Auth that uses `getSession()` instead of `getUser()` as the authority for Server Components, Server Actions, Route Handlers, or DAL code.
- Middleware/Proxy auth treated as the only gate instead of a UX pre-check backed by per-action/server authorization.
- OAuth callback routes with unvalidated `next`, `returnTo`, `redirectTo`, weak PKCE handling, or broad redirect URL allowlists.
- RLS gaps: exposed tables without RLS, `TO authenticated` policies without row predicates, update policies without `WITH CHECK`, views/functions bypassing RLS.
- Realtime, Storage, Cron, webhook, upload, invite, OTP, and AI/LLM routes missing explicit auth, signature checks, rate limits, or ownership checks.
- Public Data API drift: new `public` tables/functions created by SQL migrations with broad grants.
- Client trust: `searchParams`, route params, form data, cookies, headers, `user_metadata`, or client-side role flags used as authorization facts.
- Unsafe storage/uploads: public buckets for private files, unvalidated MIME/extension/size, path traversal-style object keys, missing storage RLS.
- Production leakage: browser source maps, verbose errors, unprotected previews containing real data, broad CORS, missing security headers.

### 4. Patch Securely

Prefer these fixes:

- Move secrets and database access into `server-only` DAL modules.
- Make Server Actions thin: validate inputs, re-authenticate, authorize ownership, call DAL, return minimal DTOs.
- Use `supabase.auth.getUser()` for server-side user authority; keep `getSession()` limited to client-side UI/session convenience unless fresh server verification is not required.
- Treat Middleware/Proxy as a soft gate for redirects and session refresh only; repeat authentication and authorization in DAL, Server Actions, and Route Handlers.
- Use Supabase RLS as the primary data boundary for browser-reachable tables.
- Use service-role clients only in server-only code paths, only for admin tasks, and never with user-controlled queries unless authorization was already proven.
- Add explicit grants and RLS policies in migrations; do not rely on dashboard state.
- Add or tighten Vercel/Next.js headers and deployment settings in code where possible, and document dashboard-only settings.

### 5. Verify

Run project-appropriate checks:

- Type/build/test: `npm run build`, `npm test`, `pnpm test`, or the repo's scripts.
- Supabase local checks: `supabase db lint`, `supabase db diff`, `supabase db reset`, `supabase db test`, or SQL assertions if available.
- Manual probes: unauthenticated request, wrong-user request, correct-user request, oversized upload, forbidden storage path.

When a dashboard setting is required, provide a short verification checklist instead of pretending it was changed locally.

## Output Standard

For reviews, lead with findings ordered by severity and include file/line evidence. If the user asks for a report, write it to `security_review.md` or the requested path and then summarize the highest-risk findings in chat. For fixes, summarize changed files, risk closed, and verification run. For unresolved risk, name the exact remaining condition.

Use the severity and report template in [references/reporting.md](references/reporting.md).
