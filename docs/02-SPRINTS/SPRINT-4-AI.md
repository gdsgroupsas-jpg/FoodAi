---
title: "Sprint 4: AI Assistant"
scope: sprint
audience: engineering
owner: engineering
status: active
updated: 2026-02-09
---

# Sprint 4: AI Assistant — Food Cost Analytics, Previsioni, Suggerimenti Ordini

**Obiettivo**: Assistente AI conversazionale (stile "Anne" di SpedireSicuro) che analizza food cost, identifica margini critici, prevede domanda, e suggerisce ordini fornitori.

**Durata stimata**: 2-3 settimane

**Prerequisito**: Sprint 3 completato (magazzino + scarico automatico funzionanti)

---

## Cosa si costruisce

1. **Dashboard Food Cost** — Panoramica margini per piatto, trend costi, alert
2. **Chat AI** — Interfaccia conversazionale per domande su food cost, stock, previsioni
3. **Intent Detection** — Riconoscimento intento dalle domande del ristoratore
4. **Worker Analisi** — Calcoli food cost, trend prezzi, previsioni domanda
5. **Suggerimenti Ordini** — AI suggerisce cosa ordinare, da quale fornitore, quando

---

## Step 1: Dashboard Food Cost

### `app/dashboard/food-cost/page.tsx`

Struttura dashboard:
- **KPI Cards** (in alto):
  - Food cost medio del menu (%)
  - Piatti con margine < 50% (alert)
  - Variazione costi ingredienti questo mese (%)
  - Valore stock totale

- **Tabella Piatti** con:
  - Nome piatto
  - Prezzo vendita
  - Costo ingredienti
  - Margine % (con badge colore: verde >65%, giallo 50-65%, rosso <50%)
  - Trend (freccia su/giu rispetto al mese precedente)

- **Grafici**:
  - Pie chart: distribuzione food cost per categoria (antipasti, primi, secondi...)
  - Bar chart: top 10 piatti per margine
  - Line chart: andamento food cost medio negli ultimi 30 giorni

### Server Action per analytics

```typescript
// actions/food-cost-analytics.ts
'use server';

import { supabaseAdmin } from '@/lib/db/client';
import { getCurrentUser } from '@/lib/db/auth';
import { calculateRecipeFoodCost } from '@/lib/food-cost/calculator';

export interface FoodCostDashboardData {
  recipes: Array<{
    id: string;
    name: string;
    category: string;
    selling_price: number;
    food_cost: number;
    margin_percent: number;
    portions_sold_30d: number;
    revenue_30d: number;
  }>;
  kpis: {
    avg_food_cost_percent: number;
    critical_items_count: number;  // margine < 50%
    total_stock_value: number;
    ingredient_cost_variation: number; // % variazione costi mese
  };
}

export async function getFoodCostDashboard(): Promise<{
  success: boolean;
  data?: FoodCostDashboardData;
  error?: string;
}> {
  const user = await getCurrentUser();
  if (!user) return { success: false, error: 'Non autenticato' };

  const { data: userData } = await supabaseAdmin
    .from('users')
    .select('restaurant_id')
    .eq('auth_user_id', user.id)
    .single();

  if (!userData) return { success: false, error: 'Utente non trovato' };

  const restaurantId = userData.restaurant_id;

  // Carica tutte le ricette con ingredienti e prezzi
  const { data: recipes } = await supabaseAdmin
    .from('recipes')
    .select(`
      id, name, selling_price, portions,
      category:menu_categories(name),
      recipe_ingredients(
        quantity, unit,
        ingredient:ingredients(
          id, name, yield_factor,
          supplier_prices(price, unit)
        )
      )
    `)
    .eq('restaurant_id', restaurantId)
    .eq('is_active', true);

  if (!recipes) return { success: false, error: 'Nessuna ricetta trovata' };

  // Vendite ultimi 30 giorni
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const { data: salesData } = await supabaseAdmin
    .from('order_items')
    .select('recipe_id, quantity')
    .gte('created_at', thirtyDaysAgo.toISOString())
    .in(
      'recipe_id',
      recipes.map((r) => r.id)
    );

  // Aggrega vendite per ricetta
  const salesMap = new Map<string, number>();
  salesData?.forEach((s) => {
    salesMap.set(s.recipe_id, (salesMap.get(s.recipe_id) || 0) + s.quantity);
  });

  // Calcola food cost per ogni ricetta
  const recipesWithCost = recipes.map((recipe: any) => {
    // Trova il prezzo piu recente di ogni ingrediente
    const ingredients = (recipe.recipe_ingredients || []).map((ri: any) => {
      const prices = ri.ingredient?.supplier_prices || [];
      // Prendi il prezzo piu basso disponibile
      const bestPrice =
        prices.length > 0
          ? Math.min(...prices.map((p: any) => p.price))
          : 0;

      return {
        name: ri.ingredient?.name || '???',
        quantity: ri.quantity,
        unit: ri.unit,
        ingredient_unit_cost: bestPrice,
        yield_factor: ri.ingredient?.yield_factor || 1.0,
      };
    });

    const result = calculateRecipeFoodCost(
      {
        selling_price: recipe.selling_price,
        portions: recipe.portions || 1,
      },
      ingredients
    );

    const portionsSold = salesMap.get(recipe.id) || 0;

    return {
      id: recipe.id,
      name: recipe.name,
      category: recipe.category?.name || 'Altro',
      selling_price: recipe.selling_price,
      food_cost: result.costPerPortion,
      margin_percent: result.marginPercent,
      portions_sold_30d: portionsSold,
      revenue_30d: portionsSold * recipe.selling_price,
    };
  });

  // Calcola KPI
  const avgFoodCost =
    recipesWithCost.length > 0
      ? recipesWithCost.reduce((sum, r) => sum + (100 - r.margin_percent), 0) /
        recipesWithCost.length
      : 0;

  const criticalItems = recipesWithCost.filter(
    (r) => r.margin_percent < 50
  ).length;

  // Stock value
  const { data: stockValue } = await supabaseAdmin.rpc(
    'calc_total_stock_value',
    { p_restaurant_id: restaurantId }
  );

  return {
    success: true,
    data: {
      recipes: recipesWithCost,
      kpis: {
        avg_food_cost_percent: avgFoodCost,
        critical_items_count: criticalItems,
        total_stock_value: stockValue || 0,
        ingredient_cost_variation: 0, // TODO: calcolare nel prossimo sprint
      },
    },
  };
}
```

