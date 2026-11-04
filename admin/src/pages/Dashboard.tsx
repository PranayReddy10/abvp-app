import { Link } from 'react-router-dom'
import { useAuth } from '../auth'
import { ErrorBox, Skeleton } from '../components/ui'
import { ACTION_LABEL, fmtNum, fmtTime } from '../format'
import type { Dashboard as D } from '../types'
import { useFetch } from '../useFetch'

export default function Dashboard() {
  const { me } = useAuth()
  const { data: d, error, loading } = useFetch<D>('/admin/dashboard')
  const max = Math.max(1, ...(d?.pending_by_unit.map((u) => u.pending) ?? [1]))
  const first = (me?.profile?.full_name ?? me?.name ?? '').split(' ')[0]

  return (
    <main className="content">
      <div className="page-head">
        <h1>Namaste{first ? `, ${first}` : ''}</h1>
        <span className="muted">{d?.scope?.label}</span>
      </div>
      <ErrorBox error={error} />
      {loading && !d && <Skeleton />}
      {d && (
        <>
          <div className="kpis">
            <div className="kpi"><span>Approved members</span><b>{fmtNum(d.approved_members)}</b><small>+{fmtNum(d.approved_this_month)} this month</small></div>
            <div className={`kpi ${d.pending_over_7_days > 0 ? 'alert' : ''}`}>
              <span>Waiting for approval</span><b>{fmtNum(d.pending_applications)}</b>
              <small style={d.pending_over_7_days ? { color: 'var(--warn)', fontWeight: 600 } : undefined}>{fmtNum(d.pending_over_7_days)} waiting over 7 days</small>
            </div>
            <div className="kpi"><span>Returned for correction</span><b>{fmtNum(d.returned_for_correction)}</b><small>Waiting on applicants</small></div>
            <div className="kpi"><span>Decided today</span><b>{fmtNum(d.decided_today)}</b><small>Approved, returned or rejected</small></div>
          </div>
          <div className="grid2">
            <section className="card">
              <div className="page-head"><h3>Waiting for approval, by area</h3><Link className="btn small" to="/approvals">Open queue</Link></div>
              {d.pending_by_unit.length === 0 ? (
                <p className="muted">Nothing is waiting. New applications will appear here.</p>
              ) : (
                <div className="bars">
                  {d.pending_by_unit.map((u) => (
                    <div className="bar" key={u.org_unit.id}>
                      <span>{u.org_unit.name}</span>
                      <div className="t"><i style={{ width: `${(u.pending / max) * 100}%` }} /></div>
                      <b>{fmtNum(u.pending)}</b>
                    </div>
                  ))}
                </div>
              )}
            </section>
            <section className="card">
              <h3>Recent decisions</h3>
              {d.recent_decisions.length === 0 ? <p className="muted">No decisions yet.</p> : (
                <div className="history">
                  {d.recent_decisions.map((r, i) => (
                    <div key={i}><span className="muted">{fmtTime(r.at)}</span><span>{r.actor ?? 'Someone'}: {ACTION_LABEL[r.action]?.toLowerCase() ?? r.action}</span></div>
                  ))}
                </div>
              )}
            </section>
          </div>
        </>
      )}
    </main>
  )
}
