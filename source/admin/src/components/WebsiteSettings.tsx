import { useEffect, useState, type FormEvent } from 'react'
import { api } from '../api'
import { useFetch } from '../useFetch'
import { ErrorBox, Skeleton } from './ui'

interface Site { ga_id: string | null; google_verification: string | null; bing_verification: string | null }

/** Settings → Website: Google Analytics and search-engine verification. The website reads these at start. */
export default function WebsiteSettings() {
  const { data, error, reload } = useFetch<Site>('/admin/settings/website')
  const [f, setF] = useState({ ga_id: '', google_verification: '', bing_verification: '' })
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [msg, setMsg] = useState('')
  useEffect(() => { if (data) setF({ ga_id: data.ga_id ?? '', google_verification: data.google_verification ?? '', bing_verification: data.bing_verification ?? '' }) }, [data])
  if (!data) return <section className="card settings-card"><h3 style={{ margin: 0 }}>Website</h3><ErrorBox error={error} />{!error && <Skeleton rows={3} />}</section>

  async function save(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setErr(null); setMsg('')
    try {
      await api.put('/admin/settings/website', { ga_id: f.ga_id.trim().toUpperCase() || null, google_verification: f.google_verification || null, bing_verification: f.bing_verification || null })
      setMsg('Saved. The website picks it up the next time a page is opened.')
      reload()
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  return (
    <form className="card settings-card" onSubmit={save}>
      <div className="settings-head">
        <div>
          <h3 style={{ margin: 0 }}>Website – analytics and Google</h3>
          <p className="muted" style={{ margin: '4px 0 0' }}>Google Analytics for abvpconnect.org, and the codes Google and Bing give you to prove you own the site.</p>
        </div>
        <span className={`pill ${data.ga_id ? 'ok' : 'warn'}`}>{data.ga_id ? 'Analytics on' : 'Analytics off'}</span>
      </div>
      <div className="field"><label htmlFor="ga">Google Analytics Measurement ID</label>
        <input id="ga" className="input" placeholder="G-ABC123XYZ" value={f.ga_id} onChange={(e) => setF({ ...f, ga_id: e.target.value })} />
        <small className="muted">Google Analytics → Admin → Data streams → Web → Measurement ID. Leave empty to switch analytics off.</small>
      </div>
      <div className="field"><label htmlFor="gv">Google Search Console verification (HTML tag)</label>
        <input id="gv" className="input" placeholder='Paste the whole <meta name="google-site-verification" …> tag or just the code' value={f.google_verification} onChange={(e) => setF({ ...f, google_verification: e.target.value })} />
        <small className="muted">The DNS (TXT record) method in Hostinger is the most reliable; use this if you chose “HTML tag”.</small>
      </div>
      <div className="field"><label htmlFor="bv">Bing Webmaster verification (optional)</label>
        <input id="bv" className="input" placeholder="msvalidate.01 code" value={f.bing_verification} onChange={(e) => setF({ ...f, bing_verification: e.target.value })} />
      </div>
      {msg && <div className="notice" role="status">{msg}</div>}
      <ErrorBox error={err} />
      <div><button className="btn primary" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button></div>
    </form>
  )
}
