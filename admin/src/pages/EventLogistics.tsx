import { useState, type FormEvent } from 'react'
import { api, qs } from '../api'
import { downloadCsv, HBars } from '../components/charts'
import { Empty, ErrorBox } from '../components/ui'
import { fmtNum, fmtTime } from '../format'
import { useFetch } from '../useFetch'

interface Overview {
  participants: number
  stay: {
    beds: number; allocated: number; checked_in: number; waiting: number
    places: { id: number; name: string; address: string | null; for_gender: string; beds: number; used: number
      rooms: { id: number; name: string; capacity: number; people: { allocation_id: number; name: string; member_id: string | null; checked_in: boolean }[] }[] }[]
  }
  meals: { id: number; name: string; starts_at: string; ends_at: string; location: string | null; served: number; entitled: number }[]
  vehicles: { id: number; name: string; capacity: number; pickup_point: string | null; departs_at: string | null; driver_name: string | null; driver_phone: string | null; passengers: number; picked_up: number }[]
  travel: { submitted: number; need_pickup: number; pickup_unassigned: number; picked_up: number }
  locations: { name: string; purpose: string; expires_at: string; last_seen: string | null; map_url: string | null; accuracy_m: number | null }[]
}
interface Arrival {
  id: number; name: string; mobile: string; from: string | null; mode: string; reference: string | null; arriving_at: string | null
  arrival_point: string | null; needs_pickup: boolean; needs_stay: boolean; vehicle: string | null; pickup_status: string; room: string | null; notes: string | null
}

const SECTIONS = ['Stay', 'Food', 'Transport and arrivals', 'Shared locations'] as const
const GENDER: Record<string, string> = { any: 'Everyone', female: 'Women only', male: 'Men only' }
const MODE: Record<string, string> = { train: 'Train', bus: 'Bus', flight: 'Flight', own: 'Own vehicle', other: 'Other' }

function local(iso: string) {
  const d = new Date(iso); const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}

export default function LogisticsTab({ id, title, startsAt }: { id: number; title: string; startsAt: string }) {
  const [section, setSection] = useState<(typeof SECTIONS)[number]>('Stay')
  const { data: o, reload, error } = useFetch<Overview>(`/admin/events/${id}/logistics`)
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState<unknown>(null)
  const act = async (fn: () => Promise<string | void>) => {
    setErr(null); setMsg('')
    try { const m = await fn(); if (m) setMsg(m); reload() } catch (x) { setErr(x) }
  }

  if (error) return <ErrorBox error={error} />
  if (!o) return <p className="muted">Loading…</p>

  return (
    <>
      <div className="kpis">
        <div className={`kpi ${o.stay.waiting ? 'alert' : ''}`}><span>Beds</span><b>{fmtNum(o.stay.allocated)}<span style={{ fontSize: 16, color: 'var(--muted)' }}> / {fmtNum(o.stay.beds)}</span></b><small>{o.stay.waiting ? `${o.stay.waiting} asked for a stay and have no room` : 'Everyone who asked has a room'}</small></div>
        <div className={`kpi ${o.travel.pickup_unassigned ? 'alert' : ''}`}><span>Pickups</span><b>{fmtNum(o.travel.picked_up)}<span style={{ fontSize: 16, color: 'var(--muted)' }}> / {fmtNum(o.travel.need_pickup)}</span></b><small>{o.travel.pickup_unassigned ? `${o.travel.pickup_unassigned} without a vehicle` : 'All pickups have a vehicle'}</small></div>
        <div className="kpi"><span>Travel details given</span><b>{fmtNum(o.travel.submitted)}</b><small>of {fmtNum(o.participants)} people</small></div>
        <div className="kpi"><span>Sharing location now</span><b>{fmtNum(o.locations.length)}</b><small>Only with their consent, for a set time</small></div>
      </div>
      <div className="chips">{SECTIONS.map((s) => <button key={s} className={`chip ${section === s ? 'on' : ''}`} onClick={() => setSection(s)}>{s}</button>)}</div>
      {msg && <div className="notice">{msg}</div>}
      <ErrorBox error={err} />
      {section === 'Stay' && <StaySection id={id} o={o} act={act} />}
      {section === 'Food' && <FoodSection id={id} o={o} act={act} startsAt={startsAt} />}
      {section === 'Transport and arrivals' && <TransportSection id={id} title={title} o={o} act={act} />}
      {section === 'Shared locations' && (
        <section className="card">
          <h3>People sharing their location with coordinators</h3>
          <p className="muted">Members turn this on themselves, choose who sees it and for how long, and can stop it any time. Points are deleted a day after sharing ends.</p>
          {o.locations.length === 0 && <Empty>No one is sharing right now.</Empty>}
          <div className="table-wrap"><table>
            <thead><tr><th>Person</th><th>Why</th><th>Last seen</th><th>Sharing until</th><th /></tr></thead>
            <tbody>{o.locations.map((l, i) => (
              <tr key={i}><td><b>{l.name}</b></td><td>{l.purpose}</td><td>{l.last_seen ? `${fmtTime(l.last_seen)}${l.accuracy_m ? ` · ±${l.accuracy_m} m` : ''}` : 'No position yet'}</td><td>{fmtTime(l.expires_at)}</td>
                <td>{l.map_url && <a className="btn small" href={l.map_url} target="_blank" rel="noreferrer">Open in Google Maps</a>}</td></tr>
            ))}</tbody>
          </table></div>
        </section>
      )}
    </>
  )
}

