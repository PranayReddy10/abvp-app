import { useState } from 'react'
import { qs } from '../api'
import { Columns, downloadCsv, HBars, Split } from '../components/charts'
import { ErrorBox } from '../components/ui'
import { fmtDate, fmtNum } from '../format'
import { useFetch } from '../useFetch'

interface Month { month: string; label: string; new_members: number; applications: number; meetings: number; reports: number; participants: number }
interface UnitRow { id: number; name: string; type: string; has_children: boolean; members: number; new_members: number; pending: number; meetings: number; reports: number; participants: number; last_report_on: string | null; attention: string[] }
interface Analytics {
  scope: { id: number; name: string; type: string; label: string; parent_id: number | null }
  period: { months: number; from: string; to: string }
  summary: {
    members_total: number; members_new: number; applications_received: number; approval_rate: number | null
    median_days_to_decision: number | null; pending_now: number; pending_over_7_days: number
    meetings_held: number; attendance_rate: number | null; circulars_issued: number; circular_read_rate: number | null
    reports_submitted: number; participants_reached: number; events_held: number; event_registrations: number; event_turnout: number | null; units_total: number; units_active_30_days: number
  }
  monthly: Month[]
  funnel: { received: number; approved: number; returned: number; rejected: number; pending: number }
  units: UnitRow[]
  vibhags: { id: number; name: string; members: number; meetings: number; reports: number; participants: number }[]
  programme_types: { key: string; label: string; reports: number; participants: number }[]
  demographics: { gender: { key: string; label: string; count: number }[]; age: { label: string; count: number }[]; study_year: { label: string; count: number }[] }
  reviewers: { name: string; decisions: number; approved: number; returned: number; rejected: number; avg_days: number | null }[]
}

const pct = (n: number | null) => (n === null ? '–' : `${n}%`)
const SERIES = ['var(--series-1)', 'var(--series-2)', 'var(--series-3)', 'var(--series-mute)']
const MONTH_NAME = new Intl.DateTimeFormat('en-IN', { month: 'long', year: 'numeric' })

