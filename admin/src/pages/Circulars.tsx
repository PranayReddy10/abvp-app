import { useState, type FormEvent } from 'react'
import { api } from '../api'
import AreaPicker, { VibhagPicker } from '../components/AreaPicker'
import { Empty, ErrorBox } from '../components/ui'
import { fmtDate, fmtNum } from '../format'
import { useFetch } from '../useFetch'

interface Row { id: number; title: string; body: string; audience: string; issued_by: string | null; published_at: string; audience_size: number; reads: number; read_rate: number | null; has_attachment: boolean }

export default function Circulars() {
  const { data, error, reload } = useFetch<Row[]>('/admin/circulars')
  const [f, setF] = useState({ title: '', body: '', org_unit_id: '', vibhag_id: '' })
  const [file, setFile] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState<unknown>(null)
  const [notice, setNotice] = useState('')

  async function issue(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setFormError(null); setNotice('')
    try {
      const fd = new FormData()
      fd.set('title', f.title); fd.set('body', f.body); fd.set('org_unit_id', f.org_unit_id)
      if (f.vibhag_id) fd.set('vibhag_id', f.vibhag_id)
      if (file) fd.set('attachment', file)
      const r = await api.post<{ audience_size: number }>('/admin/circulars', fd)
      setNotice(`Issued to ${fmtNum(r.data.audience_size)} members.`)
      setF({ ...f, title: '', body: '' }); setFile(null)
      reload()
    } catch (err) { setFormError(err) } finally { setBusy(false) }
  }

  async function remind(c: Row) {
    try {
      const r = await api.post<{ reminded: number }>(`/admin/circulars/${c.id}/remind`)
      setNotice(`Reminder sent to ${fmtNum(r.data.reminded)} members who have not read “${c.title}”.`)
    } catch (err) { setFormError(err) }
  }

  return (
    <main className="content">
      <div className="page-head"><h1>Circulars</h1></div>
      <ErrorBox error={error} />
      {notice && <div className="notice">{notice}</div>}
      <div className="grid2" style={{ gridTemplateColumns: 'minmax(0,1.6fr) minmax(0,1fr)' }}>
        <section className="card">
          <div className="table-wrap">
            <table>
              <thead><tr><th>Circular</th><th>Issued</th><th>Audience</th><th>Read</th><th /></tr></thead>
              <tbody>
                {data?.map((c) => (
                  <tr key={c.id}>
                    <td><b>{c.title}</b>{c.has_attachment && <span className="muted"> · PDF</span>}<div className="muted" style={{ fontSize: 12 }}>{c.audience} · {c.issued_by}</div></td>
                    <td style={{ whiteSpace: 'nowrap' }}>{fmtDate(c.published_at)}</td>
                    <td>{fmtNum(c.audience_size)}</td>
                    <td><div className="inline-bar"><i style={{ width: `${(c.read_rate ?? 0) * 0.8}px` }} />{c.read_rate ?? 0}% <span className="muted">({fmtNum(c.reads)})</span></div></td>
                    <td>{c.reads < c.audience_size && <button className="btn small" onClick={() => remind(c)}>Remind unread</button>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {data?.length === 0 && <Empty>No circulars issued in your area yet.</Empty>}
          </div>
        </section>
        <form className="card" onSubmit={issue}>
          <h3>Issue a circular</h3>
          <p className="muted">Goes to every approved member in the area (and Vibhag, if chosen). You will see who has read it.</p>
          <ErrorBox error={formError} />
          <div className="field"><label htmlFor="ct">Title</label><input id="ct" className="input" required value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} /></div>
          <div className="row2">
            <div className="field"><label htmlFor="ca">To</label><AreaPicker id="ca" value={f.org_unit_id} onChange={(v) => setF({ ...f, org_unit_id: v })} /></div>
            <div className="field"><label htmlFor="cv">Vibhag</label><VibhagPicker id="cv" value={f.vibhag_id} onChange={(v) => setF({ ...f, vibhag_id: v })} /></div>
          </div>
          <div className="field"><label htmlFor="cb">Message</label><textarea id="cb" className="input" required style={{ minHeight: 140 }} value={f.body} onChange={(e) => setF({ ...f, body: e.target.value })} /></div>
          <div className="field"><label htmlFor="cf">Attachment (PDF or image, up to 5 MB)</label><input id="cf" type="file" accept=".pdf,image/*" onChange={(e) => setFile(e.target.files?.[0] ?? null)} /></div>
          <button className="btn primary" disabled={busy}>{busy ? 'Issuing…' : 'Issue circular'}</button>
        </form>
      </div>
    </main>
  )
}
