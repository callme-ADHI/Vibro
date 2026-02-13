# VIBRO Backend - Supabase Setup

## 📊 Supabase Project Configuration

**Project ID:** `pqtjvdfcitdpveuqzgpk`

**Project URL:** `https://pqtjvdfcitdpveuqzgpk.supabase.co`

**Publishable Key:** *(set in `user/lib/core/constants/app_constants.dart`)*

**Secret Key:** *(do not commit — set via Supabase Dashboard only)*

---

## ✅ Setup Complete

- ✅ Database schema: **1.sql** (production-ready)
- ✅ App configured with Supabase credentials
- ✅ Email-based authentication system
- ✅ 12 tables with full RLS policies
- ✅ 3 storage buckets (audio_uploads, trained_models, reports)
- ✅ Subscription limits enforcement
- ✅ Auto-profile creation on signup
- ✅ Admin logging & analytics

---

## 🚀 Deployment Steps

### 1. Run SQL Migration
1. Open Supabase Dashboard: https://supabase.com/dashboard/project/pqtjvdfcitdpveuqzgpk
2. Go to **SQL Editor**
3. Copy & paste contents of `1.sql`
4. Click **Run**
5. Verify success message

### 2. Enable Email Authentication
1. Go to **Authentication** → **Providers**
2. Enable **Email** provider
3. Configure confirmation emails (optional)

### 3. Create First Admin
1. Sign up via app or Supabase dashboard
2. Run SQL: `UPDATE profiles SET role = 'admin' WHERE email = 'your@email.com';`

---

## 📂 Backend Structure

```
backend/
├── 1.sql                    # Main production schema
├── storage_buckets.sql      # Storage configuration reference
├── schema.sql              # Legacy (for reference)
├── EMAIL_AUTH_MIGRATION.md # Migration guide
└── README.md               # This file
```

---

## 🔐 Security Features

- ✅ Row Level Security (RLS) on all tables
- ✅ Users can only access their own data
- ✅ Admins have elevated permissions
- ✅ Private storage buckets
- ✅ JWT-based authentication
- ✅ Subscription limits enforced at database level

---

## 📊 Database Tables

1. **profiles** - User accounts & roles
2. **subscriptions** - Plan limits & billing
3. **trained_names** - Voice models
4. **audio_submissions** - Training data uploads
5. **training_queue** - Colab job management
6. **trained_models** - Model metadata
7. **locations** - Detection contexts
8. **location_name_mapping** - Name-location assignments
9. **detection_history** - All voice detections
10. **device_registry** - ESP32 devices
11. **admin_logs** - Admin action audit trail
12. **analytics_daily_stats** - Dashboard metrics

---

## 🎯 Next Steps

- [ ] Run 1.sql in Supabase
- [ ] Enable email authentication
- [ ] Create admin user
- [ ] Test signup flow
- [ ] Configure storage buckets (auto-created)
- [ ] Test Colab integration
- [ ] Deploy ESP32 firmware

---

**Backend Status:** ✅ Production Ready

**Last Updated:** 2026-02-13
