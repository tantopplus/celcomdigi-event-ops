# How to Put CelcomDigi Event Ops Online
### A step-by-step guide for complete beginners

You do **not** need to know coding. You will only click buttons, copy, and paste.
Total time: about **45–60 minutes** the first time.

---

## What we are going to do (the big picture)

Think of the app like a shop:

| Service | What it is in "shop" terms | What it does for us | Cost |
|---|---|---|---|
| **GitHub** | The **storeroom** | Safely keeps a copy of the app files | Free |
| **Supabase** | The **cash register + record book** | Stores staff accounts and every customer submission, online | Free |
| **Netlify** | The **shop front** | Gives the app a web link that anyone can open on their phone | Free |

How they connect:

```
 Your computer ──upload files──▶ GitHub ──auto-copies──▶ Netlify (the link staff open)
                                                              │
                                                              ▼
                                                   Supabase (saves all the data)
```

The nice part: once it is set up, **every time you upload a changed file to GitHub, Netlify updates the app by itself** in about 1 minute.

> 💡 **Tip:** Do the parts **in order**. Keep this guide open on one side of the screen and the website on the other side.

---

## Before you start – things you need

- [ ] A computer with internet (Chrome or Edge browser)
- [ ] An email address you can open (to receive verification codes)
- [ ] The app folder **CelcomDigi Event Ops** (the folder this guide is in)
- [ ] A notebook or a notes app to write down passwords

Inside the app folder you should see these files:

```
index.html            ← the app itself
config.js             ← where you paste your Supabase details (Part 3)
supabase-setup.sql    ← the database setup script (Part 2)
sw.js
manifest.webmanifest
icon-192.png
icon-512.png
apple-touch-icon.png
logo-wide.png
logo.jpg
README.md
DEPLOY-GUIDE.md       ← this guide
```

---

## PART 1 — Create a GitHub account (10 min)

We create GitHub **first**, because Supabase and Netlify let you sign in *with* GitHub. That means fewer passwords to remember.

1. Open **https://github.com**
2. Click **Sign up** (top-right corner).
3. Type your **email** → click **Continue**.
4. Create a **password** → click **Continue**.
   ✏️ *Write it down in your notebook.*
5. Choose a **username** (for example `tan-eventops`) → click **Continue**.
6. Solve the small puzzle that checks you are human → click **Create account**.
7. Open your email. GitHub sends you a **code**. Type the code into GitHub.
8. GitHub may ask you some questions ("How many team members…"). You can click **Skip personalization** at the bottom.

✅ **Done when:** you see your GitHub home page (dashboard).

---

## PART 2 — Create the database on Supabase (15 min)

### 2A. Make an account and a project

1. Open **https://supabase.com**
2. Click **Start your project** (or **Sign in**).
3. Click **Continue with GitHub** → click the green **Authorize supabase** button.
4. If asked to create an **organization**: type `CelcomDigi Event Ops`, choose **Personal**, plan **Free**, then click **Create organization**.
5. Now create a **new project**. Fill in:
   | Box | What to type / choose |
   |---|---|
   | Project name | `celcomdigi-event-ops` |
   | Database Password | Click **Generate a password**, then **copy it** ✏️ *Write it down and keep it secret. The app does not need it, but you might need it one day.* |
   | Region | **Southeast Asia (Singapore)**. It's closest to Malaysia, so it's the fastest. |
6. Click **Create new project**.
7. Wait 1–2 minutes while it says "Setting up project…". Make a coffee ☕.

### 2B. Run the setup script (this creates the tables and the admin account)

1. On the left side of Supabase there is a menu with small icons. Find **SQL Editor** (the icon looks like `>_`). Click it.
2. Click **+ New query** (or the **+** button).
   You now see an empty white area. This is where we paste the script.
3. On your computer, open the app folder. **Right-click** `supabase-setup.sql` → **Open with** → **Notepad**.
4. In Notepad press **Ctrl + A** (selects everything), then **Ctrl + C** (copies).
5. Go back to Supabase. Click inside the empty white area, then press **Ctrl + V** (paste).
6. Click the green **Run** button (bottom-right), or press **Ctrl + Enter**.
7. If a pop-up warns about a "destructive operation" or "potential issue", click **Run this query**. This is normal: the script creates tables.
8. At the bottom you should see: **Success. No rows returned** ✅

> ❌ **If you see red error text:** take a screenshot and send it to Claude. Don't worry. Nothing is broken, and the script is safe to run again after fixing.

### 2C. Copy your two "keys" (the address of your database)

1. In the left menu, click the **gear icon ⚙️ Project Settings** (at the bottom).
2. Click **Data API** (or **API**). Find **Project URL**. It looks like:
   `https://abcdefghijklmnop.supabase.co`
   Click the **copy** button next to it and paste it into your notes.
