# vibecoding-security-skill

Next.js + Vercel + Supabase로 만든 앱의 보안 문제를 찾고 고치는 Codex/Antigravity용 스킬입니다.

빠르게 만든 앱에서 자주 빠지는 인증, 권한, RLS, secret, redirect, Realtime, Storage, Cron, 배포 설정 문제를 실제 코드와 설정을 기준으로 점검합니다.

## 주요 점검 범위

| 영역 | 확인하는 문제 |
| --- | --- |
| Next.js | Server Actions, Route Handlers, Middleware/Proxy, server-only 경계, 사용자별 cache 오염 |
| Supabase | `getSession()` 오용, RLS, service role key, OAuth callback, `auth.users`, Realtime, Storage, Database Webhooks |
| Vercel | 환경변수, Preview 보호, `VERCEL_URL` 오용, Cron 인증, source maps, security headers |
| 공통 웹 보안 | IDOR/BOLA, open redirect, CORS, rate limiting, upload 검증, secret 노출 |

## 설치

### Codex

Windows PowerShell:

```powershell
git clone https://github.com/AITutor3/vibecoding-security-skill.git $env:USERPROFILE\.codex\skills\vibecoding-security-skill
```

macOS/Linux:

```bash
git clone https://github.com/AITutor3/vibecoding-security-skill.git ~/.codex/skills/vibecoding-security-skill
```

### Antigravity

Windows PowerShell:

```powershell
git clone https://github.com/AITutor3/vibecoding-security-skill.git $env:USERPROFILE\.agents\skills\vibecoding-security-skill
```

macOS/Linux:

```bash
git clone https://github.com/AITutor3/vibecoding-security-skill.git ~/.agents/skills/vibecoding-security-skill
```

설치 후 Codex 또는 Antigravity 세션을 새로 시작하면 스킬을 사용할 수 있습니다.

이미 설치했다면:

```bash
cd ~/.codex/skills/vibecoding-security-skill
git pull
```

## 사용 예시

스킬 이름을 프롬프트에 직접 넣어 호출합니다.

```text
Use $vibecoding-security-skill to review this Next.js/Vercel/Supabase app for security issues and propose fixes.
```

한국어 예시:

```text
$vibecoding-security-skill 을 사용해서 이 Next.js + Vercel + Supabase 앱의 보안 문제를 심각도별로 찾아주고, 고칠 수 있는 것은 직접 패치해줘.
```

보고서까지 원할 때:

```text
$vibecoding-security-skill 로 전체 보안 리뷰를 하고 security_review.md 파일로 보고서를 작성해줘.
```

## 동작 방식

1. 저장소 구조와 기술 스택을 확인합니다.
2. Next.js, Supabase, Vercel 보안 표면을 스캔합니다.
3. Critical/High 위험 항목을 우선 검토합니다.
4. 취약점과 hardening gap을 근거와 함께 분류합니다.
5. 가능한 경우 최소 수정으로 패치합니다.
6. 빌드, 테스트, SQL assertion, manual probe 등으로 검증합니다.

## 포함 파일

| 파일 | 역할 |
| --- | --- |
| `SKILL.md` | 스킬 진입점과 핵심 워크플로우 |
| `references/nextjs-security.md` | Next.js App Router, Server Actions, cache, Middleware 보안 |
| `references/supabase-security.md` | Supabase Auth, RLS, OAuth, Realtime, Storage, Webhook 보안 |
| `references/vercel-security.md` | Vercel env, Preview, Cron, headers, source map 보안 |
| `references/audit-checklist.md` | 체크박스형 감사 목록 |
| `references/reporting.md` | finding/fix report 템플릿 |
| `scripts/audit.sh` | `rg` 기반 빠른 감사 스크립트 |

## 빠른 감사 스크립트

프로젝트 루트에서 실행합니다.

```bash
~/.codex/skills/vibecoding-security-skill/scripts/audit.sh .
```

스크립트 출력은 취약점 확정이 아니라 리뷰할 후보 목록입니다. 실제 판단은 코드 흐름, 권한 모델, 런타임 설정과 함께 확인해야 합니다.

## 참고 출처

- Supabase Agent Skills: https://github.com/supabase/agent-skills
- OpenAI Security Best Practices Skill: https://github.com/openai/skills/tree/main/skills/.curated/security-best-practices
- Next.js Data Security: https://nextjs.org/docs/app/guides/data-security
- Supabase RLS Docs: https://supabase.com/docs/guides/database/postgres/row-level-security
- Vercel Docs: https://vercel.com/docs
