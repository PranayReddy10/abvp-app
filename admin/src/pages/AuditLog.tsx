import { useState } from 'react'
import { Empty, ErrorBox } from '../components/ui'
import { fmtTime } from '../format'
import { useFetch } from '../useFetch'

interface Row { id: number; action: string; actor: string | null; subject: string | null; after: Record<string, unknown> | null; ip: string | null; at: string }

export default function AuditLog() {
  const [page, setPage] = useState(1)
  const { data, meta, error } = useFetch<Row[]>(`/admin/audit-logs?page=${page}`)

  return (
    <main className="content">
      <div className="page-head"><h1>Audit log</h1><span className="muted">Every approval, role change and setup change, with who did it</span></div>
      <ErrorBox error={error} />
      <section className="card">
        <div className="table-wrap">
          <table>
            <thead><tr><th>When</th><th>Who</th><th>Action</th><th>Record</th><th>Details</th></tr></thead>
            <tbody>
              {data?.map((r) => (
                <tr key={r.id}>
                  <td>{fmtTime(r.at)}</td>
                  <td>{r.actor ?? 'System'}</td>
                  <td className="mono">{r.action}</td>
                  <td>{r.subject}</td>
                  <td className="muted" style={{ maxWidth: 360, overflowWrap: 'anywhere' }}>{r.after ? Object.entries(r.after).map(([k, v]) => `${k}: ${String(v)}`).join(' · ') : ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {data?.length === 0 && <Empty>Nothing recorded yet.</Empty>}
        </div>
        <div className="pager">
          <button className="btn small" disabled={page <= 1} onClick={() => setPage(page - 1)}>Newer</button>
          <button className="btn small" disabled={page >= Number(meta.last_page ?? 1)} onClick={() => setPage(page + 1)}>Older</button>
        </div>
      </section>
    </main>
  )
}
