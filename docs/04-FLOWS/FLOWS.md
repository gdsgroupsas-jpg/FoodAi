---
title: Flow Operativi
scope: workflows
audience: all
owner: product
status: active
source_of_truth: true
updated: 2026-02-09
---

# Flow Operativi — FoodCost AI

Diagrammi dei flussi principali del sistema.

---

## Flow 1: Comanda → Scarico Magazzino

Il flusso core che collega sala, cucina e magazzino.

```
CAMERIERE                          SISTEMA                          CUCINA
   │                                  │                                │
   │  1. Apre app, seleziona         │                                │
   │     tavolo libero               │                                │
   │─────────────────────────────────>│                                │
   │                                  │  2. Mostra menu per categoria  │
   │                                  │<──────────────────────────────│
   │  3. Seleziona piatti,           │                                │
   │     quantita, note              │                                │
   │     ("senza cipolla")           │                                │
   │─────────────────────────────────>│                                │
   │                                  │  4. Crea ordine:               │
   │                                  │     - INSERT orders            │
   │                                  │     - INSERT order_items       │
   │                                  │       (status='sent')          │
   │                                  │     - UPDATE tables             │
   │                                  │       (status='occupied')       │
   │                                  │                                │
   │                                  │  5. Scarico magazzino:         │
   │                                  │     Per ogni piatto:           │
   │                                  │     → Leggi distinta base      │
   │                                  │     → Per ogni ingrediente:    │
   │                                  │       dose × qty / yield_factor│
   │                                  │     → FIFO: consuma lotti      │
   │                                  │     → UPDATE stock_batches     │
   │                                  │     → UPDATE stock             │
   │                                  │     → INSERT stock_movements   │
   │                                  │                                │
   │                                  │  6. Supabase Realtime ──────> │
   │                                  │     (postgres_changes)         │  7. Kitchen Display
   │                                  │                                │     mostra ordine
   │                                  │                                │     con piatti e note
   │                                  │                                │
   │                                  │                                │  8. Chef marca piatto
   │                                  │                                │     come "in preparazione"
   │                                  │                                │─>│
   │                                  │                                │
   │                                  │                                │  9. Chef marca piatto
   │                                  │                                │     come "pronto"
   │                                  │  <──────────────────────────── │
   │  10. Cameriere vede piatto      │  Realtime → Sala               │
   │      pronto per servizio        │                                │
   │<─────────────────────────────── │                                │
   │                                  │                                │
   │  11. Cameriere serve piatto     │                                │
   │      e marca "servito"          │                                │
   │─────────────────────────────────>│                                │
   │                                  │                                │
   │  12. Cameriere chiude tavolo    │                                │
   │      (richiedi conto)           │                                │
   │─────────────────────────────────>│                                │
   │                                  │  13. Calcola totale:           │
   │                                  │      SUM(qty × prezzo_vendita) │
   │                                  │      UPDATE orders (closed)    │
   │                                  │      UPDATE tables (free)      │
   │                                  │                                │
   │  14. Mostra riepilogo conto     │                                │
   │<─────────────────────────────── │                                │
```

---

## Flow 2: Carico Merci con Barcode

```
OPERATORE                         SISTEMA                         DATABASE
   │                                 │                                │
   │  1. Apre sezione               │                                │
   │     "Carico Merci"             │                                │
   │────────────────────────────────>│                                │
   │                                 │                                │
   │  2. Scansiona barcode          │                                │
   │     (camera telefono)          │                                │
   │────────────────────────────────>│                                │
   │                                 │  3. Cerca ingrediente          │
   │                                 │     WHERE barcode = ?          │
   │                                 │────────────────────────────────>│
   │                                 │                                │
   │                                 │  Se TROVATO:                   │
   │                                 │  ← nome, unita, ultimo prezzo  │
   │                                 │                                │
   │                                 │  Se NON TROVATO:               │
   │                                 │  ← "Barcode sconosciuto"       │
   │                                 │    Chiedi: "A quale ingrediente│
   │                                 │    associo questo barcode?"    │
   │                                 │                                │
   │  4. Inserisce:                  │                                │
   │     - Quantita                  │                                │
   │     - Numero lotto              │                                │
   │     - Data scadenza             │                                │
   │     - Prezzo unitario           │                                │
   │     - Fornitore                 │                                │
   │────────────────────────────────>│                                │
   │                                 │  5. Transazione atomica:       │
   │                                 │     - INSERT stock_batches     │
   │                                 │     - UPDATE stock (+qty)      │
   │                                 │     - INSERT stock_movements   │
   │                                 │     - UPDATE supplier_prices   │
   │                                 │────────────────────────────────>│
   │                                 │                                │
   │  6. Conferma: "Caricato!       │                                │
   │     2kg guanciale (lotto L42)  │                                │
   │     scadenza 15/03/2025"       │                                │
   │<────────────────────────────── │                                │
```

---

## Flow 3: AI Food Cost Analysis

