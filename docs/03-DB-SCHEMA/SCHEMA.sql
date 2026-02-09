-- =============================================================================
-- FoodCost AI - Schema Database Completo (Supabase/PostgreSQL)
-- =============================================================================
-- title: Schema Database
-- scope: database
-- audience: engineering
-- owner: engineering
-- status: active
-- source_of_truth: true
-- updated: 2026-02-09
-- =============================================================================
-- Eseguire su Supabase SQL Editor nell'ordine indicato.
-- Ogni tabella ha RLS abilitato con policy per isolamento multi-tenant.
-- =============================================================================

-- 0. EXTENSIONS
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- 1. RISTORANTI (Tenant)
-- =============================================================================
CREATE TABLE restaurants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  email TEXT,
  piva TEXT,                           -- Partita IVA
  logo_url TEXT,
  settings JSONB DEFAULT '{}',         -- Impostazioni personalizzabili
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- 2. UTENTI
-- =============================================================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'cameriere'
    CHECK (role IN ('proprietario', 'chef', 'cameriere', 'magazziniere')),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  auth_user_id UUID,                   -- Link a Supabase Auth
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_restaurant ON users(restaurant_id);
CREATE INDEX idx_users_email ON users(email);

-- =============================================================================
-- 3. CATEGORIE INGREDIENTI
-- =============================================================================
CREATE TABLE ingredient_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,                  -- Es: "Latticini", "Carni", "Verdure"
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- 4. INGREDIENTI
-- =============================================================================
CREATE TABLE ingredients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,                  -- Es: "Mozzarella di bufala"
  category_id UUID REFERENCES ingredient_categories(id),
  unit TEXT NOT NULL DEFAULT 'kg'
    CHECK (unit IN ('kg', 'g', 'l', 'ml', 'pz', 'conf')),
  barcode TEXT,                        -- Codice a barre EAN-13
  yield_factor NUMERIC(4,2) DEFAULT 1.00,
    -- Fattore resa: 1.00 = nessun calo, 0.70 = 30% calo peso cottura
    -- Es: 1kg carne cruda → 0.70kg cotta
  min_stock NUMERIC(10,3) DEFAULT 0,   -- Soglia minima per alert
  shelf_life_days INT,                 -- Giorni shelf life tipica
  allergens TEXT[],                    -- Es: {'glutine', 'lattosio'}
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ingredients_restaurant ON ingredients(restaurant_id);
CREATE INDEX idx_ingredients_barcode ON ingredients(barcode);
CREATE UNIQUE INDEX idx_ingredients_barcode_unique
  ON ingredients(restaurant_id, barcode) WHERE barcode IS NOT NULL;

-- =============================================================================
-- 5. FORNITORI
-- =============================================================================
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,                  -- Es: "Caseificio Napoli"
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  min_order_amount NUMERIC(10,2),      -- Ordine minimo in EUR
  delivery_days TEXT[],                -- Es: {'lunedi', 'mercoledi', 'venerdi'}
  lead_time_hours INT DEFAULT 24,      -- Ore tra ordine e consegna
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_suppliers_restaurant ON suppliers(restaurant_id);

-- =============================================================================
-- 6. LISTINI FORNITORE (Prezzi ingredienti)
-- =============================================================================
CREATE TABLE supplier_prices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  price NUMERIC(10,4) NOT NULL,        -- Prezzo per unita
  unit TEXT NOT NULL,                  -- Unita del prezzo (kg, pz, conf)
  pack_size NUMERIC(10,3),             -- Dimensione confezione (es: 1.0 kg, 6 pz)
  valid_from DATE DEFAULT CURRENT_DATE,
  valid_until DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_supplier_prices_ingredient ON supplier_prices(ingredient_id);
CREATE INDEX idx_supplier_prices_supplier ON supplier_prices(supplier_id);

-- =============================================================================
-- 7. CATEGORIE MENU
-- =============================================================================
CREATE TABLE menu_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,                  -- Es: "Antipasti", "Primi", "Secondi"
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- 8. RICETTE (Piatti del menu)
-- =============================================================================
CREATE TABLE recipes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,                  -- Es: "Carbonara"
  category_id UUID REFERENCES menu_categories(id),
  description TEXT,
  selling_price NUMERIC(10,2) NOT NULL, -- Prezzo di vendita
  portions INT DEFAULT 1,              -- Porzioni per preparazione
  prep_time_minutes INT,               -- Tempo preparazione
  photo_url TEXT,
  allergens TEXT[],                    -- Calcolati dagli ingredienti + override
  is_active BOOLEAN DEFAULT TRUE,      -- Visibile nel menu
  is_available BOOLEAN DEFAULT TRUE,   -- Disponibile oggi (puo cambiare)
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_recipes_restaurant ON recipes(restaurant_id);
CREATE INDEX idx_recipes_category ON recipes(category_id);

