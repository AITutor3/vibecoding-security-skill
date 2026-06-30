# Vercel Security Reference

Use for Vercel deployment settings, environment variables, preview deployments, source maps, headers, and production hardening.

## Environment Variables

Audit:

```bash
rg -n "NEXT_PUBLIC_|VERCEL_URL|VERCEL_BRANCH_URL|SUPABASE|SERVICE|SECRET|TOKEN|KEY|DATABASE_URL|SENTRY|SOURCE_MAP|productionBrowserSourceMaps|headers\(|Content-Security-Policy|Access-Control-Allow" .
```

Rules:

- Never put secrets in `NEXT_PUBLIC_*`.
- Do not commit `.env`, `.env.local`, `.env.production`, Vercel pull outputs, or deployment tokens.
- Vercel env changes apply only to new deployments; mention redeploy and rotation when fixing leaked values.
- Scope variables by environment. Avoid production Supabase projects and production secrets in Preview unless deliberately required.
- Rotate any key that may have reached git history, build logs, source maps, or the browser.

## Deployment Protection

Check whether preview deployments expose real data or admin workflows.

Recommended:

- Use Standard Protection for previews and generated deployment URLs.
- Use All Deployments or Trusted IPs where production must be private.
- Gate source maps with Protected Source Maps if production source maps are needed.
- Prefer relative client-side fetches instead of generated deployment URLs after enabling protection.

Dashboard-only findings should be reported as required settings with verification steps.

## Headers And Browser Controls

Prefer setting stable headers in `next.config.*` unless the app has route-specific needs:

```ts
const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
]

export default {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: securityHeaders,
      },
    ]
  },
}
```

For CSP:

- Add CSP only after checking scripts, analytics, Supabase auth redirects, images, and uploads.
- Prefer nonce-based CSP for apps with inline scripts or third-party scripts.
- Do not ship a broken CSP silently. Test login, uploads, analytics, and critical pages.

## CORS And API Surface

- Avoid `Access-Control-Allow-Origin: *` on authenticated routes.
- Explicitly allow trusted origins for APIs meant for browser cross-origin access.
- Do not rely on CORS as authorization; enforce auth and resource ownership in the route/action/DAL.
- Reject unexpected methods and content types.

## Source Maps, Logs, And Errors

Check:

- `productionBrowserSourceMaps: true` without protection.
- Public `.map` files containing source, secrets, internal URLs, or comments.
- Logs that print cookies, JWTs, service-role keys, magic links, OAuth codes, or webhook payload secrets.
- Error responses exposing stack traces, SQL messages, table names, policy names, or provider tokens.

## Verification

- Run a production build and inspect generated client env references when secrets are suspected.
- Use browser devtools or grep build output for leaked key names/values.
- Confirm protected preview URLs require auth where expected.
- Curl API routes with wrong origin and missing auth.

## Sources To Recheck

- https://vercel.com/docs/environment-variables
- https://vercel.com/docs/deployment-protection
- https://vercel.com/docs/security
- https://nextjs.org/docs/app/guides/content-security-policy
