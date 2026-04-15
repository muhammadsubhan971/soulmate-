# Database Setup

## Essential Files

### 1. `schema.sql`
Complete database schema with all tables, triggers, and initial setup.

**Run this first** when setting up a new Supabase project.

### 2. `NUCLEAR_FIX_PERMISSION_DENIED.sql`
Fix for "permission denied for table users" error during profile picture upload.

**Run this if you get permission errors** when creating profiles.

---

## Quick Setup

1. Run `schema.sql` in Supabase SQL Editor
2. If you get permission errors, run `NUCLEAR_FIX_PERMISSION_DENIED.sql`
3. Done! ✅