-- =============================================================================
-- 9. RICETTA_INGREDIENTI (Distinta base)
-- =============================================================================
CREATE TABLE recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  quantity NUMERIC(10,4) NOT NULL,     -- Dose per porzione (in unita dell'ingrediente)
  unit TEXT NOT NULL,                  -- Unita della dose (g, ml, pz)
  notes TEXT,                          -- Es: "a dadini", "grattugiato"
  is_optional BOOLEAN DEFAULT FALSE,   -- Ingrediente opzionale (variante)

  UNIQUE(recipe_id, ingredient_id)
);

CREATE INDEX idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);

-- =============================================================================
-- 10. TAVOLI
-- =============================================================================
CREATE TABLE tables (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,                  -- Es: "Tavolo 1", "Bancone", "Esterno 3"
  seats INT DEFAULT 4,
  zone TEXT,                           -- Es: "Sala", "Esterno", "Piano 1"
  sort_order INT DEFAULT 0,
  status TEXT DEFAULT 'libero'
    CHECK (status IN ('libero', 'occupato', 'prenotato', 'conto_richiesto')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tables_restaurant ON tables(restaurant_id);

-- =============================================================================
-- 11. COMANDE
-- =============================================================================
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  table_id UUID REFERENCES tables(id),
  order_number SERIAL,                 -- Numero progressivo giornaliero
  order_type TEXT DEFAULT 'dine_in'
    CHECK (order_type IN ('dine_in', 'takeaway', 'delivery')),
  status TEXT DEFAULT 'aperta'
    CHECK (status IN ('aperta', 'in_preparazione', 'servita', 'chiusa', 'annullata')),
  waiter_id UUID REFERENCES users(id),
  covers INT DEFAULT 1,               -- Numero coperti
  notes TEXT,                          -- Note generali comanda
  subtotal NUMERIC(10,2) DEFAULT 0,
  total NUMERIC(10,2) DEFAULT 0,
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_restaurant ON orders(restaurant_id);
CREATE INDEX idx_orders_table ON orders(table_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_date ON orders(created_at);

-- =============================================================================
-- 12. COMANDA_ITEMS (Piatti ordinati)
-- =============================================================================
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  recipe_id UUID NOT NULL REFERENCES recipes(id),
  quantity INT NOT NULL DEFAULT 1,
  unit_price NUMERIC(10,2) NOT NULL,   -- Prezzo al momento dell'ordine
  status TEXT DEFAULT 'ordinato'
    CHECK (status IN ('ordinato', 'in_preparazione', 'pronto', 'servito', 'annullato')),
  notes TEXT,                          -- Es: "senza glutine", "ben cotta"
  sent_to_kitchen_at TIMESTAMPTZ,
  ready_at TIMESTAMPTZ,
  served_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_status ON order_items(status);

-- =============================================================================
-- 13. MAGAZZINO - STOCK CORRENTE
-- =============================================================================
CREATE TABLE stock (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  current_quantity NUMERIC(10,3) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL,
  last_updated TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(restaurant_id, ingredient_id)
);

CREATE INDEX idx_stock_restaurant ON stock(restaurant_id);
CREATE INDEX idx_stock_ingredient ON stock(ingredient_id);

-- =============================================================================
-- 14. MAGAZZINO - LOTTI (per FIFO e scadenze)
-- =============================================================================
CREATE TABLE stock_batches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  supplier_id UUID REFERENCES suppliers(id),
  batch_number TEXT,                   -- Numero lotto fornitore
  quantity_remaining NUMERIC(10,3) NOT NULL,
  unit TEXT NOT NULL,
  purchase_price NUMERIC(10,4),        -- Prezzo di acquisto per unita
  received_at TIMESTAMPTZ DEFAULT NOW(),
  expiry_date DATE,                    -- Data scadenza
  is_depleted BOOLEAN DEFAULT FALSE,   -- Lotto esaurito
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stock_batches_ingredient ON stock_batches(ingredient_id);
CREATE INDEX idx_stock_batches_expiry ON stock_batches(expiry_date)
  WHERE NOT is_depleted;

-- =============================================================================
-- 15. MOVIMENTI MAGAZZINO (Log completo)
-- =============================================================================
CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  batch_id UUID REFERENCES stock_batches(id),
  movement_type TEXT NOT NULL
    CHECK (movement_type IN (
      'carico',          -- Merce ricevuta da fornitore
      'scarico_comanda', -- Scarico automatico da comanda
      'scarico_manuale', -- Scarico manuale (spreco, rottura, ecc.)
      'rettifica',       -- Rettifica inventario
      'trasferimento'    -- Trasferimento tra sedi (futuro)
    )),
  quantity NUMERIC(10,3) NOT NULL,     -- Positivo per carico, negativo per scarico
  unit TEXT NOT NULL,
  reference_id UUID,                   -- ID comanda/ordine fornitore collegato
  reference_type TEXT,                 -- 'order_item', 'purchase_order', ecc.
  reason TEXT,                         -- Causale (es: "spreco", "rottura", "scaduto")
  performed_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stock_movements_ingredient ON stock_movements(ingredient_id);
CREATE INDEX idx_stock_movements_date ON stock_movements(created_at);
CREATE INDEX idx_stock_movements_type ON stock_movements(movement_type);

-- =============================================================================
-- 16. ORDINI FORNITORE
-- =============================================================================
CREATE TABLE purchase_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  status TEXT DEFAULT 'bozza'
    CHECK (status IN ('bozza', 'inviato', 'confermato', 'ricevuto', 'annullato')),
  order_date DATE DEFAULT CURRENT_DATE,
  expected_delivery DATE,
  total_amount NUMERIC(10,2),
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE purchase_order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  quantity NUMERIC(10,3) NOT NULL,
  unit TEXT NOT NULL,
  unit_price NUMERIC(10,4),
  received_quantity NUMERIC(10,3),     -- Quantita effettivamente ricevuta
  notes TEXT
);

-- =============================================================================
-- 17. FOOD COST SNAPSHOTS (Storico giornaliero)
-- =============================================================================
CREATE TABLE food_cost_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  recipe_id UUID NOT NULL REFERENCES recipes(id),
  snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
  food_cost NUMERIC(10,4) NOT NULL,    -- Costo ingredienti calcolato
  selling_price NUMERIC(10,2) NOT NULL,
  margin_amount NUMERIC(10,2) NOT NULL,
  margin_percent NUMERIC(5,2) NOT NULL,
  quantity_sold INT DEFAULT 0,         -- Piatti venduti quel giorno
  revenue NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(restaurant_id, recipe_id, snapshot_date)
);

CREATE INDEX idx_food_cost_snapshots_date ON food_cost_snapshots(snapshot_date);

-- =============================================================================
-- 18. AI CHAT MESSAGES (Storico conversazioni)
-- =============================================================================
CREATE TABLE ai_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  user_id UUID NOT NULL REFERENCES users(id),
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_messages_restaurant ON ai_messages(restaurant_id);

-- =============================================================================
-- RLS POLICIES (Row Level Security)
-- =============================================================================
-- Abilitare RLS su tutte le tabelle
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_cost_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;

-- Policy di esempio: ogni utente vede solo i dati del suo ristorante
-- (Replicare per ogni tabella con restaurant_id)
CREATE POLICY "Users see own restaurant"
  ON users FOR ALL
  USING (restaurant_id IN (
    SELECT restaurant_id FROM users WHERE auth_user_id = auth.uid()
  ));

-- NOTA: Creare policy simili per TUTTE le tabelle.
-- Vedi docs/02-SPRINTS/SPRINT-0-SETUP.md per le policy complete.

-- =============================================================================
-- FUNZIONI HELPER
-- =============================================================================

-- Calcola food cost per una ricetta
CREATE OR REPLACE FUNCTION calc_recipe_food_cost(p_recipe_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_total NUMERIC := 0;
BEGIN
  SELECT COALESCE(SUM(
    ri.quantity * COALESCE(sp.price, 0) * COALESCE(i.yield_factor, 1.0)
  ), 0)
  INTO v_total
  FROM recipe_ingredients ri
  JOIN ingredients i ON i.id = ri.ingredient_id
  LEFT JOIN LATERAL (
    SELECT price
    FROM supplier_prices sp2
    WHERE sp2.ingredient_id = ri.ingredient_id
      AND sp2.valid_from <= CURRENT_DATE
      AND (sp2.valid_until IS NULL OR sp2.valid_until >= CURRENT_DATE)
    ORDER BY sp2.valid_from DESC
    LIMIT 1
  ) sp ON TRUE
  WHERE ri.recipe_id = p_recipe_id;

  RETURN v_total;
END;
$$ LANGUAGE plpgsql STABLE;
