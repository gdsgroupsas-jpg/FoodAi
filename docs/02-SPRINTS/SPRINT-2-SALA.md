---
title: "Sprint 2: Gestionale Sala"
scope: sprint
audience: engineering
owner: engineering
status: active
updated: 2026-02-09
---

# Sprint 2: Gestionale Sala — Tavoli, Comande, Kitchen Display

**Obiettivo**: Gestione tavoli con stati, creazione comande con selezione piatti dal menu, invio ordini in cucina via Realtime, Kitchen Display per chef.

**Durata stimata**: 2-3 settimane

**Prerequisito**: Sprint 1 completato (ricette, ingredienti, fornitori funzionanti)

---

## Cosa si costruisce

1. **Gestione Tavoli** — CRUD tavoli con stati (libero, occupato, prenotato, conto)
2. **Creazione Comanda** — Selezione piatti dal menu, note, varianti
3. **Invio Cucina** — Supabase Realtime per notifica istantanea alla cucina
4. **Kitchen Display** — Schermo cucina con ordini in arrivo, stati preparazione
5. **Chiusura Tavolo** — Riepilogo conto, scontrino

---

## Step 1: Server Actions — Tavoli

### `actions/tables.ts`

```
listTables(restaurantId)          → lista tavoli con stato corrente
getTable(id)                      → dettaglio tavolo con comande attive
createTable(data)                 → crea nuovo tavolo
updateTable(id, data)             → aggiorna (nome, posti, zona)
deleteTable(id)                   → soft delete
updateTableStatus(id, status)     → cambia stato tavolo
```

### Schema dati tavolo

```typescript
// types/tables.ts
import { z } from 'zod';

export const tableStatusEnum = z.enum([
  'free',       // Libero
  'occupied',   // Occupato (comanda attiva)
  'reserved',   // Prenotato
  'bill',       // In attesa di conto
]);

export const tableSchema = z.object({
  name: z.string().min(1, 'Nome obbligatorio').max(50),
  seats: z.number().int().min(1).max(50).default(4),
  zone: z.string().max(50).optional(), // es: "Sala", "Terrazza", "Privé"
  position_x: z.number().optional(),   // per mappa visuale
  position_y: z.number().optional(),
});

export type TableInput = z.infer<typeof tableSchema>;
export type TableStatus = z.infer<typeof tableStatusEnum>;
```

### Server Action pattern

```typescript
'use server';

import { supabaseAdmin } from '@/lib/db/client';
import { getCurrentUser } from '@/lib/db/auth';

export async function listTables() {
  const user = await getCurrentUser();
  if (!user) return { success: false, error: 'Non autenticato' };

  const { data: userData } = await supabaseAdmin
    .from('users')
    .select('restaurant_id')
    .eq('auth_user_id', user.id)
    .single();

  if (!userData) return { success: false, error: 'Utente non trovato' };

  const { data, error } = await supabaseAdmin
    .from('tables')
    .select('*')
    .eq('restaurant_id', userData.restaurant_id)
    .eq('is_active', true)
    .order('name');

  if (error) return { success: false, error: error.message };
  return { success: true, tables: data };
}

export async function updateTableStatus(
  tableId: string,
  status: 'free' | 'occupied' | 'reserved' | 'bill'
) {
  const user = await getCurrentUser();
  if (!user) return { success: false, error: 'Non autenticato' };

  const { error } = await supabaseAdmin
    .from('tables')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', tableId);

  if (error) return { success: false, error: error.message };
  return { success: true };
}
```

## Step 2: Pagina UI — Mappa Tavoli

### `app/dashboard/sala/page.tsx`

Layout a griglia visuale dei tavoli:
- Ogni tavolo è una card con colore per stato:
  - **Verde** = libero
  - **Rosso** = occupato
  - **Giallo** = prenotato
  - **Blu** = conto richiesto
- Click su tavolo libero → apri comanda
- Click su tavolo occupato → vedi comanda attiva
- Bottone "Aggiungi Tavolo" per gestione

**Componenti da creare:**
- `components/sala/table-grid.tsx` — griglia tavoli con drag & drop (opzionale)
- `components/sala/table-card.tsx` — singolo tavolo con stato e info
- `components/sala/table-form.tsx` — form creazione/modifica tavolo

### Esempio TableCard