type Act = (fn: () => Promise<string | void>) => Promise<void>

function StaySection({ id, o, act }: { id: number; o: Overview; act: Act }) {
  const [f, setF] = useState({ name: '', address: '', for_gender: 'any', room_prefix: 'Room', room_count: '10', beds_per_room: '4' })
  const [assign, setAssign] = useState<Record<number, string>>({})

  const add = (e: FormEvent) => { e.preventDefault(); act(async () => {
    const r = await api.post<{ beds: number }>(`/admin/events/${id}/stays`, { ...f, room_count: Number(f.room_count), beds_per_room: Number(f.beds_per_room) })
    setF({ ...f, name: '', address: '' }); return `Added ${r.data.beds} beds.`
  }) }

  return (
    <div className="grid2">
      <section className="card">
        <div className="page-head"><h3>Places and rooms</h3>
          <button className="btn primary small" onClick={() => act(async () => {
            const r = await api.post<{ allocated: number; left_without: string[] }>(`/admin/events/${id}/stays/auto-allocate`)
            return `Gave rooms to ${r.data.allocated} people.${r.data.left_without.length ? ` No bed left for: ${r.data.left_without.join(', ')}.` : ''}`
          })}>Allocate rooms automatically</button></div>
        <p className="muted">Automatic allocation fills rooms for everyone who asked for a stay, keeps people from the same unit together, and follows each place's women/men rule. Everyone is notified of their room.</p>
        {o.stay.places.length === 0 && <Empty>No places yet. Add a hostel or hall on the right.</Empty>}
        {o.stay.places.map((p) => (
          <div key={p.id} style={{ display: 'grid', gap: 8 }}>
            <div className="page-head"><b>{p.name} <span className="muted" style={{ fontWeight: 500 }}>· {GENDER[p.for_gender]} · {p.used}/{p.beds} beds</span></b>
              <button className="btn small danger" onClick={() => act(async () => { await api.del(`/admin/events/${id}/stays/${p.id}`) })}>Remove place</button></div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(190px, 1fr))', gap: 8 }}>
              {p.rooms.map((r) => (
                <div key={r.id} className="post" style={{ gap: 6, borderColor: r.people.length >= r.capacity ? 'var(--line)' : 'var(--saffron)' }}>
                  <div className="page-head"><b>{r.name}</b><span className="muted" style={{ fontSize: 12 }}>{r.people.length}/{r.capacity}</span></div>
                  {r.people.map((m) => (
                    <div key={m.allocation_id} style={{ display: 'flex', gap: 6, alignItems: 'center', fontSize: 13 }}>
                      <span style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={m.member_id ?? ''}>{m.name}</span>
                      {m.checked_in ? <span className="pill ok">In</span> : <button className="btn small" onClick={() => act(async () => { await api.post(`/admin/events/${id}/allocations/${m.allocation_id}`, { action: 'check_in' }) })}>Check in</button>}
                      <button className="btn small" title="Remove from room" aria-label={`Remove ${m.name}`} onClick={() => act(async () => { await api.post(`/admin/events/${id}/allocations/${m.allocation_id}`, { action: 'remove' }) })}>×</button>
                    </div>
                  ))}
                  {r.people.length < r.capacity && (
                    <form style={{ display: 'flex', gap: 4 }} onSubmit={(e) => { e.preventDefault(); act(async () => { await api.post(`/admin/events/${id}/rooms/${r.id}/allocate`, { member_id: assign[r.id] }); setAssign({ ...assign, [r.id]: '' }) }) }}>
                      <input className="input mono" style={{ padding: '4px 8px', fontSize: 12 }} placeholder="Member ID" value={assign[r.id] ?? ''} onChange={(e) => setAssign({ ...assign, [r.id]: e.target.value })} aria-label={`Add to ${r.name}`} />
                      <button className="btn small">Add</button>
                    </form>
                  )}
                </div>
              ))}
            </div>
          </div>
        ))}
      </section>
      <form className="card" onSubmit={add}>
        <h3>Add a place to stay</h3>
        <div className="field"><label htmlFor="sn">Name</label><input id="sn" className="input" required value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} placeholder="Girls Hostel 3, Kakatiya University" /></div>
        <div className="field"><label htmlFor="sa">Address</label><input id="sa" className="input" value={f.address} onChange={(e) => setF({ ...f, address: e.target.value })} /></div>
        <div className="field"><label htmlFor="sg">Who stays here</label><select id="sg" className="input" value={f.for_gender} onChange={(e) => setF({ ...f, for_gender: e.target.value })}><option value="any">Everyone</option><option value="female">Women only</option><option value="male">Men only</option></select></div>
        <div className="row2">
          <div className="field"><label htmlFor="sp">Room name</label><input id="sp" className="input" required value={f.room_prefix} onChange={(e) => setF({ ...f, room_prefix: e.target.value })} /></div>
          <div className="field"><label htmlFor="sc">How many rooms</label><input id="sc" type="number" min={1} className="input" required value={f.room_count} onChange={(e) => setF({ ...f, room_count: e.target.value })} /></div>
        </div>
        <div className="field"><label htmlFor="sb">Beds per room</label><input id="sb" type="number" min={1} className="input" required value={f.beds_per_room} onChange={(e) => setF({ ...f, beds_per_room: e.target.value })} /></div>
        <div><button className="btn primary">Add place</button></div>
      </form>
    </div>
  )
}

