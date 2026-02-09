---
title: "Sprint 3: Magazzino"
scope: sprint
audience: engineering
owner: engineering
status: active
updated: 2026-02-09
---

# Sprint 3: Magazzino — Stock, Scarico Automatico, Scadenze, Barcode

**Obiettivo**: Gestione completa magazzino con carico/scarico merci, scarico automatico da comanda (distinta base), monitoraggio scadenze FIFO, e scansione barcode per carico rapido.

**Durata stimata**: 2-3 settimane

**Prerequisito**: Sprint 2 completato (comande funzionanti, Kitchen Display attivo)

---

## Cosa si costruisce

1. **Dashboard Magazzino** — Vista stock attuale con alert soglie minime e scadenze
2. **Carico Merci** — Inserimento manuale o con barcode, lotto, scadenza
3. **Scarico Automatico** — Quando parte una comanda, gli ingredienti si scaricano dalla distinta base
4. **Gestione Scadenze** — FIFO automatico, alert prodotti in scadenza
5. **Scanner Barcode** — Scansione da camera del telefono per carico rapido

---

## Step 1: Server Actions — Magazzino

### `actions/inventory.ts`

```
getStockOverview(restaurantId)     → vista stock con alert
getStockItem(ingredientId)         → dettaglio stock + lotti attivi
loadStock(data)                    → carico merci (nuovo lotto)
unloadStock(data)                  → scarico manuale
autoUnloadFromOrder(orderId)       → scarico automatico da comanda
getExpiringItems(days)             → prodotti in scadenza entro N giorni
getStockAlerts()                   → prodotti sotto soglia minima
getStockMovements(ingredientId)    → storico movimenti (carico/scarico)
```

### Logica FIFO — Il cuore del magazzino

```typescript
// lib/inventory/fifo.ts

export interface StockBatch {
  id: string;
  ingredient_id: string;
  quantity_remaining: number; // quantita ancora disponibile nel lotto
  expiry_date: string | null; // data scadenza
  lot_number: string | null;
  loaded_at: string;          // data carico
  unit_cost: number;          // costo unitario al momento del carico
}

/**
 * Scarica una quantita dal magazzino usando logica FIFO.
 * Consuma prima i lotti con scadenza piu vicina.
 *
 * @returns Array di movimenti (un movimento per ogni lotto toccato)
 */
export function calculateFifoUnload(
  batches: StockBatch[],
  quantityNeeded: number
): {
  movements: Array<{
    batch_id: string;
    quantity_consumed: number;
    unit_cost: number;
  }>;
  totalCost: number;
  remainingQuantity: number; // > 0 se stock insufficiente
} {
  // Ordina per scadenza (FIFO): prima quelli con scadenza piu vicina
  // I lotti senza scadenza vanno alla fine
  const sorted = [...batches]
    .filter((b) => b.quantity_remaining > 0)
    .sort((a, b) => {
      if (!a.expiry_date && !b.expiry_date) {
        // Entrambi senza scadenza: ordina per data carico (piu vecchio prima)
        return new Date(a.loaded_at).getTime() - new Date(b.loaded_at).getTime();
      }
      if (!a.expiry_date) return 1;  // Senza scadenza → in fondo
      if (!b.expiry_date) return -1;
      return new Date(a.expiry_date).getTime() - new Date(b.expiry_date).getTime();
    });

  let remaining = quantityNeeded;
  let totalCost = 0;
  const movements: Array<{
    batch_id: string;
    quantity_consumed: number;
    unit_cost: number;
  }> = [];

  for (const batch of sorted) {
    if (remaining <= 0) break;

    const consumed = Math.min(remaining, batch.quantity_remaining);
    movements.push({
      batch_id: batch.id,
      quantity_consumed: consumed,
      unit_cost: batch.unit_cost,
    });

    totalCost += consumed * batch.unit_cost;
    remaining -= consumed;
  }

  return {
    movements,
    totalCost,
    remainingQuantity: Math.max(0, remaining),
  };
}

/**
 * Identifica prodotti in scadenza entro N giorni
 */
export function findExpiringBatches(
  batches: StockBatch[],
  withinDays: number
): StockBatch[] {
  const deadline = new Date();
  deadline.setDate(deadline.getDate() + withinDays);

  return batches.filter((b) => {
    if (!b.expiry_date || b.quantity_remaining <= 0) return false;
    return new Date(b.expiry_date) <= deadline;
  });
}
```

