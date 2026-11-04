import { useState, type FormEvent } from 'react'
import { api } from '../api'
import AreaPicker, { VibhagPicker } from '../components/AreaPicker'
import { ErrorBox } from '../components/ui'
import { useFetch } from '../useFetch'

export interface EventDetail {
  id: number; title: string; description: string | null; category: string; category_label: string; instructions: string | null
  venue: string; venue_map_url: string | null; starts_at: string; ends_at: string; status: string
  org_unit: { id: number; name: string }; organiser: string | null
  registration_opens_at: string | null; registration_closes_at: string | null; capacity: number | null
  requires_approval: boolean; waitlist_enabled: boolean; contact_name: string | null; contact_phone: string | null
  rules: { org_unit_id: number | null; vibhag_id: number | null; label: string }[]
  counts: { members: number; guests: number; pending: number; waitlisted: number; cancelled: number; arrived: number }
}

const CATEGORIES: [string, string][] = [
  ['conference', 'Conference / adhiveshan'], ['training', 'Training camp / abhyas varg'], ['programme', 'Programme'],
  ['campaign', 'Campaign'], ['cultural', 'Cultural'], ['sports', 'Sports'], ['seminar', 'Seminar'],
]

function local(iso?: string | null) {
  if (!iso) return ''
  const d = new Date(iso)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}
const iso = (v: string) => (v ? new Date(v).toISOString() : null)

