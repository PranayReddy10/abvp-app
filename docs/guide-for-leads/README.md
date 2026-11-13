# Guide for leads (PDF)

`../ABVP-Connect-Guide-for-Leads.pdf` is a 16-page, non-technical booklet for leads: what the app does, how delegates use the conference guide, and what each lead needs to send. Screenshots use sample data.

To rebuild after changing `booklet.html` or the screenshots in `img/`:

```bash
node render.js "$PWD/booklet.html" "$PWD/../ABVP-Connect-Guide-for-Leads.pdf"
```

(Needs Playwright with Chromium. Fonts are loaded from `mobile/assets/fonts`.)