## Step 2: Architettura AI — Intent Detection + Workers

### Modello conversazionale

L'AI del ristorante usa lo stesso pattern di Anne (SpedireSicuro):

```
Utente: "Quanto mi costa la carbonara?"
  │
  ├→ Intent Detection: FOOD_COST_QUERY
  │    entity: recipe = "carbonara"
  │
  ├→ Worker: FoodCostWorker
  │    → Cerca ricetta "carbonara"
  │    → Calcola food cost con ingredienti attuali
  │    → Formatta risposta
  │
  └→ Risposta: "La carbonara ti costa 3.58€ per porzione.
                Prezzo vendita 14€ → margine 74.4%.
                Ingredienti: pasta 0.23€, uova 0.90€,
                guanciale 1.80€, pecorino 0.66€."
```

### Intent Detector

```typescript
// lib/ai/intent-detector.ts

export type AIIntent =
  | 'FOOD_COST_QUERY'        // "quanto costa la carbonara?"
  | 'MARGIN_ANALYSIS'        // "quali piatti hanno margine basso?"
  | 'STOCK_CHECK'            // "quanto guanciale ho in magazzino?"
  | 'EXPIRY_CHECK'           // "cosa sta per scadere?"
  | 'ORDER_SUGGESTION'       // "cosa devo ordinare?"
  | 'PRICE_COMPARISON'       // "chi vende il guanciale al miglior prezzo?"
  | 'SALES_ANALYSIS'         // "qual è il piatto più venduto?"
  | 'PREDICTION'             // "quanto guanciale mi serve per il weekend?"
  | 'GENERAL_QUESTION'       // domande generiche
  | 'UNKNOWN';

export interface DetectedIntent {
  intent: AIIntent;
  confidence: number;
  entities: {
    recipe_name?: string;
    ingredient_name?: string;
    supplier_name?: string;
    time_period?: string;
    threshold?: number;
  };
}

/**
 * Rileva l'intento dalla domanda dell'utente usando Claude API.
 *
 * In alternativa, per ridurre costi API, si puo usare un match
 * regex/keyword come primo livello (fast path) e Claude solo
 * per domande complesse.
 */
export async function detectIntent(
  userMessage: string,
  context: { restaurantName: string }
): Promise<DetectedIntent> {
  // Fast path: keyword matching per intenti comuni
  const lower = userMessage.toLowerCase();

  if (lower.match(/quanto (mi )?cost[ao]/)) {
    const recipeName = extractRecipeName(lower);
    if (recipeName) {
      return {
        intent: 'FOOD_COST_QUERY',
        confidence: 0.9,
        entities: { recipe_name: recipeName },
      };
    }
  }

  if (lower.match(/margine?\s*(basso|sotto|critico|rosso)/)) {
    return {
      intent: 'MARGIN_ANALYSIS',
      confidence: 0.85,
      entities: {},
    };
  }

  if (lower.match(/magazzino|stock|scorte|quant[oi]\s+\w+\s+ho/)) {
    const ingredientName = extractIngredientName(lower);
    return {
      intent: 'STOCK_CHECK',
      confidence: 0.85,
      entities: { ingredient_name: ingredientName },
    };
  }

  if (lower.match(/scad[eao]|shelf.?life|freschezza/)) {
    return {
      intent: 'EXPIRY_CHECK',
      confidence: 0.9,
      entities: {},
    };
  }

  if (lower.match(/ordinar[ei]|comprare|rifornir[ei]|manca/)) {
    return {
      intent: 'ORDER_SUGGESTION',
      confidence: 0.85,
      entities: {},
    };
  }

  if (lower.match(/prezzo|miglior[ei]?\s+fornitor/)) {
    const ingredientName = extractIngredientName(lower);
    return {
      intent: 'PRICE_COMPARISON',
      confidence: 0.8,
      entities: { ingredient_name: ingredientName },
    };
  }

  if (lower.match(/vendut[oi]|popular[ei]|piu\s+ordinat/)) {
    return {
      intent: 'SALES_ANALYSIS',
      confidence: 0.85,
      entities: {},
    };
  }

  if (lower.match(/previsi|quant[oi]\s+.*\s+serv[ei]|weekend|sabato|domenica/)) {
    return {
      intent: 'PREDICTION',
      confidence: 0.75,
      entities: {
        time_period: extractTimePeriod(lower),
      },
    };
  }

  // Fallback: usa Claude API per intenti complessi
  return {
    intent: 'GENERAL_QUESTION',
    confidence: 0.5,
    entities: {},
  };
}

function extractRecipeName(text: string): string | undefined {
  // Pattern: "quanto costa la/il/lo {nome}"
  const match = text.match(/cost[ao]\s+(?:la|il|lo|l'|un[ao]?\s+)(\w[\w\s]+)/);
  return match?.[1]?.trim();
}

function extractIngredientName(text: string): string | undefined {
  // Pattern: "quanto {ingrediente} ho" oppure "prezzo del {ingrediente}"
  const match = text.match(
    /(?:quanto|quanta)\s+(\w[\w\s]+?)\s+(?:ho|abbiamo|c'è)/
  );
  if (match) return match[1].trim();

  const match2 = text.match(/(?:prezzo|costo)\s+(?:del|della|dello)\s+(\w[\w\s]+)/);
  return match2?.[1]?.trim();
}

function extractTimePeriod(text: string): string {
  if (text.includes('weekend') || text.includes('fine settimana')) return 'weekend';
  if (text.includes('settimana')) return 'week';
  if (text.includes('domani')) return 'tomorrow';
  if (text.includes('sabato')) return 'saturday';
  if (text.includes('domenica')) return 'sunday';
  return 'week';
}
```

