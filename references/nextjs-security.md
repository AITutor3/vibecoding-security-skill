# Next.js Security Reference

Use for App Router, Server Components, Server Actions, Route Handlers, middleware/proxy, and client/server data flow.

## Core Model

- Treat Server Components as able to access private data, but do not pass broad objects into Client Components.
- Use a dedicated Data Access Layer (DAL) for new projects. The DAL should be server-only, perform authorization, and return minimal DTOs.
- Import `server-only` in DAL modules and any module that touches secrets, privileged SDK clients, direct database clients, or internal APIs.
- Keep `process.env` access inside server-only modules. Any `NEXT_PUBLIC_*` variable is intentionally exposed to browser code.
- Use React taint APIs when enabled to prevent accidental transfer of sensitive objects or values to the client.

## Audit Patterns

Search:

```bash
rg -n "'use client'|\"use client\"|'use server'|\"use server\"|process\.env|NEXT_PUBLIC_|cookies\(|headers\(|searchParams|params|redirect\(|notFound\(|createClient|service_role|server-only" app lib src
```

High-risk signs:

- `process.env.SUPABASE_SERVICE_ROLE_KEY`, private API keys, or database URLs imported outside server-only modules.
- Client components accepting `user`, `profile`, `account`, `organization`, `membership`, or ORM entity objects with more fields than needed.
- Page-level auth checks assumed to protect Server Actions or Route Handlers.
- Server Actions that mutate data without re-authenticating and authorizing the specific resource.
- Route Handlers that trust request JSON, query strings, route params, cookies, headers, or webhook payloads without validation.
- Use of `searchParams.isAdmin`, role flags in local storage, or values from `user_metadata` for authorization.
- Cache directives around user-specific data without per-user keys or private/no-store behavior.
- Redirects using unvalidated `next`, `returnTo`, or URL params.
- Middleware or Proxy that redirects unauthenticated users but is treated as the only protection for Server Actions, Route Handlers, or DAL functions.
- `unstable_cache`, `use cache`, `revalidate`, or `force-static` around private data without a user/tenant-specific key.

## Fix Patterns

Use a server-only DAL:

```ts
// src/data/projects.ts
import 'server-only'

import { z } from 'zod'
import { getCurrentUser } from '@/auth/session'
import { createServerSupabase } from '@/lib/supabase/server'

const ProjectId = z.string().uuid()

export async function getProjectDTO(projectIdInput: unknown) {
  const projectId = ProjectId.parse(projectIdInput)
  const user = await getCurrentUser()
  if (!user) throw new Error('Unauthorized')

  const supabase = await createServerSupabase()
  const { data, error } = await supabase
    .from('projects')
    .select('id,name,owner_id')
    .eq('id', projectId)
    .eq('owner_id', user.id)
    .single()

  if (error) throw error
  return { id: data.id, name: data.name }
}
```

Keep Server Actions thin:

```ts
// app/projects/actions.ts
'use server'

import 'server-only'
import { z } from 'zod'
import { updateProjectName } from '@/data/projects'

const Input = z.object({
  projectId: z.string().uuid(),
  name: z.string().trim().min(1).max(120),
})

export async function renameProjectAction(formData: FormData) {
  const input = Input.parse(Object.fromEntries(formData))
  await updateProjectName(input)
  return { ok: true }
}
```

Route Handler rules:

- Validate method, content type, body shape, route params, and query strings.
- Rebuild auth from server-side cookies or a verified token; never trust client-supplied user IDs.
- For webhooks, verify signature before parsing as trusted business data.
- For CORS, allow explicit origins only when browser cross-origin access is actually required.

Middleware/Proxy rules:

- Treat Middleware/Proxy as a soft gate for UX redirects, coarse route gating, and Supabase session refresh.
- Do not treat Middleware/Proxy as authorization. Edge checks can miss Server Actions, Route Handlers, alternate routes, direct fetches, or future route additions.
- Repeat authentication and resource authorization in the DAL, Server Action, and Route Handler.
- If Middleware uses `matcher`, compare it against every protected route and API route. Add tests for protected routes without cookies.

Safe pattern:

```ts
// middleware.ts can redirect early, but it does not replace server-side authz.
export async function middleware(request: NextRequest) {
  const user = await readUserForRedirectOnly(request)
  if (!user && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

// app/projects/actions.ts still re-checks identity and ownership.
'use server'

export async function updateProjectAction(formData: FormData) {
  const user = await requireVerifiedUser()
  await assertProjectMember(user.id, formData.get('projectId'))
  // mutate after authz
}
```

Caching rules:

- Avoid caching personalized data unless the cache key is tied to the authenticated user and cannot be shared.
- Do not put secret-dependent or user-dependent data in static generation paths.
- After mutations, revalidate only paths/tags the current user is authorized to affect.
- For `unstable_cache` or `use cache`, include the user ID, organization ID, tenant ID, or other authorization boundary in the cache key/tags when the result is private.

Unsafe:

```ts
const getDashboard = unstable_cache(async () => {
  return loadDashboardForCurrentUser()
})
```

Safer:

```ts
const getDashboard = (userId: string) =>
  unstable_cache(
    async () => loadDashboardForUser(userId),
    ['dashboard', userId],
    { tags: [`user-${userId}`] },
  )()
```

Rate limiting rules:

- Add rate limits to login, signup, OTP/magic-link send, password reset, invite, upload, webhook, expensive report generation, and AI/LLM routes.
- In Vercel/serverless environments, prefer an external durable store such as Upstash Redis with `@upstash/ratelimit`, or use Vercel Firewall for coarse IP-based limits.
- Do not use in-memory Express middleware patterns as the only limit in serverless Route Handlers; instances are ephemeral and do not share state.

Example:

```ts
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(5, '1 m'),
})

export async function POST(request: Request) {
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown'
  const { success } = await ratelimit.limit(`login:${ip}`)
  if (!success) return new Response('Too many requests', { status: 429 })
  // continue with validated auth flow
}
```

## Verification

- Build should fail if `server-only` modules are imported by client components.
- Test wrong-user and unauthenticated calls for every protected action/route.
- Confirm return values are DTOs, not full database rows or auth/session objects.
- Directly call protected Server Actions/Route Handlers where possible instead of only testing page navigation guarded by Middleware.
- Test private cached data with two different users or tenants.

## Sources To Recheck

- https://nextjs.org/docs/app/guides/data-security
- https://nextjs.org/docs/app/guides/content-security-policy
- https://nextjs.org/docs/app/guides/environment-variables
- https://nextjs.org/docs/app/api-reference/functions/unstable_cache
- https://upstash.com/docs/redis/sdks/ratelimit-ts/overview
