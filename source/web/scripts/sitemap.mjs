// Writes dist/sitemap.xml after each build: the public pages plus every published, upcoming event.
// Events come from the live API; if it cannot be reached the sitemap still lists the main pages.
import { execFileSync } from 'node:child_process'
import { writeFileSync } from 'node:fs'

const SITE = 'https://abvpconnect.org'
const API = process.env.VITE_API_URL || 'https://api.abvpconnect.org/api/v1'
const today = new Date().toISOString().slice(0, 10)
const urls = [
  { loc: '/', freq: 'daily', pri: '1.0' },
  { loc: '/events', freq: 'daily', pri: '0.8' },
  { loc: '/community', freq: 'hourly', pri: '0.6' },
]

async function events() {
  try {
    const ctrl = new AbortController()
    const t = setTimeout(() => ctrl.abort(), 8000)
    const r = await fetch(`${API}/public/events`, { headers: { Accept: 'application/json' }, signal: ctrl.signal })
    clearTimeout(t)
    return await r.json()
  } catch {
    // Behind a proxy Node's fetch may fail where curl works.
    return JSON.parse(execFileSync('curl', ['-s', '-m', '10', '-H', 'Accept: application/json', `${API}/public/events`], { encoding: 'utf8' }))
  }
}

try {
  const body = await events()
  for (const e of body.data ?? []) urls.push({ loc: `/events/${e.id}`, freq: 'daily', pri: '0.9' })
  const conf = (body.data ?? []).find((e) => e.guide_enabled)
  if (conf) urls.push({ loc: `/support/${conf.id}`, freq: 'weekly', pri: '0.5' })
  console.log(`sitemap: ${urls.length} pages (events from ${API})`)
} catch (e) {
  console.log(`sitemap: API not reachable (${e.message}); main pages only`)
}

const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((u) => `  <url><loc>${SITE}${u.loc}</loc><lastmod>${today}</lastmod><changefreq>${u.freq}</changefreq><priority>${u.pri}</priority></url>`).join('\n')}
</urlset>
`
writeFileSync(new URL('../dist/sitemap.xml', import.meta.url), xml)