### Scarico automatico da comanda

```typescript
// actions/inventory.ts

export async function autoUnloadFromOrder(orderId: string) {
  const user = await getCurrentUser();
  if (!user) return { success: false, error: 'Non autenticato' };

  // 1. Ottieni items dell'ordine con ricette e ingredienti
  const { data: orderItems } = await supabaseAdmin
    .from('order_items')
    .select(`
      quantity,
      recipe:recipes(
        id,
        portions,
        recipe_ingredients(
          ingredient_id,
          quantity,
          unit,
          ingredient:ingredients(
            id,
            name,
            yield_factor
          )
        )
      )
    `)
    .eq('order_id', orderId)
    .neq('status', 'cancelled');

  if (!orderItems) return { success: false, error: 'Ordine non trovato' };

  const movements: any[] = [];
  const alerts: string[] = [];

  // 2. Per ogni piatto ordinato, scarica ingredienti
  for (const item of orderItems) {
    const recipe = item.recipe as any;
    if (!recipe?.recipe_ingredients) continue;

    for (const ri of recipe.recipe_ingredients) {
      // Dose necessaria = dose_ricetta × quantita_ordinata / porzioni_ricetta
      const doseNeeded =
        (ri.quantity * item.quantity) / (recipe.portions || 1);

      // Considera fattore resa: servono piu grammi lordi
      const grossQuantity = doseNeeded / (ri.ingredient?.yield_factor || 1);

      // 3. Ottieni lotti disponibili per questo ingrediente
      const { data: batches } = await supabaseAdmin
        .from('stock_batches')
        .select('*')
        .eq('ingredient_id', ri.ingredient_id)
        .gt('quantity_remaining', 0)
        .order('expiry_date', { ascending: true, nullsFirst: false })
        .order('loaded_at', { ascending: true });

      if (!batches || batches.length === 0) {
        alerts.push(`Stock esaurito: ${ri.ingredient?.name}`);
        continue;
      }

      // 4. Calcola scarico FIFO
      const fifo = calculateFifoUnload(batches, grossQuantity);

      // 5. Registra movimenti
      for (const mov of fifo.movements) {
        // Aggiorna lotto
        await supabaseAdmin
          .from('stock_batches')
          .update({
            quantity_remaining: supabaseAdmin.rpc('decrement', {
              row_id: mov.batch_id,
              amount: mov.quantity_consumed,
            }),
          })
          .eq('id', mov.batch_id);

        // Registra movimento
        movements.push({
          ingredient_id: ri.ingredient_id,
          batch_id: mov.batch_id,
          type: 'unload_auto',
          quantity: -mov.quantity_consumed,
          unit_cost: mov.unit_cost,
          reference_type: 'order',
          reference_id: orderId,
          notes: `Scarico automatico da comanda`,
        });
      }

      // 6. Aggiorna stock totale
      await supabaseAdmin.rpc('update_stock_quantity', {
        p_ingredient_id: ri.ingredient_id,
        p_delta: -grossQuantity,
      });

      // 7. Alert se stock insufficiente
      if (fifo.remainingQuantity > 0) {
        alerts.push(
          `${ri.ingredient?.name}: mancano ${fifo.remainingQuantity.toFixed(3)} ${ri.unit}`
        );
      }

      // 8. Alert se sotto soglia minima
      const { data: stock } = await supabaseAdmin
        .from('stock')
        .select('current_quantity, min_quantity')
        .eq('ingredient_id', ri.ingredient_id)
        .single();

      if (stock && stock.current_quantity < stock.min_quantity) {
        alerts.push(
          `${ri.ingredient?.name}: sotto soglia minima (${stock.current_quantity} / ${stock.min_quantity})`
        );
      }
    }
  }

  // 9. Inserisci tutti i movimenti in batch
  if (movements.length > 0) {
    await supabaseAdmin.from('stock_movements').insert(movements);
  }

  return { success: true, movements: movements.length, alerts };
}
```

## Step 2: Carico Merci con Barcode

### Scanner Barcode

