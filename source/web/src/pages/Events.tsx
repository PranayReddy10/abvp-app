import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth'
import PassCard from '../components/PassCard'
import { ErrorBox, Icon, KIND, Orbs, Reveal, Skeleton, Tilt, fmtDate, fmtDateTime, fmtDay, fmtTime, grad } from '../components/ui'
import type { Delegate, Hub, Pass } from '../types'
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
  contact?: { name: string; phone: string | null } | null; venue_map_url?: string | null; helpline?: string | null
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

const FOOD: Record<string, string> = { veg: 'Vegetarian', jain: 'Jain', nonveg: 'Non-vegetarian' }
const daysBetween = (a: string, b: string) => {
  const out: string[] = []
  const d = new Date(a); const end = new Date(b)
  for (let i = 0; i < 14 && d <= end; i++) { out.push(d.toISOString()); d.setDate(d.getDate() + 1) }
  return out
}

function Block({ title, icon, children, i = 0 }: { title: string; icon: 'pin' | 'clock' | 'user' | 'ticket' | 'sparkle' | 'support' | 'phone' | 'bell'; children: React.ReactNode; i?: number }) {
  return (
    <motion.section className="card ev-block" initial={{ opacity: 0, y: 18 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: .08 + i * .06 }}>
      <h2><span className="ev-ic"><Icon name={icon} size={18} /></span>{title}</h2>
      {children}
    </motion.section>
  )
}