```typescript
// components/sala/table-card.tsx
'use client';

interface TableCardProps {
  table: {
    id: string;
    name: string;
    seats: number;
    status: string;
    zone?: string;
  };
  onClick: (tableId: string) => void;
}

const statusColors: Record<string, string> = {
  free: 'bg-green-100 border-green-500 hover:bg-green-200',
  occupied: 'bg-red-100 border-red-500 hover:bg-red-200',
  reserved: 'bg-yellow-100 border-yellow-500 hover:bg-yellow-200',
  bill: 'bg-blue-100 border-blue-500 hover:bg-blue-200',
};

const statusLabels: Record<string, string> = {
  free: 'Libero',
  occupied: 'Occupato',
  reserved: 'Prenotato',
  bill: 'Conto',
};

export function TableCard({ table, onClick }: TableCardProps) {
  return (
    <button
      onClick={() => onClick(table.id)}
      className={`
        p-4 rounded-lg border-2 min-w-[120px] min-h-[100px]
        flex flex-col items-center justify-center gap-1
        transition-colors cursor-pointer
        ${statusColors[table.status] || statusColors.free}
      `}
    >
      <span className="font-bold text-lg">{table.name}</span>
      <span className="text-sm text-gray-600">{table.seats} posti</span>
      <span className="text-xs font-medium">
        {statusLabels[table.status]}
      </span>
    </button>
  );
}
```

## Step 3: Server Actions — Comande

### `actions/orders.ts`

```
createOrder(tableId, items)       → crea comanda con lista piatti
getOrder(orderId)                 → dettaglio comanda con items
getActiveOrderByTable(tableId)    → comanda attiva del tavolo
addOrderItem(orderId, item)       → aggiungi piatto a comanda esistente
updateOrderItemStatus(itemId, s)  → aggiorna stato item (preparazione, pronto, servito)
closeOrder(orderId)               → chiudi comanda (calcola totale, libera tavolo)
listActiveOrders(restaurantId)    → tutte comande attive (per Kitchen Display)
```

### Tipo Comanda

```typescript
// types/orders.ts
import { z } from 'zod';

export const orderItemSchema = z.object({
  recipe_id: z.string().uuid(),
  quantity: z.number().int().min(1).default(1),
  notes: z.string().max(200).optional(), // "senza cipolla", "ben cotta"
});

export const createOrderSchema = z.object({
  table_id: z.string().uuid(),
  items: z.array(orderItemSchema).min(1, 'Almeno un piatto'),
  covers: z.number().int().min(1).default(1), // coperti
});

export type OrderItemInput = z.infer<typeof orderItemSchema>;
export type CreateOrderInput = z.infer<typeof createOrderSchema>;

// Stati dell'item
export type OrderItemStatus =
  | 'pending'      // In attesa di invio
  | 'sent'         // Inviato in cucina
  | 'preparing'    // In preparazione
  | 'ready'        // Pronto per servizio
  | 'served'       // Servito al tavolo
  | 'cancelled';   // Annullato
```

### Creazione comanda con invio cucina

```typescript
'use server';

import { supabaseAdmin } from '@/lib/db/client';
import { getCurrentUser } from '@/lib/db/auth';
import { createOrderSchema, type CreateOrderInput } from '@/types/orders';

export async function createOrder(input: CreateOrderInput) {
  const user = await getCurrentUser();
  if (!user) return { success: false, error: 'Non autenticato' };

  // Valida input
  const parsed = createOrderSchema.safeParse(input);
  if (!parsed.success) {
    return { success: false, error: parsed.error.errors[0].message };
  }

  const { data: userData } = await supabaseAdmin
    .from('users')
    .select('restaurant_id')
    .eq('auth_user_id', user.id)
    .single();

  if (!userData) return { success: false, error: 'Utente non trovato' };

  // Crea ordine
  const { data: order, error: orderError } = await supabaseAdmin
    .from('orders')
    .insert({
      restaurant_id: userData.restaurant_id,
      table_id: parsed.data.table_id,
      waiter_id: user.id,
      covers: parsed.data.covers,
      status: 'active',
    })
    .select()
    .single();

  if (orderError) return { success: false, error: orderError.message };

  // Inserisci items
  const items = parsed.data.items.map((item) => ({
    order_id: order.id,
    recipe_id: item.recipe_id,
    quantity: item.quantity,
    notes: item.notes || null,
    status: 'sent', // Invio diretto in cucina
    sent_at: new Date().toISOString(),
  }));

  const { error: itemsError } = await supabaseAdmin
    .from('order_items')
    .insert(items);

  if (itemsError) return { success: false, error: itemsError.message };

  // Aggiorna stato tavolo → occupato
  await supabaseAdmin
    .from('tables')
    .update({ status: 'occupied' })
    .eq('id', parsed.data.table_id);

  return { success: true, orderId: order.id };
}
```

