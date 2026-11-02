# 🗄️ توثيق قاعدة بيانات MyLawyer الإنتاجية (PostgreSQL Schema & Models)

> **محرك قاعدة البيانات:** PostgreSQL 16.x مع ملحقات `uuid-ossp` و `pgcrypto`  
> **السيرفر المستضيف:** Contabo Cloud (Germany) - IP: `13.140.141.32`

---

## 📌 1. مخطط الكيانات والعلاقات (ER Diagram)

```mermaid
erDiagram
    USERS ||--o| USER_CREDENTIALS : has
    USERS ||--o| LAWYER_PROFILES : has_profile
    USERS ||--o| CLIENT_PROFILES : has_profile
    USERS ||--o{ EMAIL_VERIFICATIONS : validates
    USERS ||--o{ USER_SESSIONS : maintains
    USERS ||--o{ SERVICE_ORDERS : places_or_handles
    SERVICE_ORDERS ||--o{ ORDER_STATUS_LOGS : tracks_history
    LAWYER_PROFILES ||--o{ LAWYER_DOCUMENTS : owns_documents

    USERS {
        uuid id PK
        varchar phone UK
        varchar email UK
        enum role
        enum status
        timestamptz email_verified_at
        timestamptz created_at
    }

    LAWYER_PROFILES {
        uuid id PK
        uuid user_id FK
        varchar full_name
        varchar syndicate_number UK
        varchar degree
        numeric rating
        numeric latitude
        numeric longitude
        boolean is_available
        enum approval_status
    }

    SERVICE_ORDERS {
        uuid id PK
        varchar order_number UK
        uuid client_id FK
        uuid lawyer_id FK
        varchar service_title
        numeric price
        varchar status
        numeric client_latitude
        numeric client_longitude
        timestamptz created_at
    }

    ORDER_STATUS_LOGS {
        uuid id PK
        uuid order_id FK
        uuid changed_by_user_id FK
        varchar old_status
        varchar new_status
        timestamptz created_at
    }
```

---

## 🚀 2. استراتيجية الفهارس والأداء (Performance Indices)

1. **فهارس البحث الجغرافي السريع (Geo Query Indices):**
   - `idx_lawyer_profiles_availability` على الأعمدة `(approval_status, is_available, last_active_at)`.
   - `idx_lawyer_profiles_coords` على الأعمدة `(latitude, longitude)`.
   - تضمن هذه الفهارس استجابة استعلام `/lawyers/nearby` في أقل من 15ms ضمن دائرة البحث.

2. **فهارس الطلبات ومتابعة الحالات:**
   - `idx_orders_client_id`: استرجاع طلبات العميل مرتبة زمنياً.
   - `idx_orders_lawyer_id`: استرجاع مهام المحامي الجارية.
   - `idx_orders_status`: فرز الطلبات حسب الحالة (PENDING / IN_PROGRESS).
   - `idx_order_logs_order`: تتبع كامل لسجل الحالات وتاريخ التحويلات.

3. **سلامة العمليات المتزامنة (Concurrency & Idempotency):**
   - استخدام الـ Database Transactions `withTransaction` عند إنشاء أو قبول الطلبات يمنع قبول الطلب من أكثر من محامٍ في نفس الوقت (`Race Conditions`).
   - مفتاح فريد `order_number` لمنع تكرار الفواتير والطلبات.

---

## 🧾 4. الجداول الحالية حسب التحديثات (Migrations)

التحديثات في `backend/migrations` بتتطبق لوحدها مع كل تشغيل للسيرفر، بالترتيب، ومرة واحدة لكل تحديث.

| التحديث | الجداول والأعمدة |
|---|---|
| `001` | `users`، `user_credentials`، `user_sessions`، `email_verifications`، `password_resets`، `lawyer_profiles`، `lawyer_documents` |
| `002` | `service_orders`، `order_status_logs`، وموقع المحامي وإتاحته |
| `003` | `complaints`، `order_appeals`، `client_credits`، `reviews`، `problem_prices`، `client_problem_prices`، `notifications`، `lawyer_strikes`، `lawyer_reports` |
| `004` | `device_tokens` لإشعارات الموبايل |
| `005`–`007` | حداثة موقع المحامي، وسبب قفل الإتاحة |
| `008` | نسبة الضريبة في الطلب وشروط الخدمة |
| `009` | حالة التقديم على «محاميك حالاً» `urgent_status` |
| `013` | `service_orders.review_reminder_sent` لتذكير التقييم مرة واحدة |
| `012` | ترقيم ML الموحد: `order_number` و`reference` في `complaints` و`lawyer_reports` و`order_appeals` و`wallet_transfers`، كل واحد بتسلسل خاص بيه |
| `011` | `wallet_transfers`: كل تحويل بين حسابين، والفلوس نفسها بتتسجل في `client_credits` أو `lawyer_adjustments` |
| `010` | `account_warnings`، و`lawyer_adjustments`، و`users.suspended_until`، ونوع الشكوى `kind` في `complaints` و`lawyer_reports` |

**الفلوس:**
- **رصيد الموكل:** مجموع `client_credits`، وفيه الردود والتسويات وحركات الإدارة والدفع من الرصيد بالسالب.
- **أتعاب المحامي:** `payout_amount` في الطلب حسب `payout_status`: `HELD` أو `FROZEN` أو `AVAILABLE` أو `REFUNDED`.
- **حركات الإدارة على المحامي:** في `lawyer_adjustments`، وبتتجمع على المتاح.
- **الرصيد السالب:** دين بيتسدد من المبالغ اللي بتدخل بعده.

**الإنذارات:** في `account_warnings` للطرفين. الإنذار الملغى `revoked_at` ما بيتحسبش، و3 سارية في 30 يوم بتوقف الحساب أسبوع عبر `users.suspended_until`.