```typescript
// components/magazzino/barcode-scanner.tsx
'use client';

import { useEffect, useRef, useState } from 'react';

interface BarcodeScannerProps {
  onScan: (barcode: string) => void;
  onClose: () => void;
}

export function BarcodeScanner({ onScan, onClose }: BarcodeScannerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let scanner: any = null;

    async function initScanner() {
      try {
        // Usa html5-qrcode per scansione barcode
        const { Html5Qrcode } = await import('html5-qrcode');
        scanner = new Html5Qrcode('barcode-reader');

        await scanner.start(
          { facingMode: 'environment' }, // Camera posteriore
          {
            fps: 10,
            qrbox: { width: 250, height: 150 },
          },
          (decodedText: string) => {
            // Barcode riconosciuto!
            onScan(decodedText);
            scanner.stop();
          },
          () => {
            // Errore decodifica (normale, continua a scansionare)
          }
        );
      } catch (err: any) {
        setError('Camera non disponibile. Inserisci il barcode manualmente.');
      }
    }

    initScanner();

    return () => {
      scanner?.stop?.().catch(() => {});
    };
  }, []);

  return (
    <div className="fixed inset-0 bg-black/80 z-50 flex flex-col items-center justify-center">
      <div className="bg-white rounded-lg p-4 max-w-md w-full">
        <h3 className="text-lg font-bold mb-2">Scansiona Barcode</h3>

        {error ? (
          <p className="text-red-500">{error}</p>
        ) : (
          <div id="barcode-reader" className="w-full" />
        )}

        <button
          onClick={onClose}
          className="mt-4 w-full py-2 bg-gray-200 rounded-lg"
        >
          Annulla
        </button>
      </div>
    </div>
  );
}
```

### Pagina Carico Merci

```typescript
// Struttura: app/dashboard/magazzino/carico/page.tsx

// 1. Bottone "Scansiona Barcode" → apre scanner
// 2. Scanner riconosce barcode → cerca ingrediente associato
//    - Se trovato: pre-compila form con nome, unita
//    - Se NON trovato: chiede di associare barcode a un ingrediente esistente
// 3. Form carico: Ingrediente | Quantita | Lotto | Data Scadenza | Prezzo Unitario | Fornitore
// 4. Submit → INSERT stock_batches + UPDATE stock + INSERT stock_movements
```

## Step 3: Dashboard Magazzino

### `app/dashboard/magazzino/page.tsx`

Struttura:
- **Alert Bar** (in alto): prodotti sotto soglia, prodotti in scadenza
- **Tabella Stock**: Ingrediente | Stock Attuale | Unita | Soglia Min | Stato | Azioni
  - Stato: badge verde/giallo/rosso
  - Azioni: Carica, Scarica manuale, Dettaglio
- **Filtri**: categoria, stato (tutti/alert/scadenza), ricerca nome
- **Quick Actions**: "Carico rapido con barcode", "Export inventario"

**Componenti:**
- `components/magazzino/stock-table.tsx` — tabella stock con filtri e ordinamento
- `components/magazzino/stock-alerts.tsx` — banner alert per soglie e scadenze
- `components/magazzino/load-stock-form.tsx` — form carico merci
- `components/magazzino/batch-details.tsx` — dettaglio lotti per ingrediente
- `components/magazzino/movement-history.tsx` — storico movimenti

### Alert Scadenze

```typescript
// components/magazzino/expiry-alerts.tsx
'use client';

interface ExpiryAlert {
  ingredient_name: string;
  lot_number: string | null;
  expiry_date: string;
  quantity_remaining: number;
  unit: string;
  days_until_expiry: number;
}

export function ExpiryAlerts({ alerts }: { alerts: ExpiryAlert[] }) {
  if (alerts.length === 0) return null;

  // Ordina per urgenza
  const sorted = [...alerts].sort(
    (a, b) => a.days_until_expiry - b.days_until_expiry
  );

  return (
    <div className="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-4">
      <h3 className="font-bold text-orange-800 mb-2">
        Prodotti in scadenza ({alerts.length})
      </h3>
      <div className="space-y-2">
        {sorted.map((alert, i) => (
          <div
            key={i}
            className={`flex justify-between items-center p-2 rounded ${
              alert.days_until_expiry <= 1
                ? 'bg-red-100 text-red-800'
                : alert.days_until_expiry <= 3
                  ? 'bg-orange-100 text-orange-800'
                  : 'bg-yellow-100 text-yellow-800'
            }`}
          >
            <div>
              <span className="font-medium">{alert.ingredient_name}</span>
              {alert.lot_number && (
                <span className="text-sm ml-2">(Lotto: {alert.lot_number})</span>
              )}
            </div>
            <div className="text-right text-sm">
              <div>{alert.quantity_remaining.toFixed(2)} {alert.unit}</div>
              <div className="font-bold">
                {alert.days_until_expiry <= 0
                  ? 'SCADUTO!'
                  : alert.days_until_expiry === 1
                    ? 'Scade domani'
                    : `Scade tra ${alert.days_until_expiry} giorni`}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Step 4: Collegamento Comanda → Scarico Magazzino

Il flusso critico che collega Sprint 2 e Sprint 3:

```
1. Cameriere crea comanda (Sprint 2)
   │
