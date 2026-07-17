import "server-only";
import { serviceClient } from "./supabase";
import { isDemoMode } from "./config";
import type { Permission } from "./rbac";
import { requirePermission } from "./auth";

export type Row = Record<string, unknown>;
export async function secureList(project: "admin"|"med3druk"|"calculator", table: string, permission: Permission, page = 1, query = "") {
  await requirePermission(permission);
  if (isDemoMode()) return [];
  const client = serviceClient(project); if (!client) return [];
  const from = Math.max(0, page - 1) * 25;
  let request = client.from(table).select(safeSelect[table] ?? "*").range(from, from + 24).order("created_at", { ascending: false });
  if (query && searchColumns[table]) request = request.ilike(searchColumns[table], `%${query.slice(0, 100)}%`);
  const { data, error } = await request; if (error) throw new Error(`Не вдалося завантажити ${table}`); return data as unknown as Row[];
}
const safeSelect: Record<string,string> = {
 users:"id,name,email,auth_provider,email_verified_at,role,plan,created_at",
 email_verifications:"email,purpose,expires_at,sent_at,attempts",
 uploaded_files:"id,user_id,original_name,kind,size_bytes,source,created_at",
 print_orders:"id,order_number,customer_name,customer_email,customer_phone,model_name,material,color,weight_grams,print_time_minutes,quantity,displayed_price,currency,pricing_option,status,admin_note,created_at",
 saved_quotes:"id,user_id,part_name,material,weight_grams,print_time_minutes,quantity,selected_pricing,selected_price_with_vat_eur,display_currency,created_at",
 orders:"id,public_code,client_name,client_email,center,model,status,assigned_to,unit_price,created_at",
 catalog_products:"id,slug,name,category,material,compatibility,base_price,currency,status,is_featured,rating,created_at",
 crm_clients:"id,full_name,email,phone,status,created_at",crm_centers:"id,name,city,email,phone,status,created_at",crm_partners:"id,name,kind,email,phone,contract_status,created_at",
 model_files:"id,name,file_type,version,size_bytes,status,created_at",deliveries:"id,carrier,tracking_number,status,recipient_name,destination,created_at",documents:"id,title,document_type,status,issued_at,created_at",
 profiles:"id,full_name,email,status,is_owner,created_at",audit_logs:"id,actor_id,project_key,action,entity_type,entity_id,created_at"
};
const searchColumns: Record<string,string> = { users:"email",print_orders:"customer_email",saved_quotes:"id",uploaded_files:"original_name",email_verifications:"email" };
