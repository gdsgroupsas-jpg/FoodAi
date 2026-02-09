---
title: Architettura FoodCost AI
scope: architecture
audience: engineering
owner: engineering
status: active
source_of_truth: true
updated: 2026-02-09
---

# Architettura FoodCost AI

## Panoramica

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND (Next.js)                     │
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  Sala /   │  │  Cucina  │  │Magazzino │  │   AI     │ │
│  │  Comande  │  │ Display  │  │  Stock   │  │Assistant │ │
│  └─────┬────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│        │            │             │              │        │
│  ┌─────┴────────────┴─────────────┴──────────────┴─────┐ │
│  │              Server Actions (Next.js)                │ │
│  └─────────────────────┬───────────────────────────────┘ │
└────────────────────────┼─────────────────────────────────┘
                         │
┌────────────────────────┼─────────────────────────────────┐
│                   BACKEND (Supabase)                      │
│                        │                                  │
│  ┌────────────┐  ┌─────┴──────┐  ┌───────────────┐      │
│  │ PostgreSQL │  │  Realtime  │  │  Auth (email)  │      │
│  │  (RLS)     │  │ (comande)  │  │               │      │
│  └────────────┘  └────────────┘  └───────────────┘      │
│                                                           │
│  ┌────────────┐  ┌─────────────┐                         │
│  │  Storage   │  │  Edge Fn    │                         │
│  │ (foto,pdf) │  │ (cron jobs) │                         │
│  └────────────┘  └─────────────┘                         │
└───────────────────────────────────────────────────────────┘
                         │
┌────────────────────────┼─────────────────────────────────┐
│                   AI LAYER                                │
│                        │                                  │
│  ┌────────────┐  ┌─────┴──────┐  ┌───────────────┐      │
│  │  Claude    │  │  Intent    │  │   Workers     │      │
│  │  API       │  │  Detector  │  │ (food cost,   │      │
│  │            │  │            │  │  previsioni,   │      │
│  │            │  │            │  │  ordini)       │      │
│  └────────────┘  └────────────┘  └───────────────┘      │
└───────────────────────────────────────────────────────────┘
```

## Flusso Core: Comanda → Scarico Magazzino

```
1. Cameriere batte piatto sul tablet/telefono
   │
2. Server Action: creaComanda(tavoloId, [piatti])
   │
3. INSERT INTO comande + comanda_items
   │
4. Supabase Realtime → Kitchen Display riceve ordine
   │
5. Trigger/Server Action: per ogni piatto ordinato
   │  → Leggi distinta base (ricetta_ingredienti)
   │  → Per ogni ingrediente:
   │     → Calcola quantita = dose_ricetta × num_porzioni
   │     → UPDATE magazzino SET quantita = quantita - dose
   │     → Se quantita < soglia_minima → genera alert
   │
6. Kitchen Display mostra ordine con stato "in preparazione"
   │
7. Chef marca piatto come "pronto"
   │
8. Supabase Realtime → Sala vede piatto pronto per servizio
```

## Flusso: Carico Magazzino con Barcode

```
1. Arriva merce dal fornitore
   │
2. Operatore apre app → sezione "Carico Merci"
   │
3. Scansiona barcode prodotto (camera telefono)
   │
4. App riconosce prodotto da barcode → mostra nome, unita
   │  (se nuovo: chiede di associare barcode a ingrediente)
   │
5. Operatore inserisce: quantita, lotto, data scadenza
   │
6. Server Action: caricaMagazzino(ingredienteId, quantita, lotto, scadenza)
   │
7. INSERT INTO movimenti_magazzino (tipo: 'carico')
   │  UPDATE magazzino SET quantita = quantita + nuova_quantita
   │
8. Sistema FIFO: il lotto con scadenza piu vicina viene usato prima
```

## Flusso: AI Food Cost Analysis

```
1. Ristoratore apre chat AI o dashboard food cost
   │
2. AI analizza dati:
   │  → Costo ingredienti per ricetta (da listini fornitori)
   │  → Fattore resa per ingrediente (calo peso cottura)
   │  → Vendite per piatto (da storico comande)
   │  → Prezzo di vendita menu
   │
3. Calcolo per ogni piatto:
   │  food_cost = SUM(ingrediente.costo × ingrediente.dose × ingrediente.fattore_resa)
   │  margine = prezzo_vendita - food_cost
   │  margine_percentuale = margine / prezzo_vendita × 100
   │
4. AI genera insights:
   │  → "La carbonara ti costa 3.20€, la vendi a 14€ = margine 77%"
   │  → "Il salmone costa 8.50€, lo vendi a 16€ = margine 47% (sotto soglia)"
   │  → "Il prezzo del guanciale e salito del 15% questo mese"
   │  → "Domani e sabato: prevedo 30 carbonare, ti servono 3kg di guanciale"
```

## Modello Dati Semplificato

```
RISTORANTE (tenant)
  │
  ├── FORNITORI
  │     └── LISTINI_FORNITORE
  │           └── PREZZI_INGREDIENTE (ingrediente_id, prezzo, unita, data)
  │
  ├── INGREDIENTI
  │     ├── barcode, nome, unita_misura, categoria
  │     ├── fattore_resa (es. 0.70 per carne = 30% calo cottura)
  │     └── soglia_minima (alert quando stock sotto questa quantita)
  │
  ├── RICETTE (= piatti del menu)
  │     ├── nome, categoria, prezzo_vendita
  │     └── RICETTA_INGREDIENTI (ingrediente_id, dose, unita)
  │
  ├── TAVOLI
  │     └── COMANDE
  │           └── COMANDA_ITEMS (ricetta_id, quantita, stato)
  │
  └── MAGAZZINO
        ├── STOCK (ingrediente_id, quantita_attuale, soglia_minima)
        └── MOVIMENTI (tipo: carico/scarico, ingrediente_id, quantita, lotto, scadenza, causale)
```

## Decisioni Architetturali

| Decisione | Scelta | Motivo |
|-----------|--------|--------|
| Realtime comande | Supabase Realtime | Gia incluso, zero infra aggiuntiva |
| Barcode scanner | Camera + quagga2/html5-qrcode | Zero hardware, funziona su qualsiasi telefono |
| FIFO magazzino | Logica applicativa (non trigger DB) | Piu testabile, piu flessibile |
| Food cost calculation | Server-side (server action) | Dati sensibili, calcoli complessi |
| AI chat | Claude API via server action | Stessa architettura di Anne (SpedireSicuro) |
| Multi-tenant | Campo restaurant_id + RLS | Un DB per tutti, isolamento a livello di row |
| Kitchen Display | Pagina web separata su tablet | Nessuna app nativa, un browser basta |
