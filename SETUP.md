# MatchGrade + Supabase Setup

## 1. Create a Supabase project

1. Go to https://supabase.com → New project
2. Note the **Project URL** and **anon public** key  
   (Project Settings → API)

## 2. Run the schema

1. Open **SQL Editor** in the Supabase dashboard
2. Paste the contents of `schema.sql` and run it
3. Confirm tables `profiles` and `matches` exist under Table Editor

## 3. Enable Auth

1. Authentication → Providers → **Email** → enable
2. Optional: enable “Confirm email” or turn it off for faster testing
3. Authentication → URL Configuration  
   - Site URL: `https://matchgrade.netlify.app` (or your domain)  
   - Redirect URLs: add the same origin

## 4. Wire the frontend

In `index.html`, find:

```js
const SUPABASE_CONFIG = {
  url: '',      // e.g. https://xxxx.supabase.co
  anonKey: ''   // anon public key
};
```

Paste your Project URL and anon key.  
**Never put the service_role key in the frontend.**

## 5. Deploy

Deploy `index.html` to Netlify (or any static host) as before.

## Behaviour

| State | Calculator | Compare | My Matches |
|-------|------------|---------|------------|
| Logged out | Works | Works | localStorage only |
| Logged in | Works | Works | Supabase cloud (synced) |

Saving while logged in writes to Supabase.  
Logging in does not block the calculator.

## Security notes

- RLS ensures users only see/edit their own rows
- Anon key is safe for the browser; RLS is the real protection
- Stats and ratings are validated with CHECK constraints and client-side bounds
- No service_role or database password is ever se
- nt to the client
