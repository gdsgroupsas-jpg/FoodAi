---
title: "Sprint 1: Dominio Base"
scope: sprint
audience: engineering
owner: engineering
status: active
updated: 2026-02-09
---

# Sprint 1: Dominio Base — Ingredienti, Ricette, Fornitori

**Obiettivo**: CRUD completo per ingredienti, ricette con distinta base, fornitori con listini prezzo. Calcolo food cost per piatto.

**Durata stimata**: 2-3 settimane

**Prerequisito**: Sprint 0 completato

---

## Cosa si costruisce

1. **Pagina Ingredienti** — CRUD con categorie, unita di misura, fattore resa, allergeni
2. **Pagina Ricette** — CRUD piatti con distinta base (ingredienti + dosi)
3. **Pagina Fornitori** — CRUD fornitori con listini prezzo ingredienti
4. **Calcolo Food Cost** — Per ogni ricetta, calcolare costo ingredienti e margine
5. **Test** — Unit test per la logica food cost

---

## Step 1: Server Actions — Ingredienti

### `actions/ingredients.ts`

Creare le seguenti server actions:

```
listIngredients(restaurantId)        → lista ingredienti con categorie
getIngredient(id)                    → dettaglio singolo ingrediente
createIngredient(data)               → crea nuovo ingrediente
updateIngredient(id, data)           → aggiorna ingrediente
deleteIngredient(id)                 → elimina (soft delete: is_active = false)
listIngredientCategories(restaurantId) → lista categorie
createIngredientCategory(data)       → crea categoria
```

**Pattern da seguire** (identico a SpedireSicuro):

```typescript
'use server';

import { supabaseAdmin } from '@/lib/db/client';
import { getCurrentUser } from '@/lib/db/auth';

export async function listIngredients() {
  // 1. Verifica auth
  const user = await getCurrentUser();
  if (!user) return { success: false, error: 'Non autenticato' };

  // 2. Ottieni restaurant_id dell'utente
  const { data: userData } = await supabaseAdmin
    .from('users')
    .select('restaurant_id')
    .eq('auth_user_id', user.id)
    .single();

  if (!userData) return { success: false, error: 'Utente non trovato' };

  // 3. Query con filtro restaurant_id
  const { data, error } = await supabaseAdmin
    .from('ingredients')
    .select('*, category:ingredient_categories(name)')
    .eq('restaurant_id', userData.restaurant_id)
    .eq('is_active', true)
    .order('name');

  if (error) return { success: false, error: error.message };
  return { success: true, ingredients: data };
}
```

### Validazione input con Zod

```typescript
// types/ingredients.ts
import { z } from 'zod';

export const ingredientSchema = z.object({
  name: z.string().min(1, 'Nome obbligatorio').max(100),
  category_id: z.string().uuid().optional(),
  unit: z.enum(['kg', 'g', 'l', 'ml', 'pz', 'conf']),
  barcode: z.string().optional(),
  yield_factor: z.number().min(0.01).max(2.0).default(1.0),
  min_stock: z.number().min(0).default(0),
  shelf_life_days: z.number().int().min(1).optional(),
  allergens: z.array(z.string()).default([]),
});

export type IngredientInput = z.infer<typeof ingredientSchema>;
```

## Step 2: Pagina UI — Ingredienti

### `app/dashboard/ricette/ingredienti/page.tsx`

Struttura pagina:
- Header con titolo + bottone "Nuovo Ingrediente"
- Barra ricerca + filtro per categoria
- Tabella: Nome | Categoria | Unita | Fattore Resa | Stock Min | Azioni
- Dialog per creazione/modifica ingrediente
- Dialog conferma eliminazione

**Componenti da creare:**
- `components/ricette/ingredient-list.tsx` — tabella con filtri
- `components/ricette/ingredient-form.tsx` — form creazione/modifica
- `components/ricette/ingredient-category-select.tsx` — dropdown categorie

## Step 3: Server Actions — Ricette

### `actions/recipes.ts`