3. Click **API Keys**. Copy the key called **Publishable key** (starts with `sb_publishable_…`).
   *(Older projects show it as **anon public** instead, a long text starting with `eyJ…`. That one also works.)*

> ⚠️ **NEVER copy the "secret" key or the "service_role" key.** Those are like the master key to the whole database. Only the **publishable / anon** key goes into the app. It's designed to be public, and the database protects itself.

✅ **Done when:** you have the **Project URL** and the **Publishable key** saved in your notes.

---

## PART 3 — Connect the app to your database (3 min)

1. In the app folder, **right-click** `config.js` → **Open with** → **Notepad**.
2. You will see:
   ```js
   window.APP_CONFIG = {
     SUPABASE_URL: '',
     SUPABASE_KEY: ''
   };
   ```
3. Paste your details **between the two quote marks `''`**, so it looks like this (with your own values):
   ```js
   window.APP_CONFIG = {
     SUPABASE_URL: 'https://abcdefghijklmnop.supabase.co',
     SUPABASE_KEY: 'sb_publishable_xxxxxxxxxxxxxxxxxxxx'
   };
   ```
   ⚠️ Keep the quote marks `'` and the comma `,` at the end of the first line exactly as shown.
4. Press **Ctrl + S** to save. Close Notepad.

✅ **Done when:** `config.js` has your URL and key inside the quotes.

---

## PART 4 — Upload the app to GitHub (10 min)

### 4A. Create a "repository" (just a fancy word for a project folder on GitHub)

1. Go to **https://github.com** (log in if needed).
2. Click the **+** at the top-right → **New repository**.
3. Fill in:
   | Box | What to type / choose |
   |---|---|
   | Repository name | `celcomdigi-event-ops` |
   | Description | `Event redemption app` (optional) |
   | Public / Private | Choose **Private** 🔒 (only you can see the files) |
   | Add a README file | Leave **unticked** |
4. Click **Create repository**.

### 4B. Upload the files

1. On the new page, find the blue link **"uploading an existing file"** and click it.
2. Open the app folder on your computer. Press **Ctrl + A** to select all files.
3. **Drag** all the files into the GitHub page (onto the area that says "Drag files here").
   *(If you see a `.claude` folder, you don't need to upload it. It's fine if you do.)*
4. Wait until all files show in the list.
5. Scroll down. In the "Commit changes" box type: `First version`
6. Click the green **Commit changes** button.

✅ **Done when:** you see the list of files (index.html, config.js …) on your GitHub repository page.

---

## PART 5 — Put the app online with Netlify (10 min)

1. Open **https://www.netlify.com** → click **Sign up**.
2. Choose **Sign up with GitHub** → click **Authorize Netlify**.
3. Netlify may ask a few questions (your name, "what are you planning to use Netlify for"). Answer anything you like and choose the **Free** plan.
4. On the Netlify dashboard click **Add new project** (or **Add new site**) → **Import an existing project**.
5. Click **GitHub**. A window opens asking to **install Netlify on GitHub**:
   - Choose **Only select repositories** → pick `celcomdigi-event-ops` → click **Install** (or **Save**).
6. Back on Netlify, click on **celcomdigi-event-ops** in the list.
7. You'll see build settings. **Leave everything empty / as default.** This app needs no "build":
   - Branch to deploy: `main`
   - Build command: *(empty)*
   - Publish directory: *(empty)*
8. Click **Deploy** (the button may say **Deploy celcomdigi-event-ops**).
9. Wait about 30 seconds until it says **Published** ✅

### Give it a nice name

1. Netlify gives you a random link like `https://jolly-otter-12345.netlify.app`.
2. Go to **Project configuration** (or **Site configuration**) → **Change project name** (or **Change site name**).
3. Type `celcomdigi-event-ops` → **Save**.
4. Your link is now: **https://celcomdigi-event-ops.netlify.app** 🎉
   *(If the name is taken, try `cdg-event-ops` or add a number.)*

### Test it

1. Open your link on the computer.
2. You should **not** see the yellow "DEMO MODE" bar. If you still see it, `config.js` was not filled in correctly (go back to Part 3, then see "How to update" in Part 8).
3. Click **Admin Login** → ID `tan`, password `Tan@0302`.

✅ **Done when:** you can log in to the back office from your link.

---

## PART 6 — First-time setup in the back office (10 min)

Do these **once**, right after going live:

1. **Change the admin password** 🔑. This matters because the starting password is written in this guide.
   Click the **key icon** (top-right) → type the current password `Tan@0302` → type a new password (at least 8 characters) → **Save**.
   ✏️ *Write the new password in your notebook.*
2. Go to **Settings**:
   - **Event / Venue List** → delete the sample (click **×**) → add your real events.
   - **Freebies List** → delete the sample → add your real gifts.
   - **Plan Subscribed List** → check the 9 plans are correct.
   - **Mandatory Fields** → switch on/off as you like.