## Step 4: Pagina Comanda — Selezione Piatti

### `app/dashboard/sala/comanda/[tableId]/page.tsx`

Struttura:
- Header: "Tavolo {nome} — Nuova Comanda"
- Colonna sinistra: **Menu** (ricette raggruppate per categoria)
- Colonna destra: **Carrello** (piatti selezionati con quantita e note)
- Footer: Bottone "Invia in Cucina"

**Componenti:**
- `components/sala/menu-grid.tsx` — griglia piatti per categoria
- `components/sala/menu-item-card.tsx` — singolo piatto cliccabile
- `components/sala/order-cart.tsx` — carrello comanda con +/- quantita
- `components/sala/order-item-row.tsx` — riga carrello con note

### Menu con categorie

```typescript
// components/sala/menu-grid.tsx
'use client';

import { useState } from 'react';

interface Recipe {
  id: string;
  name: string;
  selling_price: number;
  category: { name: string } | null;
}

interface MenuGridProps {
  recipes: Recipe[];
  onAddItem: (recipeId: string) => void;
}

export function MenuGrid({ recipes, onAddItem }: MenuGridProps) {
  const [activeCategory, setActiveCategory] = useState<string | null>(null);

  // Raggruppa per categoria
  const categories = new Map<string, Recipe[]>();
  recipes.forEach((r) => {
    const cat = r.category?.name || 'Altro';
    if (!categories.has(cat)) categories.set(cat, []);
    categories.get(cat)!.push(r);
  });

  const categoryNames = Array.from(categories.keys());

  return (
    <div>
      {/* Tabs categorie */}
      <div className="flex gap-2 mb-4 overflow-x-auto">
        <button
          onClick={() => setActiveCategory(null)}
          className={`px-3 py-1 rounded-full text-sm ${
            activeCategory === null ? 'bg-primary text-white' : 'bg-gray-100'
          }`}
        >
          Tutti
        </button>
        {categoryNames.map((cat) => (
          <button
            key={cat}
            onClick={() => setActiveCategory(cat)}
            className={`px-3 py-1 rounded-full text-sm whitespace-nowrap ${
              activeCategory === cat ? 'bg-primary text-white' : 'bg-gray-100'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      {/* Griglia piatti */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        {recipes
          .filter((r) =>
            activeCategory ? (r.category?.name || 'Altro') === activeCategory : true
          )
          .map((recipe) => (
            <button
              key={recipe.id}
              onClick={() => onAddItem(recipe.id)}
              className="p-3 border rounded-lg hover:bg-gray-50 text-left"
            >
              <div className="font-medium">{recipe.name}</div>
              <div className="text-sm text-gray-500">
                {recipe.selling_price.toFixed(2)} EUR
              </div>
            </button>
          ))}
      </div>
    </div>
  );
}
```

## Step 5: Kitchen Display — Supabase Realtime

### `app/dashboard/cucina/page.tsx`

Schermo dedicato per la cucina (tablet appeso in cucina):
- Colonne Kanban: **In arrivo** → **In preparazione** → **Pronto**
- Ogni card = un ordine con lista piatti
- Click su piatto → cambia stato
- Audio alert quando arriva nuovo ordine

### Sottoscrizione Realtime

```typescript
// components/cucina/kitchen-display.tsx
'use client';

import { useEffect, useState } from 'react';
import { createBrowserClient } from '@supabase/ssr';

interface OrderItem {
  id: string;
  recipe_name: string;
  quantity: number;
  notes: string | null;
  status: string;
  table_name: string;
  order_id: string;
  sent_at: string;
}

