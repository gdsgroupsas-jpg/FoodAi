---
title: AI Do and Dont
scope: rules
audience: ai
owner: engineering
status: active
source_of_truth: true
updated: 2026-02-09
---

# AI Do and Dont

Regole operative per l'agent AI quando lavora sul progetto FoodCost AI.

## Do (Fai)

- Segui i task assegnati in autonomia dopo che sono stati definiti.
- Aggiungi o aggiorna i test per ogni componente modificato.
- Esegui i test e riporta i risultati SOLO dopo che passano tutti.
- Mantieni i link della documentazione coerenti con la struttura handbook.
- Aggiorna la documentazione PRIMA del commit (non dopo).
- Spiega cosa stai facendo mentre procedi (l'utente vuole imparare).
- Presenta opzioni nei punti decisionali chiave.
- Consulta `docs/00-HANDBOOK/DECISION_LOG.md` prima di proporre cambi architetturali (la decisione potrebbe essere gia stata presa).
- Consulta `docs/03-DB-SCHEMA/SCHEMA.sql` come source of truth per lo schema DB.
- Usa il pattern `getAuthContext()` in ogni server action.
- Filtra SEMPRE per `restaurant_id` in ogni query.

## Dont (Non fare)

- **MAI** saltare i test per le modifiche al codice.
- **MAI** riportare lavoro come "finito" senza test verdi.
- **MAI** cambiare doc di processo senza approvazione esplicita dell'utente.
- **MAI** creare fonti di verita duplicate (se un concetto esiste gia in un doc, linkalo).
- **MAI** committare segreti — nessun token, password, API key nel codice o documentazione. Vedi `docs/00-HANDBOOK/rules/SECURITY_SECRETS.md`.
- **MAI** usare `any` per dati provenienti dal database — usa i tipi generati.
- **MAI** fare query senza filtro `restaurant_id` (leak multi-tenant).
- **MAI** scegliere in silenzio tra alternative con trade-off significativi.
- **MAI** modificare lo schema DB senza aggiornare `SCHEMA.sql` e `DECISION_LOG.md`.
- **MAI** aggiungere dipendenze npm senza chiedere prima.

## Processo operativo (5 step)

1. **Task Assignment** — Ricevi il task, conferma l'interpretazione.
2. **Esecuzione Autonoma** — Implementa senza richiedere micro-decisioni.
3. **Testing Obbligatorio** — Aggiorna/aggiungi test. Esegui. Solo con test verdi il lavoro e "finito".
4. **Documentazione** — Aggiorna doc pertinente PRIMA del commit (vedi mappa in `workflow-delivery.mdc`).
5. **Validazione** — Riporta risultati e rischi residui. Chiedi approvazione se serve aggiornare regole/workflow.
