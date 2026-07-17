import "server-only";

export type ConnectionKey = "admin" | "med3druk" | "calculator";
const configs = {
  admin: [process.env.NEXT_PUBLIC_ADMIN_SUPABASE_URL, process.env.ADMIN_SUPABASE_SERVICE_ROLE_KEY],
  med3druk: [process.env.MED3DRUK_SUPABASE_URL, process.env.MED3DRUK_SUPABASE_SERVICE_ROLE_KEY],
  calculator: [process.env.CALCULATOR_SUPABASE_URL, process.env.CALCULATOR_SUPABASE_SERVICE_ROLE_KEY],
} satisfies Record<ConnectionKey, (string | undefined)[]>;

export const connectionStatus = () => Object.fromEntries(Object.entries(configs).map(([key, values]) => [key, values.every(Boolean)])) as Record<ConnectionKey, boolean>;
export const isDemoMode = () => !Object.values(connectionStatus()).every(Boolean);
export const ownerEmails = () => (process.env.OWNER_EMAILS ?? "").split(",").map((v) => v.trim().toLowerCase()).filter(Boolean);
