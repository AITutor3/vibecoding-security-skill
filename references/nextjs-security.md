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

Caching rules:

- Avoid caching personalized data unless the cache key is tied to the authenticated user and cannot be shared.
- Do not put secret-dependent or user-dependent data in static generation paths.
- After mutations, revalidate only paths/tags the current user is authorized to affect.

## Verification

- Build should fail if `server-only` modules are imported by client components.
- Test wrong-user and unauthenticated calls for every protected action/route.
- Confirm return values are DTOs, not full database rows or auth/session objects.

## Sources To Recheck

- https://nextjs.org/docs/app/guides/data-security
- https://nextjs.org/docs/app/guides/content-security-policy
- https://nextjs.org/docs/app/guides/environment-variables
