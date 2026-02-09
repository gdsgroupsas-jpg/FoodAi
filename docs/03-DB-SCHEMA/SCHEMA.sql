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
-- FIX APPLICATI: gen_random_uuid(), stati inglese, is_active tavoli,
--   trigger updated_at, RLS complete, funzioni helper.
-- =============================================================================

-- =============================================================================
-- 0. HELPER: Trigger updated_at automatico
-- =============================================================================
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 1. RISTORANTI (Tenant)
-- =============================================================================
CREATE TABLE restaurants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  email TEXT,
  piva TEXT,
  logo_url TEXT,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER set_restaurants_updated_at
  BEFORE UPDATE ON restaurants
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- 2. UTENTI
-- =============================================================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'cameriere'
    CHECK (role IN ('proprietario', 'chef', 'cameriere', 'magazziniere')),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  auth_user_id UUID UNIQUE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_restaurant ON users(restaurant_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_auth ON users(auth_user_id);

-- =============================================================================
-- 3. CATEGORIE INGREDIENTI
-- =============================================================================
CREATE TABLE ingredient_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ingredient_categories_restaurant ON ingredient_categories(restaurant_id);

-- =============================================================================
-- 4. INGREDIENTI
-- =============================================================================
CREATE TABLE ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,
  category_id UUID REFERENCES ingredient_categories(id),
  unit TEXT NOT NULL DEFAULT 'kg'
    CHECK (unit IN ('kg', 'g', 'l', 'ml', 'pz', 'conf')),
  barcode TEXT,
  yield_factor NUMERIC(4,2) DEFAULT 1.00,
  min_stock NUMERIC(10,3) DEFAULT 0,
  shelf_life_days INT,
  allergens TEXT[],
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ingredients_restaurant ON ingredients(restaurant_id);
CREATE INDEX idx_ingredients_barcode ON ingredients(barcode);
CREATE UNIQUE INDEX idx_ingredients_barcode_unique
  ON ingredients(restaurant_id, barcode) WHERE barcode IS NOT NULL;

CREATE TRIGGER set_ingredients_updated_at
  BEFORE UPDATE ON ingredients
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- 5. FORNITORI
-- =============================================================================
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  min_order_amount NUMERIC(10,2),
  delivery_days TEXT[],
  lead_time_hours INT DEFAULT 24,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_suppliers_restaurant ON suppliers(restaurant_id);

-- =============================================================================
-- 6. LISTINI FORNITORE
-- =============================================================================
CREATE TABLE supplier_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  price NUMERIC(10,4) NOT NULL,
  unit TEXT NOT NULL,
  pack_size NUMERIC(10,3),
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_menu_categories_restaurant ON menu_categories(restaurant_id);

-- =============================================================================
-- 8. RICETTE (Piatti del menu)
-- =============================================================================
CREATE TABLE recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,
  category_id UUID REFERENCES menu_categories(id),
  description TEXT,
  selling_price NUMERIC(10,2) NOT NULL,
  portions INT DEFAULT 1,
  prep_time_minutes INT,
  photo_url TEXT,
  allergens TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  is_available BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_recipes_restaurant ON recipes(restaurant_id);
CREATE INDEX idx_recipes_category ON recipes(category_id);

CREATE TRIGGER set_recipes_updated_at
  BEFORE UPDATE ON recipes
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- 9. RICETTA_INGREDIENTI (Distinta base)
-- =============================================================================
CREATE TABLE recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  quantity NUMERIC(10,4) NOT NULL,
  unit TEXT NOT NULL,
  notes TEXT,
  is_optional BOOLEAN DEFAULT FALSE,

  UNIQUE(recipe_id, ingredient_id)
);

CREATE INDEX idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);

