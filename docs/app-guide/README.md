# ABVP Connect – App guide (PDF)

`../ABVP-Connect-App-Guide.pdf` is a 17-page walkthrough of the current app design and flow:
sign-up, Home, the delegate form, the conference guide and gallery, help and emergency,
Volunteer (ghats, departments and people), profiles, team chat, community, Me, languages,
and the admin panel (members and the blue tick, conference team, community approval,
guide editor, phone layout), ending with a checklist for the admin team.

It replaces `../ABVP-Connect-Guide-for-Leads.pdf`, which shows the older design with passes and scanning.

## Rebuild

```
cd docs/app-guide
node render.js "$PWD/booklet.html" ../ABVP-Connect-App-Guide.pdf
```

- `booklet.html` – the pages (A4, one `<section class="page">` each)
- `img/` – screenshots at phone size (390×844) and admin desktop size (1280×800), taken with sample data
- `fonts/` – Mukta, Anek Devanagari and Anek Telugu (SIL Open Font License, see `OFL*.txt`)
- `render.js` – prints the HTML to PDF with Playwright/Chromium
