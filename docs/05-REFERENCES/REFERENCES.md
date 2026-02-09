---
title: Riferimenti e Risorse
scope: references
audience: all
owner: engineering
status: active
updated: 2026-02-09
---

# Riferimenti e Risorse — FoodCost AI

## Repository Open Source di Riferimento

### 1. ManageRestaurantFrontend (PRIMARIO)
- **Repo**: https://github.com/cqhung1412/ManageRestaurantFrontend
- **Stack**: React + TypeScript (vicino al nostro Next.js)
- **Cosa prendere**: struttura componenti sala, UI gestionale, pattern tavoli/comande
- **Nota**: UI-only, no backend — il backend lo facciamo noi con Supabase

### 2. URY (Restaurant Management)
- **Repo**: https://github.com/AravindKumaran/URY
- **Stack**: MERN (MongoDB, Express, React, Node)
- **Cosa prendere**: logica di business ristorazione, flussi comanda-cucina
- **Nota**: Stack diverso ma logica riusabile. Buon riferimento per Kitchen Display

### 3. NexoPOS (POS + Inventory)
- **Repo**: https://github.com/Blair2004/NexoPOS
- **Stack**: Laravel + Vue.js
- **Cosa prendere**: logica magazzino (FIFO, lotti, scadenze), gestione fornitori
- **Nota**: Il modulo inventory/stock e molto maturo e ben documentato

### 4. html5-qrcode (Barcode Scanner)
- **Repo**: https://github.com/mebjas/html5-qrcode
- **Docs**: https://scanapp.org/html5-qrcode-docs/
- **Cosa prendere**: integrazione scanner barcode da camera
- **NPM**: `html5-qrcode`
- **Nota**: Supporta EAN-13, EAN-8, Code 128, QR Code. Zero hardware.

---

## Librerie NPM Chiave

| Libreria | Scopo | NPM |
|----------|-------|-----|
| `@supabase/supabase-js` | Client Supabase | `@supabase/supabase-js` |
| `@supabase/ssr` | Auth SSR per Next.js | `@supabase/ssr` |
| `zod` | Validazione input | `zod` |
| `html5-qrcode` | Scanner barcode da camera | `html5-qrcode` |
| `recharts` | Grafici dashboard food cost | `recharts` |
| `@anthropic-ai/sdk` | Claude API per AI assistant | `@anthropic-ai/sdk` |
| `date-fns` | Manipolazione date (scadenze) | `date-fns` |
| `lucide-react` | Icone | `lucide-react` |

---

## Documentazione Tecnica

- **Next.js 15**: https://nextjs.org/docs
- **Supabase**: https://supabase.com/docs
- **Supabase Realtime**: https://supabase.com/docs/guides/realtime
- **Supabase RLS**: https://supabase.com/docs/guides/auth/row-level-security
- **Tailwind CSS**: https://tailwindcss.com/docs
- **Vitest**: https://vitest.dev/guide/
- **Playwright**: https://playwright.dev/docs/intro

---

## Pattern da SpedireSicuro (riutilizzabili)

Il progetto SpedireSicuro (`c:\Users\sigor\spediresicuro-fusion`) contiene pattern gia testati in produzione:

### 1. Autenticazione
- `lib/db/client.ts` — Setup client Supabase admin
- `lib/db/auth.ts` → adattare come `lib/db/auth.ts` — getCurrentUser()
- `lib/safe-auth.ts` — Pattern auth sicuro con context

### 2. Server Actions
- `actions/reseller-clients.ts` — Pattern completo: auth → query → risposta tipizzata
- Pattern: `{ success: boolean; data?: T; error?: string }`

### 3. Layout Dashboard
- `app/dashboard/layout.tsx` — Sidebar + content area
- `components/sidebar/` — Componenti sidebar riutilizzabili

### 4. AI Chat (Anne)
- `lib/ai/` — Intent detection, workers, Claude API integration
- `components/ai/` — Chat interface components
- Pattern identico per FoodCost AI, cambiamo solo gli intenti e i worker

### 5. Testing
- `vitest.config.ts` — Configurazione Vitest
- `tests/unit/` — Pattern test con mock Supabase

---

## Competenze nel Team

### Conoscenze richieste
1. **Next.js 15** — App Router, Server Actions, Server/Client Components
2. **TypeScript** — Tipizzazione stretta, generics, Zod
3. **Supabase** — PostgreSQL, RLS, Realtime, Auth
4. **Tailwind CSS** — Utility-first styling
5. **Vitest** — Unit testing

### Conoscenze di dominio
1. **Food cost** — Come funziona il calcolo (costo ingredienti / prezzo vendita)
2. **Fattore resa** — Calo peso cottura (carne 30%, pesce 20-40%, verdure 15%)
3. **FIFO** — First In First Out per magazzino alimentare
4. **Shelf life** — Scadenze prodotti freschi
5. **Distinta base** — Lista ingredienti per ricetta con dosi precise

---

## Competitor da Studiare

| Nome | Sito | Punti di forza | Punti deboli |
|------|------|---------------|-------------|
| Ristomanager | ristomanager.it | Completo, mercato italiano | Legacy, no AI |
| iKentoo (Lightspeed) | ikentoo.com | POS integrato, UX moderna | Costoso, no food cost avanzato |
| MarketMan | marketman.com | Inventory forte, integrazioni | Solo magazzino, no sala |
| Apicbase | apicbase.com | Food cost AI, enterprise | Molto costoso, non per PMI |
| BlueCart | bluecart.com | Ordini fornitori, B2B | Solo procurement |
| PipApp | pip.app | ?? | ?? |

### Differenziazione FoodCost AI
1. **AI-first**: non dashboard, ma conversazione ("quanto mi costa la carbonara?")
2. **Prezzo accessibile**: target trattoria/ristorante medio, non catena
3. **Zero hardware**: barcode via camera, Kitchen Display via browser
4. **Italiano nativo**: UI, AI, supporto tutto in italiano
5. **Integrato**: sala + cucina + magazzino + food cost in un unico sistema