-- =============================================================================
-- 10. TAVOLI
-- =============================================================================
CREATE TABLE tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  name TEXT NOT NULL,
  seats INT DEFAULT 4,
  zone TEXT,
  sort_order INT DEFAULT 0,
  status TEXT DEFAULT 'free'
    CHECK (status IN ('free', 'occupied', 'reserved', 'bill_requested')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_tables_restaurant ON tables(restaurant_id);

-- =============================================================================
-- 11. COMANDE
-- =============================================================================
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  table_id UUID REFERENCES tables(id),
  order_number SERIAL,
  order_type TEXT DEFAULT 'dine_in'
    CHECK (order_type IN ('dine_in', 'takeaway', 'delivery')),
  status TEXT DEFAULT 'open'
    CHECK (status IN ('open', 'preparing', 'served', 'closed', 'cancelled')),
  waiter_id UUID REFERENCES users(id),
  covers INT DEFAULT 1,
  notes TEXT,
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

CREATE TRIGGER set_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- 12. COMANDA_ITEMS (Piatti ordinati)
-- =============================================================================
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  recipe_id UUID NOT NULL REFERENCES recipes(id),
  quantity INT NOT NULL DEFAULT 1,
  unit_price NUMERIC(10,2) NOT NULL,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'preparing', 'ready', 'served', 'cancelled')),
  notes TEXT,
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  supplier_id UUID REFERENCES suppliers(id),
  batch_number TEXT,
  quantity_remaining NUMERIC(10,3) NOT NULL,
  unit TEXT NOT NULL,
  purchase_price NUMERIC(10,4),
  received_at TIMESTAMPTZ DEFAULT NOW(),
  expiry_date DATE,
  is_depleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stock_batches_ingredient ON stock_batches(ingredient_id);
CREATE INDEX idx_stock_batches_expiry ON stock_batches(expiry_date)
  WHERE NOT is_depleted;

-- =============================================================================
-- 15. MOVIMENTI MAGAZZINO (Log completo)
-- =============================================================================
CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  batch_id UUID REFERENCES stock_batches(id),
  movement_type TEXT NOT NULL
    CHECK (movement_type IN (
      'load',              -- Merce ricevuta da fornitore
      'unload_order',      -- Scarico automatico da comanda
      'unload_manual',     -- Scarico manuale (spreco, rottura, ecc.)
      'adjustment',        -- Rettifica inventario
      'transfer'           -- Trasferimento tra sedi (futuro)
    )),
  quantity NUMERIC(10,3) NOT NULL,
  unit TEXT NOT NULL,
  reference_id UUID,
  reference_type TEXT,
  reason TEXT,
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
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  status TEXT DEFAULT 'draft'
    CHECK (status IN ('draft', 'sent', 'confirmed', 'received', 'cancelled')),
  order_date DATE DEFAULT CURRENT_DATE,
  expected_delivery DATE,
  total_amount NUMERIC(10,2),
  notes TEXT,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_purchase_orders_restaurant ON purchase_orders(restaurant_id);

CREATE TABLE purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id),
  quantity NUMERIC(10,3) NOT NULL,
  unit TEXT NOT NULL,
  unit_price NUMERIC(10,4),
  received_quantity NUMERIC(10,3),
  notes TEXT
);

-- =============================================================================
-- 17. FOOD COST SNAPSHOTS (Storico giornaliero)
-- =============================================================================
CREATE TABLE food_cost_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id),
  recipe_id UUID NOT NULL REFERENCES recipes(id),
  snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
  food_cost NUMERIC(10,4) NOT NULL,
  selling_price NUMERIC(10,2) NOT NULL,
  margin_amount NUMERIC(10,2) NOT NULL,
  margin_percent NUMERIC(5,2) NOT NULL,
  quantity_sold INT DEFAULT 0,
  revenue NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(restaurant_id, recipe_id, snapshot_date)
);

CREATE INDEX idx_food_cost_snapshots_date ON food_cost_snapshots(snapshot_date);

-- =============================================================================
-- 18. AI CHAT MESSAGES
-- =============================================================================
CREATE TABLE ai_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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

-- Helper: funzione per ottenere il restaurant_id dell'utente corrente
CREATE OR REPLACE FUNCTION auth_restaurant_id()
RETURNS UUID AS $$
  SELECT restaurant_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- RESTAURANTS: il proprietario vede il suo ristorante
CREATE POLICY "restaurant_select" ON restaurants FOR SELECT
  USING (id = auth_restaurant_id());
CREATE POLICY "restaurant_update" ON restaurants FOR UPDATE
  USING (id = auth_restaurant_id());

-- USERS: vedono gli utenti del proprio ristorante
CREATE POLICY "users_select" ON users FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "users_insert" ON users FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "users_update" ON users FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());

-- Macro per tutte le tabelle con restaurant_id
-- (Ogni tabella ha policy CRUD limitate al proprio ristorante)

-- INGREDIENT_CATEGORIES
CREATE POLICY "ingredient_categories_select" ON ingredient_categories FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "ingredient_categories_insert" ON ingredient_categories FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "ingredient_categories_update" ON ingredient_categories FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "ingredient_categories_delete" ON ingredient_categories FOR DELETE
  USING (restaurant_id = auth_restaurant_id());

-- INGREDIENTS
CREATE POLICY "ingredients_select" ON ingredients FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "ingredients_insert" ON ingredients FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "ingredients_update" ON ingredients FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "ingredients_delete" ON ingredients FOR DELETE
  USING (restaurant_id = auth_restaurant_id());

