# vibecoding-security-skill

Next.js, Vercel, Supabase 조합으로 빠르게 만든 앱에서 자주 생기는 보안 문제를 식별하고 고치는 Codex/Antigravity용 보안 스킬입니다.

이 스킬은 단순 체크리스트가 아니라, 실제 저장소를 훑고 위험한 코드 경계가 어디인지 찾은 뒤 최소 수정으로 막고 검증하는 흐름을 제공합니다.

## 무엇을 점검하나요?

- Next.js App Router, Server Components, Server Actions, Route Handlers
- `NEXT_PUBLIC_*` 환경변수와 서버 전용 secret 노출
- Supabase Auth, SSR client, service role key 사용
- Supabase Row Level Security 정책, grants, views, functions, Storage 정책
- Vercel 환경변수, Preview/Production 보호 설정, source map, security headers
- IDOR/BOLA, 권한 검증 누락, unsafe redirect, CORS, upload/storage 접근 제어

## 언제 쓰면 좋나요?

- "Next.js + Supabase 앱 보안 리뷰해줘"
- "Vercel 배포 전에 secret 노출이나 RLS 문제 찾아줘"
- "Supabase RLS 정책이 안전한지 봐줘"
- "Server Actions에서 권한 체크 빠진 곳 찾아서 고쳐줘"
- "vibecoding으로 만든 앱을 출시 전에 보안 점검해줘"

## 설치 방법

### Codex

이 저장소를 Codex skills 폴더에 복사하거나 clone합니다.

Windows PowerShell:

```powershell
git clone https://github.com/AITutor3/vibecoding-security-skill.git $env:USERPROFILE\.codex\skills\vibecoding-security-skill
```

macOS/Linux:

```bash
git clone https://github.com/AITutor3/vibecoding-security-skill.git ~/.codex/skills/vibecoding-security-skill
```

이미 폴더가 있다면 최신 버전으로 갱신합니다.

```bash
cd ~/.codex/skills/vibecoding-security-skill
git pull
```

설치 후 Codex 세션을 새로 시작하면 스킬 목록에 자동으로 잡힙니다.

### Antigravity

Antigravity에서 agent skills 폴더를 사용하는 경우 아래 위치에 clone합니다.

Windows PowerShell:

```powershell
git clone https://github.com/AITutor3/vibecoding-security-skill.git $env:USERPROFILE\.agents\skills\vibecoding-security-skill
```

macOS/Linux:

```bash
git clone https://github.com/AITutor3/vibecoding-security-skill.git ~/.agents/skills/vibecoding-security-skill
```

Antigravity의 skills 경로를 별도로 설정했다면, 해당 skills 디렉터리 아래에 `vibecoding-security-skill` 폴더를 두면 됩니다.

## 사용 방법

프롬프트에서 스킬 이름을 직접 호출합니다.

```text
Use $vibecoding-security-skill to review this Next.js/Vercel/Supabase app for security issues and propose fixes.
```

한국어로는 이렇게 요청해도 됩니다.

```text
$vibecoding-security-skill 을 사용해서 이 Next.js + Vercel + Supabase 앱의 보안 문제를 찾아줘. 심각도별로 정리하고, 고칠 수 있는 건 직접 패치해줘.
```

보고서 파일을 원하면 이렇게 요청합니다.

```text
$vibecoding-security-skill 로 전체 보안 리뷰를 하고 security_review.md 파일로 보고서를 작성해줘.
```

## 스킬이 하는 일

1. 저장소 구조를 파악합니다.
2. Next.js, Vercel, Supabase 관련 보안 표면을 찾습니다.
3. high-risk 항목을 먼저 확인합니다.
4. 확인된 취약점과 hardening gap을 심각도별로 분류합니다.
5. 가능한 경우 안전한 최소 수정으로 패치합니다.
6. 빌드, 테스트, SQL assertion, manual probe 등으로 검증합니다.

## 포함된 참고자료

- `SKILL.md`: 스킬의 핵심 워크플로우
- `references/nextjs-security.md`: Next.js 보안 경계와 Server Actions/DAL 패턴
- `references/supabase-security.md`: Supabase RLS, service role, Storage, Data API 보안
- `references/vercel-security.md`: Vercel env, deployment protection, headers, source maps
- `references/reporting.md`: 보안 finding과 fix report 템플릿

## 주요 참고 출처

- Supabase Agent Skills: https://github.com/supabase/agent-skills
- OpenAI Security Best Practices Skill: https://github.com/openai/skills/tree/main/skills/.curated/security-best-practices
- Next.js Data Security: https://nextjs.org/docs/app/guides/data-security
- Supabase RLS Docs: https://supabase.com/docs/guides/database/postgres/row-level-security
- Vercel Docs: https://vercel.com/docs