```
listRecipes(restaurantId)            → lista ricette con food cost calcolato
getRecipe(id)                        → dettaglio ricetta con ingredienti
createRecipe(data)                   → crea ricetta
updateRecipe(id, data)               → aggiorna ricetta
deleteRecipe(id)                     → soft delete
addRecipeIngredient(recipeId, data)  → aggiungi ingrediente a distinta base
removeRecipeIngredient(id)           → rimuovi ingrediente da distinta base
updateRecipeIngredient(id, data)     → aggiorna dose ingrediente
calculateFoodCost(recipeId)          → calcola food cost della ricetta
```

### Logica Food Cost (CORE del prodotto)

```typescript
// lib/food-cost/calculator.ts

export interface FoodCostResult {
  totalCost: number;           // Costo totale ingredienti
  costPerPortion: number;      // Costo per porzione
  sellingPrice: number;        // Prezzo di vendita
  marginAmount: number;        // Margine in EUR
  marginPercent: number;       // Margine percentuale
  ingredients: Array<{
    name: string;
    quantity: number;
    unit: string;
    unitCost: number;          // Costo per unita
    yieldFactor: number;       // Fattore resa
    lineCost: number;          // Costo riga = quantity * unitCost / yieldFactor
  }>;
}

export function calculateRecipeFoodCost(
  recipe: { selling_price: number; portions: number },
  ingredients: Array<{
    name: string;
    quantity: number;           // Dose nella ricetta
    unit: string;
    ingredient_unit_cost: number; // Costo per unita dell'ingrediente
    yield_factor: number;
  }>
): FoodCostResult {
  const lines = ingredients.map((ing) => ({
    name: ing.name,
    quantity: ing.quantity,
    unit: ing.unit,
    unitCost: ing.ingredient_unit_cost,
    yieldFactor: ing.yield_factor,
    // Il costo reale tiene conto del calo peso
    // Se resa = 0.70, servono piu grammi lordi per ottenere la dose netta
    lineCost: ing.quantity * ing.ingredient_unit_cost / ing.yield_factor,
  }));

  const totalCost = lines.reduce((sum, l) => sum + l.lineCost, 0);
  const costPerPortion = totalCost / (recipe.portions || 1);
  const marginAmount = recipe.selling_price - costPerPortion;
  const marginPercent = recipe.selling_price > 0
    ? (marginAmount / recipe.selling_price) * 100
    : 0;

  return {
    totalCost,
    costPerPortion,
    sellingPrice: recipe.selling_price,
    marginAmount,
    marginPercent,
    ingredients: lines,
  };
}
```

**IMPORTANTE sul fattore resa:**
- `yield_factor = 1.0` → nessun calo (es: pasta secca, olio)
- `yield_factor = 0.70` → 30% calo peso (es: carne, pesce)
- `yield_factor = 0.85` → 15% calo (es: verdure)
- Dividere per yield_factor perche servono piu grammi lordi per ottenere la dose netta

## Step 4: Pagina UI — Ricette

### `app/dashboard/ricette/page.tsx`

Struttura:
- Lista ricette come card con: nome, foto, prezzo vendita, food cost, margine %
- Colore margine: verde (>65%), giallo (50-65%), rosso (<50%)
- Click su ricetta → dettaglio con distinta base

### `app/dashboard/ricette/[id]/page.tsx`

Dettaglio ricetta:
- Info generali (nome, prezzo, categoria, foto)
- **Distinta Base**: tabella ingredienti con dosi
- **Food Cost Card**: costo totale, margine, breakdown per ingrediente
- Bottone "Aggiungi Ingrediente" → dialog con autocomplete ingredienti

## Step 5: Server Actions — Fornitori e Listini

### `actions/suppliers.ts`

```
listSuppliers(restaurantId)          → lista fornitori
createSupplier(data)                 → crea fornitore
updateSupplier(id, data)             → aggiorna
deleteSupplier(id)                   → soft delete

listSupplierPrices(supplierId)       → listino prezzi del fornitore
upsertSupplierPrice(data)            → crea/aggiorna prezzo ingrediente
deleteSupplierPrice(id)              → elimina prezzo
```

### `app/dashboard/fornitori/page.tsx`

- Lista fornitori con: nome, telefono, email, n. prodotti, giorni consegna
- Click → dettaglio fornitore + listino prezzi
- Listino: tabella Ingrediente | Prezzo | Unita | Validita

