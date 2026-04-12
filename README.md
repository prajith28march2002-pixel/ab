# abkya.in — Career Guidance Platform

India's smartest career guidance platform powered by NIRF 2025 data.

---

## Stack

| Layer | Tech |
|---|---|
| Frontend | Single-page HTML app (no build step needed) |
| Auth | Supabase Auth (Email/Password + Google OAuth) |
| Database | Supabase (Postgres) |
| Payments | Razorpay (server-side order creation + HMAC verification) |
| Backend | Express.js (Node.js) |
| Hosting | **Any** — Render, Railway, Fly.io, VPS, Heroku, Vercel, DigitalOcean |

---

## Project Structure

```
abkya/
├── public/
│   └── index.html          ← Full SPA (all pages + embedded NIRF data)
├── api/
│   ├── create-order.js     ← Razorpay order creation (used by Vercel only)
│   └── verify-payment.js   ← Payment verification (used by Vercel only)
├── server.js               ← Express server with all API routes
├── supabase-schema.sql     ← Run once in Supabase SQL editor
├── package.json
├── vercel.json             ← Vercel deployment config (optional)
├── .env.example            ← Copy to .env and fill in
└── README.md
```

---

## Step 1 — Supabase Setup

1. Go to [supabase.com](https://supabase.com) → New project (free tier works)
2. Go to **Settings → API** and copy:
   - **Project URL** (looks like `https://abcdef.supabase.co`)
   - **anon public key** (starts with `eyJ...`)
   - **service_role key** (starts with `eyJ...`) — keep this secret!
3. Go to **SQL Editor** → paste the contents of `supabase-schema.sql` → Run
4. Go to **Authentication → Providers → Google** → enable it:
   - Create a Google OAuth app at [console.cloud.google.com](https://console.cloud.google.com)
   - Set **Authorized redirect URI** to: `https://YOUR_PROJECT.supabase.co/auth/v1/callback`
   - Paste Client ID and Secret into Supabase
5. Go to **Authentication → URL Configuration**:
   - Site URL: `https://abkya.in` (or your deployed URL)
   - Add redirect URL: `https://abkya.in/**`

---

## Step 2 — Configure index.html

Open `public/index.html` and find these two lines near the bottom in the `<script>` section:

```js
const SB_URL  = 'YOUR_SUPABASE_URL';
const SB_ANON = 'YOUR_SUPABASE_ANON_KEY';
```

Replace them with your actual values. These are **public** keys — safe to put in HTML.

---

## Step 3 — Environment Variables

Copy `.env.example` to `.env` and fill in:

```bash
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=eyJ...                     # not used by server, just for reference
SUPABASE_SERVICE_ROLE_KEY=eyJ...             # used by server to write reports
RAZORPAY_KEY_ID=rzp_live_XXXXXXXX            # or rzp_test_ for testing
RAZORPAY_KEY_SECRET=XXXXXXXXXXXXXXXX
PORT=3000
```

---

## Deployment Options

### Option A — Render (Recommended, free tier)

1. Push this folder to GitHub
2. Go to [render.com](https://render.com) → New Web Service → connect your repo
3. Settings:
   - **Build command**: `npm install`
   - **Start command**: `node server.js`
   - **Environment**: Node
4. Add all env vars from your `.env` in the Render dashboard
5. Add your custom domain `abkya.in` in Render → Settings → Custom Domains
6. Update Supabase Site URL and redirect URLs to `https://abkya.in`

### Option B — Railway

1. Push to GitHub → go to [railway.app](https://railway.app) → New Project → Deploy from GitHub
2. Add env vars in Railway dashboard
3. Railway auto-detects Node.js, runs `npm start`
4. Attach custom domain in Railway → Settings → Domains

### Option C — Fly.io

```bash
npm install -g flyctl
fly launch
fly secrets set SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=...
fly deploy
```

### Option D — Vercel

Vercel routes everything through `server.js` via `vercel.json`:

1. Push to GitHub → [vercel.com](https://vercel.com) → Import Project
2. Add env vars in Vercel project settings
3. Add custom domain in Vercel → Settings → Domains

### Option E — VPS (DigitalOcean, Linode, AWS EC2)

```bash
# On your server:
git clone your-repo
cd abkya
cp .env.example .env
# Edit .env with your values
npm install
npm install -g pm2
pm2 start server.js --name abkya
pm2 startup && pm2 save

# Nginx reverse proxy config:
# location / { proxy_pass http://localhost:3000; }
```

### Option F — Heroku

```bash
heroku create abkya
heroku config:set SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... RAZORPAY_KEY_ID=... RAZORPAY_KEY_SECRET=...
git push heroku main
heroku domains:add abkya.in
```

---

## Domain Setup (abkya.in)

After deploying, point your domain:

| Host | Type | Value |
|---|---|---|
| `@` | A | Your host's IP (Render: `216.24.57.1`, Railway: check dashboard) |
| `www` | CNAME | Your host's domain (e.g. `abkya.onrender.com`) |

SSL is automatic on all platforms above.

---

## Razorpay Setup

1. Create account at [razorpay.com](https://razorpay.com)
2. For testing: use `rzp_test_` keys (no real money)
3. For production: complete KYC → get `rzp_live_` keys
4. The payment flow is fully server-side verified — users cannot bypass payment

---

## How It Works

### Authentication
- Supabase Auth handles sessions (JWT tokens, refresh tokens)
- Google OAuth redirects back to your site URL
- A Postgres trigger auto-creates a profile row on signup

### Matching Algorithm
The college matching uses a weighted scoring system:
- **NIRF rank** (primary weight — lower rank = higher score)
- **Location preference** (home state match = +80 points)
- **Salary target** (colleges meeting target = +60 points)
- **Priority boosts** (prestige, research, placement, etc.)
- **Placement rate** (>70% = +50 points)
- **Stream alignment** (e.g. Engineering background → Engineering colleges)
- **Work experience** (2+ years → MBA boost)

### Payment Security
```
User clicks "Unlock ₹19" →
  POST /api/create-order (server creates Razorpay order) →
  Razorpay checkout modal →
  User pays →
  POST /api/verify-payment (server verifies HMAC signature) →
  If valid: Supabase upserts report with service_role key →
  Frontend reloads with unlocked content
```

The `RAZORPAY_KEY_SECRET` **never leaves the server**. Payment verification is cryptographic — no user can unlock content without paying.

### Data
- NIRF 2025 data for 937 institutions is embedded in `index.html` as gzip-compressed base64 (~138KB)
- Includes: rankings, placement stats, salary data, PhD counts, research funding, faculty counts
- No API calls needed for college data — works offline after first load

---

## Local Development

```bash
npm install
cp .env.example .env
# Fill in .env
node server.js
# Visit http://localhost:3000
```

For Google OAuth locally, add `http://localhost:3000` as an authorized redirect in:
- Your Google OAuth app
- Supabase → Authentication → URL Configuration (add `http://localhost:3000/**`)

---

## Database Schema Summary

**`profiles`** — One row per user
- `id`, `email`, `name`, `avatar_url` (auto-created on signup)
- Career data: `education`, `stream`, `work_ex`, `goals`, `home_state`, `salary_target`, etc.
- `profile_complete: boolean` — gates dashboard access

**`reports`** — One row per user (upserted on payment)
- `plan: 'basic' | 'pro'`
- `payment_id`, `order_id` — Razorpay references
- `report_data: jsonb` — the full matched colleges + score + gaps at time of purchase
- Reports are **permanent** — editing profile shows a new free match but preserves the paid report
