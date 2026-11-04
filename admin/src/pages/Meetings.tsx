import { useState, type FormEvent } from 'react'
import { api } from '../api'
import AreaPicker, { VibhagPicker } from '../components/AreaPicker'
import { Empty, ErrorBox, Pill } from '../components/ui'
import { fmtTime } from '../format'
import { useFetch } from '../useFetch'

interface Row {
  id: number; title: string; starts_at: string; mode: string; provider: string | null; venue: string | null; status: string
  audience: string; organiser: string | null; invited: number; going: number; attended: number; open_action_items: number; has_minutes: boolean
}

const PROVIDER: Record<string, string> = { google_meet: 'Google Meet', zoom: 'Zoom', teams: 'Teams', jitsi: 'Jitsi', youtube: 'YouTube Live', link: 'Online link' }

function localInput(d: Date) {
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}

export default function Meetings() {
  const [when, setWhen] = useState<'upcoming' | 'past'>('upcoming')
  const { data, error, reload } = useFetch<Row[]>(`/admin/meetings?when=${when}`)
  const tomorrow7 = new Date(); tomorrow7.setDate(tomorrow7.getDate() + 1); tomorrow7.setHours(19, 0, 0, 0)
  const [f, setF] = useState({ title: '', agenda: '', mode: 'online', link: '', venue: '', start: localInput(tomorrow7), minutes: '60', org_unit_id: '', vibhag_id: '' })
  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState<unknown>(null)
  const [done, setDone] = useState('')

  async function schedule(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setFormError(null); setDone('')
    try {
      const start = new Date(f.start)
      const end = new Date(start.getTime() + Number(f.minutes) * 60000)
      const r = await api.post<{ rsvp_counts: { pending: number } }>('/meetings', {
        kind: 'meeting', title: f.title, agenda: f.agenda || null, mode: f.mode,
        link: f.mode === 'in_person' ? null : f.link, venue: f.mode === 'online' ? null : f.venue,
        starts_at: start.toISOString(), ends_at: end.toISOString(),
        org_unit_id: Number(f.org_unit_id), vibhag_id: f.vibhag_id ? Number(f.vibhag_id) : null,
      })
      setDone(`Scheduled. ${r.data.rsvp_counts.pending} people invited and notified.`)
      setF({ ...f, title: '', agenda: '', link: '' })
      reload()
    } catch (err) { setFormError(err) } finally { setBusy(false) }
  }

  return (
    <main className="content">
      <div className="page-head"><h1>Meetings</h1>
        <div className="chips">
          <button className={`chip ${when === 'upcoming' ? 'on' : ''}`} onClick={() => setWhen('upcoming')}>Upcoming</button>
          <button className={`chip ${when === 'past' ? 'on' : ''}`} onClick={() => setWhen('past')}>Past</button>
        </div>
      </div>
      <ErrorBox error={error} />
      <div className="grid2" style={{ gridTemplateColumns: 'minmax(0,1.6fr) minmax(0,1fr)' }}>
        <section className="card">
          <div className="table-wrap">
            <table>
              <thead><tr><th>Meeting</th><th>When</th><th>Where</th><th>Invited</th><th>{when === 'past' ? 'Joined' : 'Going'}</th><th>Follow-up</th></tr></thead>
              <tbody>
                {data?.map((m) => (
                  <tr key={m.id}>
                    <td><b>{m.title}</b><div className="muted" style={{ fontSize: 12 }}>{m.audience} · {m.organiser}</div>{m.status === 'cancelled' && <Pill status="rejected" label="Cancelled" />}</td>
                    <td style={{ whiteSpace: 'nowrap' }}>{fmtTime(m.starts_at)}</td>
                    <td>{m.mode === 'in_person' ? m.venue : PROVIDER[m.provider ?? 'link']}{m.mode === 'hybrid' ? ` + ${m.venue}` : ''}</td>
                    <td>{m.invited}</td>
                    <td>{when === 'past' ? `${m.attended} (${m.invited ? Math.round((m.attended / m.invited) * 100) : 0}%)` : m.going}</td>
                    <td>{when === 'past' ? (m.has_minutes ? `${m.open_action_items} open items` : <span className="pill warn">No minutes</span>) : '–'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {data?.length === 0 && <Empty>No {when} meetings in your area.</Empty>}
          </div>
        </section>
        <form className="card" onSubmit={schedule}>
          <h3>Schedule a meeting</h3>
          <p className="muted">Paste a Google Meet, Zoom, Teams or any https link. Everyone in the chosen area (and Vibhag) is invited and reminded a day before and 15 minutes before.</p>
          <ErrorBox error={formError} />
          {done && <div className="notice">{done}</div>}
          <div className="field"><label htmlFor="mt">Title</label><input id="mt" className="input" required value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} placeholder="SFD Zilla Baithak – November" /></div>
          <div className="row2">
            <div className="field"><label htmlFor="ma">Area</label><AreaPicker id="ma" value={f.org_unit_id} onChange={(v) => setF({ ...f, org_unit_id: v })} /></div>
            <div className="field"><label htmlFor="mv">Vibhag</label><VibhagPicker id="mv" value={f.vibhag_id} onChange={(v) => setF({ ...f, vibhag_id: v })} /></div>
          </div>
          <div className="chips" role="group" aria-label="Mode">
            {[['online', 'Online'], ['in_person', 'In person'], ['hybrid', 'Both']].map(([k, l]) => (
              <button type="button" key={k} className={`chip ${f.mode === k ? 'on' : ''}`} onClick={() => setF({ ...f, mode: k })}>{l}</button>
            ))}
          </div>
          {f.mode !== 'in_person' && <div className="field"><label htmlFor="ml">Meeting link</label><input id="ml" className="input mono" type="url" required placeholder="https://meet.google.com/abc-defg-hij" value={f.link} onChange={(e) => setF({ ...f, link: e.target.value })} /></div>}
          {f.mode !== 'online' && <div className="field"><label htmlFor="mvn">Venue</label><input id="mvn" className="input" required value={f.venue} onChange={(e) => setF({ ...f, venue: e.target.value })} /></div>}
          <div className="row2">
            <div className="field"><label htmlFor="ms">Starts</label><input id="ms" className="input" type="datetime-local" required value={f.start} onChange={(e) => setF({ ...f, start: e.target.value })} /></div>
            <div className="field"><label htmlFor="md">Length</label>
              <select id="md" className="input" value={f.minutes} onChange={(e) => setF({ ...f, minutes: e.target.value })}>
                {[['30', '30 minutes'], ['60', '1 hour'], ['90', '1½ hours'], ['120', '2 hours'], ['180', '3 hours']].map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select></div>
          </div>
          <div className="field"><label htmlFor="mag">Agenda</label><textarea id="mag" className="input" value={f.agenda} onChange={(e) => setF({ ...f, agenda: e.target.value })} placeholder={'1. Review last month\n2. Plan for December'} /></div>
          <button className="btn primary" disabled={busy}>{busy ? 'Scheduling…' : 'Schedule and invite'}</button>
        </form>
      </div>
    </main>
  )
}
