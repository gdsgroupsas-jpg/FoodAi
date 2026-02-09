---
title: Task Doc Test Map
scope: testing
audience: engineering
owner: engineering
status: active
source_of_truth: true
updated: 2026-02-09
---

# Task, Doc, Test Map

Usa questa tabella per saltare da un'area alla sua doc canonica e ai test corrispondenti.

| Area | Doc Canonica | Test | Note |
|------|-------------|------|------|
| Food Cost | `docs/02-SPRINTS/SPRINT-1-DOMINIO.md` | `tests/unit/food-cost-calculator.test.ts` | Calcolo costo ingredienti, margine, resa |
| Ingredienti | `docs/02-SPRINTS/SPRINT-1-DOMINIO.md` | `tests/unit/ingredients.test.ts` | CRUD, categorie, barcode, allergeni |
| Ricette | `docs/02-SPRINTS/SPRINT-1-DOMINIO.md` | `tests/unit/recipes.test.ts` | CRUD, distinta base, calcolo food cost |
| Fornitori | `docs/02-SPRINTS/SPRINT-1-DOMINIO.md` | `tests/unit/suppliers.test.ts` | CRUD, listini prezzo |
| Tavoli | `docs/02-SPRINTS/SPRINT-2-SALA.md` | `tests/unit/order-management.test.ts` | CRUD, stati, transizioni |
| Comande | `docs/02-SPRINTS/SPRINT-2-SALA.md` | `tests/unit/order-management.test.ts` | Creazione, items, calcolo conto |
| Kitchen Display | `docs/02-SPRINTS/SPRINT-2-SALA.md` | `tests/unit/order-management.test.ts` | Realtime, raggruppamento, stati |
| Magazzino / FIFO | `docs/02-SPRINTS/SPRINT-3-MAGAZZINO.md` | `tests/unit/fifo-inventory.test.ts` | FIFO, lotti, scarico automatico |
| Scadenze | `docs/02-SPRINTS/SPRINT-3-MAGAZZINO.md` | `tests/unit/fifo-inventory.test.ts` | Alert scadenze, shelf life |
| Barcode | `docs/02-SPRINTS/SPRINT-3-MAGAZZINO.md` | `tests/unit/barcode.test.ts` | Scansione, associazione ingrediente |
| AI Chat | `docs/02-SPRINTS/SPRINT-4-AI.md` | `tests/unit/intent-detector.test.ts` | Intent detection, worker routing |
| AI Suggerimenti Ordini | `docs/02-SPRINTS/SPRINT-4-AI.md` | `tests/unit/order-suggestions.test.ts` | Soglie, urgenza, quantita suggerite |
| Schema DB | `docs/03-DB-SCHEMA/SCHEMA.sql` | — | Source of truth per tutte le tabelle |
| Flow Operativi | `docs/04-FLOWS/FLOWS.md` | — | Diagrammi flusso utente |
| Architettura | `docs/01-ARCHITECTURE/ARCHITECTURE.md` | — | Panoramica sistema, decisioni |
| Auth / RLS | `docs/02-SPRINTS/SPRINT-0-SETUP.md` | `tests/unit/auth.test.ts` | Login, RLS, middleware |

## Come usare questa mappa

1. **Stai lavorando su un'area?** Trova la riga corrispondente.
2. **Leggi la doc canonica** prima di toccare il codice.
3. **Verifica i test** esistenti prima di modificare.
4. **Aggiorna test e doc** dopo la modifica.

## Regola

Se aggiungi un'area nuova al progetto, **aggiungi una riga a questa tabella**.