-- SUPPLIERS
CREATE POLICY "suppliers_select" ON suppliers FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "suppliers_insert" ON suppliers FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "suppliers_update" ON suppliers FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "suppliers_delete" ON suppliers FOR DELETE
  USING (restaurant_id = auth_restaurant_id());

-- SUPPLIER_PRICES
CREATE POLICY "supplier_prices_select" ON supplier_prices FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "supplier_prices_insert" ON supplier_prices FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "supplier_prices_update" ON supplier_prices FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "supplier_prices_delete" ON supplier_prices FOR DELETE
  USING (restaurant_id = auth_restaurant_id());

-- MENU_CATEGORIES
CREATE POLICY "menu_categories_select" ON menu_categories FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "menu_categories_insert" ON menu_categories FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "menu_categories_update" ON menu_categories FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "menu_categories_delete" ON menu_categories FOR DELETE
  USING (restaurant_id = auth_restaurant_id());

-- RECIPES
CREATE POLICY "recipes_select" ON recipes FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "recipes_insert" ON recipes FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "recipes_update" ON recipes FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "recipes_delete" ON recipes FOR DELETE
  USING (restaurant_id = auth_restaurant_id());

-- RECIPE_INGREDIENTS (join tramite recipe)
CREATE POLICY "recipe_ingredients_select" ON recipe_ingredients FOR SELECT
  USING (recipe_id IN (SELECT id FROM recipes WHERE restaurant_id = auth_restaurant_id()));
CREATE POLICY "recipe_ingredients_insert" ON recipe_ingredients FOR INSERT
  WITH CHECK (recipe_id IN (SELECT id FROM recipes WHERE restaurant_id = auth_restaurant_id()));
CREATE POLICY "recipe_ingredients_update" ON recipe_ingredients FOR UPDATE
  USING (recipe_id IN (SELECT id FROM recipes WHERE restaurant_id = auth_restaurant_id()));
CREATE POLICY "recipe_ingredients_delete" ON recipe_ingredients FOR DELETE
  USING (recipe_id IN (SELECT id FROM recipes WHERE restaurant_id = auth_restaurant_id()));

-- TABLES
CREATE POLICY "tables_select" ON tables FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "tables_insert" ON tables FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "tables_update" ON tables FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "tables_delete" ON tables FOR DELETE
  USING (restaurant_id = auth_restaurant_id());

-- ORDERS
CREATE POLICY "orders_select" ON orders FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "orders_insert" ON orders FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "orders_update" ON orders FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());

-- ORDER_ITEMS (join tramite order)
CREATE POLICY "order_items_select" ON order_items FOR SELECT
  USING (order_id IN (SELECT id FROM orders WHERE restaurant_id = auth_restaurant_id()));
CREATE POLICY "order_items_insert" ON order_items FOR INSERT
  WITH CHECK (order_id IN (SELECT id FROM orders WHERE restaurant_id = auth_restaurant_id()));
CREATE POLICY "order_items_update" ON order_items FOR UPDATE
  USING (order_id IN (SELECT id FROM orders WHERE restaurant_id = auth_restaurant_id()));

-- STOCK
CREATE POLICY "stock_select" ON stock FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "stock_insert" ON stock FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "stock_update" ON stock FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());

-- STOCK_BATCHES
CREATE POLICY "stock_batches_select" ON stock_batches FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "stock_batches_insert" ON stock_batches FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "stock_batches_update" ON stock_batches FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());

-- STOCK_MOVEMENTS
CREATE POLICY "stock_movements_select" ON stock_movements FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "stock_movements_insert" ON stock_movements FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());

-- PURCHASE_ORDERS
CREATE POLICY "purchase_orders_select" ON purchase_orders FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "purchase_orders_insert" ON purchase_orders FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());
CREATE POLICY "purchase_orders_update" ON purchase_orders FOR UPDATE
  USING (restaurant_id = auth_restaurant_id());

-- PURCHASE_ORDER_ITEMS (join tramite purchase_order)
CREATE POLICY "purchase_order_items_select" ON purchase_order_items FOR SELECT
  USING (purchase_order_id IN (SELECT id FROM purchase_orders WHERE restaurant_id = auth_restaurant_id()));
CREATE POLICY "purchase_order_items_insert" ON purchase_order_items FOR INSERT
  WITH CHECK (purchase_order_id IN (SELECT id FROM purchase_orders WHERE restaurant_id = auth_restaurant_id()));
