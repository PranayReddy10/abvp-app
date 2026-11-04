import { useEffect, useState, type FormEvent } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth'
import { useFetch } from '../useFetch'
import type { Dashboard } from '../types'
import { Icon, VerifiedBadge, type IconName } from './icons'
import { Avatar } from './ui'

function Item({ to, icon, label, count, end }: { to: string; icon: IconName; label: string; count?: number; end?: boolean }) {
  return (
    <NavLink to={to} end={end}>
      <span className="nav-icon"><Icon name={icon} /></span>
      <span className="nav-label">{label}</span>
      {count ? <span className="count">{count}</span> : null}
    </NavLink>
  )
}

export default function Layout() {
  const { me, can, signOut } = useAuth()
  const { data: dash, reload } = useFetch<Dashboard>('/admin/dashboard')
  const { pathname, search } = useLocation()
  const navigate = useNavigate()
  const top = me?.roles[0]
  const [q, setQ] = useState('')
  const [dark, setDark] = useState(() => document.documentElement.dataset.theme === 'dark'
    || (!document.documentElement.dataset.theme && window.matchMedia?.('(prefers-color-scheme: dark)').matches))

  function toggleTheme() {
    const next = dark ? 'light' : 'dark'
    document.documentElement.dataset.theme = next
    try { localStorage.setItem('abvp.admin.theme', next) } catch { /* private mode */ }
    setDark(!dark)
  }

  function find(e: FormEvent) {
    e.preventDefault()
    if (q.trim()) navigate(`/members?q=${encodeURIComponent(q.trim())}`)
  }
  const waiting = (dash?.pending_applications ?? 0) + (dash?.reported_posts ?? 0)

  // Keep the Approvals badge current after a decision.
  useEffect(() => {
    window.addEventListener('abvp:queue-changed', reload)
    return () => window.removeEventListener('abvp:queue-changed', reload)
  }, [reload])

  return (
    <div className="shell">
      <aside className="side" aria-label="Main">
        <div className="brand"><span className="brand-mark"><img src="/favicon.svg" alt="" /></span><span>ABVP Connect<small>Admin panel</small></span></div>
        <h6>Main</h6>
        <Item to="/" end icon="dashboard" label="Dashboard" />
        {can('analytics.view') && <Item to="/analytics" icon="chart" label="Analysis" />}
        <h6>Membership</h6>
        {can('members.view') && <Item to="/approvals" icon="approvals" label="Approvals" count={dash?.pending_applications} />}
        {can('members.view') && <Item to="/members" icon="members" label="Members" />}
        {can('events.manage') && <><h6>Events</h6><Item to="/events" icon="events" label="Events" /></>}
        <h6>Organisation work</h6>
        {can('meetings.schedule') && <Item to="/meetings" icon="meetings" label="Meetings" />}
        {can('circulars.issue') && <Item to="/circulars" icon="circulars" label="Circulars" />}
        {can('reports.view') && <Item to="/reports" icon="reports" label="Activity reports" />}
        {can('vibhag.post') && <Item to="/updates" icon="updates" label="Vibhag updates" />}
        {can('feed.moderate') && <Item to="/moderation" icon="flag" label="Community" count={dash?.reported_posts} />}
        <h6>Setup</h6>
        <Item to="/vibhags" icon="vibhags" label="Vibhags" />
        {can('roles.assign') && <Item to="/roles" icon="roles" label="Admins and roles" />}
        {can('audit.view') && <Item to="/audit" icon="audit" label="Audit log" />}
        {can('settings.manage') && <Item to="/settings" icon="settings" label="Settings" />}
        <div className="grow" />
        <div className="side-card">
          <b>एक सदस्य · एक पहचान</b>
          <span>Every office, one panel. Approvals, events and members in your area.</span>
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          {top && (
            <div className="scope" title="Everything on screen is limited to this area">
              <span className="dot" /> {dash?.scope?.name ?? top.org_unit.name}
            </div>
          )}
          {can('members.view') && (
            <form className="top-search" role="search" onSubmit={find}>
              <Icon name="search" size={19} />
              <input placeholder="Search members…" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search members" />
            </form>
          )}
          <div className="grow" />
          <button className="icon-btn" onClick={toggleTheme} title={dark ? 'Light mode' : 'Dark mode'} aria-label={dark ? 'Switch to light mode' : 'Switch to dark mode'}>
            <Icon name={dark ? 'sun' : 'moon'} size={19} />
          </button>
          <button className="icon-btn" onClick={() => navigate(dash?.pending_applications ? '/approvals' : '/moderation')} title="Waiting for you" aria-label={`${waiting} items waiting for you`}>
            <Icon name="bell" size={19} />{waiting > 0 && <i className="dot-badge" />}
          </button>
          <div className="me-chip">
            <Avatar name={me?.profile?.full_name ?? me?.name} src={me?.profile?.photo_url} size={40} />
            <div className="me-text">
              <b>{me?.profile?.full_name ?? me?.name}{me?.profile?.verified && <VerifiedBadge size={14} />}</b>
              <span>{top?.label}</span>
            </div>
          </div>
          <button className="icon-btn" onClick={signOut} title="Sign out" aria-label="Sign out"><Icon name="logout" size={18} /></button>
        </header>
        {/* Re-keyed per route so each page animates in. */}
        <div key={pathname + search} className="page-enter"><Outlet /></div>
      </div>
    </div>
  )
}
