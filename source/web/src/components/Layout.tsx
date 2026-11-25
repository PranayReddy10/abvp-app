import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { api, ApiError } from '../api'
import { nameOf, useAuth } from '../auth'
import type { GuideSummary, Me } from '../types'
import { useFetch } from '../useFetch'
import { Avatar, Icon } from './ui'

/** The next conference with a guide (public). */
// eslint-disable-next-line react-refresh/only-export-components
export function useConference() {
  const r = useFetch<GuideSummary[]>('/guide/events')
  return { conf: r.data?.[0] ?? null, loading: r.loading }
}

export function Brand() {
  return (
    <Link to="/" className="brand" aria-label="ABVP Connect home">
      <span className="mark"><img src="/abvp-emblem.png" alt="" width={38} height={38} /></span>
      ABVP Connect
    </Link>
  )
}

function Nav() {
  const { me, signOut } = useAuth()
  const { conf } = useConference()
  const { pathname } = useLocation()
  const [solid, setSolid] = useState(false)
  const [open, setOpen] = useState(false)
  const dark = pathname === '/' || pathname.startsWith('/guide')
  const form = pathname === '/login' || pathname === '/signup'
  useEffect(() => {
    const f = () => setSolid(window.scrollY > 24)
    f()
    window.addEventListener('scroll', f, { passive: true })
    return () => window.removeEventListener('scroll', f)
  }, [])
  useEffect(() => setOpen(false), [pathname])

  return (
    <header className={`nav ${solid || form ? 'solid' : ''} ${dark ? 'dark' : ''}`}>
      <div className="wrap">
        <Brand />
        <nav className={`nav-links ${open ? 'open' : ''}`} aria-label="Main">
          {conf && <NavLink to={`/guide/${conf.event.id}`}>Conference guide</NavLink>}
          {conf?.event.delegate_registration_open && <NavLink to={`/conference/${conf.event.id}/register`}>Register</NavLink>}
          <NavLink to="/events">Events</NavLink>
          <NavLink to="/community">Community</NavLink>
          {me && <NavLink to="/me">My space</NavLink>}
          {!me && <NavLink to="/login" className="only-sm">Sign in</NavLink>}
        </nav>
        <div className="grow" />
        {me ? (
          <>
            <Link to="/me" className="btn sm hide-sm" style={dark && !solid ? { background: 'rgba(255,255,255,.16)', color: '#fff', boxShadow: 'none' } : undefined}>
              <Avatar name={nameOf(me) || '?'} src={me.profile?.photo_url} size={28} /> {nameOf(me).split(' ')[0] || 'Me'}
            </Link>
            <button className="icon-btn" onClick={signOut} title="Sign out" aria-label="Sign out"><Icon name="logout" size={18} /></button>
          </>
        ) : (
          <>
            <Link to="/login" className={`btn sm hide-sm ${dark && !solid && !form ? 'glass' : ''}`}>Sign in</Link>
            <Link to="/signup" className="btn sm primary">Sign up</Link>
          </>
        )}
        <button className="icon-btn menu-btn" onClick={() => setOpen(!open)} aria-label="Menu" aria-expanded={open}><Icon name={open ? 'close' : 'menu'} /></button>
      </div>
    </header>
  )
}