## Step 6: Test Unit

### `tests/unit/food-cost-calculator.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { calculateRecipeFoodCost } from '@/lib/food-cost/calculator';

describe('Food Cost Calculator', () => {
  it('calcola food cost semplice senza calo peso', () => {
    const result = calculateRecipeFoodCost(
      { selling_price: 14.00, portions: 1 },
      [
        { name: 'Pasta', quantity: 0.150, unit: 'kg',
          ingredient_unit_cost: 1.50, yield_factor: 1.0 },
        { name: 'Uova', quantity: 3, unit: 'pz',
          ingredient_unit_cost: 0.30, yield_factor: 1.0 },
        { name: 'Guanciale', quantity: 0.100, unit: 'kg',
          ingredient_unit_cost: 18.00, yield_factor: 1.0 },
        { name: 'Pecorino', quantity: 0.030, unit: 'kg',
          ingredient_unit_cost: 22.00, yield_factor: 1.0 },
      ]
    );

    // Pasta: 0.150 * 1.50 = 0.225
    // Uova: 3 * 0.30 = 0.90
    // Guanciale: 0.100 * 18.00 = 1.80
    // Pecorino: 0.030 * 22.00 = 0.66
    // Totale: 3.585
    expect(result.totalCost).toBeCloseTo(3.585, 2);
    expect(result.marginPercent).toBeGreaterThan(70);
  });

  it('calcola food cost con calo peso cottura', () => {
    const result = calculateRecipeFoodCost(
      { selling_price: 22.00, portions: 1 },
      [
        { name: 'Filetto manzo', quantity: 0.200, unit: 'kg',
          ingredient_unit_cost: 35.00, yield_factor: 0.70 },
      ]
    );

    // Filetto: 0.200 * 35.00 / 0.70 = 10.00
    // (servono 285g lordi per ottenere 200g cotti)
    expect(result.totalCost).toBeCloseTo(10.00, 2);
    expect(result.marginPercent).toBeCloseTo(54.55, 1);
  });

  it('gestisce ricetta multi-porzione', () => {
    const result = calculateRecipeFoodCost(
      { selling_price: 8.00, portions: 4 },
      [
        { name: 'Farina', quantity: 0.500, unit: 'kg',
          ingredient_unit_cost: 1.20, yield_factor: 1.0 },
        { name: 'Mozzarella', quantity: 0.400, unit: 'kg',
          ingredient_unit_cost: 8.00, yield_factor: 1.0 },
        { name: 'Pomodoro', quantity: 0.300, unit: 'kg',
          ingredient_unit_cost: 3.00, yield_factor: 1.0 },
      ]
    );

    // Totale: 0.60 + 3.20 + 0.90 = 4.70
    // Per porzione: 4.70 / 4 = 1.175
    expect(result.costPerPortion).toBeCloseTo(1.175, 2);
    expect(result.marginPercent).toBeGreaterThan(80);
  });

  it('margine rosso per piatto costoso', () => {
    const result = calculateRecipeFoodCost(
      { selling_price: 16.00, portions: 1 },
      [
        { name: 'Astice', quantity: 0.350, unit: 'kg',
          ingredient_unit_cost: 45.00, yield_factor: 0.50 },
      ]
    );

    // Astice: 0.350 * 45.00 / 0.50 = 31.50
    // Margine: (16 - 31.50) / 16 = -96.9% (in perdita!)
    expect(result.marginPercent).toBeLessThan(0);
  });
});
```

## Checklist Sprint 1

- [ ] CRUD Ingredienti funzionante (lista, crea, modifica, elimina)
- [ ] Categorie ingredienti funzionanti
- [ ] CRUD Ricette funzionante
- [ ] Distinta base: aggiunta/rimozione ingredienti con dosi
- [ ] Calcolo food cost corretto (con fattore resa)
- [ ] Visualizzazione margine con colori (verde/giallo/rosso)
- [ ] CRUD Fornitori funzionante
- [ ] Listini prezzi fornitore
- [ ] Test food cost calculator: tutti verdi
- [ ] `npm run build` zero errori

**Quando tutto verde → procedi a Sprint 2**
