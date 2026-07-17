export const permissions = [
  "team.read","team.manage","roles.read","roles.manage","audit.read","projects.read","settings.manage",
  "med3druk.dashboard.read","med3druk.orders.read","med3druk.orders.manage","med3druk.products.read","med3druk.products.manage","med3druk.clients.read","med3druk.clients.manage","med3druk.centers.read","med3druk.centers.manage","med3druk.partners.read","med3druk.partners.manage","med3druk.models.read","med3druk.models.manage","med3druk.deliveries.read","med3druk.deliveries.manage","med3druk.documents.read","med3druk.documents.manage","med3druk.analytics.read","med3druk.settings.manage",
  "calculator.dashboard.read","calculator.orders.read","calculator.orders.manage","calculator.order_files.download","calculator.quotes.read","calculator.users.read","calculator.uploads.read","calculator.uploads.download","calculator.email_verifications.read","calculator.analytics.read","calculator.settings.manage",
] as const;
export type Permission = typeof permissions[number];
export type Role = "owner" | "co_owner" | "manager" | "production" | "viewer";
const projectRead = (p: Permission) => (p.startsWith("med3druk.") || p.startsWith("calculator.")) && p.endsWith(".read") && p !== "calculator.email_verifications.read";
export const rolePermissions: Record<Role, Permission[]> = {
  owner: [...permissions],
  co_owner: permissions.filter((p) => p !== "roles.manage" && p !== "calculator.email_verifications.read"),
  manager: permissions.filter((p) => p === "projects.read" || projectRead(p) || ["med3druk.orders.manage","med3druk.products.manage","med3druk.clients.manage","med3druk.centers.manage","med3druk.partners.manage","med3druk.deliveries.manage","med3druk.documents.manage","calculator.orders.manage","calculator.order_files.download","calculator.uploads.download"].includes(p)),
  production: permissions.filter((p) => ["projects.read","med3druk.dashboard.read","med3druk.orders.read","med3druk.orders.manage","med3druk.models.read","med3druk.deliveries.read","med3druk.deliveries.manage","calculator.dashboard.read","calculator.orders.read","calculator.orders.manage","calculator.order_files.download"].includes(p)),
  viewer: permissions.filter((p) => p === "projects.read" || projectRead(p)),
};
