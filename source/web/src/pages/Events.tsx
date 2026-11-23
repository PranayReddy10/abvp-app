import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth'
import PassCard from '../components/PassCard'
import { ErrorBox, Icon, Orbs, Reveal, Skeleton, Tilt, fmtDate, fmtDateTime, fmtDay } from '../components/ui'
import type { Pass } from '../types'
import { useFetch } from '../useFetch'

interface EventCard {
  id: number; title: string; category: string; category_label: string; starts_at: string; ends_at: string; venue: string
  organised_by: string | null; cover_url: string | null; registration_open: boolean
  guide_enabled?: boolean; delegate_registration_open?: boolean
  eligible?: boolean; eligibility?: string; seats_left?: number | null; status?: string
  my_registration?: { status: string; kind: string; note: string | null } | null
}
interface EventDetail extends EventCard {
  description: string | null; instructions?: string | null; requires_approval?: boolean; waitlist_position?: number | null
  contact?: { name: string; phone: string | null } | null; venue_map_url?: string | null
}

const CAT_COLOR: Record<string, [string, string]> = {
  conference: ['#F08A3C', '#E3620C'], training: ['#3E8BF0', '#2563C9'], programme: ['#25B48C', '#14866A'], campaign: ['#F06AAE', '#B72F72'],
  cultural: ['#A47CF3', '#6A45C9'], sports: ['#F5B53D', '#C98A0C'], seminar: ['#4CC3D9', '#1E8FA6'],
}
const catGrad = (c: string) => { const [a, b] = CAT_COLOR[c] ?? CAT_COLOR.programme; return `linear-gradient(135deg, ${a}, ${b})` }
const REG_LABEL: Record<string, string> = { registered: 'You are registered', pending: 'Waiting for approval', waitlisted: 'On the waitlist', cancelled: 'Cancelled', rejected: 'Not approved' }

function Cover({ e, h = 170 }: { e: EventCard; h?: number }) {
  return (
    <div className="ev-cover" style={{ height: h, background: e.cover_url ? `center/cover no-repeat url("${e.cover_url}")` : catGrad(e.category) }}>
      {!e.cover_url && <Orbs seed={e.id % 3} />}
      <span className="ev-date"><b>{fmtDay(e.starts_at).split(' ')[0]}</b>{fmtDay(e.starts_at).split(' ')[1]}</span>
    </div>
  )
}

