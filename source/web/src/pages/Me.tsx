import { motion } from 'framer-motion'
import { useState } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { nameOf, useAuth } from '../auth'
import { useConference } from '../components/Layout'
import { MySeva } from './Team'
import { Avatar, Icon, Orbs, Skeleton, Tick, fmtDate, useCountdown } from '../components/ui'
import type { Delegate } from '../types'
import { useSeo } from '../seo'
import { useFetch } from '../useFetch'

const THOUGHTS: [string, string][] = [
  ['Take up one idea. Make that one idea your life.', 'Swami Vivekananda'],
  ['Arise, awake, and stop not till the goal is reached.', 'Swami Vivekananda'],
  ['Knowledge, character, unity.', 'ABVP – Gyan, Sheel, Ekta'],
  ['The nation is built one student at a time.', 'ABVP'],
]

function Count({ iso }: { iso: string }) {
  const c = useCountdown(iso)
  if (c.done) return <div className="me-count"><div style={{ gridColumn: '1 / -1' }}><b>Live</b><span>Happening now</span></div></div>
  return (
    <div className="me-count">
      {[[c.d, 'Days'], [c.h, 'Hours'], [c.m, 'Minutes'], [c.s, 'Seconds']].map(([v, l]) => (
        <div key={l}><motion.b key={String(v)} initial={{ y: -6, opacity: 0 }} animate={{ y: 0, opacity: 1 }}>{String(v).padStart(2, '0')}</motion.b><span>{l}</span></div>
      ))}
    </div>
  )
}

/** My space: the same as Home in the app – who I am, the countdown, and Delegate and Volunteer. */
export default function Me() {
  useSeo({ title: 'My space', noindex: true })
  const { me, loading, signOut } = useAuth()
  const { conf } = useConference()
  const nav = useNavigate()
  const e = conf?.event
  const dele = useFetch<Delegate>(me && e ? `/events/${e.id}/delegate` : null)
  const seva = useFetch<{ places: unknown[] }>(me ? '/me/seva' : null)
  const [closed, setClosed] = useState(false)
  const [thought] = useState(() => THOUGHTS[new Date().getDate() % THOUGHTS.length])
  if (!loading && !me) return <Navigate to="/login?next=/me" replace />
  if (!me) return <div className="page wrap"><Skeleton /></div>
  const hour = new Date().getHours()
  const name = nameOf(me)
  const verified = !!me.profile?.verified
  const registered = !!dele.data?.registration
  const team = (seva.data?.places.length ?? 0) > 0

  function openDelegate() {
    if (!e) return
    if (registered) nav(`/guide/${e.id}`)
    else if (dele.data && !dele.data.open) setClosed(true)
    else nav(`/conference/${e.id}/register`)
  }

  return (
    <div className="page wrap">
      <div className="banner me-head">
        <Orbs />
        <div className="me-who">
          <Avatar name={name || '?'} src={me.profile?.photo_url} size={76} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{ opacity: .9 }}>{hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening'} 🙏</p>
            <h1 style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>{name || 'Welcome'}{verified && <Tick size={26} />}</h1>
            <p style={{ opacity: .85 }} className="mono">{me.profile?.member_id ?? me.mobile}</p>
            <div className="me-chips">
              {registered && <span><Icon name="ticket" size={14} /> Delegate</span>}
              {team && <span><Icon name="heart" size={14} /> Volunteer</span>}
              <span><Icon name="check" size={14} /> {verified ? 'Verified member' : 'Member'}</span>
            </div>
          </div>
          <Link to="/me/edit" className="btn glass sm"><Icon name="edit" size={16} /> Edit profile</Link>
        </div>
      </div>

      {e && (
        <motion.div className="card me-conf" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }}>
          <div style={{ flex: 1, minWidth: 240 }}>
            <h2>{e.title}</h2>
            <p className="muted">{fmtDate(e.starts_at)} – {fmtDate(e.ends_at)} · {e.venue}</p>
          </div>
          <Count iso={e.starts_at} />
        </motion.div>
      )}

      <div className="me-tiles">
        {e && (
          <motion.button className="me-tile delegate" onClick={openDelegate} whileHover={{ y: -4 }} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: .08 }}>
            <span className="ic"><Icon name="ticket" size={26} /></span>
            <b>Delegate</b>
            <span>{registered ? 'Registered ✓ · open guide' : dele.data && !dele.data.open ? 'Registration closed' : 'Fill the delegate form'}</span>
          </motion.button>
        )}
        <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: .14 }}>
          <Link to="/conference/team" className="me-tile volunteer">
            <span className="ic"><Icon name="heart" size={26} /></span>
            <b>Volunteer</b>
            <span>{team ? 'My team, ghats and departments' : 'Ghats, departments and people'}</span>
          </Link>
        </motion.div>
      </div>

      <div className="card me-thought">
        <span className="q">“</span>
        <div><small>Thought for the day</small><p>“{thought[0]}”</p><span className="muted">— {thought[1]}</span></div>
      </div>

      <MySeva />

      <div className="me-links">
        {e && <Link to={`/support/${e.id}`} className="card"><Icon name="support" /> <b>Help and emergency</b><Icon name="arrow" /></Link>}
        <Link to="/community" className="card"><Icon name="chat" /> <b>Community</b><Icon name="arrow" /></Link>
        <Link to="/events" className="card"><Icon name="calendar" /> <b>Events</b><Icon name="arrow" /></Link>
      </div>

      <h2 style={{ fontSize: 28, fontWeight: 800, margin: '40px 0 16px' }}>My details</h2>
      <div className="review" style={{ maxWidth: 640 }}>
        <div><span>Name</span><b>{name || '–'}{verified && <Tick />}</b></div>
        <div><span>Member ID</span><b>{me.profile?.member_id ?? '–'}</b></div>
        <div><span>Mobile</span><b>{me.mobile}</b></div>
        <div><span>Email</span><b>{me.email ?? '–'}</b></div>
        <div><span>Area</span><b>{me.profile?.org_unit?.label || me.profile?.org_unit?.name || me.prant || '–'}</b></div>
        <div><span>College / organisation</span><b>{me.institution ?? '–'}</b></div>
        <div><span>Membership</span><b>{verified ? 'Verified member' : 'Member – an admin gives the blue tick after checking'}</b></div>
      </div>
      <Link to="/me/edit" className="btn primary" style={{ marginTop: 20, marginRight: 10 }}><Icon name="edit" size={18} /> Edit profile</Link>
      <button className="btn" style={{ marginTop: 20 }} onClick={signOut}><Icon name="logout" size={18} /> Sign out</button>

      {closed && (
        <div className="overlay center" onMouseDown={(ev) => { if (ev.target === ev.currentTarget) setClosed(false) }}>
          <motion.div className="card dialog" initial={{ scale: .92, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} role="dialog" aria-label="Registration closed">
            <span className="ic" style={{ background: 'linear-gradient(135deg, #FF6363, #C81E1E)' }}><Icon name="clock" size={26} /></span>
            <h2>Delegate registration is closed</h2>
            <p className="muted">Registration is not open right now. Please check again soon, or call the helpline.</p>
            <button className="btn dark" onClick={() => setClosed(false)}>OK</button>
          </motion.div>
        </div>
      )}
    </div>
  )
}