CREATE POLICY "purchase_order_items_update" ON purchase_order_items FOR UPDATE
  USING (purchase_order_id IN (SELECT id FROM purchase_orders WHERE restaurant_id = auth_restaurant_id()));

-- FOOD_COST_SNAPSHOTS
CREATE POLICY "food_cost_snapshots_select" ON food_cost_snapshots FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "food_cost_snapshots_insert" ON food_cost_snapshots FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());

-- AI_MESSAGES
CREATE POLICY "ai_messages_select" ON ai_messages FOR SELECT
  USING (restaurant_id = auth_restaurant_id());
CREATE POLICY "ai_messages_insert" ON ai_messages FOR INSERT
  WITH CHECK (restaurant_id = auth_restaurant_id());

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

-- Scarico FIFO: scala quantita dal lotto piu vecchio non esaurito
CREATE OR REPLACE FUNCTION fifo_unload(
  p_restaurant_id UUID,
  p_ingredient_id UUID,
  p_quantity NUMERIC,
  p_unit TEXT,
  p_user_id UUID,
  p_reference_id UUID DEFAULT NULL,
  p_reference_type TEXT DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_remaining NUMERIC := p_quantity;
  v_batch RECORD;
  v_deduct NUMERIC;
BEGIN
  FOR v_batch IN
    SELECT id, quantity_remaining
    FROM stock_batches
    WHERE restaurant_id = p_restaurant_id
      AND ingredient_id = p_ingredient_id
      AND NOT is_depleted
      AND quantity_remaining > 0
    ORDER BY received_at ASC  -- FIFO: piu vecchio prima
  LOOP
    EXIT WHEN v_remaining <= 0;

    v_deduct := LEAST(v_batch.quantity_remaining, v_remaining);

    UPDATE stock_batches
    SET quantity_remaining = quantity_remaining - v_deduct,
        is_depleted = (quantity_remaining - v_deduct <= 0)
    WHERE id = v_batch.id;

    -- Log del movimento
    INSERT INTO stock_movements (
      restaurant_id, ingredient_id, batch_id, movement_type,
      quantity, unit, reference_id, reference_type, reason, performed_by
    ) VALUES (
      p_restaurant_id, p_ingredient_id, v_batch.id, 'unload_order',
      -v_deduct, p_unit, p_reference_id, p_reference_type, p_reason, p_user_id
    );

    v_remaining := v_remaining - v_deduct;
  END LOOP;

  -- Aggiorna stock corrente
  UPDATE stock
  SET current_quantity = current_quantity - p_quantity,
      last_updated = NOW()
  WHERE restaurant_id = p_restaurant_id
    AND ingredient_id = p_ingredient_id;
END;
$$ LANGUAGE plpgsql;

-- Funzione: ingredienti sotto scorta minima
CREATE OR REPLACE FUNCTION get_low_stock_items(p_restaurant_id UUID)
RETURNS TABLE (
  ingredient_id UUID,
  ingredient_name TEXT,
  current_qty NUMERIC,
  min_stock NUMERIC,
  unit TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.name,
    COALESCE(s.current_quantity, 0),
    i.min_stock,
    i.unit
  FROM ingredients i
  LEFT JOIN stock s ON s.ingredient_id = i.id AND s.restaurant_id = i.restaurant_id
  WHERE i.restaurant_id = p_restaurant_id
    AND i.is_active = TRUE
    AND COALESCE(s.current_quantity, 0) <= i.min_stock
  ORDER BY COALESCE(s.current_quantity, 0) / NULLIF(i.min_stock, 0) ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Funzione: lotti in scadenza nei prossimi N giorni
CREATE OR REPLACE FUNCTION get_expiring_batches(
  p_restaurant_id UUID,
  p_days INT DEFAULT 3
)
RETURNS TABLE (
  batch_id UUID,
  ingredient_name TEXT,
  quantity_remaining NUMERIC,
  unit TEXT,
  expiry_date DATE,
  days_until_expiry INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    sb.id,
    i.name,
    sb.quantity_remaining,
    sb.unit,
    sb.expiry_date,
    (sb.expiry_date - CURRENT_DATE)::INT
  FROM stock_batches sb
  JOIN ingredients i ON i.id = sb.ingredient_id
  WHERE sb.restaurant_id = p_restaurant_id
    AND NOT sb.is_depleted
    AND sb.expiry_date IS NOT NULL
    AND sb.expiry_date <= CURRENT_DATE + p_days
  ORDER BY sb.expiry_date ASC;
END;
$$ LANGUAGE plpgsql STABLE;
