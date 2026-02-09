import { redirect } from 'next/navigation';

/**
 * Root page — redirect a /login.
 * Il middleware gestira il redirect a /dashboard se l'utente e gia autenticato.
 */
export default function HomePage() {
  redirect('/login');
}
