import { createBrowserClient } from '@supabase/ssr';

/**
 * Client Supabase per componenti client ('use client').
 * RLS attivo — l'utente vede solo i dati del suo ristorante.
 */
export function createBrowserSupabase() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