## Step 3: AI Workers

### Food Cost Worker

```typescript
// lib/ai/workers/food-cost-worker.ts

import { supabaseAdmin } from '@/lib/db/client';
import { calculateRecipeFoodCost } from '@/lib/food-cost/calculator';

export async function handleFoodCostQuery(
  restaurantId: string,
  recipeName: string
): Promise<string> {
  // Cerca la ricetta
  const { data: recipe } = await supabaseAdmin
    .from('recipes')
    .select(`
      id, name, selling_price, portions,
      recipe_ingredients(
        quantity, unit,
        ingredient:ingredients(
          name, yield_factor,
          supplier_prices(price)
        )
      )
    `)
    .eq('restaurant_id', restaurantId)
    .ilike('name', `%${recipeName}%`)
    .limit(1)
    .single();

  if (!recipe) {
    return `Non ho trovato la ricetta "${recipeName}" nel tuo menu. Controlla il nome o aggiungila nella sezione Ricette.`;
  }

  const ingredients = (recipe.recipe_ingredients as any[]).map((ri) => {
    const prices = ri.ingredient?.supplier_prices || [];
    const bestPrice = prices.length > 0
      ? Math.min(...prices.map((p: any) => p.price))
      : 0;

    return {
      name: ri.ingredient?.name || '???',
      quantity: ri.quantity,
      unit: ri.unit,
      ingredient_unit_cost: bestPrice,
      yield_factor: ri.ingredient?.yield_factor || 1.0,
    };
  });

  const result = calculateRecipeFoodCost(
    { selling_price: recipe.selling_price, portions: recipe.portions || 1 },
    ingredients
  );

  // Formatta risposta conversazionale
  let response = `**${recipe.name}** — Food Cost Analysis\n\n`;
  response += `Prezzo vendita: **${recipe.selling_price.toFixed(2)}€**\n`;
  response += `Costo ingredienti: **${result.costPerPortion.toFixed(2)}€**\n`;
  response += `Margine: **${result.marginPercent.toFixed(1)}%**`;

  if (result.marginPercent >= 65) {
    response += ` ✅ Ottimo\n`;
  } else if (result.marginPercent >= 50) {
    response += ` ⚠️ Accettabile\n`;
  } else {
    response += ` 🔴 Sotto soglia!\n`;
  }

  response += `\nDettaglio ingredienti:\n`;
  result.ingredients.forEach((ing) => {
    response += `- ${ing.name}: ${ing.quantity} ${ing.unit} × ${ing.unitCost.toFixed(2)}€`;
    if (ing.yieldFactor < 1) {
      response += ` (resa ${(ing.yieldFactor * 100).toFixed(0)}%)`;
    }
    response += ` = **${ing.lineCost.toFixed(2)}€**\n`;
  });

  return response;
}
```