export function EventPage() {
  const { id } = useParams()
  const { me } = useAuth()
  const ev = useFetch<EventDetail>(me ? `/events/${id}` : `/public/events/${id}`)
  const passes = useFetch<Pass[]>(me ? '/me/passes' : null)
  const e = ev.data
  const reg = e?.my_registration && !['cancelled', 'rejected'].includes(e.my_registration.status) ? e.my_registration : null
  const delegate = useFetch<Delegate>(me && reg?.kind === 'delegate' ? `/events/${id}/delegate` : null)
  const hub = useFetch<Hub>(e?.guide_enabled ? `/events/${id}/guide` : null)
  const news = useFetch<{ id: number; title: string; body: string | null; at: string }[]>(me && (reg || e?.guide_enabled) ? `/events/${id}/announcements` : null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const pass = passes.data?.find((p) => p.event.id === Number(id) && p.status === 'registered')

  async function act(path: string) {
    setBusy(true); setErr(null)
    try { await api.post(path); ev.reload(); passes.reload() } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  if (!e) return <div className="page wrap"><ErrorBox error={ev.error} />{!ev.error && <Skeleton h={320} n={2} />}</div>
  const days = daysBetween(e.starts_at, e.ends_at)
  const d = delegate.data?.registration
  let n = 0

  return (
    <div className="page wrap" style={{ maxWidth: 1080 }}>
      <Link to="/events" className="btn ghost sm" style={{ marginBottom: 14 }}><Icon name="back" size={16} /> All events</Link>
      <motion.div className="ev-hero" initial={{ opacity: 0, scale: .98 }} animate={{ opacity: 1, scale: 1 }}>
        <Cover e={e} h={300} />
        <div className="ev-hero-text">
          <span className="chip" style={{ background: 'rgba(255,255,255,.2)', color: '#fff' }}>{e.category_label}</span>
          <h1>{e.title}</h1>
          <div className="ev-facts">
            <span><Icon name="clock" size={16} /> {fmtDate(e.starts_at)}{days.length > 1 ? ` – ${fmtDate(e.ends_at)}` : ''}</span>
            <span><Icon name="pin" size={16} /> {e.venue}</span>
            {e.organised_by && <span><Icon name="user" size={16} /> {e.organised_by}</span>}
          </div>
        </div>
      </motion.div>

      <div className="ev-detail">
        <div style={{ display: 'grid', gap: 18, alignContent: 'start', minWidth: 0 }}>
          <Block title="About" icon="sparkle" i={n++}>
            {e.description ? <p style={{ whiteSpace: 'pre-line', fontSize: 16.5, lineHeight: 1.75 }}>{e.description}</p>
              : <p className="muted">The organisers will add the programme details here.</p>}
          </Block>

          <Block title="When" icon="clock" i={n++}>
            <div className="ev-days">
              {days.map((day, k) => (
                <div key={day} className="ev-day">
                  <b>Day {k + 1}</b>
                  <span>{new Intl.DateTimeFormat('en-IN', { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'Asia/Kolkata' }).format(new Date(day))}</span>
                  {k === 0 && <small>from {fmtTime(e.starts_at)}</small>}
                  {k === days.length - 1 && <small>till {fmtTime(e.ends_at)}</small>}
                </div>
              ))}
            </div>
          </Block>

          <Block title="Where" icon="pin" i={n++}>
            <p style={{ fontSize: 17, fontWeight: 700 }}>{e.venue}</p>
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              {e.venue_map_url && <a className="btn sm" href={e.venue_map_url} target="_blank" rel="noreferrer"><Icon name="pin" size={16} /> Open in Google Maps</a>}
              {e.guide_enabled && <Link className="btn sm" to={`/guide/${e.id}/arrival`}>How to reach – transport desks</Link>}
            </div>
          </Block>

          {hub.data && hub.data.sections.length > 0 && (
            <Block title="Conference guide" icon="sparkle" i={n++}>
              <div className="ev-guide">
                {hub.data.sections.filter((s) => s.count > 0).map((s) => (
                  <Link key={s.kind} to={`/guide/${e.id}/${s.kind}`} className="ev-guide-tile">
                    <span className="ic" style={{ background: grad(s.kind) }}><Icon name={KIND[s.kind]?.icon ?? 'sparkle'} size={20} /></span>
                    <b>{s.title}</b><small className="hi">{s.hindi}</small>
                  </Link>
                ))}
              </div>
            </Block>
          )}

          {news.data && news.data.length > 0 && (
            <Block title="Announcements" icon="bell" i={n++}>
              {news.data.slice(0, 5).map((a) => (
                <div key={a.id} className="ev-news"><b>{a.title}</b>{a.body && <p>{a.body}</p>}<small className="muted">{fmtDateTime(a.at)}</small></div>
              ))}
            </Block>
          )}

          {(e.instructions || e.contact || e.helpline) && (
            <Block title="Good to know" icon="support" i={n++}>
              {e.instructions && <p style={{ whiteSpace: 'pre-line' }}>{e.instructions}</p>}
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                {e.contact && <a className="btn sm" href={e.contact.phone ? `tel:${e.contact.phone}` : undefined}><Icon name="phone" size={16} /> {e.contact.name}{e.contact.phone ? ` · ${e.contact.phone}` : ''}</a>}
                {e.helpline && <a className="btn sm" href={`tel:${e.helpline}`}><Icon name="phone" size={16} /> Helpline {e.helpline}</a>}
                {me && reg && <Link className="btn sm" to={`/support/${e.id}`}><Icon name="support" size={16} /> Help desk</Link>}
              </div>
            </Block>
          )}

          {d && (
            <Block title="Your registration" icon="user" i={n++}>
              <div className="review">
                <div><span>Name</span><b>{d.full_name}</b></div>
                {d.details.prant && <div><span>Prant</span><b>{d.details.prant}</b></div>}
                {d.details.institution && <div><span>College</span><b>{d.details.institution}</b></div>}
                {d.details.food && <div><span>Food</span><b>{FOOD[d.details.food] ?? d.details.food}</b></div>}
                {d.travel && <div><span>Arriving</span><b style={{ textTransform: "none" }}>{d.travel.mode.charAt(0).toUpperCase() + d.travel.mode.slice(1)} {d.travel.reference ?? ''} · {d.travel.arrival_point} · {fmtDateTime(d.travel.arriving_at)}</b></div>}
                {d.travel && <div><span>Pickup / stay</span><b>{d.travel.needs_pickup ? 'Pickup needed' : 'No pickup'} · {d.travel.needs_stay ? 'Needs a bed' : 'Own stay'}</b></div>}
                {d.details.emergency_name && <div><span>Emergency contact</span><b>{d.details.emergency_name} · {d.details.emergency_phone}</b></div>}
              </div>
              {e.delegate_registration_open && <Link to={`/conference/${e.id}/register`} className="btn sm" style={{ justifySelf: 'start' }}>Edit my registration</Link>}
            </Block>
          )}

          {hub.data && hub.data.my_stays.length > 0 && (
            <Block title="Your stay" icon="pin" i={n++}>
              {hub.data.my_stays.map((s) => <Link key={s.id} to={`/guide/${e.id}/stay`} className="ev-news"><b>{s.title}</b>{s.subtitle && <p>{s.subtitle}</p>}</Link>)}
            </Block>
          )}
        </div>

        <aside style={{ display: 'grid', gap: 16, alignContent: 'start', position: 'sticky', top: 96 }}>
          <div className="card" style={{ display: 'grid', gap: 12 }}>
            <ErrorBox error={err} />
            {!me ? (
              <>
                <b style={{ fontSize: 18 }}>Want to attend?</b>
                <p className="muted">Sign in to register and get your pass.</p>
                {e.delegate_registration_open && <Link to={`/signup?next=/conference/${e.id}/register`} className="btn primary block">Register as delegate</Link>}
                <Link to={`/login?next=/events/${e.id}`} className="btn dark block">Sign in</Link>
              </>
            ) : reg ? (
              <>
                <span className={`status-pill ${reg.status === 'registered' ? 'ok' : 'info'}`} style={{ justifySelf: 'start' }}>{REG_LABEL[reg.status] ?? reg.status}{reg.kind === 'delegate' ? ' · Delegate' : ''}</span>
                {e.waitlist_position ? <p className="muted">You are number {e.waitlist_position} on the waitlist.</p> : null}
                {reg.note && <p className="muted">{reg.note}</p>}
                {reg.kind === 'member' && <button className="btn ghost" disabled={busy} onClick={() => act(`/events/${e.id}/cancel-registration`)}>Cancel my registration</button>}
              </>
            ) : (
              <>
                <b style={{ fontSize: 18 }}>{e.delegate_registration_open ? 'Delegate registration is open' : e.registration_open ? 'Registration is open' : 'Registration is closed'}</b>
                {e.delegate_registration_open && <Link to={`/conference/${e.id}/register`} className="btn primary block">Register as delegate</Link>}
                {!e.delegate_registration_open && e.eligibility && <p className="muted">{e.eligibility}</p>}
                {e.seats_left != null && <p className="muted">{e.seats_left} seat{e.seats_left === 1 ? '' : 's'} left</p>}
                {e.eligible && e.registration_open && !e.delegate_registration_open && <button className="btn primary block" disabled={busy} onClick={() => act(`/events/${e.id}/register`)}>{busy ? 'Registering…' : 'Register'}</button>}
                {!e.eligible && !me.is_member && !e.delegate_registration_open && <Link to="/me/edit" className="btn block">Apply for membership</Link>}
              </>
            )}
            {e.guide_enabled && <Link to={`/guide/${e.id}`} className="btn block">Open the conference guide</Link>}
          </div>
          {pass && <PassCard title={e.title} venue={e.venue} starts={e.starts_at} name={pass.name} kind={pass.kind} token={pass.token} status={pass.status} />}
        </aside>
      </div>
    </div>
  )
}