/** Upcoming events: public list for everyone; signed-in people also see whether they can register. */
export function Events() {
  const { me } = useAuth()
  const pub = useFetch<EventCard[]>(me ? null : '/public/events')
  const mine = useFetch<EventCard[]>(me ? '/events' : null)
  const list = me ? mine : pub
  const [cat, setCat] = useState<string>('all')
  const cats = Array.from(new Set((list.data ?? []).map((e) => e.category)))
  const shown = (list.data ?? []).filter((e) => cat === 'all' || e.category === cat)

  return (
    <div className="page wrap">
      <div className="banner" style={{ background: 'linear-gradient(135deg, #25B48C, #14866A 45%, #14161F)' }}>
        <Orbs />
        <div style={{ position: 'relative', zIndex: 2 }}>
          <span style={{ opacity: .85, fontWeight: 700 }}>Events</span>
          <h1>What’s coming up</h1>
          <p style={{ opacity: .9, maxWidth: 560 }}>Conferences, abhyas vargs, campaigns and programmes from units across the country.</p>
        </div>
      </div>
      <ErrorBox error={list.error} />
      {cats.length > 1 && (
        <div className="chips" style={{ marginBottom: 20 }}>
          <button className={`chip-btn ${cat === 'all' ? 'on' : ''}`} onClick={() => setCat('all')}>All</button>
          {cats.map((c) => <button key={c} className={`chip-btn ${cat === c ? 'on' : ''}`} onClick={() => setCat(c)}>{list.data?.find((e) => e.category === c)?.category_label.split(' /')[0]}</button>)}
        </div>
      )}
      {list.loading && !list.data ? <Skeleton h={300} n={3} /> : shown.length === 0 ? (
        <Reveal><div className="card" style={{ display: 'grid', gap: 8 }}><b style={{ fontSize: 20 }}>No upcoming events yet</b><p className="muted">When your unit publishes an event it shows here.</p></div></Reveal>
      ) : (
        <div className="ev-grid">
          <AnimatePresence>
            {shown.map((e, i) => (
              <motion.div key={e.id} layout initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ delay: Math.min(i, 8) * .05 }}>
                <Tilt className="card ev-card">
                  <Link to={`/events/${e.id}`} style={{ color: 'inherit', textDecoration: 'none', display: 'grid', gap: 12 }}>
                    <Cover e={e} />
                    <div style={{ display: 'grid', gap: 6, padding: '0 4px 4px' }}>
                      <span className="eyebrow" style={{ fontSize: 12 }}>{e.category_label}</span>
                      <h3 style={{ fontSize: 20, fontWeight: 800, lineHeight: 1.25 }}>{e.title}</h3>
                      <span className="muted" style={{ display: 'flex', gap: 6, fontSize: 14.5 }}><Icon name="pin" size={16} /> {e.venue}</span>
                      <span className="muted" style={{ display: 'flex', gap: 6, fontSize: 14.5 }}><Icon name="clock" size={16} /> {fmtDate(e.starts_at)}{fmtDate(e.ends_at) !== fmtDate(e.starts_at) ? ` – ${fmtDate(e.ends_at)}` : ''}</span>
                      {e.my_registration && e.my_registration.status !== 'cancelled' && <span className="status-pill ok" style={{ justifySelf: 'start', marginTop: 4 }}>{REG_LABEL[e.my_registration.status] ?? e.my_registration.status}</span>}
                    </div>
                  </Link>
                </Tilt>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      )}
    </div>
  )
}

export function EventPage() {
  const { id } = useParams()
  const { me } = useAuth()
  const ev = useFetch<EventDetail>(me ? `/events/${id}` : `/public/events/${id}`)
  const passes = useFetch<Pass[]>(me ? '/me/passes' : null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const e = ev.data
  const pass = passes.data?.find((p) => p.event.id === Number(id) && p.status === 'registered')

  async function act(path: string) {
    setBusy(true); setErr(null)
    try { await api.post(path); ev.reload(); passes.reload() } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  if (!e) return <div className="page wrap"><ErrorBox error={ev.error} />{!ev.error && <Skeleton h={320} n={2} />}</div>
  const reg = e.my_registration && !['cancelled', 'rejected'].includes(e.my_registration.status) ? e.my_registration : null

  return (
    <div className="page wrap" style={{ maxWidth: 980 }}>
      <Link to="/events" className="btn ghost sm" style={{ marginBottom: 14 }}><Icon name="back" size={16} /> All events</Link>
      <motion.div initial={{ opacity: 0, scale: .98 }} animate={{ opacity: 1, scale: 1 }}><Cover e={e} h={260} /></motion.div>
      <div className="ev-detail">
        <div style={{ display: 'grid', gap: 14, alignContent: 'start' }}>
          <span className="eyebrow">{e.category_label}</span>
          <h1 style={{ fontSize: 'clamp(30px, 4vw, 44px)', fontWeight: 800, lineHeight: 1.1 }}>{e.title}</h1>
          <p style={{ display: 'flex', gap: 8 }}><Icon name="pin" /> {e.venue}</p>
          <p style={{ display: 'flex', gap: 8 }}><Icon name="clock" /> {fmtDateTime(e.starts_at)} – {fmtDateTime(e.ends_at)}</p>
          {e.organised_by && <p className="muted">Organised by {e.organised_by}</p>}
          {e.description && <p style={{ whiteSpace: 'pre-line', fontSize: 16.5, lineHeight: 1.7 }}>{e.description}</p>}
          {e.instructions && <div className="hint"><b>For you:</b> {e.instructions}</div>}
          {e.contact && <p>Contact: <b>{e.contact.name}</b>{e.contact.phone && <> · <a href={`tel:${e.contact.phone}`}>{e.contact.phone}</a></>}</p>}
          {e.venue_map_url && <a className="btn sm" href={e.venue_map_url} target="_blank" rel="noreferrer" style={{ justifySelf: 'start' }}><Icon name="pin" size={16} /> Open map</a>}
        </div>

        <aside className="card" style={{ display: 'grid', gap: 14, alignContent: 'start', position: 'sticky', top: 96 }}>
          <ErrorBox error={err} />
          {e.guide_enabled !== undefined && (e.guide_enabled || e.delegate_registration_open) && (
            <div style={{ display: 'grid', gap: 10 }}>
              {e.delegate_registration_open && <Link to={me ? `/conference/${e.id}/register` : `/signup?next=/conference/${e.id}/register`} className="btn primary block">Register as delegate</Link>}
              {e.guide_enabled && <Link to={`/guide/${e.id}`} className="btn block">Conference guide</Link>}
            </div>
          )}
          {!me ? (
            <>
              <b style={{ fontSize: 18 }}>Want to attend?</b>
              <p className="muted">Sign in to see whether you can register and to get your pass.</p>
              <Link to={`/login?next=/events/${e.id}`} className="btn dark block">Sign in</Link>
              <Link to={`/signup?next=/events/${e.id}`} className="btn block">Create an account</Link>
            </>
          ) : reg ? (
            <>
              <span className={`status-pill ${reg.status === 'registered' ? 'ok' : 'info'}`} style={{ justifySelf: 'start' }}>{REG_LABEL[reg.status] ?? reg.status}</span>
              {e.waitlist_position ? <p className="muted">You are number {e.waitlist_position} on the waitlist.</p> : null}
              {pass && <PassCard title={e.title} venue={e.venue} starts={e.starts_at} name={pass.name} kind={pass.kind} token={pass.token} status={pass.status} />}
              {reg.kind !== 'guest' && <button className="btn ghost" disabled={busy} onClick={() => act(`/events/${e.id}/cancel-registration`)}>Cancel my registration</button>}
            </>
          ) : (
            <>
              <b style={{ fontSize: 18 }}>{e.registration_open ? 'Registration is open' : 'Registration is closed'}</b>
              {e.eligibility && <p className="muted">{e.eligibility}</p>}
              {e.seats_left != null && <p className="muted">{e.seats_left} seat{e.seats_left === 1 ? '' : 's'} left</p>}
              {e.eligible && e.registration_open && <button className="btn primary block" disabled={busy} onClick={() => act(`/events/${e.id}/register`)}>{busy ? 'Registering…' : 'Register'}</button>}
              {!e.eligible && !me.is_member && <Link to="/me/edit" className="btn block">Apply for membership</Link>}
            </>
          )}
        </aside>
      </div>
    </div>
  )
}