### Order Suggestion Worker

```typescript
// lib/ai/workers/order-suggestion-worker.ts

import { supabaseAdmin } from '@/lib/db/client';

export interface OrderSuggestion {
  ingredient_name: string;
  current_stock: number;
  min_stock: number;
  unit: string;
  suggested_quantity: number;
  best_supplier: string | null;
  best_price: number | null;
  estimated_cost: number;
  urgency: 'critical' | 'soon' | 'planned';
  reason: string;
}

export async function generateOrderSuggestions(
  restaurantId: string
): Promise<OrderSuggestion[]> {
  // 1. Ingredienti sotto soglia
  const { data: lowStock } = await supabaseAdmin
    .from('stock')
    .select(`
      current_quantity,
      min_quantity,
      ingredient:ingredients(
        id, name, unit,
        supplier_prices(
          price, supplier:suppliers(name)
        )
      )
    `)
    .eq('restaurant_id', restaurantId)
    .lt('current_quantity', supabaseAdmin.raw('min_quantity'));

  // 2. Ingredienti che stanno per scadere (entro 3 giorni)
  const threeDays = new Date();
  threeDays.setDate(threeDays.getDate() + 3);

  const { data: expiring } = await supabaseAdmin
    .from('stock_batches')
    .select(`
      quantity_remaining,
      expiry_date,
      ingredient:ingredients(id, name, unit)
    `)
    .eq('restaurant_id', restaurantId)
    .gt('quantity_remaining', 0)
    .lte('expiry_date', threeDays.toISOString());

  // 3. Previsione domanda (media vendite ultimi 7 giorni × 3)
  // TODO: implementare modello previsionale piu sofisticato

  const suggestions: OrderSuggestion[] = [];

  // Processa ingredienti sotto soglia
  lowStock?.forEach((item: any) => {
    const ing = item.ingredient;
    if (!ing) return;

    // Trova miglior fornitore
    const prices = ing.supplier_prices || [];
    const bestOffer = prices.reduce(
      (best: any, p: any) =>
        !best || p.price < best.price ? p : best,
      null as any
    );

    // Suggerisci quantita: riporta a 2× soglia minima
    const suggestedQty = Math.max(
      item.min_quantity * 2 - item.current_quantity,
      item.min_quantity
    );

    suggestions.push({
      ingredient_name: ing.name,
      current_stock: item.current_quantity,
      min_stock: item.min_quantity,
      unit: ing.unit,
      suggested_quantity: suggestedQty,
      best_supplier: bestOffer?.supplier?.name || null,
      best_price: bestOffer?.price || null,
      estimated_cost: suggestedQty * (bestOffer?.price || 0),
      urgency: item.current_quantity <= 0 ? 'critical' : 'soon',
      reason:
        item.current_quantity <= 0
          ? 'Stock esaurito!'
          : `Sotto soglia minima (${item.current_quantity}/${item.min_quantity} ${ing.unit})`,
    });
  });

  // Ordina per urgenza
  const urgencyOrder = { critical: 0, soon: 1, planned: 2 };
  suggestions.sort(
    (a, b) => urgencyOrder[a.urgency] - urgencyOrder[b.urgency]
  );

  return suggestions;
}
```

