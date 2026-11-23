import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { Icon } from '../components/icons'
import { ErrorBox, Skeleton } from '../components/ui'
import { fmtNum } from '../format'
import { useFetch } from '../useFetch'

interface Area {
  id: number; parent_id: number | null; type: string; name: string; name_local: string | null; code: string | null
  is_active: boolean; label: string; children: number; can_have_children: boolean; members: number
}

const CHILD: Record<string, string> = { national: 'state', state: 'district', district: 'unit' }
const TYPE_LABEL: Record<string, string> = { national: 'National', state: 'State (prant)', district: 'District', unit: 'Unit / college' }

/** States, districts and units. Members pick their district from this list; roles and events are scoped to it. */
export default function Areas() {
  const roots = useFetch<Area[]>('/admin/org-units')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const [err, setErr] = useState<unknown>(null)
  const [round, setRound] = useState(0)
  const national = roots.data?.some((a) => a.type === 'national')

  async function importPrants() {
    setBusy(true); setErr(null); setMsg('')
    try {
      const r = await api.post<{ added: string[] }>('/admin/org-units/import-prants')
      setMsg(r.data.added.length ? `Added ${r.data.added.length} prants: ${r.data.added.join(', ')}.` : 'Every ABVP prant is already listed.')
      roots.reload(); setRound(round + 1)
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  return (
    <main className="content">
      <div className="page-head">
        <div>
          <h1>Areas</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>States (prants), districts and units. Members choose their state and district from this list when they sign up or edit their profile; admin roles, approvals and events follow it.</p>
        </div>
        {national && <button className="btn" disabled={busy} onClick={importPrants}>{busy ? 'Adding…' : 'Add all ABVP prants'}</button>}
      </div>
      <ErrorBox error={roots.error ?? err} />
      {msg && <div className="notice" role="status">{msg}</div>}
      <section className="card area-tree">
        {!roots.data ? <Skeleton rows={5} /> : roots.data.map((a) => <Node key={`${a.id}-${round}`} area={a} depth={0} startOpen onChanged={roots.reload} />)}
      </section>
      <p className="muted" style={{ fontSize: 13 }}>Switching an area off hides it from the sign-up and profile lists; people already in it keep it. Areas are not deleted, so history and member IDs stay correct.</p>
    </main>
  )
}

function Node({ area, depth, startOpen = false, onChanged }: { area: Area; depth: number; startOpen?: boolean; onChanged: () => void }) {
  const [open, setOpen] = useState(startOpen)
  const kids = useFetch<Area[]>(open ? `/admin/org-units?parent_id=${area.id}` : null)
  const [adding, setAdding] = useState(false)
  const [renaming, setRenaming] = useState(false)
  const [name, setName] = useState('')
  const [local, setLocal] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const childType = CHILD[area.type]

  async function add(e: FormEvent) {
    e.preventDefault(); setBusy(true); setErr(null)
    try { await api.post('/admin/org-units', { parent_id: area.id, name: name.trim(), name_local: local.trim() || null }); setName(''); setLocal(''); setAdding(false); setOpen(true); kids.reload(); onChanged() } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  async function rename(e: FormEvent) {
    e.preventDefault(); setBusy(true); setErr(null)
    try { await api.patch(`/admin/org-units/${area.id}`, { name: name.trim(), name_local: local.trim() || null }); setRenaming(false); onChanged() } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  async function toggle() {
    if (area.is_active && !confirm(`Switch off ${area.name}? It will no longer be offered when people choose their area.`)) return
    setBusy(true); setErr(null)
    try { await api.patch(`/admin/org-units/${area.id}`, { is_active: !area.is_active }); onChanged() } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  return (
    <div className="area-node" style={{ ['--depth' as string]: depth }}>
      <div className={`area-row ${area.is_active ? '' : 'off'}`}>
        <button className="area-toggle" aria-label={open ? `Collapse ${area.name}` : `Expand ${area.name}`} aria-expanded={open} disabled={!area.can_have_children} onClick={() => setOpen(!open)}>
          {area.can_have_children ? (open ? '▾' : '▸') : '•'}
        </button>
        {renaming ? (
          <form onSubmit={rename} className="area-form">
            <input className="input" value={name} onChange={(e) => setName(e.target.value)} required aria-label="Name" autoFocus />
            <input className="input" value={local} onChange={(e) => setLocal(e.target.value)} placeholder="Local name (optional)" aria-label="Local name" />
            <button className="btn small primary" disabled={busy}>Save</button>
            <button type="button" className="btn small" onClick={() => setRenaming(false)}>Cancel</button>
          </form>
        ) : (
          <div className="area-name">
            <b>{area.name}</b>{area.name_local && <span className="muted"> · {area.name_local}</span>}
            <span className="pill mute">{TYPE_LABEL[area.type] ?? area.type}</span>
            {!area.is_active && <span className="pill bad">Off</span>}
          </div>
        )}
        <span className="muted area-counts">{area.children > 0 && `${fmtNum(area.children)} ${CHILD[area.type] ?? 'sub-area'}${area.children === 1 ? '' : 's'} · `}{fmtNum(area.members)} member{area.members === 1 ? '' : 's'}</span>
        {!renaming && (
          <div className="area-actions">
            {childType && <button className="btn small" onClick={() => { setAdding(!adding); setName(''); setLocal(''); setOpen(true) }}><Icon name="map" size={14} /> Add {childType}</button>}
            {area.type !== 'national' && <button className="btn small" onClick={() => { setRenaming(true); setName(area.name); setLocal(area.name_local ?? '') }}>Rename</button>}
            {area.type !== 'national' && <button className={`btn small ${area.is_active ? '' : 'good'}`} disabled={busy} onClick={toggle}>{area.is_active ? 'Switch off' : 'Switch on'}</button>}
          </div>
        )}
      </div>
      {err != null && <div style={{ marginLeft: 34 }}><ErrorBox error={err} /></div>}
      {adding && (
        <form onSubmit={add} className="area-form" style={{ marginLeft: 34 + 22, marginBottom: 8 }}>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} placeholder={`New ${childType} name`} required autoFocus aria-label={`New ${childType} name`} />
          <input className="input" value={local} onChange={(e) => setLocal(e.target.value)} placeholder="Local name (optional)" aria-label="Local name" />
          <button className="btn small primary" disabled={busy || !name.trim()}>{busy ? 'Adding…' : `Add ${childType}`}</button>
          <button type="button" className="btn small" onClick={() => setAdding(false)}>Cancel</button>
        </form>
      )}
      {open && (
        <div className="area-children">
          {!kids.data ? (area.children > 0 ? <Skeleton rows={2} /> : null) : kids.data.length === 0 ? (
            <p className="muted" style={{ fontSize: 13, margin: '4px 0 8px 34px' }}>No {childType}s yet.</p>
          ) : kids.data.map((k) => <Node key={k.id} area={k} depth={depth + 1} onChanged={kids.reload} />)}
        </div>
      )}
    </div>
  )
}
