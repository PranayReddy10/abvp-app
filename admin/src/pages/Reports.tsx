import { useState } from 'react'
import { qs } from '../api'
import { downloadCsv } from '../components/charts'
import { Empty, ErrorBox } from '../components/ui'
import { fmtDate, fmtNum } from '../format'
import { useFetch } from '../useFetch'
import { VibhagPicker } from '../components/AreaPicker'

interface Report { id: number; title: string; programme_label: string; held_on: string; place: string | null; participants: number; institutions: number; description: string | null; unit: string; vibhag: string | null; submitted_by: string | null; photo_urls: string[] }

export default function Reports() {
  const [type, setType] = useState('')
  const [vibhag, setVibhag] = useState('')
  const [page, setPage] = useState(1)
  const { data, meta, error } = useFetch<Report[]>(`/admin/activity-reports${qs({ programme_type: type, vibhag_id: vibhag, page })}`)
  const { data: types } = useFetch<{ key: string; label: string }[]>('/activity-reports/types')

  return (
    <main className="content">
      <div className="page-head">
        <h1>Activity reports</h1>
        <div className="toolbar">
          <select className="input" style={{ width: 200 }} value={type} onChange={(e) => { setType(e.target.value); setPage(1) }} aria-label="Programme type">
            <option value="">All programme types</option>
            {types?.map((t) => <option key={t.key} value={t.key}>{t.label}</option>)}
          </select>
          <div style={{ width: 200 }}><VibhagPicker id="rv" value={vibhag} onChange={(v) => { setVibhag(v); setPage(1) }} /></div>
          <button className="btn small" disabled={!data?.length} onClick={() => data && downloadCsv('abvp-activity-reports.csv', data.map(({ photo_urls: _p, id: _i, ...r }) => r))}>Download CSV</button>
        </div>
      </div>
      <ErrorBox error={error} />
      <p className="muted">{fmtNum(Number(meta.total_reports ?? 0))} reports · {fmtNum(Number(meta.total_participants ?? 0))} students reached</p>
      <section className="card">
        <div className="table-wrap">
          <table>
            <thead><tr><th>Programme</th><th>Date</th><th>Unit</th><th>Students</th><th>Colleges</th><th>Photos</th></tr></thead>
            <tbody>
              {data?.map((r) => (
                <tr key={r.id}>
                  <td><b>{r.title}</b><div className="muted" style={{ fontSize: 12 }}>{r.programme_label}{r.vibhag ? ` · ${r.vibhag}` : ''}{r.place ? ` · ${r.place}` : ''} · by {r.submitted_by}</div>
                    {r.description && <div style={{ fontSize: 13, marginTop: 4, maxWidth: 520 }}>{r.description}</div>}</td>
                  <td>{fmtDate(r.held_on)}</td>
                  <td>{r.unit}</td>
                  <td>{fmtNum(r.participants)}</td>
                  <td>{r.institutions || '–'}</td>
                  <td><div className="photos">{r.photo_urls.map((u, i) => <a key={i} href={u} target="_blank" rel="noreferrer"><img src={u} alt={`Photo ${i + 1} of ${r.title}`} /></a>)}</div></td>
                </tr>
              ))}
            </tbody>
          </table>
          {data?.length === 0 && <Empty>No reports match.</Empty>}
        </div>
        <div className="pager">
          <button className="btn small" disabled={page <= 1} onClick={() => setPage(page - 1)}>Newer</button>
          <button className="btn small" disabled={page >= Number(meta.last_page ?? 1)} onClick={() => setPage(page + 1)}>Older</button>
        </div>
      </section>
    </main>
  )
}