## Step 4: Chat UI

### `app/dashboard/ai-assistant/page.tsx`

Interfaccia chat simile ad Anne:
- Input testo in basso
- Messaggi scorrevoli (utente a destra, AI a sinistra)
- Suggerimenti rapidi (chip cliccabili):
  - "Quali piatti hanno margine basso?"
  - "Cosa devo ordinare?"
  - "Cosa sta per scadere?"
  - "Food cost della carbonara"

### Componenti

```typescript
// components/ai/chat-interface.tsx
'use client';

import { useState, useRef, useEffect } from 'react';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

const quickSuggestions = [
  'Quali piatti hanno margine sotto il 50%?',
  'Cosa devo ordinare questa settimana?',
  'Cosa sta per scadere?',
  'Quanto mi costa la carbonara?',
  'Qual è il piatto più venduto?',
];

export function ChatInterface({ restaurantId }: { restaurantId: string }) {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '0',
      role: 'assistant',
      content:
        'Ciao! Sono il tuo assistente food cost. Posso aiutarti con analisi margini, stock, scadenze e suggerimenti ordini. Cosa ti serve?',
      timestamp: new Date(),
    },
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  async function sendMessage(text: string) {
    if (!text.trim() || loading) return;

    const userMsg: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: text,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInput('');
    setLoading(true);

    try {
      // Chiama server action per processare il messaggio
      const response = await processAIMessage(restaurantId, text);

      const aiMsg: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response,
        timestamp: new Date(),
      };

      setMessages((prev) => [...prev, aiMsg]);
    } catch (error) {
      const errMsg: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: 'Mi dispiace, si è verificato un errore. Riprova tra un momento.',
        timestamp: new Date(),
      };
      setMessages((prev) => [...prev, errMsg]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex flex-col h-[calc(100vh-120px)]">
      {/* Area messaggi */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className={`max-w-[80%] p-3 rounded-lg ${
                msg.role === 'user'
                  ? 'bg-primary text-white'
                  : 'bg-gray-100 text-gray-900'
              }`}
            >
              <div className="whitespace-pre-wrap">{msg.content}</div>
              <div className="text-xs opacity-60 mt-1">
                {msg.timestamp.toLocaleTimeString('it-IT', {
                  hour: '2-digit',
                  minute: '2-digit',
                })}
              </div>
            </div>
          </div>
        ))}
        {loading && (
          <div className="flex justify-start">
            <div className="bg-gray-100 p-3 rounded-lg animate-pulse">
              Sto analizzando...
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Suggerimenti rapidi */}
      {messages.length <= 1 && (
        <div className="px-4 pb-2 flex gap-2 flex-wrap">
          {quickSuggestions.map((suggestion) => (
            <button
              key={suggestion}
              onClick={() => sendMessage(suggestion)}
              className="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded-full"
            >
              {suggestion}
            </button>
          ))}
        </div>
      )}

      {/* Input */}
      <div className="border-t p-4">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            sendMessage(input);
          }}
          className="flex gap-2"
        >
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Chiedi qualcosa sul food cost, magazzino, ordini..."
            className="flex-1 px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary"
            disabled={loading}
          />
          <button
            type="submit"
            disabled={loading || !input.trim()}
            className="px-6 py-2 bg-primary text-white rounded-lg disabled:opacity-50"
          >
            Invia
          </button>
        </form>
      </div>
    </div>
  );
}
```