function FoodSection({ id, o, act, startsAt }: { id: number; o: Overview; act: Act; startsAt: string }) {
  const [f, setF] = useState({ name: '', location: '', starts_at: local(startsAt), hours: '2' })
  const add = (e: FormEvent) => { e.preventDefault(); act(async () => {
    const s = new Date(f.starts_at)
    await api.post(`/admin/events/${id}/meal-sessions`, { name: f.name, location: f.location || null, starts_at: s.toISOString(), ends_at: new Date(s.getTime() + Number(f.hours) * 3600000).toISOString() })
    setF({ ...f, name: '' }); return 'Meal added. Food counter volunteers pick it in Gate check-in.'
  }) }
  return (
    <div className="grid2">
      <section className="card">
        <h3>Meals served</h3>
        <p className="muted">Volunteers at the counter scan the same event pass. Each person gets one plate per meal; a second scan shows when and where they were served.</p>
        {o.meals.length === 0 ? <Empty>No meals yet.</Empty> : (
          <HBars rows={o.meals.map((m) => ({ label: m.name, value: m.served, hint: `${fmtTime(m.starts_at)} · ${m.location ?? ''} · ${m.served} of ${m.entitled}` }))} format={(n) => fmtNum(n)} unit={` / ${fmtNum(o.participants)}`} />
        )}
        <div className="history">{o.meals.map((m) => (
          <div key={m.id}><span className="muted">{fmtTime(m.starts_at)}</span><span>{m.name}{m.location ? ` · ${m.location}` : ''} {m.served === 0 && <button className="btn small danger" onClick={() => act(async () => { await api.del(`/admin/events/${id}/meal-sessions/${m.id}`) })}>Remove</button>}</span></div>
        ))}</div>
      </section>
      <form className="card" onSubmit={add}>
        <h3>Add a meal</h3>
        <div className="field"><label htmlFor="mn">Name</label><input id="mn" className="input" required value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} placeholder="Day 1 Lunch" /></div>
        <div className="field"><label htmlFor="ml2">Where</label><input id="ml2" className="input" value={f.location} onChange={(e) => setF({ ...f, location: e.target.value })} placeholder="Dining hall B" /></div>
        <div className="row2">
          <div className="field"><label htmlFor="ms2">Starts</label><input id="ms2" type="datetime-local" className="input" required value={f.starts_at} onChange={(e) => setF({ ...f, starts_at: e.target.value })} /></div>
          <div className="field"><label htmlFor="mh">Hours</label><select id="mh" className="input" value={f.hours} onChange={(e) => setF({ ...f, hours: e.target.value })}>{['1', '2', '3'].map((h) => <option key={h} value={h}>{h}</option>)}</select></div>
        </div>
        <div><button className="btn primary">Add meal</button></div>
      </form>
    </div>
  )
}

