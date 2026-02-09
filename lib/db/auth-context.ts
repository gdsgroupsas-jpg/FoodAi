import { getCurrentUser } from './auth';
import { supabaseAdmin } from './client';

export class AuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AuthError';
  }
}

export interface AuthContext {
  userId: string;
  restaurantId: string;
  role: string;
  authUserId: string;
}

/**
 * Ottieni il contesto auth completo: utente + restaurant_id + ruolo.
 * Da usare in OGNI server action come prima riga.
 *
 * @throws AuthError se non autenticato o utente non trovato
 */
export async function getAuthContext(): Promise<AuthContext> {
  const user = await getCurrentUser();
  if (!user) throw new AuthError('Non autenticato');

  const { data: userData, error } = await supabaseAdmin
    .from('users')
    .select('id, restaurant_id, role')
    .eq('auth_user_id', user.id)
    .single();

  if (error || !userData) {
    throw new AuthError('Utente non trovato nel sistema');
  }

  return {
    userId: userData.id,
    restaurantId: userData.restaurant_id,
    role: userData.role,
    authUserId: user.id,
  };
}
