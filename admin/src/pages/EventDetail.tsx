import { useEffect, useState, type FormEvent } from 'react'
import { useParams, Link } from 'react-router-dom'
import { api, qs } from '../api'
import { Columns, downloadCsv, HBars, Split } from '../components/charts'
import { VerifiedBadge } from '../components/icons'
import { Empty, ErrorBox, Pill, Skeleton } from '../components/ui'
import { fmtDate, fmtNum, fmtTime } from '../format'
import { useFetch } from '../useFetch'
import EventForm, { type EventDetail as Detail } from './EventForm'
import LogisticsTab from './EventLogistics'
import { AnnouncementsTab, DutiesTab, DutySummary, HelpTab } from './EventOperations'
import { EVENT_STATUS } from './Events'

interface Live {
  expected: { members: number; guests: number }; arrived: { members: number; guests: number }
  pending_approval: number; waitlisted: number
  by_gate: { gate: string; count: number }[]; timeline: { at: string; count: number }[]
  recent: { name: string; kind: string; gate: string | null; place: string | null; at: string }[]; updated_at: string
  duties: Record<string, number>; help_open: number; help_medical_open: number
  logistics: { beds: number; beds_used: number; pickups_pending: number; meal_now: { name: string; served: number } | null; sharing_location: number }
}
interface RegRow { id: number; name: string; kind: string; member_id: string | null; verified?: boolean; mobile: string | null; place: string | null; status: string; registered_at: string; checked_in_at: string | null; gate: string | null; method: string | null }
interface Staff { id: number; role: string; name: string | null; member_id: string | null }

const TABS = ['Live', 'Duties', 'Logistics', 'Help desk', 'Announcements', 'Registrations', 'Guests and team', 'Details'] as const
const REG_STATUS: Record<string, string> = { registered: 'approved', waitlisted: 'submitted', pending: 'submitted', cancelled: 'draft', rejected: 'rejected' }
const REG_LABEL: Record<string, string> = { registered: 'Confirmed', waitlisted: 'Waitlist', pending: 'To approve', cancelled: 'Cancelled', rejected: 'Not approved' }
const time = new Intl.DateTimeFormat('en-IN', { hour: 'numeric', minute: '2-digit' })

