import { api } from './api'

/**
 * Google Analytics 4. The Measurement ID is set in the admin panel (Settings → Website), so it can be
 * turned on or changed without rebuilding the site. Nothing loads until an ID is set.
 * No names, mobiles or emails are ever sent – only page views and what kind of action happened.
 */
type Gtag = (...args: unknown[]) => void
declare global { interface Window { dataLayer?: unknown[]; gtag?: Gtag } }

let id: string | null = null
const queue: [string, Record<string, unknown>][] = []

export async function initSite() {
  try {
    const r = await api.get<{ ga_id: string | null; google_verification: string | null; bing_verification: string | null }>('/site')
    const s = r.data
    if (s.google_verification) addMeta('google-site-verification', s.google_verification)
    if (s.bing_verification) addMeta('msvalidate.01', s.bing_verification)
    if (s.ga_id && /^G-[A-Z0-9]+$/.test(s.ga_id)) start(s.ga_id)
  } catch { /* the site works without analytics */ }
}

function addMeta(name: string, content: string) {
  if (document.head.querySelector(`meta[name="${name}"]`)) return
  const m = document.createElement('meta'); m.name = name; m.content = content; document.head.appendChild(m)
}

function start(gaId: string) {
  id = gaId
  window.dataLayer = window.dataLayer || []
  // Google's tag needs the real `arguments` object, not an array.
  // eslint-disable-next-line prefer-rest-params
  window.gtag = function gtag() { window.dataLayer!.push(arguments) } as Gtag
  window.gtag('js', new Date())
  // Page views are sent by pageView() on every route change (this is a single-page site).
  window.gtag('config', gaId, { send_page_view: false })
  const s = document.createElement('script')
  s.async = true
  s.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(gaId)}`
  document.head.appendChild(s)
  pageView()
  queue.splice(0).forEach(([e, p]) => track(e, p))
}

let lastPath = ''
export function pageView() {
  const path = window.location.pathname + window.location.search
  if (!id || !window.gtag || path === lastPath) return
  lastPath = path
  // Small delay so the page has set its own title first.
  setTimeout(() => window.gtag?.('event', 'page_view', { page_location: window.location.href, page_path: path, page_title: document.title }), 50)
}

/** Key actions: sign_up, login, search, delegate_register, post_create, help_request, share. */
export function track(event: string, params: Record<string, unknown> = {}) {
  if (!id || !window.gtag) { if (queue.length < 20) queue.push([event, params]); return }
  window.gtag('event', event, params)
}
