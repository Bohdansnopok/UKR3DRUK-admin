import "server-only";
import { cache } from "react";
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";
import { redirect } from "next/navigation";
import { ownerEmails } from "./config";
import { serviceClient } from "./supabase";
import { rolePermissions, type Permission, type Role } from "./rbac";

export type SessionProfile = { id: string; email: string; name: string; role: Role; permissions: Permission[]; demo: boolean };
export const getSessionProfile = cache(async (): Promise<SessionProfile | null> => {
  const url = process.env.NEXT_PUBLIC_ADMIN_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_ADMIN_SUPABASE_ANON_KEY;
  if (!url || !anon) return null;
  const store = await cookies();
  const client = createServerClient(url, anon, {
    cookies: {
      getAll: () => store.getAll(),
      setAll: (items) => {
        try {
          items.forEach(({ name, value, options }) => store.set(name, value, options));
        } catch {
          // Server Components cannot persist a refreshed session. A route
          // handler or proxy will do that on the next request.
        }
      },
    },
  });

  try {
    const { data: { user }, error: authError } = await client.auth.getUser();
    if (authError || !user?.email) return null;

    const admin = serviceClient("admin");
    if (!admin) return null;
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id,email,full_name,status,is_owner")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError || !profile || profile.status !== "active") return null;

    const owner = profile.is_owner || ownerEmails().includes(user.email.toLowerCase());
    if (owner) return { id: user.id, email: user.email, name: profile.full_name ?? user.email, role: "owner", permissions: rolePermissions.owner, demo: false };

    const { data, error: permissionsError } = await admin
      .from("effective_user_permissions")
      .select("permission_key")
      .eq("user_id", user.id);
    if (permissionsError) return null;
    return { id: user.id, email: user.email, name: profile.full_name ?? user.email, role: "viewer", permissions: (data ?? []).map((v) => v.permission_key as Permission), demo: false };
  } catch {
    return null;
  }
});
export async function requirePermission(permission: Permission) { const user = await getSessionProfile(); if (!user) redirect("/login"); if (!user.permissions.includes(permission)) redirect("/forbidden"); return user; }
