---
title: Security - Secrets Management
scope: rules
audience: all
owner: engineering
status: active
source_of_truth: true
priority: CRITICAL
updated: 2026-02-09
---

# REGOLE SEGRETI — MAI COMMITTARE!

## REGOLA ASSOLUTA

**I SEGRETI NON VANNO MAI E POI MAI COMMITTATI NEL REPOSITORY.**

Questa regola non ha eccezioni.

---

## Cosa sono i segreti?

| Tipo | Pattern | Esempio |
|------|---------|---------|
| Supabase Anon Key | `eyJhbGciOi...` (JWT) | Token lungo base64 |
| Supabase Service Role Key | `eyJhbGciOi...` (JWT) | Token lungo base64 |
| Supabase Access Token | `sbp_*` | `sbp_abc123...` |
| Anthropic API Key | `sk-ant-*` | `sk-ant-api03-...` |
| GitHub Token | `ghp_*`, `gho_*`, `ghs_*` | `ghp_abc123...` |
| Vercel Token | `*` | Qualsiasi token Vercel |
| Password | Qualsiasi password | `password123` |
| API Keys generiche | `*_API_KEY`, `*_SECRET` | Qualsiasi chiave API |

---

## Dove mettere i segreti?

### Sviluppo locale

```
.env.local  (MAI committare — e' nel .gitignore)
```

### Produzione

```
Vercel Dashboard > Settings > Environment Variables
```

### CI/CD

```
GitHub > Settings > Secrets and variables > Actions
```

---

## File `.env.example` (l'unico consentito nel repo)

Contiene solo placeholder, MAI valori reali:

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key-here

# AI (Sprint 4)
ANTHROPIC_API_KEY=your-anthropic-api-key-here
```

---

## Cosa fare SE hai committato un segreto

1. **RUOTA IMMEDIATAMENTE** la credenziale (genera una nuova)
2. **PULISCI** la cronologia git con `git filter-repo`
3. **FORCE PUSH** al remote
4. **AVVISA** il team

---

## Prevenzione

### Pre-commit hook

Installare gitleaks o detect-secrets come pre-commit hook:

```bash
# Con husky (gia configurato nel progetto)
# Aggiungere check segreti nel pre-commit
```

### Review PR

Checklist per ogni PR:
- [ ] Nessun segreto nei file modificati
- [ ] Nessun segreto nei messaggi di commit
- [ ] Nessun segreto nella documentazione
- [ ] `.env.local` non e stato committato

---

_Questa regola e assoluta e non negoziabile._