export default function EventDetail() {
  const { id } = useParams()
  const [tab, setTab] = useState<(typeof TABS)[number]>('Live')
  const { data: e, error, reload } = useFetch<Detail>(`/admin/events/${id}`)
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState<unknown>(null)

  async function publish() {
    try { await api.post(`/admin/events/${id}/publish`); setMsg('Published. Members can now see and register.'); reload() } catch (x) { setErr(x) }
  }
  async function cancel() {
    const reason = (document.getElementById('cancel-reason') as HTMLInputElement | null)?.value ?? ''
    try { await api.post(`/admin/events/${id}/cancel`, { reason }); setMsg('Cancelled. Everyone registered has been told.'); reload() } catch (x) { setErr(x) }
  }

  if (error) return <main className="content"><ErrorBox error={error} /></main>
  if (!e) return <main className="content"><Skeleton /></main>
  const st = EVENT_STATUS[e.status]
  const seats = e.counts.members + e.counts.guests + e.counts.pending

  return (
    <main className="content">
      <div className="crumbs"><Link to="/events">Events</Link> ›</div>
      <div className="page-head">
        <div style={{ display: 'grid', gap: 4 }}>
          <h1>{e.title}</h1>
          <span className="muted">{fmtTime(e.starts_at)} – {fmtTime(e.ends_at)} · {e.venue} · {e.org_unit.name}</span>
        </div>
        <div className="toolbar">
          <span className={`pill ${st?.tone}`}>{st?.label}</span>
          {e.status === 'draft' && <button className="btn primary" onClick={publish}>Publish</button>}
        </div>
      </div>
      {msg && <div className="notice">{msg}</div>}
      <ErrorBox error={err} />
      <div className="kpis six">
        <div className="kpi"><span>Confirmed members</span><b>{fmtNum(e.counts.members)}</b><small>{e.capacity ? `${fmtNum(Math.max(0, e.capacity - seats))} seats left of ${fmtNum(e.capacity)}` : 'No seat limit'}</small></div>
        <div className="kpi"><span>Guests</span><b>{fmtNum(e.counts.guests)}</b><small>Invited personally</small></div>
        <div className={`kpi ${e.counts.pending ? 'alert' : ''}`}><span>To approve</span><b>{fmtNum(e.counts.pending)}</b><small>{e.requires_approval ? 'Approval is on' : 'Approval is off'}</small></div>
        <div className="kpi"><span>Waitlist</span><b>{fmtNum(e.counts.waitlisted)}</b><small>Move up when seats free</small></div>
        <div className="kpi"><span>Arrived</span><b>{fmtNum(e.counts.arrived)}</b><small>{e.counts.members + e.counts.guests ? `${Math.round((e.counts.arrived / (e.counts.members + e.counts.guests)) * 100)}% of confirmed` : '–'}</small></div>
        <div className="kpi"><span>Cancelled</span><b>{fmtNum(e.counts.cancelled)}</b><small>By the person</small></div>
      </div>
      <div className="chips" role="tablist">
        {TABS.map((t) => <button key={t} role="tab" aria-selected={tab === t} className={`chip ${tab === t ? 'on' : ''}`} onClick={() => setTab(t)}>{t}</button>)}
      </div>
      {tab === 'Live' && <LiveTab id={e.id} />}
      {tab === 'Duties' && <DutiesTab id={e.id} title={e.title} startsAt={e.starts_at} />}
      {tab === 'Logistics' && <LogisticsTab id={e.id} title={e.title} startsAt={e.starts_at} />}
      {tab === 'Help desk' && <HelpTab id={e.id} />}
      {tab === 'Announcements' && <AnnouncementsTab id={e.id} />}
      {tab === 'Registrations' && <RegistrationsTab id={e.id} title={e.title} onChange={reload} />}
      {tab === 'Guests and team' && <PeopleTab id={e.id} onChange={reload} />}
      {tab === 'Details' && (
        <div className="grid2">
          {e.status !== 'cancelled' && e.status !== 'completed' ? <EventForm event={e} onSaved={() => { setMsg('Saved.'); reload() }} /> : <section className="card"><p className="muted">This event is closed.</p></section>}
          <section className="card">
            <CoverBox id={e.id} url={e.cover_url ?? null} onSaved={() => { setMsg('Cover photo updated.'); reload() }} />
            <h3 style={{ marginTop: 16 }}>Who can register</h3>
            <p>{e.rules.length ? e.rules.map((r) => r.label).join(' or ') : 'All approved members'}</p>
            {e.status === 'published' && (
              <>
                <h3 style={{ marginTop: 10 }}>Cancel this event</h3>
                <p className="muted">Everyone registered, waitlisted or waiting for approval gets your reason.</p>
                <input id="cancel-reason" className="input" placeholder="Reason, e.g. Postponed due to exams" />
                <div><button className="btn danger" onClick={cancel}>Cancel event</button></div>
              </>
            )}
          </section>
        </div>
      )}
    </main>
  )
}

