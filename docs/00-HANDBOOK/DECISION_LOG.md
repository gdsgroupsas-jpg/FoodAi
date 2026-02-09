---
title: Decision Log
scope: process
audience: all
owner: engineering
status: active
source_of_truth: true
updated: 2026-02-09
---

# Decision Log

Registro delle decisioni strutturali e architetturali. Ogni entry include data, decisione, motivazione e impatto.

Serve per:
- Ricordare PERCHE' abbiamo scelto qualcosa
- Evitare di rivisitare decisioni gia prese
- Dare contesto rapido all'AI agent

---

## 2026-02-09 — Inizializzazione progetto e documentazione

- **Decisione**: Creare documentazione completa PRIMA del codice.
- **Motivazione**: Allineare visione, architettura e regole prima di scrivere una riga. Lezione appresa da SpedireSicuro dove la doc era arrivata dopo.
- **Impatto**: `docs/` con 6 sezioni, `.cursor/rules/` con 4 file, handbook strutturato.

## 2026-02-09 — Stack tecnologico

- **Decisione**: Next.js 15 + TypeScript + Tailwind + Supabase + Vercel + Claude API.
- **Motivazione**: Stesso stack di SpedireSicuro, competenza interna gia consolidata. Supabase offre RLS, Auth, Realtime, Storage in un unico servizio.
- **Impatto**: Zero curva di apprendimento, pattern riusabili da SpedireSicuro.

## 2026-02-09 — Multi-tenant con RLS

- **Decisione**: Un database unico per tutti i ristoranti, isolamento via `restaurant_id` + RLS.
- **Motivazione**: Piu semplice da gestire rispetto a un DB per tenant. RLS garantisce isolamento a livello di riga senza logica applicativa.
- **Impatto**: Ogni tabella ha `restaurant_id`, ogni query DEVE filtrare per tenant.

## 2026-02-09 — Stati DB in inglese

- **Decisione**: Tutti gli stati nel database in inglese (`free`, `occupied`, `open`, `closed`). La UI traduce in italiano.
- **Motivazione**: Coerenza con lo stack (TypeScript, PostgreSQL). Evita mismatch tra codice e schema. La localizzazione e responsabilita del frontend.
- **Impatto**: Allineamento schema SQL e codice TypeScript. Tabella stati in `supabase-patterns.mdc`.

## 2026-02-09 — FIFO applicativo (non trigger DB)

- **Decisione**: La logica FIFO per il magazzino e implementata lato applicazione (TypeScript), non come trigger PostgreSQL.
- **Motivazione**: Piu testabile con unit test, piu flessibile per edge case, piu facile da debuggare.
- **Impatto**: `lib/inventory/fifo.ts` con test dedicati. Stored procedure solo per transazioni atomiche.

## 2026-02-09 — Scarico magazzino non blocca comanda

- **Decisione**: Se un ingrediente e esaurito in magazzino, la comanda procede comunque. Si genera un alert ma NON si blocca la cucina.
- **Motivazione**: Il magazzino potrebbe non essere aggiornato (carico non registrato). Il ristorante non puo rifiutare un piatto perche il software dice stock = 0.
- **Impatto**: `autoUnloadFromOrder` restituisce alert ma non errori bloccanti.

## 2026-02-09 — Handbook strutturato (pattern SpedireSicuro)

- **Decisione**: Adottare la struttura handbook di SpedireSicuro con frontmatter YAML, hub centralizzato, decision log, AI do/dont, security secrets, task-doc-test map.
- **Motivazione**: Struttura collaudata in produzione. L'AI agent lavora meglio con doc strutturata e source of truth chiare.
- **Impatto**: `docs/00-HANDBOOK/` ristrutturato, nuovi file regole e testing.
