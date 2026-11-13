import { useEffect, useState, type FormEvent } from 'react'
import { api, ApiError, qs } from '../api'
import { downloadCsv, Split } from '../components/charts'
import { VerifiedBadge } from '../components/icons'
import { Empty, ErrorBox } from '../components/ui'
import { fmtTime } from '../format'
import { useFetch } from '../useFetch'

interface Team { id: number; name: string; description: string | null; lead: { name: string | null; member_id: string | null } | null; duties: number; done: number; problems: number }
interface Duty {
  id: number; title: string; location: string | null; starts_at: string; ends_at: string; status: string; status_note: string | null
  team: { id: number; name: string } | null; assignee: { name: string | null; member_id: string | null; verified?: boolean }; assignee_phone?: string | null; report_to: { name: string } | null
}
interface Help {
  id: number; category: string; category_label: string; message: string; location: string | null; status: string; raised_by: string
  raiser_mobile: string | null; at: string; waiting_minutes: number | null; replies: { by: string; from_team: boolean; body: string; at: string }[]
}
interface Clash { name: string; duty: string; event: string; starts_at: string; ends_at: string }

export const DUTY_STATUS: Record<string, { label: string; tone: string; color: string }> = {
  assigned: { label: 'Not accepted yet', tone: 'warn', color: 'var(--series-mute)' },
  accepted: { label: 'Accepted', tone: 'info', color: 'var(--series-3)' },
  in_progress: { label: 'On duty', tone: 'info', color: 'var(--series-1)' },
  done: { label: 'Done', tone: 'ok', color: 'var(--ok)' },
  blocked: { label: 'Problem', tone: 'bad', color: 'var(--bad)' },
  declined: { label: "Can't do", tone: 'bad', color: 'var(--warn)' },
  cancelled: { label: 'Cancelled', tone: 'mute', color: 'var(--line)' },
}

function local(iso: string) {
  const d = new Date(iso); const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}

export function DutySummary({ counts }: { counts: Record<string, number> }) {
  const order = ['done', 'in_progress', 'accepted', 'assigned', 'declined', 'blocked']
  return <Split parts={order.map((k) => ({ label: DUTY_STATUS[k].label, value: Number(counts[k] ?? 0), color: DUTY_STATUS[k].color }))} />
}

