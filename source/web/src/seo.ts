import { useEffect } from 'react'

/**
 * Per-page title, description, canonical link and share tags. Google renders the website, so what is
 * set here is what appears in search results and when a link is shared.
 */
export const SITE = 'https://abvpconnect.org'
const DEFAULT_DESC = 'ABVP Connect is the official app and website of Akhil Bharatiya Vidyarthi Parishad for the Rashtriya Adhiveshan: delegate registration, the conference guide, volunteers, help desk and the members community.'

function meta(attr: 'name' | 'property', key: string, value: string) {
  let el = document.head.querySelector<HTMLMetaElement>(`meta[${attr}="${key}"]`)
  if (!el) { el = document.createElement('meta'); el.setAttribute(attr, key); document.head.appendChild(el) }
  el.content = value
}
function link(rel: string, href: string) {
  let el = document.head.querySelector<HTMLLinkElement>(`link[rel="${rel}"]:not([hreflang])`)
  if (!el) { el = document.createElement('link'); el.rel = rel; document.head.appendChild(el) }
  el.href = href
}

export interface Seo {
  title: string
  description?: string
  /** Path for the canonical link; defaults to the current path without the query. */
  path?: string
  /** Personal or sign-in-only pages: keep them out of search results. */
  noindex?: boolean
  image?: string
  /** Extra structured data for this page (an Event, for example). */
  jsonLd?: object | null
}

export function applySeo({ title, description = DEFAULT_DESC, path, noindex, image, jsonLd }: Seo) {
  const full = title.includes('ABVP Connect') ? title : `${title} | ABVP Connect`
  const url = SITE + (path ?? window.location.pathname)
  document.title = full
  meta('name', 'description', description)
  meta('name', 'robots', noindex ? 'noindex, nofollow' : 'index, follow, max-image-preview:large')
  link('canonical', url)
  meta('property', 'og:title', full)
  meta('property', 'og:description', description)
  meta('property', 'og:url', url)
  meta('property', 'og:image', image ?? `${SITE}/og-image.jpg`)
  meta('name', 'twitter:title', full)
  meta('name', 'twitter:description', description)
  meta('name', 'twitter:image', image ?? `${SITE}/og-image.jpg`)
  let ld = document.getElementById('page-ld')
  if (jsonLd) {
    if (!ld) { ld = document.createElement('script'); ld.id = 'page-ld'; ld.setAttribute('type', 'application/ld+json'); document.head.appendChild(ld) }
    ld.textContent = JSON.stringify({ '@context': 'https://schema.org', ...jsonLd })
  } else ld?.remove()
}

export function useSeo(s: Seo) {
  const key = JSON.stringify(s)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { applySeo(s) }, [key])
}
