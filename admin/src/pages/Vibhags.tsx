import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { useAuth } from '../auth'
import { ErrorBox, Pill } from '../components/ui'
import { fmtNum } from '../format'
import type { Vibhag } from '../types'
import { useFetch } from '../useFetch'

export default function Vibhags() {
  const { can } = useAuth()
  const { data, error, reload } = useFetch<Vibhag[]>('/admin/vibhags')
  const [form, setForm] = useState({ name: '', code: '', description: '' })
  const [busy, setBusy] = useState(false)
  const [formError, setFormError] = useState<unknown>(null)
  const manage = can('vibhags.manage')

  async function add(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setFormError(null)
    try {
      await api.post('/admin/vibhags', form)
      setForm({ name: '', code: '', description: '' })
      reload()
    } catch (err) { setFormError(err) } finally { setBusy(false) }
  }

  async function toggle(v: Vibhag) {
    await api.patch(`/admin/vibhags/${v.id}`, { is_active: !v.is_active }).catch(setFormError)
    reload()
  }

  return (
    <main className="content">
      <div className="page-head"><h1>Vibhags</h1><span className="muted">{data ? `${data.filter((v) => v.is_active).length} active` : ''}</span></div>
      <ErrorBox error={error} />
      <div className="grid2" style={{ gridTemplateColumns: manage ? 'minmax(0,1.6fr) minmax(0,1fr)' : '1fr' }}>
        <section className="card">
          <div className="table-wrap">
            <table>
              <thead><tr><th>Vibhag</th><th>Code</th><th>Members</th><th>Status</th>{manage && <th />}</tr></thead>
              <tbody>
                {data?.map((v) => (
                  <tr key={v.id}>
                    <td><b>{v.name}</b>{v.description && <div className="muted" style={{ fontSize: 12 }}>{v.description}</div>}</td>
                    <td className="mono">{v.code}</td>
                    <td>{fmtNum(v.members_count)}</td>
                    <td><Pill status={v.is_active ? 'approved' : 'draft'} label={v.is_active ? 'Active' : 'Paused'} /></td>
                    {manage && <td><button className="btn small" onClick={() => toggle(v)}>{v.is_active ? 'Pause' : 'Activate'}</button></td>}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
        {manage && (
          <form className="card" onSubmit={add}>
            <h3>Add a Vibhag</h3>
            <ErrorBox error={formError} />
            <div className="field"><label htmlFor="vn">Name</label><input id="vn" className="input" required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
            <div className="field"><label htmlFor="vc">Short code</label><input id="vc" className="input mono" required placeholder="SFD" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value.toUpperCase() })} /></div>
            <div className="field"><label htmlFor="vd">Description</label><textarea id="vd" className="input" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></div>
            <button className="btn primary" disabled={busy}>Add Vibhag</button>
          </form>
        )}
      </div>
    </main>
  )
}
