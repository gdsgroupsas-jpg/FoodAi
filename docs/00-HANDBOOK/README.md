---
title: Handbook Hub
scope: process
audience: all
owner: docs
status: active
source_of_truth: true
updated: 2026-02-09
---

# Documentation Hub — FoodCost AI

Questo e il punto di ingresso unico per regole, workflow, documentazione, testing e decisioni del progetto.

## Inizia da qui

- [Regole AI Agent](./rules/AI_DO_DONT.md) — Cosa l'AI deve e non deve fare
- [Sicurezza e Segreti](./rules/SECURITY_SECRETS.md) — Gestione credenziali (regola assoluta)
- [Decision Log](./DECISION_LOG.md) — Registro decisioni architetturali
- [Task-Doc-Test Map](./testing/TASK_DOC_TEST_MAP.md) — Mappa area -> doc canonica -> test

## Documentazione Progetto

| Sezione | Percorso | Contenuto |
|---------|----------|-----------|
| Handbook (qui) | `docs/00-HANDBOOK/` | Regole, processi, decisioni |
| Architettura | `docs/01-ARCHITECTURE/ARCHITECTURE.md` | Architettura tecnica, diagrammi, decisioni |
| Sprint Tutorial | `docs/02-SPRINTS/SPRINT-*.md` | Tutorial passo-passo per ogni sprint |
| Schema DB | `docs/03-DB-SCHEMA/SCHEMA.sql` | Schema SQL Supabase completo |
| Flow Operativi | `docs/04-FLOWS/FLOWS.md` | Diagrammi di flusso utente |
| Riferimenti | `docs/05-REFERENCES/REFERENCES.md` | Repo open source, librerie, competitor |

## Cursor Rules (IDE)

Le regole dell'agent AI sono in `.cursor/rules/`:

| Rule | Scope | Contenuto |
|------|-------|-----------|
| `project-config.mdc` | Always | Visione progetto, ruoli, fasi, sprint plan |
| `code-conventions.mdc` | `*.ts/*.tsx` | Naming, struttura, pattern server action |
| `supabase-patterns.mdc` | `*.ts/*.tsx/*.sql` | Client Supabase, RLS, Realtime, stati DB |
| `workflow-delivery.mdc` | Always | Delivery flow, test, qualita, sicurezza |

> `.cursor/rules/` e la source of truth per le regole IDE. Questo handbook e la source of truth per i processi.

## Source of Truth

| Argomento | File canonico |
|-----------|--------------|
| Visione prodotto | `README.md` (root) |
| Architettura | `docs/01-ARCHITECTURE/ARCHITECTURE.md` |
| Schema database | `docs/03-DB-SCHEMA/SCHEMA.sql` |
| Flow operativi | `docs/04-FLOWS/FLOWS.md` |
| Decisioni | `docs/00-HANDBOOK/DECISION_LOG.md` |
| Sicurezza segreti | `docs/00-HANDBOOK/rules/SECURITY_SECRETS.md` |
| Regole AI | `docs/00-HANDBOOK/rules/AI_DO_DONT.md` |

## Note

- Tieni questa pagina aggiornata quando aggiungi doc principali.
- Ogni documento ha frontmatter YAML con `title`, `scope`, `audience`, `owner`, `status`, `updated`.
- Non creare fonti di verita duplicate. Se un concetto esiste gia in un doc, linkalo.