## Step 5: Server Action — AI Message Processing

### `actions/ai-chat.ts`

```typescript
'use server';

import { supabaseAdmin } from '@/lib/db/client';
import { getCurrentUser } from '@/lib/db/auth';
import { detectIntent } from '@/lib/ai/intent-detector';
import { handleFoodCostQuery } from '@/lib/ai/workers/food-cost-worker';
import { generateOrderSuggestions } from '@/lib/ai/workers/order-suggestion-worker';

export async function processAIMessage(
  restaurantId: string,
  userMessage: string
): Promise<string> {
  const user = await getCurrentUser();
  if (!user) return 'Non autenticato.';

  // 1. Rileva intento
  const { intent, entities } = await detectIntent(userMessage, {
    restaurantName: '', // TODO: caricare nome ristorante
  });

  // 2. Esegui worker appropriato
  switch (intent) {
    case 'FOOD_COST_QUERY':
      if (entities.recipe_name) {
        return handleFoodCostQuery(restaurantId, entities.recipe_name);
      }
      return 'Per quale piatto vuoi il food cost? Dimmi il nome.';

    case 'MARGIN_ANALYSIS':
      return handleMarginAnalysis(restaurantId);

    case 'STOCK_CHECK':
      return handleStockCheck(restaurantId, entities.ingredient_name);

    case 'EXPIRY_CHECK':
      return handleExpiryCheck(restaurantId);

    case 'ORDER_SUGGESTION':
      return handleOrderSuggestion(restaurantId);

    case 'PRICE_COMPARISON':
      return handlePriceComparison(restaurantId, entities.ingredient_name);

    case 'SALES_ANALYSIS':
      return handleSalesAnalysis(restaurantId);

    case 'PREDICTION':
      return handlePrediction(restaurantId, entities.time_period);

    default:
      // Fallback: usa Claude API per risposta generica
      return handleGeneralQuestion(restaurantId, userMessage);
  }
}

async function handleMarginAnalysis(restaurantId: string): Promise<string> {
  // Carica ricette con food cost calcolato
  // Filtra quelle con margine < 50%
  // Formatta risposta
  return 'TODO: implementare analisi margini';
}

async function handleStockCheck(
  restaurantId: string,
  ingredientName?: string
): Promise<string> {
  if (!ingredientName) {
    return 'Quale ingrediente vuoi controllare? Dimmi il nome.';
  }

  const { data: stock } = await supabaseAdmin
    .from('stock')
    .select(`
      current_quantity,
      min_quantity,
      ingredient:ingredients(name, unit)
    `)
    .eq('restaurant_id', restaurantId)
    .ilike('ingredient.name', `%${ingredientName}%`)
    .limit(1)
    .single();

  if (!stock) {
    return `Non ho trovato "${ingredientName}" nel magazzino.`;
  }

  const ing = stock.ingredient as any;
  const status =
    stock.current_quantity > stock.min_quantity
      ? '✅ OK'
      : stock.current_quantity > 0
        ? '⚠️ Sotto soglia'
        : '🔴 Esaurito';

  return (
    `**${ing.name}**: ${stock.current_quantity.toFixed(2)} ${ing.unit} ${status}\n` +
    `Soglia minima: ${stock.min_quantity} ${ing.unit}`
  );
}

async function handleExpiryCheck(restaurantId: string): Promise<string> {
  const threeDays = new Date();
  threeDays.setDate(threeDays.getDate() + 3);

  const { data: expiring } = await supabaseAdmin
    .from('stock_batches')
    .select(`
      quantity_remaining,
      expiry_date,
      lot_number,
      ingredient:ingredients(name, unit)
    `)
    .eq('restaurant_id', restaurantId)
    .gt('quantity_remaining', 0)
    .lte('expiry_date', threeDays.toISOString())
    .order('expiry_date', { ascending: true });

  if (!expiring || expiring.length === 0) {
    return '✅ Nessun prodotto in scadenza nei prossimi 3 giorni.';
  }

  let response = `⚠️ **${expiring.length} prodotti in scadenza**:\n\n`;
  expiring.forEach((item: any) => {
    const ing = item.ingredient;
    const daysLeft = Math.ceil(
      (new Date(item.expiry_date).getTime() - Date.now()) / (1000 * 60 * 60 * 24)
    );
    const urgency = daysLeft <= 0 ? '🔴 SCADUTO' : daysLeft === 1 ? '🟡 Domani' : `📅 ${daysLeft}g`;

    response += `- **${ing.name}**: ${item.quantity_remaining.toFixed(2)} ${ing.unit} — ${urgency}`;
    if (item.lot_number) response += ` (Lotto: ${item.lot_number})`;
    response += '\n';
  });

  return response;
}

async function handleOrderSuggestion(restaurantId: string): Promise<string> {
  const suggestions = await generateOrderSuggestions(restaurantId);

  if (suggestions.length === 0) {
    return '✅ Magazzino OK! Non ci sono ordini urgenti da fare.';
  }

  let response = `📦 **Suggerimenti ordini** (${suggestions.length} prodotti):\n\n`;

  const urgencyLabel = {
    critical: '🔴 URGENTE',
    soon: '🟡 Presto',
    planned: '📅 Pianificato',
  };

  let totalEstimated = 0;

  suggestions.forEach((s) => {
    response += `${urgencyLabel[s.urgency]} **${s.ingredient_name}**\n`;
    response += `  Stock: ${s.current_stock.toFixed(2)}/${s.min_stock} ${s.unit}\n`;
    response += `  Ordina: ${s.suggested_quantity.toFixed(2)} ${s.unit}`;
    if (s.best_supplier) {
      response += ` da ${s.best_supplier} (${s.best_price?.toFixed(2)}€/${s.unit})`;
    }
    response += `\n  Costo stimato: ${s.estimated_cost.toFixed(2)}€\n\n`;
    totalEstimated += s.estimated_cost;
  });

  response += `---\n**Totale stimato ordine: ${totalEstimated.toFixed(2)}€**`;

  return response;
}

async function handlePriceComparison(
  restaurantId: string,
  ingredientName?: string
): Promise<string> {
  return 'TODO: confronto prezzi fornitori';
}

async function handleSalesAnalysis(restaurantId: string): Promise<string> {
  return 'TODO: analisi vendite';
}

async function handlePrediction(
  restaurantId: string,
  timePeriod?: string
): Promise<string> {
  return 'TODO: previsioni domanda (richiede storico vendite di almeno 4 settimane)';
}

async function handleGeneralQuestion(
  restaurantId: string,
  question: string
): Promise<string> {
  // Qui si chiama Claude API per domande generiche
  // con contesto del ristorante
  return 'Posso aiutarti con: food cost, margini, magazzino, scadenze, e suggerimenti ordini. Prova a chiedermi qualcosa di specifico!';
}
```

