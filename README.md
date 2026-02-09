---
title: FoodCost AI
scope: product
audience: all
owner: product
status: active
source_of_truth: true
updated: 2026-02-09
---

# FoodCost AI

**Gestionale ristorazione AI-first: comande, magazzino, food cost, previsioni acquisti.**

## Visione

Un sistema integrato dove l'ordine di un piatto in sala scarica automaticamente gli ingredienti dal magazzino, calcola il food cost al centesimo, monitora le scadenze, e un assistente AI suggerisce quando e quanto ordinare dai fornitori.

## Requisiti di Michele (ristoratore - primo cliente)

1. **Comanda → scarico magazzino**: quando il cameriere batte un piatto, gli ingredienti si scaricano in tempo reale secondo la distinta base (ricetta)
2. **Food cost al grammo**: calcolo preciso del costo di ogni piatto = somma (ingrediente × quantità × costo unitario × fattore resa)
3. **Gestione scadenze**: monitoraggio shelf-life prodotti freschi, FIFO automatico, alert scadenze
4. **AI predittiva**: analisi storico vendite → previsione domanda → suggerimento ordini fornitori
5. **Codici a barre**: scansione per carico/scarico rapido merci

## Stack Tecnologico

| Componente | Tecnologia | Motivo |
|-----------|-----------|--------|
| Frontend | Next.js 15 + TypeScript + Tailwind CSS | Stesso stack di SpedireSicuro, competenza interna |
| Database | PostgreSQL (Supabase) | RLS, auth, realtime, storage |
| Hosting | Vercel | Deploy automatico, edge functions |
| AI | Claude API (Anthropic) | Intent detection, analisi, suggerimenti |
| Barcode | Camera device + libreria JS | Zero hardware aggiuntivo |

## Struttura Documentazione

```
docs/
  00-HANDBOOK/          ← Regole, convenzioni, flow di lavoro per il team
  01-ARCHITECTURE/      ← Architettura tecnica, diagrammi, decisioni
  02-SPRINTS/           ← Tutorial passo-passo per ogni sprint
  03-DB-SCHEMA/         ← Schema SQL Supabase completo
  04-FLOWS/             ← Diagrammi di flusso operativi
  05-REFERENCES/        ← Repo open source di riferimento, link utili
```

## Sprint Plan

| Sprint | Obiettivo | Durata stimata |
|--------|----------|---------------|
| **S0** | Setup progetto (Next.js + Supabase + Auth + CI) | 1 settimana |
| **S1** | Dominio base: ingredienti, ricette, fornitori, listini | 2-3 settimane |
| **S2** | Gestionale sala: tavoli, comande, invio cucina | 2-3 settimane |
| **S3** | Magazzino: stock, scarico automatico da comanda, scadenze, barcode | 2-3 settimane |
| **S4** | AI Assistant: food cost analytics, previsioni, suggerimenti ordini | 2-3 settimane |
| **S5** | Polish: UI/UX, onboarding Michele, beta test | 1-2 settimane |

## Quick Start

Vedi `docs/02-SPRINTS/SPRINT-0-SETUP.md` per il tutorial completo di setup.