3. Go to **Staff** → **+ Add Staff** → create each sales executive (Login ID, password, name, email, contact).
4. Go to **Admins** → **+ Add Admin** if other people need back office access (max 5).

---

## PART 7 — Install the app on staff phones (2 min per phone)

Send your link to the staff (e.g. by WhatsApp): `https://celcomdigi-event-ops.netlify.app`

### 📱 Android (Chrome)
1. Open the link in **Chrome**.
2. Tap the **⋮** menu (top-right).
3. Tap **Add to Home screen** or **Install app** → **Install**.
4. The CelcomDigi icon appears on the home screen. Open the app from there.

### 🍎 iPhone (Safari, it **must** be Safari)
1. Open the link in **Safari**.
2. Tap the **Share** button (square with an arrow ⬆️ at the bottom).
3. Scroll down → tap **Add to Home Screen** → tap **Add**.
4. Open the app from the new icon.

---

## PART 8 — How to make changes in the future

There are **two kinds** of changes.

### Kind 1: Everyday changes → NO coding, NO uploading
Done directly inside the back office, and they take effect on all phones immediately:
- Add / delete staff, reset passwords
- Add / remove events, plans, freebies
- Change which fields are mandatory
- Edit / delete submissions, export Excel

### Kind 2: Changing the app itself (new field, new button, new design, new text)

**Step 1 – Ask Claude to make the change**
1. Open the **Claude** desktop app → **Code** tab.
2. Choose the **CelcomDigi Event Ops** folder as the project folder.
3. Describe what you want in normal words. For example:
   *"Add a new field 'Customer Email' below Customer Full Name, not mandatory, and include it in the WhatsApp text and the Excel export."*
4. Claude changes the files, tests them, and tells you:
   - **which files changed** (often just `index.html`), and
   - whether the **database also needs a change**. If it does, Claude gives you a small SQL script.

**Step 2 – If Claude gave you a SQL script, run it first**
Supabase → **SQL Editor** → **+ New query** → paste → **Run** (same as Part 2B).

**Step 3 – Upload the changed files to GitHub**
1. Open your repository on **https://github.com** (`celcomdigi-event-ops`).
2. Click **Add file** → **Upload files**.
3. Drag in **only the changed files**. A file with the same name **replaces** the old one.
4. Type a short note, e.g. `Added customer email field` → **Commit changes**.

**Step 4 – Wait about 1 minute**
Netlify notices the new files and updates the app **automatically**.
You can watch it on Netlify → your project → **Deploys**. Wait until the top line says **Published**.

**Step 5 – Staff get the new version**
Staff simply **close the app completely and open it again**. If they still see the old version, close and open once more.

### 😱 Oops, the new version has a problem! How do I undo?
1. Netlify → your project → **Deploys**.
2. Click on an **older deploy** (one that was working).
3. Click **Publish deploy**. The old version is back online within seconds.
4. Then tell Claude what went wrong so it can fix it.

---

## PART 9 — Important things to know

**🟡 Supabase free plan "sleeps" after 7 days without use.**
If nobody uses the app for a week (e.g. no events), Supabase pauses the database, and the app will show "Server error" when someone logs in.
➡️ Fix: log in to **supabase.com** → open your project → click **Restore project**. It takes a few minutes, and no data is lost.
➡️ If you run events every week, it will never sleep. For heavy daily use you can upgrade to **Supabase Pro (US$25/month)**: it never sleeps and makes daily backups.

**💾 Backups.** The free plan has no automatic backups. **Export to Excel regularly** (e.g. after every event) and keep the files.

**🔐 Security**
- The key in `config.js` is a *public* key. It's normal for it to be visible.
- **Never** share the Supabase **Database Password**, **secret key**, or **service_role key** with anyone.
- Passwords of staff and admins are stored **encrypted**. Even you cannot read them, you can only reset them.
- When a staff member leaves, **delete** their account in Staff. They are logged out immediately, and their past submissions are kept.

**📶 Internet.** The app only works with internet. Without signal it shows "No internet connection".

**📱 One phone per account.** If a staff member logs in on a second phone, the first phone is logged out automatically.

**📈 Capacity.** The free plan easily handles 50 staff and 1,000 submissions a day.

---

## Quick reference card

| I want to… | Where |
|---|---|
| Open the app | `https://celcomdigi-event-ops.netlify.app` *(your link)* |
| Add staff / events / freebies | App → Admin Login → Staff / Settings |
| See or export data | App → Admin Login → Submissions → Export Excel |
| Restore a sleeping database | supabase.com → your project → Restore |
| Change how the app works | Claude Code → then upload changed files to GitHub |
| Undo a bad update | Netlify → Deploys → older deploy → Publish deploy |

**Stuck at any step?** Take a screenshot and send it to Claude with the Part number (e.g. "I'm stuck at Part 5, step 7").