## Step 6: Test

### `tests/unit/intent-detector.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { detectIntent } from '@/lib/ai/intent-detector';

describe('Intent Detector', () => {
  const ctx = { restaurantName: 'Da Michele' };

  it('rileva FOOD_COST_QUERY per "quanto costa la carbonara"', async () => {
    const result = await detectIntent('quanto costa la carbonara?', ctx);
    expect(result.intent).toBe('FOOD_COST_QUERY');
    expect(result.entities.recipe_name).toBe('carbonara');
  });

  it('rileva FOOD_COST_QUERY per "quanto mi costa il tiramisù"', async () => {
    const result = await detectIntent('quanto mi costa il tiramisù?', ctx);
    expect(result.intent).toBe('FOOD_COST_QUERY');
  });

  it('rileva MARGIN_ANALYSIS per "margine basso"', async () => {
    const result = await detectIntent('quali piatti hanno margine basso?', ctx);
    expect(result.intent).toBe('MARGIN_ANALYSIS');
  });

  it('rileva STOCK_CHECK per "quanto guanciale ho"', async () => {
    const result = await detectIntent('quanto guanciale ho in magazzino?', ctx);
    expect(result.intent).toBe('STOCK_CHECK');
    expect(result.entities.ingredient_name).toBe('guanciale');
  });

  it('rileva EXPIRY_CHECK per "cosa scade"', async () => {
    const result = await detectIntent('cosa sta per scadere?', ctx);
    expect(result.intent).toBe('EXPIRY_CHECK');
  });

  it('rileva ORDER_SUGGESTION per "cosa devo ordinare"', async () => {
    const result = await detectIntent('cosa devo ordinare questa settimana?', ctx);
    expect(result.intent).toBe('ORDER_SUGGESTION');
  });

  it('rileva PRICE_COMPARISON per "miglior fornitore"', async () => {
    const result = await detectIntent(
      'chi è il miglior fornitore per il guanciale?',
      ctx
    );
    expect(result.intent).toBe('PRICE_COMPARISON');
  });

  it('rileva SALES_ANALYSIS per "piatto più venduto"', async () => {
    const result = await detectIntent('qual è il piatto più venduto?', ctx);
    expect(result.intent).toBe('SALES_ANALYSIS');
  });

  it('rileva PREDICTION per "quanto serve per il weekend"', async () => {
    const result = await detectIntent(
      'quanto guanciale mi serve per il weekend?',
      ctx
    );
    expect(result.intent).toBe('PREDICTION');
    expect(result.entities.time_period).toBe('weekend');
  });

  it('fallback a GENERAL_QUESTION per domanda generica', async () => {
    const result = await detectIntent('ciao come stai?', ctx);
    expect(result.intent).toBe('GENERAL_QUESTION');
  });
});
```

### `tests/unit/order-suggestions.test.ts`

```typescript
import { describe, it, expect } from 'vitest';

