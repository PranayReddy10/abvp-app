# ABVP Connect admin panel

React + Vite. Builds to static files that Hostinger serves directly; no Node server in production.

```bash
cp .env.example .env      # set VITE_API_URL
npm install
npm run dev               # http://localhost:5173
npm run build             # output in dist/, upload with its .htaccess
```

Screens: sign in (OTP), dashboard, membership approvals, members, Vibhags, admins and roles, audit log. Menu items appear only for the permissions the signed-in admin holds, and every list is limited to their area by the API.
