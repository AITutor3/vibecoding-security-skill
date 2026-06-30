# Reporting And Severity

Use this format for security reviews and fix summaries.

## Severity Calibration

Critical:

- Remote unauthenticated access to other users' private data or admin actions.
- Service-role key, database URL, JWT signing secret, OAuth client secret, or equivalent exposed to the browser or git history.
- RLS disabled or bypassed on exposed tables containing sensitive production data.

High:

- Authenticated IDOR/BOLA across users, projects, teams, tenants, or organizations.
- Server Action or Route Handler mutation missing authorization for a specific resource.
- Broad Supabase grants plus weak/missing policies on sensitive tables.
- Public private-file storage bucket or cross-user object path access.
- `security definer` function callable by public roles and touching sensitive data.

Medium:

- Missing input validation that can cause privilege confusion, stored XSS, unsafe redirects, or business logic abuse.
- Production source maps exposed for sensitive app code.
- Broad CORS on authenticated endpoints.
- Missing rate limiting on expensive auth, upload, invite, notification, or AI routes.

Low:

- Missing standard hardening headers without a directly exploitable path.
- Overly verbose errors in non-production contexts.
- Minor policy performance issues that do not change authorization.

## Finding Template

```md
Severity: Critical | High | Medium | Low
Status: Confirmed | Likely | Hardening | False positive
Location: path/to/file:line

Issue:
Explain the vulnerable behavior in one short paragraph.

Impact:
Describe what an attacker can access or do.

Evidence:
Point to code, SQL, config, route, or reproduction steps.

Fix:
Describe the minimal secure fix.

Verification:
State the test, build, SQL assertion, or manual probe that proves the fix.
```

## Fix Summary Template

```md
Changed:
- path/to/file: what changed

Risk closed:
- Name the vulnerability class and boundary restored.

Verified:
- Command or manual probe and result.

Remaining:
- Any dashboard setting, secret rotation, or production-only check still needed.
```

## Sources To Recheck

- https://github.com/openai/skills/tree/main/skills/.curated/security-best-practices
- https://cheatsheetseries.owasp.org/
