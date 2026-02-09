import { createClient } from '@supabase/supabase-js';

// Client admin (server only) — bypassa RLS
// USARE SOLO in server actions quando strettamente necessario
export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);