```
RISTORATORE                       AI ASSISTANT                     WORKERS
   │                                 │                                │
   │  "Quanto mi costa               │                                │
   │   la carbonara?"                │                                │
   │────────────────────────────────>│                                │
   │                                 │  1. Intent Detection           │
   │                                 │     → FOOD_COST_QUERY          │
   │                                 │     entity: "carbonara"        │
   │                                 │                                │
   │                                 │  2. Attiva FoodCostWorker     │
   │                                 │────────────────────────────────>│
   │                                 │                                │  3. Cerca ricetta
   │                                 │                                │  4. Carica ingredienti
   │                                 │                                │     con prezzi fornitori
   │                                 │                                │  5. Calcola:
   │                                 │                                │     pasta: 0.15×1.50 = 0.23€
   │                                 │                                │     uova: 3×0.30 = 0.90€
   │                                 │                                │     guanciale: 0.1×18/1.0=1.80€
   │                                 │                                │     pecorino: 0.03×22 = 0.66€
   │                                 │                                │     TOTALE: 3.59€
   │                                 │                                │     Margine: 74.4%
   │                                 │  <────────────────────────────│
   │                                 │                                │
   │  "La carbonara ti costa        │                                │
   │   3.59€. Prezzo vendita 14€.   │                                │
   │   Margine: 74.4% ✅             │                                │
   │   Dettaglio: pasta 0.23€,      │                                │
   │   uova 0.90€, guanciale 1.80€, │                                │
   │   pecorino 0.66€"              │                                │
   │<────────────────────────────── │                                │
   │                                 │                                │
   │  "E per il filetto?"           │                                │
   │────────────────────────────────>│                                │
   │                                 │  Intent: FOOD_COST_QUERY      │
   │                                 │  entity: "filetto"            │
   │                                 │────────────────────────────────>│
   │                                 │                                │  Calcola...
   │                                 │                                │  filetto: 0.2×35/0.7 = 10€
   │                                 │                                │  Margine: 54.5% ⚠️
   │                                 │  <────────────────────────────│
   │  "Il filetto ti costa 10€      │                                │
   │   (resa 70%, serve più carne   │                                │
   │   lorda). Prezzo vendita 22€.  │                                │
   │   Margine: 54.5% ⚠️            │                                │
   │   Potresti alzare il prezzo    │                                │
   │   a 24€ per un margine >58%"   │                                │
   │<────────────────────────────── │                                │
```

---

## Flow 4: Suggerimento Ordini AI

```
RISTORATORE                       AI ASSISTANT                     SISTEMA
   │                                 │                                │
   │  "Cosa devo ordinare?"         │                                │
   │────────────────────────────────>│                                │
   │                                 │  Intent: ORDER_SUGGESTION     │
   │                                 │                                │
   │                                 │  1. Controlla stock:           │
   │                                 │     → Ingredienti sotto soglia │
   │                                 │     → Ingredienti in scadenza  │
   │                                 │────────────────────────────────>│
   │                                 │                                │
   │                                 │  2. (Futuro) Analizza storico: │
   │                                 │     → Media vendite/giorno     │
   │                                 │     → Giorno settimana         │
   │                                 │     → Stagionalita             │
   │                                 │────────────────────────────────>│
   │                                 │                                │
   │                                 │  3. Per ogni ingrediente:      │
   │                                 │     → Trova miglior fornitore  │
   │                                 │     → Calcola quantita         │
   │                                 │     → Stima costo              │
   │                                 │                                │
   │  "Ecco i suggerimenti:         │                                │
   │                                 │                                │
   │   🔴 URGENTE:                   │                                │
   │   • Guanciale: 0/2 kg          │                                │
   │     Ordina 4kg da Salumeria    │                                │
   │     Rossi (18€/kg = 72€)      │                                │
   │                                 │                                │
   │   🟡 PRESTO:                    │                                │
   │   • Mozzarella: 0.5/2 kg      │                                │
   │     Ordina 3.5kg da Caseificio │                                │
   │     Napoli (8€/kg = 28€)      │                                │
   │                                 │                                │
   │   Totale stimato: 100€"        │                                │
   │<────────────────────────────── │                                │
```

---

## Flow 5: Gestione Scadenze (FIFO)

```
SISTEMA (automatico/giornaliero)
   │
   │  1. Controlla tutti i lotti attivi
   │     WHERE quantity_remaining > 0
   │     AND expiry_date IS NOT NULL
   │
   │  2. Classifica per urgenza:
   │
   │     🔴 SCADUTO (expiry_date < oggi)
   │     → Alert immediato al manager
   │     → Suggerisci scarico (perdita/spreco)
   │
   │     🟡 DOMANI (expiry_date = domani)
   │     → Alert al manager
   │     → Suggerisci: usare oggi in menu del giorno
   │
   │     📅 ENTRO 3 GIORNI
   │     → Notifica nel dashboard
   │     → Suggerisci: prioritizzare nelle ricette
   │
   │  3. Quando arriva una comanda:
   │     → FIFO automatico
   │     → Usa PRIMA i lotti con scadenza piu vicina
   │     → Il sistema aiuta a ruotare lo stock naturalmente
   │
   │  4. Report settimanale spreco:
   │     → Kg buttati per scadenza
   │     → Valore economico perso
   │     → Trend rispetto settimane precedenti
```

---

## Flow 6: Onboarding Nuovo Ristorante

```
RISTORATORE                       SISTEMA
   │
   │  1. Registrazione
   │     (email + password + nome ristorante)
   │─────────────────────────────>│
   │                               │  → Crea account
   │                               │  → Crea ristorante
   │                               │  → Assegna utente a ristorante
   │
   │  2. Setup guidato (wizard):
   │
   │  Step A: Categorie Ingredienti
   │  (pre-caricati: Carne, Pesce, Latticini,
   │   Verdura, Pasta, Condimenti, Bevande)
   │  → Il ristoratore puo aggiungerne
   │
   │  Step B: Primi Ingredienti
   │  (inserimento bulk o da template)
   │  → Nome, unita, categoria, fattore resa
   │
   │  Step C: Primi Fornitori
   │  (almeno 1 fornitore con listino base)
   │
   │  Step D: Prima Ricetta
   │  (tutorial guidato: distinta base + food cost)
   │
   │  Step E: Tavoli
   │  (quanti tavoli, zone)
   │
   │  3. Dashboard attiva!
   │     → Il ristoratore puo usare il sistema
   │
   │  4. Prima settimana:
   │     AI suggerisce completamento dati
   │     "Hai 5 ricette senza distinta base,
   │      vuoi compilarle ora?"
```