// Test della logica di suggerimento ordini (senza DB)
describe('Order Suggestion Logic', () => {
  interface StockItem {
    ingredientName: string;
    currentQty: number;
    minQty: number;
    unit: string;
  }

  function classifyUrgency(
    current: number,
    min: number
  ): 'critical' | 'soon' | 'planned' {
    if (current <= 0) return 'critical';
    if (current < min) return 'soon';
    return 'planned';
  }

  function suggestQuantity(current: number, min: number): number {
    // Riporta a 2× soglia minima
    return Math.max(min * 2 - current, min);
  }

  it('classifica stock esaurito come critico', () => {
    expect(classifyUrgency(0, 5)).toBe('critical');
  });

  it('classifica stock sotto soglia come presto', () => {
    expect(classifyUrgency(2, 5)).toBe('soon');
  });

  it('classifica stock sopra soglia come pianificato', () => {
    expect(classifyUrgency(10, 5)).toBe('planned');
  });

  it('suggerisce quantita corretta per stock esaurito', () => {
    // min=5, current=0 → suggerisci max(5*2-0, 5) = 10
    expect(suggestQuantity(0, 5)).toBe(10);
  });

  it('suggerisce quantita corretta per stock sotto soglia', () => {
    // min=5, current=2 → suggerisci max(5*2-2, 5) = 8
    expect(suggestQuantity(2, 5)).toBe(8);
  });

  it('suggerisce almeno la soglia minima', () => {
    // min=5, current=9 → suggerisci max(5*2-9, 5) = max(1, 5) = 5
    expect(suggestQuantity(9, 5)).toBe(5);
  });
});
```

## Checklist Sprint 4

- [ ] Dashboard Food Cost con KPI e tabella piatti
- [ ] Margine colorato per piatto (verde/giallo/rosso)
- [ ] Grafici: distribuzione food cost, top piatti, trend
- [ ] Chat AI funzionante con interfaccia conversazionale
- [ ] Intent Detection per intenti comuni (food cost, stock, scadenze, ordini)
- [ ] Worker Food Cost: calcola e spiega costo per piatto
- [ ] Worker Stock Check: verifica stock ingrediente
- [ ] Worker Scadenze: lista prodotti in scadenza
- [ ] Worker Suggerimenti Ordini: genera lista ordini con fornitore e costo
- [ ] Quick suggestions (chip cliccabili)
- [ ] Storico messaggi chat in DB
- [ ] Test intent detector: tutti verdi
- [ ] Test suggerimenti ordini: tutti verdi
- [ ] `npm run build` zero errori

**NOTA**: Lo Sprint 4 e il cuore "AI-first" del prodotto. L'assistente deve essere UTILE dal primo giorno — non servono previsioni sofisticate subito, basta che risponda correttamente alle domande sul food cost e suggerisca gli ordini basandosi sulle soglie minime. Le previsioni basate su storico vendite arriveranno quando ci saranno dati sufficienti (minimo 4 settimane di comande).

**Quando tutto verde → procedi a Sprint 5 (Polish + Onboarding Michele)**