export default function EventForm({ event, onSaved }: { event?: EventDetail; onSaved: (id: number) => void }) {
  const { data: allUnits } = useFetch<{ id: number; name: string }[]>('/org/units?type=district')
  const [f, setF] = useState({
    title: event?.title ?? '', category: event?.category ?? 'programme', description: event?.description ?? '',
    venue: event?.venue ?? '', venue_map_url: event?.venue_map_url ?? '',
    starts_at: local(event?.starts_at), ends_at: local(event?.ends_at),
    registration_closes_at: local(event?.registration_closes_at), capacity: event?.capacity ? String(event.capacity) : '',
    requires_approval: event?.requires_approval ?? false, waitlist_enabled: event?.waitlist_enabled ?? true,
    instructions: event?.instructions ?? '', contact_name: event?.contact_name ?? '', contact_phone: event?.contact_phone ?? '',
    org_unit_id: event ? String(event.org_unit.id) : '',
    rule_unit: event?.rules[0]?.org_unit_id ? String(event.rules[0].org_unit_id) : '',
    rule_vibhag: event?.rules[0]?.vibhag_id ? String(event.rules[0].vibhag_id) : '',
  })
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF({ ...f, [k]: e.target.value })

  async function save(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setErr(null)
    const body = {
      title: f.title, category: f.category, description: f.description || null, venue: f.venue,
      venue_map_url: f.venue_map_url || null, starts_at: iso(f.starts_at), ends_at: iso(f.ends_at),
      registration_closes_at: iso(f.registration_closes_at), capacity: f.capacity ? Number(f.capacity) : null,
      requires_approval: f.requires_approval, waitlist_enabled: f.waitlist_enabled,
      instructions: f.instructions || null, contact_name: f.contact_name || null, contact_phone: f.contact_phone || null,
      rules: f.rule_unit || f.rule_vibhag ? [{ org_unit_id: f.rule_unit ? Number(f.rule_unit) : null, vibhag_id: f.rule_vibhag ? Number(f.rule_vibhag) : null }] : [],
      ...(event ? {} : { org_unit_id: Number(f.org_unit_id) }),
    }
    try {
      const r = event ? await api.patch<EventDetail>(`/admin/events/${event.id}`, body) : await api.post<EventDetail>('/admin/events', body)
      onSaved(r.data.id)
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  return (
    <form className="card" onSubmit={save} style={{ gap: 14 }}>
      <h3>{event ? 'Edit event' : 'New event'}</h3>
      <p className="muted">{event ? 'Changing the time or venue notifies everyone registered.' : 'Saved as a draft. Members see it only after you publish.'}</p>
      <ErrorBox error={err} />
      <div className="row2">
        <div className="field"><label htmlFor="et">Title</label><input id="et" className="input" required value={f.title} onChange={set('title')} placeholder="Telangana Pranth Adhiveshan 2026" /></div>
        <div className="field"><label htmlFor="ec">Type</label><select id="ec" className="input" value={f.category} onChange={set('category')}>{CATEGORIES.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select></div>
      </div>
      <div className="row2">
        <div className="field"><label htmlFor="es">Starts</label><input id="es" type="datetime-local" className="input" required value={f.starts_at} onChange={set('starts_at')} /></div>
        <div className="field"><label htmlFor="ee">Ends</label><input id="ee" type="datetime-local" className="input" required value={f.ends_at} onChange={set('ends_at')} /></div>
      </div>
      <div className="row2">
        <div className="field"><label htmlFor="ev">Venue</label><input id="ev" className="input" required value={f.venue} onChange={set('venue')} /></div>
        <div className="field"><label htmlFor="em">Map link (optional)</label><input id="em" type="url" className="input" value={f.venue_map_url} onChange={set('venue_map_url')} placeholder="https://maps.google.com/…" /></div>
      </div>
      {!event && <div className="field"><label htmlFor="eo">Organised by</label><AreaPicker id="eo" value={f.org_unit_id} onChange={(v) => setF({ ...f, org_unit_id: v })} /></div>}
      <div className="field"><label htmlFor="ed">About the event</label><textarea id="ed" className="input" value={f.description} onChange={set('description')} /></div>

      <h3 style={{ marginTop: 6 }}>Who can register</h3>
      <div className="row2">
        <div className="field"><label htmlFor="ru">Area</label>
          <select id="ru" className="input" value={f.rule_unit} onChange={set('rule_unit')}>
            <option value="">All areas</option>
            {allUnits?.map((u) => <option key={u.id} value={u.id}>{u.name} district</option>)}
          </select></div>
        <div className="field"><label htmlFor="rv">Vibhag</label><VibhagPicker id="rv" value={f.rule_vibhag} onChange={(v) => setF({ ...f, rule_vibhag: v })} /></div>
      </div>
      <div className="row2">
        <div className="field"><label htmlFor="ecap">Seats (leave empty for no limit)</label><input id="ecap" type="number" min={1} className="input" value={f.capacity} onChange={set('capacity')} /></div>
        <div className="field"><label htmlFor="ercl">Registration closes</label><input id="ercl" type="datetime-local" className="input" value={f.registration_closes_at} onChange={set('registration_closes_at')} /></div>
      </div>
      <label style={{ display: 'flex', gap: 8, alignItems: 'center' }}><input type="checkbox" checked={f.requires_approval} onChange={(e) => setF({ ...f, requires_approval: e.target.checked })} /> Each registration needs approval</label>
      <label style={{ display: 'flex', gap: 8, alignItems: 'center' }}><input type="checkbox" checked={f.waitlist_enabled} onChange={(e) => setF({ ...f, waitlist_enabled: e.target.checked })} /> Keep a waitlist when seats are full</label>

      <h3 style={{ marginTop: 6 }}>For people who are coming</h3>
      <div className="field"><label htmlFor="ei">Instructions</label><textarea id="ei" className="input" value={f.instructions} onChange={set('instructions')} placeholder="Report at Gate 3 by 8:00 AM. Carry your college ID." /></div>
      <div className="row2">
        <div className="field"><label htmlFor="ecn">Contact person</label><input id="ecn" className="input" value={f.contact_name} onChange={set('contact_name')} /></div>
        <div className="field"><label htmlFor="ecp">Contact phone</label><input id="ecp" className="input" value={f.contact_phone} onChange={set('contact_phone')} /></div>
      </div>
      <div><button className="btn primary" disabled={busy}>{busy ? 'Saving…' : event ? 'Save changes' : 'Save draft'}</button></div>
    </form>
  )
}
