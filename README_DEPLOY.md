# Dyqani Online — Supabase + Vercel

Aplikacion Flutter Web SQ/EN me produkte, kërkim, detaje, favorite, shportë dhe panel administratori.

## 1. Krijo projektin Supabase

1. Krijo një projekt në Supabase.
2. Në **SQL Editor**, ekzekuto `supabase/migrations/001_store.sql`.
3. Në **Authentication → Users**, krijo përdoruesin real admin me email dhe një password të gjatë (jo `1806`).
4. Kopjo UUID e përdoruesit dhe ekzekuto:

```sql
insert into public.profiles (id, username, role)
values ('UUID_E_ADMINIT', 'urimi1806', 'admin');
```

## 2. Konfiguro hyrjen me username/password të kërkuar

UI pranon:

- Username: `urimi1806`
- Password: `1806`

Password-i i shkurtër nuk ruhet në aplikacion. Edge Function e verifikon në server dhe hap sesionin e përdoruesit real admin.

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set ADMIN_USERNAME=urimi1806
supabase secrets set ADMIN_LOGIN_PASSWORD=1806
supabase secrets set ADMIN_AUTH_EMAIL=admin@your-domain.com
supabase secrets set ADMIN_AUTH_PASSWORD='PASSWORD_I_GJATE_I_ADMINIT_REAL'
supabase functions deploy admin-login --no-verify-jwt
```

> `1806` është password i dobët. Për prodhim rekomandohet ta ndryshosh, të shtosh rate limiting/CAPTCHA dhe MFA.

## 3. Test lokal

Kërkohet Flutter stable:

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Pa variablat Supabase, aplikacioni hapet në demo mode me produktet lokale; paneli admin kërkon Supabase.

## 4. Deploy në Vercel

1. Ngarko këtë projekt në GitHub.
2. Importo repository në Vercel.
3. Shto Environment Variables:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
4. Vercel lexon automatikisht `vercel.json` dhe ekzekuton `scripts/vercel-build.sh`.
5. Në Supabase shto domain-in e Vercel te **Authentication → URL Configuration → Redirect URLs**.

## Siguria

- `SUPABASE_ANON_KEY` mund të jetë publike; siguria mbështetet në RLS.
- Mos vendos kurrë `service_role` në Flutter ose Vercel client build.
- Kredencialet e Edge Function ruhen vetëm si Supabase secrets.
- RLS lejon shkrim vetëm për profilin me rolin `admin`.

## Porositë

Butoni **Vazhdo / Next** hap formularin e klientit dhe thërret funksionin SQL `create_order`. Çmimet dhe totali verifikohen në databazë, jo në klient. Tabelat `orders` dhe `order_items` mbrohen me RLS dhe lexohen vetëm nga administratori.