2. INSERT order_items con status = 'sent'
   │
3. Trigger lato applicazione (nella createOrder action):
   │  await autoUnloadFromOrder(order.id)
   │
4. Per ogni piatto ordinato:
   │  → Leggi distinta base (recipe_ingredients)
   │  → Per ogni ingrediente:
   │     → quantita_lorda = dose × porzioni_ordinate / yield_factor
   │     → FIFO: consuma dai lotti con scadenza piu vicina
   │     → UPDATE stock_batches (riduci quantity_remaining)
   │     → INSERT stock_movements (tipo: 'unload_auto')
   │     → UPDATE stock (riduci current_quantity)
   │     → Se current_quantity < min_quantity → genera alert
   │
5. Se stock insufficiente → alert al cameriere/manager
   (NON blocca la comanda: la cucina deve comunque preparare)
```

**IMPORTANTE**: Lo scarico NON blocca mai la comanda. Se manca un ingrediente in magazzino, si genera un alert ma il piatto viene comunque preparato. Questo perche:
- Il magazzino potrebbe non essere aggiornato (carico non registrato)
- Il ristorante non puo dire al cliente "non possiamo fare la carbonara" perche il software dice stock = 0
- L'alert serve al manager per capire che deve fare un ordine al fornitore

## Step 5: Test

### `tests/unit/fifo-inventory.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { calculateFifoUnload, findExpiringBatches } from '@/lib/inventory/fifo';
import type { StockBatch } from '@/lib/inventory/fifo';

describe('FIFO Inventory', () => {
  const baseBatches: StockBatch[] = [
    {
      id: 'b1',
      ingredient_id: 'ing1',
      quantity_remaining: 2.0,
      expiry_date: '2025-03-15',
      lot_number: 'L001',
      loaded_at: '2025-03-01',
      unit_cost: 5.00,
    },
    {
      id: 'b2',
      ingredient_id: 'ing1',
      quantity_remaining: 3.0,
      expiry_date: '2025-03-20',
      lot_number: 'L002',
      loaded_at: '2025-03-05',
      unit_cost: 5.50,
    },
    {
      id: 'b3',
      ingredient_id: 'ing1',
      quantity_remaining: 5.0,
      expiry_date: null, // senza scadenza
      lot_number: 'L003',
      loaded_at: '2025-03-10',
      unit_cost: 4.80,
    },
  ];

  it('consuma prima il lotto con scadenza piu vicina', () => {
    const result = calculateFifoUnload(baseBatches, 1.5);

    expect(result.movements).toHaveLength(1);
    expect(result.movements[0].batch_id).toBe('b1'); // scadenza 15/03
    expect(result.movements[0].quantity_consumed).toBeCloseTo(1.5, 2);
    expect(result.remainingQuantity).toBe(0);
  });

  it('attraversa piu lotti se necessario', () => {
    const result = calculateFifoUnload(baseBatches, 4.0);

    // b1: 2.0 (tutto) + b2: 2.0 (parziale) = 4.0
    expect(result.movements).toHaveLength(2);
    expect(result.movements[0].batch_id).toBe('b1');
    expect(result.movements[0].quantity_consumed).toBeCloseTo(2.0, 2);
    expect(result.movements[1].batch_id).toBe('b2');
    expect(result.movements[1].quantity_consumed).toBeCloseTo(2.0, 2);
    expect(result.remainingQuantity).toBe(0);
  });

  it('lotti senza scadenza consumati per ultimi', () => {
    const result = calculateFifoUnload(baseBatches, 6.0);

    // b1: 2.0 + b2: 3.0 + b3: 1.0 = 6.0
    expect(result.movements).toHaveLength(3);
    expect(result.movements[2].batch_id).toBe('b3'); // senza scadenza → ultimo
    expect(result.remainingQuantity).toBe(0);
  });

  it('segnala quantita mancante se stock insufficiente', () => {
    const result = calculateFifoUnload(baseBatches, 12.0);

    // Totale disponibile: 2 + 3 + 5 = 10
    expect(result.remainingQuantity).toBeCloseTo(2.0, 2);
    expect(result.movements).toHaveLength(3);
  });

  it('calcola costo totale correttamente (media ponderata FIFO)', () => {
    const result = calculateFifoUnload(baseBatches, 3.0);

    // b1: 2.0 × 5.00 = 10.00
    // b2: 1.0 × 5.50 = 5.50
    // Totale: 15.50
    expect(result.totalCost).toBeCloseTo(15.50, 2);
  });

  it('lista vuota → tutto mancante', () => {
    const result = calculateFifoUnload([], 5.0);
    expect(result.movements).toHaveLength(0);
    expect(result.remainingQuantity).toBeCloseTo(5.0, 2);
    expect(result.totalCost).toBe(0);
  });

  it('quantita zero → nessun movimento', () => {
    const result = calculateFifoUnload(baseBatches, 0);
    expect(result.movements).toHaveLength(0);
    expect(result.totalCost).toBe(0);
  });
});