function LiveTab({ id }: { id: number }) {
  const { data: l, reload, error } = useFetch<Live>(`/admin/events/${id}/live`)
  // Shared hosting has no live push, so poll every 15 seconds.
  useEffect(() => { const t = setInterval(reload, 15000); return () => clearInterval(t) }, [reload])
  if (error) return <ErrorBox error={error} />
  if (!l) return <Skeleton />
  const expected = l.expected.members + l.expected.guests
  const arrived = l.arrived.members + l.arrived.guests

  return (
    <>
      <div className="grid2">
        <section className="card">
          <div className="page-head"><h3>Arrivals</h3><span className="muted" style={{ fontSize: 12 }}>Updated {time.format(new Date(l.updated_at))} · refreshes every 15 s</span></div>
          <Split parts={[
            { label: 'Members arrived', value: l.arrived.members, color: 'var(--series-1)' },
            { label: 'Guests arrived', value: l.arrived.guests, color: 'var(--series-2)' },
            { label: 'Not arrived yet', value: Math.max(0, expected - arrived), color: 'var(--series-mute)' },
          ]} />
          <h3 style={{ marginTop: 6 }}>Arrivals every 30 minutes</h3>
          {l.timeline.length ? <Columns unit="arrived" data={l.timeline.map((b) => ({ label: time.format(new Date(b.at)), full: time.format(new Date(b.at)), value: b.count }))} /> : <p className="muted">No arrivals yet.</p>}
        </section>
        <section className="card">
          <div className="page-head"><h3>Duties</h3>
            {l.help_open > 0 && <span className={`pill ${l.help_medical_open ? 'bad' : 'warn'}`}>{l.help_open} open help request{l.help_open === 1 ? '' : 's'}{l.help_medical_open ? ` · ${l.help_medical_open} medical` : ''}</span>}</div>
          {Object.keys(l.duties ?? {}).length ? <DutySummary counts={l.duties} /> : <p className="muted">No duties assigned yet.</p>}
          {l.logistics && (l.logistics.beds > 0 || l.logistics.meal_now || l.logistics.pickups_pending > 0) && (
            <div className="history" style={{ marginTop: 4 }}>
              {l.logistics.meal_now && <div><span className="muted">Serving now</span><span>{l.logistics.meal_now.name}: {fmtNum(l.logistics.meal_now.served)} served</span></div>}
              {l.logistics.beds > 0 && <div><span className="muted">Beds</span><span>{fmtNum(l.logistics.beds_used)} of {fmtNum(l.logistics.beds)} taken</span></div>}
              {l.logistics.pickups_pending > 0 && <div><span className="muted">Pickups</span><span>{fmtNum(l.logistics.pickups_pending)} still to be picked up</span></div>}
              {l.logistics.sharing_location > 0 && <div><span className="muted">Location</span><span>{l.logistics.sharing_location} sharing with coordinators</span></div>}
            </div>
          )}
          <h3 style={{ marginTop: 6 }}>By gate</h3>
          <HBars rows={l.by_gate.map((g) => ({ label: g.gate, value: g.count }))} />
          <h3 style={{ marginTop: 6 }}>Latest arrivals</h3>
          {l.recent.length === 0 ? <p className="muted">No one yet.</p> : (
            <div className="history">{l.recent.map((r, i) => (
              <div key={i}><span className="muted">{time.format(new Date(r.at))}{r.gate ? ` · ${r.gate}` : ''}</span><span>{r.name}{r.kind === 'guest' ? ' (guest)' : ''}{r.place ? ` · ${r.place}` : ''}</span></div>
            ))}</div>
          )}
        </section>
      </div>
    </>
  )
}

