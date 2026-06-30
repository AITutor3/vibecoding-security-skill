#!/usr/bin/env bash
set -u

ROOT="${1:-.}"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for this audit script." >&2
  exit 1
fi

section() {
  printf '\n=== %s ===\n' "$1"
}

run_rg() {
  local pattern="$1"
  shift
  local targets=()

  if [ "$#" -eq 0 ]; then
    targets=("$ROOT")
  else
    local candidate
    for candidate in "$@"; do
      if [ -e "$ROOT/$candidate" ]; then
        targets+=("$ROOT/$candidate")
      elif [ -e "$candidate" ]; then
        targets+=("$candidate")
      fi
    done
  fi

  if [ "${#targets[@]}" -eq 0 ]; then
    echo "(skipped: no matching paths)"
    return 0
  fi

  rg -n --hidden --glob '!node_modules' --glob '!.next' --glob '!dist' --glob '!build' --glob '!.git' "$pattern" "${targets[@]}" || true
}

section "Secrets or private-looking values exposed through NEXT_PUBLIC"
run_rg 'NEXT_PUBLIC_.*(SECRET|TOKEN|KEY|SERVICE|DATABASE|PRIVATE|JWT)'

section "Supabase getSession used in server-capable paths; confirm server code uses getUser"
run_rg 'getSession\s*\(' app src lib middleware.ts proxy.ts

section "Supabase server verification calls"
run_rg 'getUser\s*\(' app src lib middleware.ts proxy.ts

section "Service role or privileged Supabase keys"
run_rg 'service[_-]?role|SUPABASE_SERVICE|SERVICE_ROLE'

section "Server Actions requiring authz review"
run_rg "['\"]use server['\"]|export async function .*Action|async function .*Action" app src

section "Middleware/Proxy auth gates; confirm routes/actions re-check auth"
run_rg 'middleware|proxy|matcher|getSession|getUser|redirect\(' middleware.ts proxy.ts app src

section "OAuth callback and redirect parameters"
run_rg "auth/callback|exchangeCodeForSession|redirectTo|returnTo|searchParams\\.get\\([\"'](next|redirect|returnTo|redirectTo)[\"']\\)|redirect\\(" app src

section "RLS enablement and policies"
run_rg 'create table|enable row level security|disable row level security|create policy|alter policy|grant .* to (anon|authenticated)|security definer|security_invoker' supabase db migrations

section "auth.users direct access"
run_rg 'auth\.users'

section "Realtime usage and policies"
run_rg 'postgres_changes|realtime|broadcast|presence|realtime\.messages|channel\(' app src supabase

section "Storage buckets and object policies"
run_rg "storage\\.objects|create bucket|from\\([\"'].*storage|upload\\(|upsert\\(|download\\(|getPublicUrl"

section "Caching of potentially user-specific data"
run_rg 'unstable_cache|use cache|cacheLife|cacheTag|revalidate|force-static'

section "Vercel URL and deployment-derived origins"
run_rg 'VERCEL_URL|VERCEL_BRANCH_URL|NEXT_PUBLIC_SITE_URL|SITE_URL|APP_ORIGIN'

section "Cron routes and CRON_SECRET checks"
run_rg 'cron|CRON_SECRET|Authorization.*Bearer'

section "Rate limiting / firewall / abuse controls"
run_rg 'ratelimit|rateLimit|Upstash|@upstash/ratelimit|firewall|turnstile|captcha|otp|invite|upload|ai|llm'

section "CORS and security headers"
run_rg 'Access-Control-Allow-Origin|cors|Content-Security-Policy|X-Frame-Options|Permissions-Policy|Referrer-Policy|headers\('

section "Webhook signature verification"
run_rg 'webhook|x-supabase-signature|signature|constructEvent|verify'

section "Potential unsafe redirects"
run_rg 'redirect\(|NextResponse\.redirect|location\.href|returnTo|nextUrl|searchParams\.get'
