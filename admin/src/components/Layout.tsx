import { useEffect } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../auth'
import { useFetch } from '../useFetch'
import type { Dashboard } from '../types'
import { Avatar } from './ui'

export default function Layout() {
  const { me, can, signOut } = useAuth()
  const { data: dash, reload } = useFetch<Dashboard>('/admin/dashboard')

  // Keep the Approvals badge current after a decision.
  useEffect(() => {
    window.addEventListener('abvp:queue-changed', reload)
    return () => window.removeEventListener('abvp:queue-changed', reload)
  }, [reload])
  const top = me?.roles[0]

  return (
    <div className="shell">
      <aside className="side" aria-label="Main">
        <div className="brand"><img src="/favicon.svg" alt="" />ABVP Connect</div>
        <NavLink to="/" end>Dashboard</NavLink>
        {can('analytics.view') && <NavLink to="/analytics">Analysis</NavLink>}
        <h6>Membership</h6>
        {can('members.view') && (
          <NavLink to="/approvals">
            Approvals {dash && dash.pending_applications > 0 && <span className="count">{dash.pending_applications}</span>}
          </NavLink>
        )}
        {can('members.view') && <NavLink to="/members">Members</NavLink>}
        {can('events.manage') && <><h6>Events</h6><NavLink to="/events">Events</NavLink></>}
        <h6>Organisation work</h6>
        {can('meetings.schedule') && <NavLink to="/meetings">Meetings</NavLink>}
        {can('circulars.issue') && <NavLink to="/circulars">Circulars</NavLink>}
        {can('reports.view') && <NavLink to="/reports">Activity reports</NavLink>}
        {can('vibhag.post') && <NavLink to="/updates">Vibhag updates</NavLink>}
        <h6>Setup</h6>
        <NavLink to="/vibhags">Vibhags</NavLink>
        {can('roles.assign') && <NavLink to="/roles">Admins and roles</NavLink>}
        {can('audit.view') && <><h6>Insights</h6><NavLink to="/audit">Audit log</NavLink></>}
        <div className="grow" />
      </aside>
      <div className="main">
        <header className="topbar">
          {top && (
            <div className="scope" title="Everything on screen is limited to this area">
              <span className="muted">Scope</span> {dash?.scope?.label ?? top.org_unit.label ?? top.org_unit.name}
            </div>
          )}
          {top && <span className="pill mute">{top.label}</span>}
          <div className="grow" />
          <span className="muted">{me?.profile?.full_name ?? me?.name}</span>
          <Avatar name={me?.profile?.full_name ?? me?.name} src={me?.profile?.photo_url} />
          <button className="btn small" onClick={signOut}>Sign out</button>
        </header>
        <Outlet />
      </div>
    </div>
  )
}
