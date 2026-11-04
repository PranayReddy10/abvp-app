import { useEffect } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
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
  const { pathname } = useLocation()
  const top = me?.roles[0]

  // Keep the Approvals badge current after a decision.
  useEffect(() => {
    window.addEventListener('abvp:queue-changed', reload)
    return () => window.removeEventListener('abvp:queue-changed', reload)
  }, [reload])

  return (
    <div className="shell">
      <aside className="side" aria-label="Main">
        <div className="brand"><img src="/favicon.svg" alt="" /><span>ABVP Connect<small>Admin</small></span></div>
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
        <div className="grow" />
        <div className="side-foot">
          <Avatar name={me?.profile?.full_name ?? me?.name} src={me?.profile?.photo_url} />
          <div style={{ minWidth: 0 }}>
            <b className="side-name">{me?.profile?.full_name ?? me?.name}{me?.profile?.verified && <VerifiedBadge size={14} />}</b>
            <span className="muted" style={{ fontSize: 12 }}>{top?.label}</span>
          </div>
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          {top && (
            <div className="scope" title="Everything on screen is limited to this area">
              <span className="dot" /> <span className="muted">Scope</span> {dash?.scope?.label ?? top.org_unit.label ?? top.org_unit.name}
            </div>
          )}
          <div className="grow" />
          <button className="btn small ghost" onClick={signOut}>Sign out</button>
        </header>
        {/* Re-keyed per route so each page animates in. */}
        <div key={pathname} className="page-enter"><Outlet /></div>
      </div>
    </div>
  )
}
