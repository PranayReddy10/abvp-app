import { useEffect, useState, type FormEvent } from 'react'
import { api, ApiError } from '../api'
import { ErrorBox, Skeleton } from '../components/ui'
import { fmtNum } from '../format'
import { useFetch } from '../useFetch'

interface StorageSettings {
  driver: 'local' | 'spaces'
  saved_driver: string | null
  spaces: { region: string; bucket: string | null; key_hint: string | null; has_secret: boolean }
  regions: { code: string; name: string }[]
  s3_driver_installed: boolean
  local_files: number
}
interface CopyResult { total: number; done: number; copied: number; skipped: number; failed: string[]; finished: boolean }

/** Super admin settings. Today: where photos and attachments are stored. */
export default function Settings() {
  const { data, error, reload } = useFetch<StorageSettings>('/admin/settings/storage')
  const [driver, setDriver] = useState<'local' | 'spaces'>('local')
  const [form, setForm] = useState({ region: 'blr1', bucket: '', key: '', secret: '' })
  const [busy, setBusy] = useState<'' | 'test' | 'save'>('')
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState<unknown>(null)
  const [copy, setCopy] = useState<CopyResult | null>(null)
  const [copying, setCopying] = useState(false)

  useEffect(() => {
    if (!data) return
    setDriver(data.driver)
    setForm((f) => ({ ...f, region: data.spaces.region, bucket: data.spaces.bucket ?? '' }))
  }, [data])

  async function run(kind: 'test' | 'save', ev?: FormEvent) {
    ev?.preventDefault()
    setBusy(kind)
    setMsg('')
    setErr(null)
    try {
      if (kind === 'test') {
        const r = await api.post<{ message: string }>('/admin/settings/storage/test', form)
        setMsg(r.data.message)
      } else {
        await api.put('/admin/settings/storage', driver === 'local' ? { driver } : { driver, ...form })
        setForm((f) => ({ ...f, key: '', secret: '' }))
        setMsg(driver === 'spaces' ? 'Saved. New photos now go to DigitalOcean Spaces.' : 'Saved. New photos are stored on this server.')
        reload()
      }
    } catch (e) {
      setErr(e)
    } finally {
      setBusy('')
    }
  }

  async function copyAll() {
    setCopying(true)
    setErr(null)
    let offset = 0
    let failed: string[] = []
    try {
      for (;;) {
        const r = await api.post<CopyResult>('/admin/settings/storage/copy', { offset })
        failed = failed.concat(r.data.failed)
        setCopy({ ...r.data, failed })
        if (r.data.finished) break
        offset = r.data.done
      }
    } catch (e) {
      setErr(e)
    } finally {
      setCopying(false)
    }
  }

  if (!data) return <main className="content"><h1>Settings</h1><ErrorBox error={error} />{!error && <section className="card"><Skeleton rows={5} /></section>}</main>

  const onSpaces = data.driver === 'spaces'
  const needsKeys = !data.spaces.has_secret
  const fieldErr = (k: string) => (err instanceof ApiError ? err.fields?.[k]?.[0] : undefined)

  return (
    <main className="content">
      <div className="page-head">
        <div>
          <h1>Settings</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>Only super admins see this page. Changes are recorded in the audit log.</p>
        </div>
      </div>
      <div className="grid2">
        <form className="card settings-card" onSubmit={(e) => run('save', e)}>
          <div className="settings-head">
            <div>
              <h3 style={{ margin: 0 }}>Photo storage</h3>
              <p className="muted" style={{ margin: '4px 0 0' }}>Member photos, post photos, event covers, report photos and circular PDFs.</p>
            </div>
            <span className={`pill ${onSpaces ? 'info' : 'mute'}`}>{onSpaces ? `Spaces · ${data.spaces.bucket}` : 'This server'}</span>
          </div>

          <div className="choice-grid" role="radiogroup" aria-label="Where to store photos">
            <label className={`choice ${driver === 'local' ? 'on' : ''}`}>
              <input type="radio" name="driver" checked={driver === 'local'} onChange={() => setDriver('local')} />
              <b>This server</b>
              <span className="muted">Hostinger disk. Simple, fine for the pilot. Counts against your hosting space.</span>
            </label>
            <label className={`choice ${driver === 'spaces' ? 'on' : ''}`}>
              <input type="radio" name="driver" checked={driver === 'spaces'} onChange={() => setDriver('spaces')} />
              <b>DigitalOcean Spaces</b>
              <span className="muted">Separate storage that grows without limit. Recommended once photos pile up.</span>
            </label>
          </div>

          {driver === 'spaces' && (
            <div className="settings-fields">
              {!data.s3_driver_installed && <div className="error" role="alert">The S3 driver is missing on the server. Run <code>composer require league/flysystem-aws-s3-v3</code> in the api folder.</div>}
              <div className="field">
                <label htmlFor="sp-region">Region</label>
                <select id="sp-region" className="input" value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })}>
                  {data.regions.map((r) => <option key={r.code} value={r.code}>{r.name} ({r.code})</option>)}
                </select>
              </div>
              <div className="field">
                <label htmlFor="sp-bucket">Space name</label>
                <input id="sp-bucket" className="input" placeholder="abvp-connect-photos" value={form.bucket} autoComplete="off"
                  onChange={(e) => setForm({ ...form, bucket: e.target.value.trim().toLowerCase() })} />
                {fieldErr('bucket') && <small className="bad-text">{fieldErr('bucket')}</small>}
                <small className="muted">Endpoint: https://{form.region}.digitaloceanspaces.com · keep the Space <b>private</b> (File listing: Restricted).</small>
              </div>
              <div className="field">
                <label htmlFor="sp-key">Access key</label>
                <input id="sp-key" className="input mono" autoComplete="off" placeholder={data.spaces.key_hint ? `Saved: ${data.spaces.key_hint} – leave blank to keep` : 'DO00…'}
                  value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value.trim() })} />
              </div>
              <div className="field">
                <label htmlFor="sp-secret">Secret key</label>
                <input id="sp-secret" type="password" className="input mono" autoComplete="new-password"
                  placeholder={data.spaces.has_secret ? 'Saved and encrypted – leave blank to keep' : 'Shown once when you create the key'}
                  value={form.secret} onChange={(e) => setForm({ ...form, secret: e.target.value.trim() })} />
                {fieldErr('secret') && <small className="bad-text">{fieldErr('secret')}</small>}
              </div>
              <details className="howto">
                <summary>How to get these from DigitalOcean</summary>
                <ol>
                  <li>In DigitalOcean, open <b>Spaces Object Storage</b> → <b>Create Spaces Bucket</b>. Pick a region near your members (Bangalore, blr1) and a name.</li>
                  <li>Open <b>Spaces Object Storage → Access Keys → Create Access Key</b>. Give it read/write access to this bucket only.</li>
                  <li>Copy the access key and the secret (the secret is shown only once) and paste them here.</li>
                  <li>Press <b>Test connection</b>, then <b>Save</b>. Nothing is switched unless the test passes.</li>
                </ol>
              </details>
            </div>
          )}

          <ErrorBox error={err} />
          {msg && <div className="notice" role="status">{msg}</div>}
          <div className="settings-actions">
            {driver === 'spaces' && (
              <button type="button" className="btn" disabled={!!busy || !form.bucket || (needsKeys && (!form.key || !form.secret))} onClick={() => run('test')}>
                {busy === 'test' ? 'Testing…' : 'Test connection'}
              </button>
            )}
            <button type="submit" className="btn primary" disabled={!!busy || (driver === 'spaces' && (!form.bucket || (needsKeys && (!form.key || !form.secret))))}>
              {busy === 'save' ? 'Checking and saving…' : 'Save'}
            </button>
          </div>
        </form>

        <section className="card settings-card">
          <h3 style={{ margin: 0 }}>Files already on this server</h3>
          <p className="muted" style={{ margin: 0 }}>
            {fmtNum(data.local_files)} file{data.local_files === 1 ? '' : 's'} were saved on the server.
            {onSpaces ? ' They keep working where they are; copy them to the Space so you can free up hosting space later.' : ' Switch to Spaces first to copy them.'}
          </p>
          {copy && (
            <div>
              <div className="progress" role="progressbar" aria-valuemin={0} aria-valuemax={copy.total} aria-valuenow={copy.done}>
                <i style={{ width: `${copy.total ? (copy.done / copy.total) * 100 : 100}%` }} />
              </div>
              <p className="muted" style={{ fontSize: 13, margin: '6px 0 0' }}>
                {fmtNum(copy.done)} of {fmtNum(copy.total)} checked{copy.finished ? ' – done.' : '…'}
                {copy.failed.length > 0 && <span className="bad-text"> {copy.failed.length} could not be copied; run it again.</span>}
              </p>
            </div>
          )}
          <div><button className="btn" disabled={!onSpaces || copying || data.local_files === 0} onClick={copyAll}>{copying ? 'Copying…' : 'Copy to Spaces'}</button></div>
          <p className="muted" style={{ fontSize: 12.5, margin: 0 }}>Copies 25 files at a time, so it is safe on shared hosting. Files already in the Space are skipped. Nothing is deleted from the server.</p>
        </section>
      </div>
    </main>
  )
}
