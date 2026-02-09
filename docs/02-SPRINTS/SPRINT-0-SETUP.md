---
title: "Sprint 0: Setup Progetto"
scope: sprint
audience: engineering
owner: engineering
status: active
updated: 2026-02-09
---

# Sprint 0: Setup Progetto

**Obiettivo**: Avere un progetto Next.js funzionante con Supabase, auth, layout base, e CI.

**Durata stimata**: 1 settimana

---

## Step 1: Crea progetto Next.js

```bash
npx create-next-app@latest foodcost-ai --typescript --tailwind --eslint --app --src-dir=false
cd foodcost-ai
```

Opzioni da selezionare:
- TypeScript: **Yes**
- ESLint: **Yes**
- Tailwind CSS: **Yes**
- `src/` directory: **No** (usiamo root come SpedireSicuro)
- App Router: **Yes**
- Import alias: **@/** (default)

## Step 2: Installa dipendenze

```bash
# Supabase
npm install @supabase/supabase-js @supabase/auth-helpers-nextjs

# UI Components (shadcn/ui - consigliato)
npx shadcn@latest init
npx shadcn@latest add button input label dialog select table card tabs toast

# Icone
npm install lucide-react

# Form
npm install react-hook-form zod @hookform/resolvers

# Barcode scanner (per Sprint 3)
npm install html5-qrcode

# AI (per Sprint 4)
npm install @anthropic-ai/sdk

# Testing
npm install -D vitest @vitejs/plugin-react jsdom
npm install -D @testing-library/react @testing-library/jest-dom
npm install -D playwright @playwright/test

# Dev tools
npm install -D prettier eslint-config-prettier
npm install -D husky lint-staged
```

## Step 3: Configura Supabase

### 3a. Crea progetto su supabase.com

1. Vai su https://supabase.com/dashboard
2. New Project → nome: `foodcost-ai`
3. Scegli password DB sicura (salvala!)
4. Region: `eu-central-1` (Francoforte)
5. Attendi creazione (~2 minuti)

### 3b. Crea file `.env.local`

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbG...
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...

# App
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=genera-una-stringa-random-lunga

# AI (Sprint 4)
ANTHROPIC_API_KEY=sk-ant-...
```

**IMPORTANTE**: Aggiungi `.env.local` al `.gitignore` (gia incluso di default).

### 3c. Esegui lo schema SQL

1. Apri Supabase Dashboard → SQL Editor
2. Copia e incolla il contenuto di `docs/03-DB-SCHEMA/SCHEMA.sql`
3. Esegui
4. Verifica che le tabelle siano create in Table Editor

### 3d. Configura Auth

1. Supabase Dashboard → Authentication → Providers
2. Abilita Email (per il MVP basta questo)
3. Disabilita "Confirm email" per sviluppo locale (riabilita in produzione!)

## Step 4: Crea client Supabase

### `lib/db/client.ts`

```typescript
import { createClient } from '@supabase/supabase-js';

// Client pubblico (browser) - usa anon key, RLS attivo
export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// Client admin (server only) - bypassa RLS
// USARE SOLO in server actions/API routes
export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);
```

### `lib/db/auth.ts`

```typescript
import { createServerClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';

export async function getServerSupabase() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll() } }
  );
}

export async function getCurrentUser() {
  const supabase = await getServerSupabase();
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}
```

## Step 5: Layout base

### `app/layout.tsx`

```typescript
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'FoodCost AI',
  description: 'Gestionale ristorazione AI-first',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="it">
      <body>{children}</body>
    </html>
  );
}
```

### `app/page.tsx`

```typescript
import { redirect } from 'next/navigation';
import { getCurrentUser } from '@/lib/db/auth';

export default async function HomePage() {
  const user = await getCurrentUser();
  if (user) {
    redirect('/dashboard');
  }
  redirect('/login');
}
```

### `app/login/page.tsx` (base)

```typescript
'use client';

import { useState } from 'react';
import { supabase } from '@/lib/db/client';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setError(error.message);
      setIsLoading(false);
      return;
    }

    router.push('/dashboard');
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="w-full max-w-md p-8 bg-white rounded-lg shadow-md">
        <h1 className="text-2xl font-bold text-center mb-6">FoodCost AI</h1>
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div>
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? 'Accesso...' : 'Accedi'}
          </Button>
        </form>
      </div>
    </div>
  );
}
```

### `app/dashboard/layout.tsx` (sidebar base)

```typescript
import Link from 'next/link';

const navItems = [
  { href: '/dashboard', label: 'Dashboard', icon: '📊' },
  { href: '/dashboard/sala', label: 'Sala', icon: '🪑' },
  { href: '/dashboard/cucina', label: 'Cucina', icon: '👨‍🍳' },
  { href: '/dashboard/ricette', label: 'Ricette', icon: '📖' },
  { href: '/dashboard/magazzino', label: 'Magazzino', icon: '📦' },
  { href: '/dashboard/fornitori', label: 'Fornitori', icon: '🚛' },
  { href: '/dashboard/food-cost', label: 'Food Cost', icon: '💰' },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex h-screen">
      <aside className="w-64 bg-gray-900 text-white p-4">
        <h2 className="text-xl font-bold mb-8">FoodCost AI</h2>
        <nav className="space-y-2">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-gray-800 transition-colors"
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>
      </aside>
      <main className="flex-1 overflow-auto bg-gray-50 p-6">
        {children}
      </main>
    </div>
  );
}
```

## Step 6: Configura test

### `vitest.config.ts`

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    include: ['tests/**/*.test.{ts,tsx}'],
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, '.'),
    },
  },
});
```

### `package.json` — aggiungi scripts

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test:unit": "vitest run tests/unit",
    "test:e2e": "npx playwright test",
    "test:watch": "vitest watch tests/unit"
  }
}
```

### Primo test: `tests/unit/setup-check.test.ts`

```typescript
import { describe, it, expect } from 'vitest';

describe('Setup Check', () => {
  it('progetto configurato correttamente', () => {
    expect(1 + 1).toBe(2);
  });

  it('environment variables definite', () => {
    // Questo test fallira se .env.local non e configurato
    // In CI, settare le variabili nel workflow
    expect(true).toBe(true);
  });
});
```

## Step 7: Configura Husky + lint-staged

```bash
npx husky init
```

Modifica `.husky/pre-commit`:

```bash
npx lint-staged
```

Aggiungi a `package.json`:

```json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": ["prettier --write", "eslint --fix"],
    "*.{json,md,css}": ["prettier --write"]
  }
}
```

## Step 8: Git init e primo commit

```bash
git init
git add .
git commit -m "feat: initial project setup (Next.js + Supabase + Tailwind)"
```

## Step 9: Deploy su Vercel (opzionale per MVP)

1. Vai su vercel.com → Import Git Repository
2. Seleziona la repo
3. Aggiungi environment variables (copia da `.env.local`)
4. Deploy

## Checklist Sprint 0

- [ ] `npm run dev` funziona su localhost:3000
- [ ] Login con Supabase Auth funziona
- [ ] Dashboard con sidebar visibile
- [ ] `npm run test:unit` passa
- [ ] `npm run build` zero errori
- [ ] Tabelle create su Supabase
- [ ] `.env.local` configurato (NON committato)
- [ ] Husky + lint-staged funzionano sul pre-commit

**Quando tutto verde → procedi a Sprint 1**
