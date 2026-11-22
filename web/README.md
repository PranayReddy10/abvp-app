# ABVP Connect – public website (abvpconnect.org)

React 19 + TypeScript, built with Vite into plain HTML/JS/CSS files for Hostinger.

Pages: landing, conference guide (public), sign-up, sign-in (mobile OTP or Google), delegate registration with pass, My space, help-desk chat and tickets, community feed (members).

```bash
npm ci
npm run dev        # http://localhost:5175 (API at http://localhost:8000)
npm run build      # output in dist/ – upload everything inside it, including .htaccess
```

Before building for production, create `.env.production` from `.env.example`.