describe('Scadenze', () => {
  const batches: StockBatch[] = [
    {
      id: 'b1',
      ingredient_id: 'ing1',
      quantity_remaining: 2.0,
      expiry_date: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000).toISOString(), // domani
      lot_number: 'L001',
      loaded_at: '2025-01-01',
      unit_cost: 5.0,
    },
    {
      id: 'b2',
      ingredient_id: 'ing2',
      quantity_remaining: 3.0,
      expiry_date: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(), // tra 5 giorni
      lot_number: 'L002',
      loaded_at: '2025-01-01',
      unit_cost: 8.0,
    },
    {
      id: 'b3',
      ingredient_id: 'ing3',
      quantity_remaining: 1.0,
      expiry_date: null, // senza scadenza
      lot_number: 'L003',
      loaded_at: '2025-01-01',
      unit_cost: 3.0,
    },
    {
      id: 'b4',
      ingredient_id: 'ing4',
      quantity_remaining: 0, // esaurito
      expiry_date: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000).toISOString(),
      lot_number: 'L004',
      loaded_at: '2025-01-01',
      unit_cost: 4.0,
    },
  ];

  it('trova prodotti in scadenza entro 3 giorni', () => {
    const expiring = findExpiringBatches(batches, 3);
    expect(expiring).toHaveLength(1);
    expect(expiring[0].id).toBe('b1');
  });

  it('trova prodotti in scadenza entro 7 giorni', () => {
    const expiring = findExpiringBatches(batches, 7);
    expect(expiring).toHaveLength(2); // b1 e b2
  });

  it('esclude lotti esauriti', () => {
    const expiring = findExpiringBatches(batches, 3);
    expect(expiring.find((b) => b.id === 'b4')).toBeUndefined();
  });

  it('esclude lotti senza scadenza', () => {
    const expiring = findExpiringBatches(batches, 365);
    expect(expiring.find((b) => b.id === 'b3')).toBeUndefined();
  });
});
```

## Checklist Sprint 3

- [ ] Dashboard magazzino con stock attuale
- [ ] Alert prodotti sotto soglia minima
- [ ] Alert prodotti in scadenza (1g, 3g, 7g)
- [ ] Carico merci manuale (form)
- [ ] Carico merci con barcode scanner
- [ ] Associazione barcode ↔ ingrediente
- [ ] Scarico automatico da comanda (FIFO)
- [ ] Scarico manuale (perdite, scarti)
- [ ] Storico movimenti per ingrediente
- [ ] Logica FIFO: consuma prima i lotti con scadenza vicina
- [ ] Lo scarico NON blocca mai la comanda
- [ ] Test FIFO: tutti verdi
- [ ] Test scadenze: tutti verdi
- [ ] `npm run build` zero errori

**Quando tutto verde → procedi a Sprint 4**
