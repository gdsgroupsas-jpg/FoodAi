import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

/**
 * Crea un client Supabase server-side con RLS attivo (basato sui cookie dell'utente).
 * Da usare in Server Components e Server Actions.
 */
export async function getServerSupabase() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Puo fallire in Server Component (read-only).
            // OK se il middleware gestisce il refresh.
          }
        },
      },
    }
  );
}

/**
 * Ottieni l'utente autenticato corrente.
 * Restituisce null se non autenticato.
 */
export async function getCurrentUser() {
  const supabase = await getServerSupabase();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}