export default function Analytics() {
  const [months, setMonths] = useState(6)
  const [unitId, setUnitId] = useState<number | null>(null)
  const [trail, setTrail] = useState<{ id: number | null; name: string }[]>([])
  const [table, setTable] = useState(false)
  const { data: a, error, loading } = useFetch<Analytics>(`/admin/analytics${qs({ months, unit_id: unitId })}`)

  function drill(u: UnitRow) {
    if (!a) return
    setTrail([...trail, { id: unitId, name: a.scope.name }])
    setUnitId(u.id)
  }
  function back(i: number) {
    setUnitId(trail[i].id)
    setTrail(trail.slice(0, i))
  }

  const s = a?.summary
  const series = (key: keyof Month) => (a?.monthly ?? []).map((m) => ({ label: m.label, full: MONTH_NAME.format(new Date(m.month + '-01')), value: m[key] as number }))
  const maxMembers = Math.max(1, ...(a?.units.map((u) => u.members) ?? [1]))

  return (
    <main className="content">
      <div className="page-head">
        <div style={{ display: 'grid', gap: 4 }}>
          <h1>Analysis</h1>
          <div className="crumbs">
            {trail.map((t, i) => <span key={i}><button onClick={() => back(i)}>{t.name}</button> ›</span>)}
            <span>{trail.length ? a?.scope.name : a?.scope.label}</span>
          </div>
        </div>
        <div className="toolbar">
          <div className="chips" role="group" aria-label="Period">
            {[3, 6, 12].map((m) => <button key={m} className={`chip ${months === m ? 'on' : ''}`} onClick={() => setMonths(m)}>Last {m} months</button>)}
          </div>
        </div>
      </div>
      <ErrorBox error={error} />
      {loading && !a && <p className="muted">Loading…</p>}
      {a && s && (
        <>
          <div className="kpis seven">
            <div className="kpi"><span>Approved members</span><b>{fmtNum(s.members_total)}</b><small>+{fmtNum(s.members_new)} in period</small></div>
            <div className={`kpi ${s.pending_over_7_days ? 'alert' : ''}`}><span>Waiting for approval</span><b>{fmtNum(s.pending_now)}</b>
              <small style={s.pending_over_7_days ? { color: 'var(--warn)', fontWeight: 600 } : undefined}>{fmtNum(s.pending_over_7_days)} over 7 days</small></div>
            <div className="kpi"><span>Approval rate</span><b>{pct(s.approval_rate)}</b><small>Median {s.median_days_to_decision ?? '–'} days to decide</small></div>
            <div className="kpi"><span>Meetings held</span><b>{fmtNum(s.meetings_held)}</b><small>{pct(s.attendance_rate)} of invitees joined</small></div>
            <div className="kpi"><span>Events</span><b>{fmtNum(s.events_held)}</b><small>{fmtNum(s.event_registrations)} registered · {pct(s.event_turnout)} turned up</small></div>
            <div className="kpi"><span>Circulars read</span><b>{pct(s.circular_read_rate)}</b><small>{fmtNum(s.circulars_issued)} issued</small></div>
            <div className={`kpi ${s.units_total && s.units_active_30_days / s.units_total < 0.5 ? 'alert' : ''}`}><span>Units active (30 days)</span>
              <b>{fmtNum(s.units_active_30_days)}<span style={{ fontSize: 16, color: 'var(--muted)' }}> / {fmtNum(s.units_total)}</span></b>
              <small>{fmtNum(s.reports_submitted)} reports · {fmtNum(s.participants_reached)} students</small></div>
          </div>

          <section className="card">
            <div className="page-head">
              <h3>Month by month</h3>
              <button className="btn small" onClick={() => setTable(!table)}>{table ? 'Show charts' : 'Show as table'}</button>
            </div>
            {table ? (
              <div className="table-wrap"><table>
                <thead><tr><th>Month</th><th>New members</th><th>Applications</th><th>Meetings</th><th>Activity reports</th><th>Students reached</th></tr></thead>
                <tbody>{a.monthly.map((m) => <tr key={m.month}><td>{MONTH_NAME.format(new Date(m.month + '-01'))}</td><td>{m.new_members}</td><td>{m.applications}</td><td>{m.meetings}</td><td>{m.reports}</td><td>{fmtNum(m.participants)}</td></tr>)}</tbody>
              </table></div>
            ) : (
              <div className="chart-grid">
                {([['new_members', 'New members', 'approved'], ['applications', 'Applications received', 'received'], ['meetings', 'Meetings held', 'meetings'], ['participants', 'Students reached', 'students']] as const).map(([k, t, u]) => (
                  <div className="mini" key={k}>
                    <h3>{t} <small>{fmtNum(a.monthly.reduce((x, m) => x + (m[k] as number), 0))}</small></h3>
                    <Columns data={series(k)} unit={u} />
                  </div>
                ))}
              </div>
            )}
          </section>

          <section className="card">
            <div className="page-head">
              <h3>{a.units.length === 1 && a.units[0].id === a.scope.id ? 'This unit' : `Inside ${a.scope.name}`}</h3>
              <button className="btn small" onClick={() => downloadCsv(`abvp-${a.scope.name.toLowerCase().replace(/\s+/g, '-')}-units.csv`, a.units.map(({ id: _id, type: _t, has_children: _h, ...rest }) => rest))}>Download CSV</button>
            </div>
            <div className="table-wrap">
              <table>
                <thead><tr><th>Area</th><th>Members</th><th>New</th><th>Waiting</th><th>Meetings</th><th>Reports</th><th>Students reached</th><th>Last activity</th><th>Needs attention</th><th /></tr></thead>
                <tbody>
                  {a.units.map((u) => (
                    <tr key={u.id}>
                      <td><b>{u.name}</b></td>
                      <td><div className="inline-bar"><i style={{ width: `${(u.members / maxMembers) * 80}px` }} />{fmtNum(u.members)}</div></td>
                      <td>{u.new_members ? `+${u.new_members}` : '–'}</td>
                      <td>{u.pending || '–'}</td>
                      <td>{u.meetings || '–'}</td>
                      <td>{u.reports || '–'}</td>
                      <td>{u.participants ? fmtNum(u.participants) : '–'}</td>
                      <td>{fmtDate(u.last_report_on)}</td>
                      <td><div className="attention">{u.attention.length === 0 ? <span className="pill ok">On track</span> : u.attention.map((t) => <span key={t} className="pill warn">{t}</span>)}</div></td>
                      <td>{u.has_children && <button className="btn small" onClick={() => drill(u)}>Open</button>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <div className="grid2">
            <section className="card">
              <h3>Membership applications in this period</h3>
              <HBars rows={[
                { label: 'Received', value: a.funnel.received },
                { label: 'Approved', value: a.funnel.approved },
                { label: 'Returned for correction', value: a.funnel.returned },
                { label: 'Rejected', value: a.funnel.rejected },
                { label: 'Waiting now', value: a.funnel.pending },
              ]} />
              <h3 style={{ marginTop: 8 }}>Who is reviewing</h3>
              {a.reviewers.length === 0 ? <p className="muted">No decisions in this period.</p> : (
                <div className="table-wrap"><table>
                  <thead><tr><th>Reviewer</th><th>Decisions</th><th>Approved</th><th>Returned</th><th>Rejected</th><th>Avg. days</th></tr></thead>
                  <tbody>{a.reviewers.map((r) => <tr key={r.name}><td>{r.name}</td><td>{r.decisions}</td><td>{r.approved}</td><td>{r.returned}</td><td>{r.rejected}</td><td>{r.avg_days ?? '–'}</td></tr>)}</tbody>
                </table></div>
              )}
            </section>
            <section className="card">
              <h3>Members by Vibhag</h3>
              <HBars rows={a.vibhags.filter((v) => v.members || v.reports).map((v) => ({
                label: v.name, value: v.members,
                hint: `${fmtNum(v.members)} members · ${v.meetings} meetings · ${v.reports} reports`,
              }))} />
            </section>
          </div>

          <div className="grid2">
            <section className="card">
              <h3>Field work by programme type</h3>
              <HBars rows={a.programme_types.map((p) => ({ label: p.label, value: p.reports, hint: `${p.reports} reports · ${fmtNum(p.participants)} students` }))} />
            </section>
            <section className="card">
              <h3>Who our members are</h3>
              <Split parts={a.demographics.gender.map((g, i) => ({ label: g.label, value: g.count, color: SERIES[g.key === 'not_given' ? 3 : Math.min(i, 2)] }))} />
              <h3 style={{ marginTop: 6 }}>Age</h3>
              <HBars rows={a.demographics.age.map((g) => ({ label: g.label, value: g.count }))} color="var(--series-1)" />
            </section>
          </div>
        </>
      )}
    </main>
  )
}