function Footer() {
  const { conf } = useConference()
  return (
    <footer>
      <div className="wrap">
        <div style={{ display: 'grid', gap: 10, maxWidth: 360 }}>
          <div className="brand" style={{ color: '#fff' }}><span className="mark"><img src="/abvp-emblem.png" alt="" width={38} height={38} /></span>ABVP Connect</div>
          <p className="hi" style={{ fontSize: 17 }}>एक सदस्य · एक पहचान · हर कार्यक्रम</p>
          <p style={{ fontSize: 14 }}>The conference guide, delegate registration, passes and help desk – and the online home of ABVP members.</p>
        </div>
        <div style={{ display: 'grid', gap: 8, fontSize: 15 }}>
          <b style={{ color: '#fff' }}>Conference</b>
          {conf && <Link to={`/guide/${conf.event.id}`}>Guide</Link>}
          {conf?.event.delegate_registration_open && <Link to={`/conference/${conf.event.id}/register`}>Delegate registration</Link>}
          {conf?.event.helpline && <a href={`tel:${conf.event.helpline}`}>Helpline {conf.event.helpline}</a>}
        </div>
        <div style={{ display: 'grid', gap: 8, fontSize: 15 }}>
          <b style={{ color: '#fff' }}>Account</b>
          <Link to="/signup">Sign up</Link>
          <Link to="/login">Sign in</Link>
          <Link to="/me">My space</Link>
          <Link to="/events">Events</Link>
        </div>
      </div>
      <div className="wrap" style={{ marginTop: 30, fontSize: 13, opacity: .6 }}>© {new Date().getFullYear()} Akhil Bharatiya Vidyarthi Parishad</div>
    </footer>
  )
}

export default function Layout() {
  const location = useLocation()
  useEffect(() => { window.scrollTo(0, 0) }, [location.pathname])
  const bare = location.pathname === '/login' || location.pathname === '/signup'
  return (
    <>
      <Nav />
      <AnimatePresence mode="wait">
        <motion.main key={location.pathname} initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }} transition={{ duration: .35, ease: [.2, .7, .2, 1] }}>
          <Outlet />
        </motion.main>
      </AnimatePresence>
      {!bare && <Footer />}
    </>
  )
}

/** Google Identity Services button. On a new Google account it hands back a link token for sign-up. */
export function GoogleButton({ onNew }: { onNew: (d: { link_token: string; email: string; name: string | null }) => void }) {
  const box = useRef<HTMLDivElement>(null)
  const { signIn } = useAuth()
  const navigate = useNavigate()
  const [err, setErr] = useState<string | null>(null)
  const [note, setNote] = useState(false)
  const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID

  useEffect(() => {
    if (!clientId) return
    const onCredential = async ({ credential }: { credential: string }) => {
      setErr(null)
      try {
        const r = await api.post<{ linked: boolean; token?: string; user?: Me; link_token?: string; email?: string; name?: string | null }>('/auth/google', { id_token: credential, device_name: 'web' })
        if (r.data.linked && r.data.token && r.data.user) { signIn(r.data.token, r.data.user); navigate('/me') }
        else if (r.data.link_token) onNew({ link_token: r.data.link_token, email: r.data.email ?? '', name: r.data.name ?? null })
      } catch (e) { setErr(e instanceof ApiError ? e.message : 'Google sign-in did not finish.') }
    }
    const render = () => {
      if (!window.google || !box.current) return
      window.google.accounts.id.initialize({ client_id: clientId, callback: onCredential })
      window.google.accounts.id.renderButton(box.current, { theme: 'outline', size: 'large', shape: 'pill', width: 360, text: 'continue_with' })
    }
    if (window.google) { render(); return }
    const s = document.createElement('script')
    s.src = 'https://accounts.google.com/gsi/client'
    s.async = true
    s.onload = render
    document.head.appendChild(s)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [clientId])

  return (
    <div style={{ display: 'grid', gap: 10 }}>
      {clientId ? <div ref={box} style={{ display: 'grid', placeItems: 'center', minHeight: 44 }} /> : (
        <button type="button" className="btn block" onClick={() => setNote(true)}>
          <svg width="20" height="20" viewBox="0 0 48 48" aria-hidden="true"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" /><path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" /><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z" /><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" /></svg>
          Continue with Google
        </button>
      )}
      {note && <div className="hint">Google sign-in will be switched on once the website's Google client ID is set (VITE_GOOGLE_CLIENT_ID). Use your mobile number for now.</div>}
      {err && <div className="error">{err}</div>}
    </div>
  )
}
