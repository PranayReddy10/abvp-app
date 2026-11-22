import { motion } from 'framer-motion'
import { Link, Navigate } from 'react-router-dom'
import { nameOf, useAuth } from '../auth'
import { useConference } from '../components/Layout'
import PassCard from '../components/PassCard'
import { Icon, KIND, Orbs, Reveal, Skeleton, grad } from '../components/ui'
import type { Pass } from '../types'
import { useFetch } from '../useFetch'

export default function Me() {
  const { me, loading, signOut } = useAuth()
  const { conf } = useConference()
  const passes = useFetch<Pass[]>(me ? '/me/passes' : null)
  if (!loading && !me) return <Navigate to="/login?next=/me" replace />
  if (!me) return <div className="page wrap"><Skeleton /></div>
  const hour = new Date().getHours()
  const first = nameOf(me).split(' ')[0]
  const e = conf?.event
  const registered = passes.data?.some((p) => p.event.id === e?.id)

  const actions = [
    e && { to: `/guide/${e.id}`, kind: 'stay', icon: 'sparkle' as const, t: 'Conference guide', s: 'Stay, transport, food, emergency' },
    e?.delegate_registration_open && { to: `/conference/${e.id}/register`, kind: 'arrival', icon: 'ticket' as const, t: registered ? 'My registration' : 'Register as delegate', s: registered ? 'See or edit your details' : 'Get your pass in minutes' },
    e && { to: `/support/${e.id}`, kind: 'support', icon: 'support' as const, t: 'Help desk', s: 'Chat or raise a ticket' },
    { to: '/community', kind: 'exhibit', icon: 'chat' as const, t: 'Community', s: me.is_member ? 'Share work from your unit' : 'For members' },
  ].filter(Boolean) as { to: string; kind: string; icon: 'sparkle'; t: string; s: string }[]

  return (
    <div className="page wrap">
      <div className="banner" style={{ background: 'linear-gradient(135deg, #F08A3C, #E3620C 40%, #14161F)' }}>
        <Orbs />
        <div style={{ position: 'relative', zIndex: 2, display: 'flex', justifyContent: 'space-between', gap: 20, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div>
            <p style={{ opacity: .85, fontSize: 18 }}>{hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening'},</p>
            <h1>{first || 'Welcome'} 👋</h1>
            <p style={{ opacity: .85 }}>{[me.prant, me.institution].filter(Boolean).join(' · ') || me.mobile}</p>
          </div>
          <span className="chip" style={{ background: 'rgba(255,255,255,.18)', color: '#fff' }}>{me.is_member ? `Member · ${me.profile?.member_id ?? ''}` : 'Account'}</span>
        </div>
      </div>

      <div className="tiles" style={{ marginBottom: 34 }}>
        {actions.map((a, i) => (
          <motion.div key={a.to} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: .1 + i * .06 }}>
            <Link to={a.to} className="tile" style={{ height: '100%' }}>
              <span className="top"><span className="ic" style={{ background: grad(a.kind) }}><Icon name={a.icon} size={24} /></span><Icon name="ne" /></span>
              <span><b>{a.t}</b><span className="muted" style={{ fontSize: 14 }}>{a.s}</span></span>
            </Link>
          </motion.div>
        ))}
      </div>

      <h2 style={{ fontSize: 28, fontWeight: 800, marginBottom: 16 }}>My passes</h2>
      {passes.loading && !passes.data ? <Skeleton h={300} n={1} /> : passes.data?.length ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 24 }}>
          {passes.data.map((p) => <PassCard key={p.registration_id} title={p.event.title} venue={p.event.venue} starts={p.event.starts_at} name={p.name} kind={p.kind} token={p.token} status={p.status} />)}
        </div>
      ) : (
        <Reveal>
          <div className="card" style={{ display: 'flex', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
            <span className="tile ic" style={{ width: 52, height: 52, borderRadius: 16, display: 'grid', placeItems: 'center', color: '#fff', background: grad('arrival') }}><Icon name={KIND.arrival.icon} /></span>
            <div style={{ flex: 1 }}><b style={{ fontSize: 18 }}>No passes yet</b><p className="muted">Register for the conference and your QR pass appears here.</p></div>
            {e?.delegate_registration_open && <Link to={`/conference/${e.id}/register`} className="btn primary">Register now</Link>}
          </div>
        </Reveal>
      )}

      <h2 style={{ fontSize: 28, fontWeight: 800, margin: '40px 0 16px' }}>My details</h2>
      <div className="review" style={{ maxWidth: 640 }}>
        <div><span>Name</span><b>{nameOf(me) || '–'}</b></div>
        <div><span>Mobile</span><b>{me.mobile}</b></div>
        <div><span>Email</span><b>{me.email ?? '–'}</b></div>
        <div><span>Prant</span><b>{me.prant ?? '–'}</b></div>
        <div><span>College / organisation</span><b>{me.institution ?? '–'}</b></div>
        <div><span>Membership</span><b>{me.is_member ? 'Approved member' : 'Not a member yet – apply in the ABVP Connect app'}</b></div>
      </div>
      <button className="btn" style={{ marginTop: 20 }} onClick={signOut}><Icon name="logout" size={18} /> Sign out</button>
    </div>
  )
}