function RegistrationsTab({ id, title, onChange }: { id: number; title: string; onChange: () => void }) {
  const [status, setStatus] = useState('')
  const [kind, setKind] = useState('')
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const { data, meta, error, reload } = useFetch<RegRow[]>(`/admin/events/${id}/registrations${qs({ status, kind, q: search, page })}`)
  const [err, setErr] = useState<unknown>(null)

  async function act(fn: () => Promise<unknown>) {
    setErr(null)
    try { await fn(); reload(); onChange() } catch (x) { setErr(x) }
  }

  return (
    <section className="card">
      <div className="page-head">
        <div className="chips">
          {[['', 'All'], ['registered', 'Confirmed'], ['pending', 'To approve'], ['waitlisted', 'Waitlist'], ['arrived', 'Arrived'], ['not_arrived', 'Not arrived'], ['cancelled', 'Cancelled']].map(([k, l]) => (
            <button key={k} className={`chip ${status === k ? 'on' : ''}`} onClick={() => { setStatus(k); setPage(1) }}>{l}</button>
          ))}
        </div>
        <div className="toolbar">
          <select className="input" style={{ width: 130 }} value={kind} onChange={(e) => setKind(e.target.value)} aria-label="Members or guests">
            <option value="">Everyone</option><option value="member">Members</option><option value="guest">Guests</option>
          </select>
          <form onSubmit={(e) => { e.preventDefault(); setSearch(q); setPage(1) }}><input className="input" style={{ width: 200 }} placeholder="Name or mobile" value={q} onChange={(e) => setQ(e.target.value)} /></form>
          <button className="btn small" disabled={!data?.length} onClick={() => data && downloadCsv(`${title.toLowerCase().replace(/\s+/g, '-')}-registrations.csv`, data.map(({ id: _i, ...r }) => r))}>Download CSV</button>
        </div>
      </div>
      <ErrorBox error={error ?? err} />
      <div className="table-wrap">
        <table>
          <thead><tr><th>Name</th><th>From</th><th>Status</th><th>Registered</th><th>Arrived</th><th /></tr></thead>
          <tbody>
            {data?.map((r) => (
              <tr key={r.id}>
                <td><b className="name-badge">{r.name}{r.verified && <VerifiedBadge />}</b>{r.kind === 'guest' && <span className="pill info" style={{ marginLeft: 6 }}>Guest</span>}<div className="mono muted" style={{ fontSize: 12 }}>{[r.member_id, r.mobile].filter(Boolean).join(' · ')}</div></td>
                <td>{r.place ?? '–'}</td>
                <td><Pill status={REG_STATUS[r.status]} label={REG_LABEL[r.status]} /></td>
                <td>{fmtDate(r.registered_at)}</td>
                <td>{r.checked_in_at ? `${fmtTime(r.checked_in_at)}${r.gate ? ` · ${r.gate}` : ''}` : '–'}</td>
                <td style={{ whiteSpace: 'nowrap' }}>
                  {r.status === 'pending' && <>
                    <button className="btn small good" onClick={() => act(() => api.post(`/admin/events/${id}/registrations/${r.id}/decide`, { decision: 'approve' }))}>Approve</button>{' '}
                    <button className="btn small danger" onClick={() => act(() => api.post(`/admin/events/${id}/registrations/${r.id}/decide`, { decision: 'reject', note: 'Not approved by the organisers.' }))}>Reject</button>
                  </>}
                  {r.status === 'registered' && !r.checked_in_at && <button className="btn small" onClick={() => act(() => api.post(`/events/${id}/registrations/${r.id}/check-in`, { gate: 'Admin desk' }))}>Mark arrived</button>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {data?.length === 0 && <Empty>No one here.</Empty>}
      </div>
      <div className="pager">
        <span className="muted">{fmtNum(Number(meta.total ?? 0))} people</span>
        <button className="btn small" disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button>
        <button className="btn small" disabled={page >= Number(meta.last_page ?? 1)} onClick={() => setPage(page + 1)}>Next</button>
      </div>
    </section>
  )
}

function PeopleTab({ id, onChange }: { id: number; onChange: () => void }) {
  const { data: staff, reload } = useFetch<Staff[]>(`/admin/events/${id}/staff`)
  const [g, setG] = useState({ name: '', mobile: '', organisation: '' })
  const [s, setS] = useState({ member_id: '', role: 'scanner' })
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState<unknown>(null)

  async function invite(e: FormEvent) {
    e.preventDefault(); setErr(null); setMsg('')
    try {
      const r = await api.post<{ sign_in_mobile: string }>(`/admin/events/${id}/guests`, g)
      setMsg(`${g.name} is invited. They sign in to the ABVP Connect app with ${r.data.sign_in_mobile} to see the invitation and pass.`)
      setG({ name: '', mobile: '', organisation: '' }); onChange()
    } catch (x) { setErr(x) }
  }
  async function addStaff(e: FormEvent) {
    e.preventDefault(); setErr(null); setMsg('')
    try { await api.post(`/admin/events/${id}/staff`, s); setS({ ...s, member_id: '' }); reload() } catch (x) { setErr(x) }
  }

  return (
    <div className="grid2">
      <form className="card" onSubmit={invite}>
        <h3>Invite a guest</h3>
        <p className="muted">Chief guests, speakers, faculty. A guest does not become a member; they see only this event and their pass. Guests take a seat even when the event is full.</p>
        {msg && <div className="notice">{msg}</div>}
        <ErrorBox error={err} />
        <div className="row2">
          <div className="field"><label htmlFor="gn">Name</label><input id="gn" className="input" required value={g.name} onChange={(e) => setG({ ...g, name: e.target.value })} /></div>
          <div className="field"><label htmlFor="gm">Mobile</label><input id="gm" className="input" required inputMode="tel" value={g.mobile} onChange={(e) => setG({ ...g, mobile: e.target.value })} /></div>
        </div>
        <div className="field"><label htmlFor="go">Organisation</label><input id="go" className="input" value={g.organisation} onChange={(e) => setG({ ...g, organisation: e.target.value })} placeholder="Osmania University" /></div>
        <div><button className="btn primary">Invite guest</button></div>
      </form>
      <section className="card">
        <h3>Gate and check-in team</h3>
        <p className="muted">These members get "Gate check-in" in their app for this event. Admins of the area can always scan.</p>
        <form className="toolbar" onSubmit={addStaff}>
          <input className="input mono" style={{ width: 200 }} required placeholder="Member ID" value={s.member_id} onChange={(e) => setS({ ...s, member_id: e.target.value.trim().toUpperCase() })} aria-label="Member ID" />
          <select className="input" style={{ width: 140 }} value={s.role} onChange={(e) => setS({ ...s, role: e.target.value })} aria-label="Role"><option value="scanner">Scanner</option><option value="coordinator">Coordinator</option></select>
          <button className="btn">Add</button>
        </form>
        {staff?.length === 0 && <Empty>No one on the team yet.</Empty>}
        <div className="history">{staff?.map((m) => (
          <div key={m.id}><span className="muted" style={{ textTransform: 'capitalize' }}>{m.role}</span>
            <span>{m.name} <span className="mono muted">{m.member_id}</span> <button className="btn small danger" onClick={async () => { await api.del(`/admin/events/${id}/staff/${m.id}`); reload() }}>Remove</button></span></div>
        ))}</div>
      </section>
    </div>
  )
}

/** Cover photo shown on the event card and event page in the app. */
function CoverBox({ id, url, onSaved }: { id: number; url: string | null; onSaved: () => void }) {
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  async function upload(file: File | undefined) {
    if (!file) return
    const form = new FormData()
    form.append('cover', file)
    setBusy(true)
    setErr(null)
    try {
      await api.post(`/admin/events/${id}/cover`, form)
      onSaved()
    } catch (e) {
      setErr(e)
    } finally {
      setBusy(false)
    }
  }
  return (
    <>
      <h3>Cover photo</h3>
      <ErrorBox error={err} />
      <div className="cover-box">
        {url ? <img src={url} alt="Event cover" /> : <div className="cover-ph">No cover yet</div>}
        <div>
          <label className="btn">
            {busy ? 'Uploading…' : url ? 'Replace photo' : 'Upload photo'}
            <input type="file" accept="image/jpeg,image/png,image/webp" hidden disabled={busy} onChange={(ev) => upload(ev.target.files?.[0])} />
          </label>
          <p className="muted" style={{ fontSize: 12.5, margin: '6px 0 0' }}>Wide photo, JPG/PNG/WebP up to 4 MB.<br />Shown on the event card in the app.</p>
        </div>
      </div>
    </>
  )
}
