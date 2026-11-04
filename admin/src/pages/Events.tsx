import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Empty, ErrorBox, Pill } from '../components/ui'
import { fmtNum, fmtTime } from '../format'
import { useFetch } from '../useFetch'
import EventForm from './EventForm'

interface Row {
  id: number; title: string; category_label: string; status: string; starts_at: string; venue: string; organised_by: string
  capacity: number | null; registered: number; pending: number; waitlisted: number; arrived: number
}

export const EVENT_STATUS: Record<string, { label: string; tone: string }> = {
  draft: { label: 'Draft', tone: 'mute' }, published: { label: 'Published', tone: 'info' },
  cancelled: { label: 'Cancelled', tone: 'bad' }, completed: { label: 'Finished', tone: 'ok' },
}

export default function Events() {
  const [when, setWhen] = useState<'upcoming' | 'draft' | 'past'>('upcoming')
  const [creating, setCreating] = useState(false)
  const nav = useNavigate()
  const { data, error } = useFetch<Row[]>(`/admin/events?when=${when}`)

  return (
    <main className="content">
      <div className="page-head">
        <h1>Events</h1>
        <div className="toolbar">
          <div className="chips">
            {(['upcoming', 'draft', 'past'] as const).map((w) => (
              <button key={w} className={`chip ${when === w ? 'on' : ''}`} onClick={() => setWhen(w)}>{w === 'draft' ? 'Drafts' : w[0].toUpperCase() + w.slice(1)}</button>
            ))}
          </div>
          <button className="btn primary" onClick={() => setCreating(!creating)}>{creating ? 'Close' : 'New event'}</button>
        </div>
      </div>
      <ErrorBox error={error} />
      {creating && <EventForm onSaved={(id) => nav(`/events/${id}`)} />}
      <section className="card">
        <div className="table-wrap">
          <table>
            <thead><tr><th>Event</th><th>When</th><th>Status</th><th>Registered</th><th>Waiting</th><th>Arrived</th></tr></thead>
            <tbody>
              {data?.map((e) => {
                const st = EVENT_STATUS[e.status]
                return (
                  <tr key={e.id} className="click" onClick={() => nav(`/events/${e.id}`)}>
                    <td><Link to={`/events/${e.id}`} style={{ textDecoration: 'none' }}><b>{e.title}</b></Link>
                      <div className="muted" style={{ fontSize: 12 }}>{e.category_label} · {e.venue} · {e.organised_by}</div></td>
                    <td style={{ whiteSpace: 'nowrap' }}>{fmtTime(e.starts_at)}</td>
                    <td><span className={`pill ${st?.tone}`}>{st?.label ?? e.status}</span></td>
                    <td>{fmtNum(e.registered)}{e.capacity ? <span className="muted"> / {fmtNum(e.capacity)}</span> : ''}</td>
                    <td>{e.pending ? <Pill status="submitted" label={`${e.pending} to approve`} /> : null} {e.waitlisted ? <span className="muted">{e.waitlisted} waitlist</span> : null}{!e.pending && !e.waitlisted ? '–' : ''}</td>
                    <td>{e.arrived ? fmtNum(e.arrived) : '–'}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          {data?.length === 0 && <Empty>{when === 'draft' ? 'No drafts.' : `No ${when} events in your area.`}</Empty>}
        </div>
      </section>
    </main>
  )
}
