import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { useAuth } from '../auth'
import { Empty, ErrorBox } from '../components/ui'
import { useFetch } from '../useFetch'

interface Row { id: number; role: string; label: string; member: { name: string; member_id: string | null }; org_unit: string; vibhag: string | null; ends_on: string | null }
interface Unit { id: number; name: string; type: string; children_count?: number }

const ROLE_OPTIONS = [
  ['state_admin', 'State Admin'],
  ['district_admin', 'District Admin'],
  ['vibhag_admin', 'Vibhag Admin'],
  ['verification_officer', 'Verification Officer'],
]

export default function Roles() {
  const { me } = useAuth()
  const { data, error, reload } = useFetch<Row[]>('/admin/role-assignments')
  const { data: units } = useFetch<Unit[]>(scopeUnitsPath(me?.roles[0]?.org_unit.id))
  const [form, setForm] = useState({ member_id: '', role: 'verification_officer', org_unit_id: '' })
  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState<unknown>(null)
  const [done, setDone] = useState('')

  async function assign(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setFormError(null); setDone('')
    try {
      await api.post('/admin/role-assignments', { ...form, org_unit_id: Number(form.org_unit_id) })
      setDone('Role assigned. It works the next time they sign in.')
      setForm({ ...form, member_id: '' })
      reload()
    } catch (err) { setFormError(err) } finally { setBusy(false) }
  }

  async function end(id: number) {
    try { await api.del(`/admin/role-assignments/${id}`); reload() } catch (err) { setFormError(err) }
  }

  const scope = me?.roles[0]?.org_unit

  return (
    <main className="content">
      <div className="page-head"><h1>Admins and roles</h1></div>
      <ErrorBox error={error} />
      <div className="grid2">
        <section className="card">
          <div className="table-wrap">
            <table>
              <thead><tr><th>Member</th><th>Role</th><th>Area</th><th /></tr></thead>
              <tbody>
                {data?.map((r) => (
                  <tr key={r.id}>
                    <td><b>{r.member.name}</b><div className="mono muted" style={{ fontSize: 12 }}>{r.member.member_id}</div></td>
                    <td>{r.label}{r.vibhag ? ` · ${r.vibhag}` : ''}</td>
                    <td>{r.org_unit}</td>
                    <td><button className="btn small danger" onClick={() => end(r.id)}>End role</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
            {data?.length === 0 && <Empty>No roles assigned in your area yet.</Empty>}
          </div>
        </section>
        <form className="card" onSubmit={assign}>
          <h3>Give someone an admin role</h3>
          <p className="muted">You can give roles below your own, inside {scope?.label ?? scope?.name}. The person must already be an approved member.</p>
          <ErrorBox error={formError} />
          {done && <div className="notice">{done}</div>}
          <div className="field"><label htmlFor="mid">Member ID</label><input id="mid" className="input mono" placeholder="ABVP-TS-HYD-000123" required value={form.member_id} onChange={(e) => setForm({ ...form, member_id: e.target.value.trim().toUpperCase() })} /></div>
          <div className="field"><label htmlFor="role">Role</label>
            <select id="role" className="input" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
              {ROLE_OPTIONS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </select>
          </div>
          <div className="field"><label htmlFor="unit">Area</label>
            <select id="unit" className="input" required value={form.org_unit_id} onChange={(e) => setForm({ ...form, org_unit_id: e.target.value })}>
              <option value="">Choose…</option>
              {scope && <option value={scope.id}>{scope.name} (whole area)</option>}
              {units?.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
            </select>
          </div>
          <button className="btn primary" disabled={busy}>Assign role</button>
        </form>
      </div>
    </main>
  )
}

function scopeUnitsPath(unitId?: number) {
  return unitId ? `/org/units?parent_id=${unitId}` : null
}
