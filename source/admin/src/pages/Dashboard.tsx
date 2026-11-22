import { Link } from 'react-router-dom'
import { useAuth } from '../auth'
import { Icon, type IconName } from '../components/icons'
import { Avatar, ErrorBox, Skeleton } from '../components/ui'
import { ACTION_LABEL, fmtNum, fmtTime } from '../format'
import type { Dashboard as D } from '../types'
import { useFetch } from '../useFetch'

function Stat({ tone, icon, label, value, to, children }: { tone: 1 | 2 | 3 | 4; icon: IconName; label: string; value: number; to: string; children?: React.ReactNode }) {
  return (
    <Link to={to} className={`stat t${tone}`}>
      <span className="ico"><Icon name={icon} size={22} /></span>
      <span className="label">{label}</span>
      <b className="num">{fmtNum(value)}</b>
      <span className="foot">{children}</span>
    </Link>
  )
}

const DECISION_TONE: Record<string, string> = { approved: 'ok', returned: 'warn', rejected: 'bad' }

export default function Dashboard() {
  const { me } = useAuth()
  const { data: d, error, loading } = useFetch<D>('/admin/dashboard')
  const max = Math.max(1, ...(d?.pending_by_unit.map((u) => u.pending) ?? [1]))
  const first = (me?.profile?.full_name ?? me?.name ?? '').split(' ')[0]
  const hour = new Date().getHours()
  const greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening'

  return (
    <main className="content">
      <div className="page-head">
        <div>
          <h1>{greet}{first ? `, ${first}` : ''} 👋</h1>
          <p className="page-sub">Here is what needs you today{d?.scope ? ` in ${d.scope.label}` : ''}.</p>
        </div>
        <Link className="btn primary" to="/approvals"><Icon name="approvals" size={17} /> Review applications</Link>
      </div>
      <ErrorBox error={error} />
      {loading && !d && <section className="card"><Skeleton /></section>}
      {d && (
        <>
          <div className="kpis">
            <Stat tone={1} icon="members" label="Approved members" value={d.approved_members} to="/members">
              <span className="delta"><Icon name="trend" size={14} /> +{fmtNum(d.approved_this_month)}</span> this month
            </Stat>
            <Stat tone={3} icon="approvals" label="Waiting for approval" value={d.pending_applications} to="/approvals">
              {d.pending_over_7_days > 0
                ? <><span className="delta down"><Icon name="clock" size={14} /> {fmtNum(d.pending_over_7_days)}</span> waiting over 7 days</>
                : <><span className="delta flat">On time</span> none over 7 days</>}
            </Stat>
            <Stat tone={4} icon="reports" label="Returned for correction" value={d.returned_for_correction} to="/approvals">
              Waiting on applicants
            </Stat>
            <Stat tone={2} icon="audit" label="Decided today" value={d.decided_today} to="/approvals">
              Approved, returned or rejected
            </Stat>
          </div>
          <div className="grid2">
            <section className="card">
              <div className="card-head">
                <div><h3>Waiting for approval, by area</h3><p className="sub">Areas with the most applications in the queue</p></div>
                <Link className="btn small" to="/approvals">Open queue</Link>
              </div>
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
              <div className="card-head">
                <div><h3>Recent decisions</h3><p className="sub">Latest approvals, returns and rejections</p></div>
                {d.reported_posts ? <Link className="pill warn" to="/moderation">{d.reported_posts} reported post{d.reported_posts === 1 ? '' : 's'}</Link> : null}
              </div>
              {d.recent_decisions.length === 0 ? <p className="muted">No decisions yet.</p> : (
                <div>
                  {d.recent_decisions.map((r, i) => (
                    <div className="act" key={i}>
                      <Avatar name={r.actor ?? '?'} size={38} />
                      <div className="who"><b>{r.actor ?? 'Someone'}</b><span>{fmtTime(r.at)}</span></div>
                      <span className={`pill ${DECISION_TONE[r.action] ?? 'mute'}`}>{ACTION_LABEL[r.action] ?? r.action}</span>
                    </div>
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