function TransportSection({ id, title, o, act }: { id: number; title: string; o: Overview; act: Act }) {
  const [filter, setFilter] = useState('need_pickup')
  const { data: rows, reload } = useFetch<Arrival[]>(`/admin/events/${id}/arrivals${qs({ filter })}`)
  const [picked, setPicked] = useState<number[]>([])
  const [vehicle, setVehicle] = useState('')
  const [v, setV] = useState({ name: '', capacity: '40', pickup_point: '', departs_at: '', driver_name: '', driver_phone: '' })

  const run = (fn: () => Promise<string | void>) => act(async () => { const m = await fn(); reload(); return m })

  return (
    <div className="grid2" style={{ gridTemplateColumns: 'minmax(0,1.7fr) minmax(0,1fr)' }}>
      <section className="card">
        <div className="page-head"><h3>Arrivals</h3>
          <button className="btn small" disabled={!rows?.length} onClick={() => rows && downloadCsv(`${title.toLowerCase().replace(/\s+/g, '-')}-arrivals.csv`, rows.map(({ id: _i, ...r }) => r))}>Download CSV</button></div>
        <div className="chips">
          {[['need_pickup', 'Need pickup'], ['unassigned', 'No vehicle yet'], ['picked_up', 'Picked up'], ['need_stay', 'Need stay'], ['', 'Everyone']].map(([k, l]) => (
            <button key={k} className={`chip ${filter === k ? 'on' : ''}`} onClick={() => { setFilter(k); setPicked([]) }}>{l}</button>
          ))}
        </div>
        {picked.length > 0 && (
          <div className="toolbar">
            <span><b>{picked.length}</b> selected</span>
            <select className="input" style={{ width: 200 }} value={vehicle} onChange={(e) => setVehicle(e.target.value)} aria-label="Vehicle"><option value="">Choose vehicle…</option>{o.vehicles.map((x) => <option key={x.id} value={x.id}>{x.name} ({x.capacity - x.passengers} seats left)</option>)}</select>
            <button className="btn primary small" disabled={!vehicle} onClick={() => run(async () => {
              const r = await api.post<{ assigned: number }>(`/admin/events/${id}/arrivals/assign`, { vehicle_id: Number(vehicle), travel_ids: picked })
              setPicked([]); return `${r.data.assigned} people assigned. They have been told where to wait.`
            })}>Assign to vehicle</button>
          </div>
        )}
        <div className="table-wrap"><table>
          <thead><tr><th /><th>Person</th><th>Arriving</th><th>How</th><th>Pickup</th><th>Room</th></tr></thead>
          <tbody>{rows?.map((r) => (
            <tr key={r.id}>
              <td>{r.needs_pickup && r.pickup_status !== 'picked_up' && <input type="checkbox" aria-label={`Select ${r.name}`} checked={picked.includes(r.id)} onChange={(e) => setPicked(e.target.checked ? [...picked, r.id] : picked.filter((x) => x !== r.id))} />}</td>
              <td><b>{r.name}</b><div className="muted" style={{ fontSize: 12 }}>{r.from} · <span className="mono">{r.mobile}</span></div></td>
              <td style={{ whiteSpace: 'nowrap' }}>{r.arriving_at ? fmtTime(r.arriving_at) : '–'}<div className="muted" style={{ fontSize: 12 }}>{r.arrival_point}</div></td>
              <td>{MODE[r.mode]}{r.reference ? <div className="muted" style={{ fontSize: 12 }}>{r.reference}</div> : null}</td>
              <td>{!r.needs_pickup ? <span className="muted">Not needed</span> : r.pickup_status === 'picked_up' ? <span className="pill ok">Picked up</span>
                : r.vehicle ? <span style={{ whiteSpace: 'nowrap' }}>{r.vehicle} <button className="btn small" onClick={() => run(async () => { await api.post(`/admin/events/${id}/arrivals/${r.id}/picked-up`) })}>Picked up</button></span>
                : <span className="pill warn">No vehicle</span>}</td>
              <td>{r.room ?? (r.needs_stay ? <span className="pill warn">Needs room</span> : '–')}</td>
            </tr>
          ))}</tbody>
        </table>{rows?.length === 0 && <Empty>No one here.</Empty>}</div>
      </section>
      <div style={{ display: 'grid', gap: 12, alignContent: 'start' }}>
        <section className="card">
          <h3>Vehicles</h3>
          {o.vehicles.length === 0 && <Empty>No vehicles yet.</Empty>}
          <div className="history">{o.vehicles.map((x) => (
            <div key={x.id}><span><b>{x.name}</b></span><span>{x.passengers}/{x.capacity} · {x.picked_up} picked up{x.pickup_point ? ` · ${x.pickup_point}` : ''}{x.departs_at ? ` · ${fmtTime(x.departs_at)}` : ''}{x.driver_name ? ` · ${x.driver_name} ${x.driver_phone ?? ''}` : ''}</span></div>
          ))}</div>
        </section>
        <form className="card" onSubmit={(e) => { e.preventDefault(); act(async () => {
          await api.post(`/admin/events/${id}/vehicles`, { ...v, capacity: Number(v.capacity), departs_at: v.departs_at ? new Date(v.departs_at).toISOString() : null })
          setV({ ...v, name: '' }); return 'Vehicle added.'
        }) }}>
          <h3>Add a vehicle</h3>
          <div className="row2">
            <div className="field"><label htmlFor="vn">Name</label><input id="vn" className="input" required value={v.name} onChange={(e) => setV({ ...v, name: e.target.value })} placeholder="Bus 1" /></div>
            <div className="field"><label htmlFor="vc">Seats</label><input id="vc" type="number" min={1} className="input" required value={v.capacity} onChange={(e) => setV({ ...v, capacity: e.target.value })} /></div>
          </div>
          <div className="field"><label htmlFor="vp">Pickup point</label><input id="vp" className="input" value={v.pickup_point} onChange={(e) => setV({ ...v, pickup_point: e.target.value })} placeholder="Warangal station, exit 2" /></div>
          <div className="field"><label htmlFor="vd">Leaves at</label><input id="vd" type="datetime-local" className="input" value={v.departs_at} onChange={(e) => setV({ ...v, departs_at: e.target.value })} /></div>
          <div className="row2">
            <div className="field"><label htmlFor="vdn">Driver</label><input id="vdn" className="input" value={v.driver_name} onChange={(e) => setV({ ...v, driver_name: e.target.value })} /></div>
            <div className="field"><label htmlFor="vdp">Driver phone</label><input id="vdp" className="input" value={v.driver_phone} onChange={(e) => setV({ ...v, driver_phone: e.target.value })} /></div>
          </div>
          <div><button className="btn primary">Add vehicle</button></div>
        </form>
      </div>
    </div>
  )
}
