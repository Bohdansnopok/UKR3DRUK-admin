# UKR3DRUK Admin

Центральна Next.js 16 адмін-панель для MED3DRUK і калькулятора 3D-друку. UI українською, project-scoped RBAC, три незалежні Supabase clients, setup/demo mode та server-only privileged pipeline.

## Запуск

```bash
cp .env.example .env.local
npm install
npm run dev
```

Фейкових даних немає. Без env панель показує setup state, реальні списки порожні, а мутації й приватні завантаження вимкнені.

## Central Supabase

Виконайте `supabase/migrations/001_central_admin.sql` у центральному проєкті. Він також створює durable `notification_outbox`. У Supabase калькулятора виконайте `002_calculator_admin_rpc.sql` для атомарної зміни заявки та історії статусів.

Створіть auth users, профілі з такими самими UUID та один раз викличте `sync_owner_emails(array['owner@example.ua'])` через service-role backend. Не давайте execute цього RPC browser-ролям.

### Google-вхід

У Central Supabase відкрийте Authentication → Providers → Google, увімкніть provider та додайте Google OAuth Client ID/Secret. У Google Cloud callback URL має бути `https://<central-project-ref>.supabase.co/auth/v1/callback`, а в Supabase Redirect URLs — `${NEXT_PUBLIC_APP_URL}/auth/callback`. Сам застосунок після OAuth додатково перевіряє central `profiles` і активне project membership; незапрошений email одразу розлогінюється та бачить повідомлення «Ви не є співробітником».

Ролі: `owner` (власник із незнімним повним доступом), `co_owner` (співвласник), `manager`, `production`, `viewer`. Якщо стара central migration уже виконувалась, додатково застосуйте `003_central_roles.sql`.

## Очікувана зовнішня схема

- MED3DRUK: `catalog_products`, `orders`, `crm_clients`, `crm_centers`, `crm_partners`, `model_files`, `deliveries`, `documents`, `workspace_settings`, `app_members`, `audit_events`, `notification_events`; private bucket `workspace-files` (`models/`, `documents/`).
- Calculator: `users`, `print_orders`, `order_files`, `order_status_history`, `saved_quotes`, `uploaded_files`, `email_verifications`, `email_verification_events`, `admin_role_history`; private buckets `order-files`, `calculator-uploads`.

Для атомарної зміни заявки Calculator використовується RPC із міграції `002_calculator_admin_rpc.sql`, яка в одній транзакції оновлює `print_orders` та додає `order_status_history`.

## Email-сповіщення

Заповніть `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` і `CRON_SECRET`. Кожна реалізована мутація створює central audit record та outbox-записи для всіх активних `profiles`, після чого одразу надсилає листи. Для повторної доставки викликайте `POST /api/notifications/retry` з `Authorization: Bearer <CRON_SECRET>` за розкладом. SMTP-секрети залишаються лише на сервері.

## Безпека

Service-role змінні не мають `NEXT_PUBLIC_` і імпортуються лише server-only модулями. `users.password_hash` ніколи не вибирається. Verification code повертається лише замаскованим. Signed URLs створюються сервером на 60 секунд після permission check. Реальні назви колонок зовнішніх баз слід звірити з їх SQL/type exports перед увімкненням production credentials і, за потреби, змінити централізовані select mapping у `lib/data.ts`.