export function DutiesTab({ id, title, startsAt }: { id: number; title: string; startsAt: string }) {
  const { data: teams, reload: reloadTeams } = useFetch<Team[]>(`/admin/events/${id}/teams`)
  const [filter, setFilter] = useState({ team_id: '', status: '' })
  const { data: duties, meta, reload } = useFetch<Duty[]>(`/admin/events/${id}/duties${qs(filter)}`)
  const [t, setT] = useState({ name: '', lead_member_id: '' })
  const [d, setD] = useState({ title: '', team_id: '', location: '', instructions: '', starts_at: local(startsAt), hours: '4', member_ids: '' })
  const [clashes, setClashes] = useState<Clash[] | null>(null)
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState<unknown>(null)
  const [reassign, setReassign] = useState<{ id: number; member: string } | null>(null)

  async function addTeam(e: FormEvent) {
    e.preventDefault(); setErr(null)
    try { await api.post(`/admin/events/${id}/teams`, { name: t.name, lead_member_id: t.lead_member_id || null }); setT({ name: '', lead_member_id: '' }); reloadTeams() } catch (x) { setErr(x) }
  }

  async function assign(e: FormEvent | null, force = false) {
    e?.preventDefault(); setErr(null); setMsg('')
    const start = new Date(d.starts_at)
    const body = {
      title: d.title, location: d.location || null, instructions: d.instructions || null,
      team_id: d.team_id ? Number(d.team_id) : null,
      starts_at: start.toISOString(), ends_at: new Date(start.getTime() + Number(d.hours) * 3600000).toISOString(),
      member_ids: d.member_ids.split(/[\s,]+/).map((s) => s.trim().toUpperCase()).filter(Boolean), force,
    }
    try {
      const r = await api.post<{ created: number }>(`/admin/events/${id}/duties`, body)
      setMsg(`Assigned to ${r.data.created} ${r.data.created === 1 ? 'person' : 'people'}. They have been asked to accept.`)
      setClashes(null); setD({ ...d, member_ids: '' }); reload(); reloadTeams()
    } catch (x) {
      if (x instanceof ApiError && x.code === 'DUTY_CLASH') setClashes((x.body?.clashes ?? []) as Clash[])
      else setErr(x)
    }
  }

  async function doReassign() {
    if (!reassign) return
    try { await api.patch(`/admin/events/${id}/duties/${reassign.id}`, { member_id: reassign.member.trim().toUpperCase() }); setReassign(null); reload() } catch (x) { setErr(x) }
  }

  const counts = (meta.counts ?? {}) as Record<string, number>

  return (
    <>
      <div className="grid2">
        <section className="card">
          <div className="page-head"><h3>Duties</h3>
            <button className="btn small" disabled={!duties?.length} onClick={() => duties && downloadCsv(`${title.toLowerCase().replace(/\s+/g, '-')}-duties.csv`, duties.map((x) => ({
              duty: x.title, team: x.team?.name ?? '', person: x.assignee.name, member_id: x.assignee.member_id, location: x.location, starts: x.starts_at, ends: x.ends_at, status: DUTY_STATUS[x.status]?.label, note: x.status_note,
            })))}>Download CSV</button>
          </div>
          <DutySummary counts={counts} />
          <div className="toolbar">
            <select className="input" style={{ width: 180 }} value={filter.team_id} onChange={(e) => setFilter({ ...filter, team_id: e.target.value })} aria-label="Team">
              <option value="">All teams</option>{teams?.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
            </select>
            <div className="chips">
              {[['', 'All'], ['assigned', 'Not accepted'], ['problems', 'Problems'], ['in_progress', 'On duty'], ['done', 'Done']].map(([k, l]) => (
                <button key={k} className={`chip ${filter.status === k ? 'on' : ''}`} onClick={() => setFilter({ ...filter, status: k })}>{l}</button>
              ))}
            </div>
          </div>
          <div className="table-wrap">
            <table>
              <thead><tr><th>Duty</th><th>Person</th><th>When</th><th>Status</th><th /></tr></thead>
              <tbody>
                {duties?.map((x) => (
                  <tr key={x.id}>
                    <td><b>{x.title}</b><div className="muted" style={{ fontSize: 12 }}>{[x.team?.name, x.location].filter(Boolean).join(' · ')}</div></td>
                    <td><span className="name-badge">{x.assignee.name}{x.assignee.verified && <VerifiedBadge />}</span><div className="mono muted" style={{ fontSize: 12 }}>{[x.assignee.member_id, x.assignee_phone].filter(Boolean).join(' · ')}</div></td>
                    <td style={{ whiteSpace: 'nowrap' }}>{fmtTime(x.starts_at)}</td>
                    <td><span className={`pill ${DUTY_STATUS[x.status]?.tone}`}>{DUTY_STATUS[x.status]?.label}</span>{x.status_note && <div className="muted" style={{ fontSize: 12, maxWidth: 220 }}>“{x.status_note}”</div>}</td>
                    <td style={{ whiteSpace: 'nowrap' }}>
                      {reassign?.id === x.id ? (
                        <span className="toolbar"><input className="input mono" style={{ width: 130 }} placeholder="Member ID" value={reassign.member} onChange={(e) => setReassign({ id: x.id, member: e.target.value })} /><button className="btn small primary" onClick={doReassign}>Move</button></span>
                      ) : x.status !== 'cancelled' && x.status !== 'done' && (
                        <><button className="btn small" onClick={() => setReassign({ id: x.id, member: '' })}>Reassign</button>{' '}
                          <button className="btn small danger" onClick={async () => { await api.del(`/admin/events/${id}/duties/${x.id}`); reload() }}>Cancel</button></>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {duties?.length === 0 && <Empty>No duties here yet.</Empty>}
          </div>
        </section>
        <div style={{ display: 'grid', gap: 12, alignContent: 'start' }}>
          <form className="card" onSubmit={(e) => assign(e)}>
            <h3>Assign a duty</h3>
            <p className="muted">Only people registered for this event or on its team. Each person is asked to accept, and sees who to report to.</p>
            {msg && <div className="notice">{msg}</div>}
            <ErrorBox error={err} />
            {clashes && (
              <div className="error" style={{ display: 'grid', gap: 6 }}>
                <span>Some people already have a duty at that time:</span>
                {clashes.map((c, i) => <span key={i} style={{ fontWeight: 500 }}>{c.name}: {c.duty} ({c.event}, {fmtTime(c.starts_at)})</span>)}
                <div className="toolbar"><button type="button" className="btn small" onClick={() => assign(null, true)}>Assign anyway</button><button type="button" className="btn small" onClick={() => setClashes(null)}>Change people</button></div>
              </div>
            )}
            <div className="row2">
              <div className="field"><label htmlFor="dt">Duty</label><input id="dt" className="input" required value={d.title} onChange={(e) => setD({ ...d, title: e.target.value })} placeholder="Registration desk" /></div>
              <div className="field"><label htmlFor="dteam">Team</label><select id="dteam" className="input" value={d.team_id} onChange={(e) => setD({ ...d, team_id: e.target.value })}><option value="">No team</option>{teams?.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}</select></div>
            </div>
            <div className="row2">
              <div className="field"><label htmlFor="dstart">Starts</label><input id="dstart" type="datetime-local" className="input" required value={d.starts_at} onChange={(e) => setD({ ...d, starts_at: e.target.value })} /></div>
              <div className="field"><label htmlFor="dh">Hours</label><select id="dh" className="input" value={d.hours} onChange={(e) => setD({ ...d, hours: e.target.value })}>{['1', '2', '3', '4', '6', '8', '12'].map((h) => <option key={h} value={h}>{h} hours</option>)}</select></div>
            </div>
            <div className="field"><label htmlFor="dl">Where to report</label><input id="dl" className="input" value={d.location} onChange={(e) => setD({ ...d, location: e.target.value })} placeholder="Gate 3" /></div>
            <div className="field"><label htmlFor="di">Instructions</label><textarea id="di" className="input" value={d.instructions} onChange={(e) => setD({ ...d, instructions: e.target.value })} /></div>
            <div className="field"><label htmlFor="dm">Member IDs (one or many, separated by commas or new lines)</label><textarea id="dm" className="input mono" required value={d.member_ids} onChange={(e) => setD({ ...d, member_ids: e.target.value })} /></div>
            <div><button className="btn primary">Assign</button></div>
          </form>
          <section className="card">
            <h3>Teams</h3>
            <form className="toolbar" onSubmit={addTeam}>
              <input className="input" style={{ width: 170 }} required placeholder="Team name" value={t.name} onChange={(e) => setT({ ...t, name: e.target.value })} aria-label="Team name" />
              <input className="input mono" style={{ width: 150 }} placeholder="Lead Member ID" value={t.lead_member_id} onChange={(e) => setT({ ...t, lead_member_id: e.target.value.trim().toUpperCase() })} aria-label="Lead Member ID" />
              <button className="btn">Add team</button>
            </form>
            {teams?.length === 0 && <Empty>No teams yet. Common ones: Registration, Hospitality, Stage and sound, Parking, Food, Medical.</Empty>}
            <div className="history">{teams?.map((x) => (
              <div key={x.id}><span><b>{x.name}</b></span>
                <span>{x.lead?.name ? `Lead: ${x.lead.name}` : 'No lead'} · {x.done}/{x.duties} done{x.problems ? ` · ` : ''}{x.problems ? <span className="pill bad">{x.problems} {x.problems === 1 ? 'problem' : 'problems'}</span> : null}</span></div>
            ))}</div>
          </section>
        </div>
      </div>
    </>
  )
}

export function HelpTab({ id }: { id: number }) {
  const [status, setStatus] = useState('')
  const { data, reload, error } = useFetch<Help[]>(`/admin/events/${id}/help${qs({ status })}`)
  const [reply, setReply] = useState<Record<number, string>>({})
  const [err, setErr] = useState<unknown>(null)

  // Chats arrive while the desk watches: refresh every 10 seconds.
  useEffect(() => {
    const t = window.setInterval(reload, 10000)
    return () => window.clearInterval(t)
  }, [reload])

  async function send(h: Help) {
    try { await api.post(`/help/${h.id}/reply`, { body: reply[h.id] }); setReply({ ...reply, [h.id]: '' }); reload() } catch (x) { setErr(x) }
  }
  async function setHelpStatus(h: Help, s: string) {
    try { await api.patch(`/admin/events/${id}/help/${h.id}`, { status: s }); reload() } catch (x) { setErr(x) }
  }

  return (
    <section className="card">
      <div className="page-head"><div><h3>Help desk</h3><p className="sub muted" style={{ margin: 0, fontSize: 13 }}>Tickets and chats from delegates. Updates every 10 seconds.</p></div>
        <div className="chips">{[['', 'All'], ['open', 'New'], ['in_progress', 'Being handled'], ['resolved', 'Resolved']].map(([k, l]) => <button key={k} className={`chip ${status === k ? 'on' : ''}`} onClick={() => setStatus(k)}>{l}</button>)}</div>
      </div>
      <ErrorBox error={error ?? err} />
      {data?.length === 0 && <Empty>No help requests.</Empty>}
      <div className="feed">
        {data?.map((h) => (
          <div className="post" key={h.id} style={h.category === 'medical' && h.status !== 'resolved' ? { borderColor: 'var(--bad)', boxShadow: 'inset 3px 0 0 var(--bad)' } : undefined}>
            <div className="page-head">
              <div><span className={`pill ${h.category === 'medical' ? 'bad' : 'mute'}`}>{h.category_label}</span> <b style={{ marginLeft: 6 }}>{h.raised_by}</b> <span className="mono muted">{h.raiser_mobile}</span></div>
              <span className="muted" style={{ fontSize: 12 }}>{fmtTime(h.at)}{h.waiting_minutes !== null ? ` · waiting ${h.waiting_minutes} min` : ''}</span>
            </div>
            <div className="chat">
              <div className="bubble them"><span>{h.message}</span>{h.location ? <small>at {h.location}</small> : null}</div>
              {h.replies.map((r, i) => (
                <div key={i} className={`bubble ${r.from_team ? 'us' : 'them'}`}>
                  {r.from_team && <small className="by">{r.by}</small>}
                  <span>{r.body}</span>
                  <small>{fmtTime(r.at)}</small>
                </div>
              ))}
            </div>
            {h.status !== 'resolved' && (
              <div className="toolbar">
                <input className="input" style={{ flex: 1, minWidth: 200 }} placeholder={h.category === 'chat' ? 'Type a message' : 'Reply to them'} value={reply[h.id] ?? ''} onChange={(e) => setReply({ ...reply, [h.id]: e.target.value })} aria-label="Reply" />
                <button className="btn small" disabled={!reply[h.id]} onClick={() => send(h)}>Send</button>
                <button className="btn small good" onClick={() => setHelpStatus(h, 'resolved')}>Resolved</button>
              </div>
            )}
          </div>
        ))}
      </div>
    </section>
  )
}

export function AnnouncementsTab({ id }: { id: number }) {
  const { data, reload } = useFetch<{ id: number; title: string; body: string; audience: string; recipients: number; sent_by: string | null; at: string }[]>(`/admin/events/${id}/announcements`)
  const [f, setF] = useState({ title: '', body: '', audience: 'everyone' })
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState<unknown>(null)

  async function send(e: FormEvent) {
    e.preventDefault(); setErr(null)
    try { const r = await api.post<{ recipients: number }>(`/admin/events/${id}/announcements`, f); setMsg(`Sent to ${r.data.recipients} people.`); setF({ ...f, title: '', body: '' }); reload() } catch (x) { setErr(x) }
  }

  return (
    <div className="grid2">
      <form className="card" onSubmit={send}>
        <h3>Send an announcement</h3>
        <p className="muted">Shows as a notification and on the event page in the app. Use it for changes on the day: timings, venue, food, transport.</p>
        {msg && <div className="notice">{msg}</div>}
        <ErrorBox error={err} />
        <div className="chips">
          <button type="button" className={`chip ${f.audience === 'everyone' ? 'on' : ''}`} onClick={() => setF({ ...f, audience: 'everyone' })}>Everyone at the event</button>
          <button type="button" className={`chip ${f.audience === 'team_only' ? 'on' : ''}`} onClick={() => setF({ ...f, audience: 'team_only' })}>Volunteers and team only</button>
        </div>
        <div className="field"><label htmlFor="at">Headline</label><input id="at" className="input" required value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} placeholder="Lunch moved to 1:30 PM" /></div>
        <div className="field"><label htmlFor="ab">Message</label><textarea id="ab" className="input" required value={f.body} onChange={(e) => setF({ ...f, body: e.target.value })} /></div>
        <div><button className="btn primary">Send</button></div>
      </form>
      <section className="card">
        <h3>Sent</h3>
        {data?.length === 0 && <Empty>Nothing sent yet.</Empty>}
        <div className="feed">{data?.map((a) => (
          <div className="post" key={a.id}><span className="who">{fmtTime(a.at)} · {a.sent_by} · {a.audience === 'everyone' ? 'Everyone' : 'Team only'} · {a.recipients} people</span><b>{a.title}</b><span>{a.body}</span></div>
        ))}</div>
      </section>
    </div>
  )
}
