# Digital Heroes — React + Supabase + Vercel

A production-oriented starter implementation based on the supplied Digital Heroes PRD. It includes a responsive, emotion-led public site, Supabase authentication, member dashboard, rolling five-score logic, charity directory/selection, admin surfaces, and database structures for draws, winners and subscriptions.

## 1. Local setup
1. Install Node.js 20+.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
4. Create a new Supabase project and run `supabase/schema.sql` in SQL Editor.
5. Run `npm run dev`.

## 2. Supabase setup
- Create a NEW project for this assignment.
- SQL Editor → paste/run `supabase/schema.sql`.
- Authentication → Providers → Email: enable Email/password. Configure Site URL and redirect URLs for your Vercel domain.
- Storage: create a bucket named `winner-proofs` if you implement winner proof uploads; keep policies restricted to authenticated members/admins.
- After creating your own account, promote it to admin with SQL: `update public.profiles set role='admin' where id='YOUR_AUTH_USER_UUID';`
- Never put a Supabase service-role key in React/Vite environment variables.

## 3. Vercel
1. Push this folder to a NEW GitHub repository.
2. Create a NEW Vercel project and import the repository.
3. Framework preset: Vite. Build command: `npm run build`. Output directory: `dist`.
4. Add environment variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` for Production, Preview and Development as needed.
5. Deploy.
6. In Supabase Authentication → URL Configuration, set Site URL to the Vercel production URL and add the Vercel preview URL(s) as redirect URLs if required.

## 4. Stripe
The PRD specifies monthly/yearly subscriptions and a PCI-compliant gateway. `api/create-checkout.js` is a Vercel serverless starter. To enable it:
- `npm install stripe`
- Create Stripe Products and recurring Prices for monthly/yearly plans.
- Set `STRIPE_SECRET_KEY` in Vercel only (never expose it as `VITE_*`).
- Add a checkout UI that POSTs `{priceId,email}` to `/api/create-checkout`.
- For production, add a Stripe webhook endpoint to update `subscriptions` and `profiles.subscription_status`, and verify webhook signatures.

## 5. Draw engine
The SQL includes the required 40/35/25 prize allocation and a latest-five score trigger. The PRD leaves the exact number-generation/algorithmic weighting ambiguous, so the frontend labels random vs algorithmic configuration without inventing a specific algorithm. Implement the final draw algorithm as a server-side/Edge Function with auditable inputs and an admin simulation/publish transaction.

## 6. Important production hardening
- Use server-side Stripe webhooks for subscription truth.
- Keep all draw generation server-side; do not trust browser calculations.
- Add audit logs for admin actions and draw publication.
- Add Storage RLS for winner proof files.
- Add automated tests for score rolling, duplicate-date handling, prize splits, equal winner splits and jackpot rollover.
