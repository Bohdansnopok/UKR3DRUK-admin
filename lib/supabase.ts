import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { ConnectionKey } from "./config";

export function serviceClient(project: ConnectionKey): SupabaseClient | null {
  const env = project === "admin"
    ? [process.env.NEXT_PUBLIC_ADMIN_SUPABASE_URL, process.env.ADMIN_SUPABASE_SERVICE_ROLE_KEY]
    : project === "med3druk"
      ? [process.env.MED3DRUK_SUPABASE_URL, process.env.MED3DRUK_SUPABASE_SERVICE_ROLE_KEY]
      : [process.env.CALCULATOR_SUPABASE_URL, process.env.CALCULATOR_SUPABASE_SERVICE_ROLE_KEY];
  if (!env[0] || !env[1]) return null;
  return createClient(env[0], env[1], { auth: { persistSession: false, autoRefreshToken: false } });
}