export function KitchenDisplay({ restaurantId }: { restaurantId: string }) {
  const [items, setItems] = useState<OrderItem[]>([]);
  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    // Caricamento iniziale degli ordini attivi
    loadActiveItems();

    // Sottoscrizione Realtime per nuovi ordini
    const channel = supabase
      .channel('kitchen-orders')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'order_items',
        },
        (payload) => {
          // Nuovo piatto in arrivo → aggiungi alla lista e suona alert
          loadActiveItems();
          playAlertSound();
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'order_items',
          filter: `status=eq.ready`,
        },
        (payload) => {
          // Piatto marcato come pronto → aggiorna lista
          loadActiveItems();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  async function loadActiveItems() {
    // Query per ottenere tutti gli items attivi con join su ordini e tavoli
    const { data } = await supabase
      .from('order_items')
      .select(`
        id,
        quantity,
        notes,
        status,
        sent_at,
        recipe:recipes(name),
        order:orders(
          id,
          table:tables(name)
        )
      `)
      .in('status', ['sent', 'preparing', 'ready'])
      .order('sent_at', { ascending: true });

    if (data) {
      setItems(
        data.map((item: any) => ({
          id: item.id,
          recipe_name: item.recipe?.name || '???',
          quantity: item.quantity,
          notes: item.notes,
          status: item.status,
          table_name: item.order?.table?.name || '???',
          order_id: item.order?.id,
          sent_at: item.sent_at,
        }))
      );
    }
  }

  function playAlertSound() {
    try {
      const audio = new Audio('/sounds/new-order.mp3');
      audio.play();
    } catch (e) {
      // Fallback silenzioso se audio non disponibile
    }
  }

  // Raggruppa per stato
  const sent = items.filter((i) => i.status === 'sent');
  const preparing = items.filter((i) => i.status === 'preparing');
  const ready = items.filter((i) => i.status === 'ready');

  return (
    <div className="grid grid-cols-3 gap-4 h-screen p-4 bg-gray-900 text-white">
      {/* Colonna: In arrivo */}
      <KitchenColumn
        title="In Arrivo"
        items={sent}
        color="red"
        onStatusChange={(id) => updateItemStatus(id, 'preparing')}
      />
      {/* Colonna: In preparazione */}
      <KitchenColumn
        title="In Preparazione"
        items={preparing}
        color="yellow"
        onStatusChange={(id) => updateItemStatus(id, 'ready')}
      />
      {/* Colonna: Pronto */}
      <KitchenColumn
        title="Pronto"
        items={ready}
        color="green"
        onStatusChange={(id) => updateItemStatus(id, 'served')}
      />
    </div>
  );

  async function updateItemStatus(itemId: string, newStatus: string) {
    await supabase
      .from('order_items')
      .update({ status: newStatus })
      .eq('id', itemId);
    loadActiveItems();
  }
}

