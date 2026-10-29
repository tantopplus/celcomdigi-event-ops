# CelcomDigi Event Ops – Prototype

Clickable prototype of the sales redemption PWA (sales app + back office).

> **Demo mode:** all data is saved in the browser of the device you test on.
> The live version will use Supabase so data syncs across all phones.

## Demo logins

| Role | Login ID | Password |
|---|---|---|
| Admin (main) | `tan` | `Tan@0302` |
| Sales | `S001` | `demo1234` |

Change the admin password from the key icon in the back office.
"Reset demo data" (Settings tab, main admin only) restores this starting setup.

## Run locally

```bash
python -m http.server 5173
```

Then open http://localhost:5173 in the browser.

## Files

| File | Purpose |
|---|---|
| `index.html` | Whole app: sales screens, back office, data layer (`DemoStore` / `RemoteStore`) |
| `manifest.webmanifest`, `sw.js` | Makes it installable ("Add to Home Screen") |
| `icon-*.png`, `apple-touch-icon.png`, `logo-wide.png` | App icon and logo |
| `config.js` | Supabase URL + publishable key. Empty = demo mode |
| `supabase-setup.sql` | Database tables, security and all server functions |

## Going live

Follow **[DEPLOY-GUIDE.md](DEPLOY-GUIDE.md)** (Supabase → GitHub → Netlify, step by step).
