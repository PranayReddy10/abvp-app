import { useState } from 'react'
import { api } from '../api'
import { useFetch } from '../useFetch'
import { ErrorBox, Skeleton } from './ui'

/** Settings → Membership: whether applications wait for an office to approve them. */
export default function MembershipSetting() {
  const { data, error, reload } = useFetch<{ membership_needs_approval: boolean }>('/admin/settings/sign-in')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [msg, setMsg] = useState('')
  if (!data) return <section className="card settings-card"><h3 style={{ margin: 0 }}>Membership</h3><ErrorBox error={error} />{!error && <Skeleton rows={2} />}</section>
  const on = data.membership_needs_approval

  async function toggle() {
    setBusy(true); setErr(null); setMsg('')
    try {
      await api.put('/admin/settings/sign-in', { membership_needs_approval: !on })
      setMsg(!on ? 'New applications now wait in Approvals.' : 'New applications are now approved straight away.')
      reload()
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  return (
    <section className="card settings-card">
      <div className="settings-head">
        <div>
          <h3 style={{ margin: 0 }}>Membership</h3>
          <p className="muted" style={{ margin: '4px 0 0' }}>What happens when someone applies for membership on the website or app.</p>
        </div>
        <span className={`pill ${on ? 'warn' : 'ok'}`}>{on ? 'Needs approval' : 'Approved at once'}</span>
      </div>
      <div className="toggle-row">
        <div>
          <b>Applications need approval</b>
          <p className="muted" style={{ margin: '2px 0 0', fontSize: 13.5 }}>
            {on ? 'Each application waits in Approvals for the district or state office.' : 'Off: people become members the moment they apply, with their member ID and pass.'}
          </p>
        </div>
        <button type="button" role="switch" aria-checked={on} aria-label="Applications need approval" className={`switch ${on ? 'on' : ''}`} disabled={busy} onClick={toggle}><i /></button>
      </div>
      {msg && <div className="notice" role="status">{msg}</div>}
      <ErrorBox error={err} />
      <p className="muted" style={{ fontSize: 12.5, margin: 0 }}>Applications already waiting stay in Approvals. Offices can still verify members (blue tick) and change roles as before.</p>
    </section>
  )
}