function KitchenColumn({
  title,
  items,
  color,
  onStatusChange,
}: {
  title: string;
  items: OrderItem[];
  color: string;
  onStatusChange: (id: string) => void;
}) {
  const colorMap: Record<string, string> = {
    red: 'border-red-500',
    yellow: 'border-yellow-500',
    green: 'border-green-500',
  };

  return (
    <div className={`border-t-4 ${colorMap[color]} bg-gray-800 rounded-lg p-3`}>
      <h2 className="text-xl font-bold mb-3">
        {title} ({items.length})
      </h2>
      <div className="space-y-3 overflow-y-auto" style={{ maxHeight: 'calc(100vh - 120px)' }}>
        {items.map((item) => (
          <button
            key={item.id}
            onClick={() => onStatusChange(item.id)}
            className="w-full text-left p-3 bg-gray-700 rounded-lg hover:bg-gray-600"
          >
            <div className="flex justify-between items-start">
              <span className="font-bold text-lg">
                {item.quantity}x {item.recipe_name}
              </span>
              <span className="text-sm text-gray-400">{item.table_name}</span>
            </div>
            {item.notes && (
              <div className="text-yellow-400 text-sm mt-1">
                ⚠ {item.notes}
              </div>
            )}
            <div className="text-xs text-gray-500 mt-1">
              {new Date(item.sent_at).toLocaleTimeString('it-IT', {
                hour: '2-digit',
                minute: '2-digit',
              })}
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
```

## Step 6: Chiusura Tavolo / Conto

### `actions/orders.ts` — closeOrder

```typescript
export async function closeOrder(orderId: string) {
  const user = await getCurrentUser();
  if (!user) return { success: false, error: 'Non autenticato' };

  // Ottieni ordine con items e prezzi
  const { data: order } = await supabaseAdmin
    .from('orders')
    .select(`
      id,
      table_id,
      covers,
      order_items(
        quantity,
        recipe:recipes(selling_price)
      )
    `)
    .eq('id', orderId)
    .single();

  if (!order) return { success: false, error: 'Ordine non trovato' };

  // Calcola totale
  const total = order.order_items.reduce((sum: number, item: any) => {
    return sum + (item.quantity * (item.recipe?.selling_price || 0));
  }, 0);

  // Aggiorna ordine come chiuso
  await supabaseAdmin
    .from('orders')
    .update({
      status: 'closed',
      total_amount: total,
      closed_at: new Date().toISOString(),
    })
    .eq('id', orderId);

  // Libera tavolo
  await supabaseAdmin
    .from('tables')
    .update({ status: 'free' })
    .eq('id', order.table_id);

  return { success: true, total };
}
```

## Step 7: Test

### `tests/unit/order-management.test.ts`

```typescript
import { describe, it, expect } from 'vitest';

// Test della logica di calcolo conto
describe('Calcolo Conto', () => {
  function calculateOrderTotal(
    items: Array<{ quantity: number; sellingPrice: number }>
  ): number {
    return items.reduce((sum, item) => sum + item.quantity * item.sellingPrice, 0);
  }

  it('calcola totale comanda semplice', () => {
    const total = calculateOrderTotal([
      { quantity: 2, sellingPrice: 14.00 }, // 2x Carbonara
      { quantity: 1, sellingPrice: 12.00 }, // 1x Amatriciana
      { quantity: 3, sellingPrice: 5.00 },  // 3x Acqua
    ]);
    expect(total).toBeCloseTo(55.00, 2);
  });

  it('comanda vuota = totale zero', () => {
    expect(calculateOrderTotal([])).toBe(0);
  });

  it('singolo piatto', () => {
    const total = calculateOrderTotal([
      { quantity: 1, sellingPrice: 22.00 },
    ]);
    expect(total).toBeCloseTo(22.00, 2);
  });
});

// Test stati tavolo
describe('Stati Tavolo', () => {
  const validTransitions: Record<string, string[]> = {
    free: ['occupied', 'reserved'],
    reserved: ['occupied', 'free'],
    occupied: ['bill', 'free'],  // free = comanda annullata
    bill: ['free'],              // dopo pagamento
  };

  function isValidTransition(from: string, to: string): boolean {
    return validTransitions[from]?.includes(to) ?? false;
  }

  it('tavolo libero puo diventare occupato', () => {
    expect(isValidTransition('free', 'occupied')).toBe(true);
  });

  it('tavolo libero puo diventare prenotato', () => {
    expect(isValidTransition('free', 'reserved')).toBe(true);
  });

  it('tavolo occupato non puo diventare prenotato', () => {
    expect(isValidTransition('occupied', 'reserved')).toBe(false);
  });

  it('tavolo con conto torna libero', () => {
    expect(isValidTransition('bill', 'free')).toBe(true);
  });

  it('transizione invalida rifiutata', () => {
    expect(isValidTransition('bill', 'occupied')).toBe(false);
  });
});

// Test raggruppamento items per Kitchen Display
describe('Kitchen Display Grouping', () => {
  interface KitchenItem {
    order_id: string;
    recipe_name: string;
    quantity: number;
    table_name: string;
  }

  function groupByOrder(items: KitchenItem[]): Map<string, KitchenItem[]> {
    const map = new Map<string, KitchenItem[]>();
    items.forEach((item) => {
      if (!map.has(item.order_id)) map.set(item.order_id, []);
      map.get(item.order_id)!.push(item);
    });
    return map;
  }

  it('raggruppa items per ordine', () => {
    const items: KitchenItem[] = [
      { order_id: 'o1', recipe_name: 'Carbonara', quantity: 2, table_name: 'T1' },
      { order_id: 'o1', recipe_name: 'Tiramisù', quantity: 2, table_name: 'T1' },
      { order_id: 'o2', recipe_name: 'Pizza', quantity: 1, table_name: 'T3' },
    ];

    const grouped = groupByOrder(items);
    expect(grouped.size).toBe(2);
    expect(grouped.get('o1')!.length).toBe(2);
    expect(grouped.get('o2')!.length).toBe(1);
  });

  it('lista vuota = nessun gruppo', () => {
    const grouped = groupByOrder([]);
    expect(grouped.size).toBe(0);
  });
});
```

## Checklist Sprint 2

- [ ] CRUD Tavoli funzionante
- [ ] Mappa visuale tavoli con colori per stato
- [ ] Creazione comanda con selezione piatti dal menu
- [ ] Note/varianti per piatto
- [ ] Invio comanda in cucina (INSERT → Realtime)
- [ ] Kitchen Display con colonne Kanban (In arrivo / In preparazione / Pronto)
- [ ] Audio alert per nuovi ordini in cucina
- [ ] Cambio stato piatto dal Kitchen Display (click)
- [ ] Chiusura tavolo con calcolo conto
- [ ] Test: tutti verdi
- [ ] `npm run build` zero errori

**NOTA IMPORTANTE**: Il Kitchen Display deve funzionare su tablet/monitor dedicato. Usa font grandi, bottoni touch-friendly, e contrasto alto (sfondo scuro). Il cameriere e lo chef non hanno tempo di "cercare" — tutto deve essere visibile e tappabile al primo colpo.

**Quando tutto verde → procedi a Sprint 3**
