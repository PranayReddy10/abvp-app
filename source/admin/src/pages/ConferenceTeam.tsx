import { useMemo, useState, type FormEvent } from 'react'
import { api, ApiError, download } from '../api'
import { Avatar, Empty, ErrorBox, Skeleton } from '../components/ui'
import { fmtDate } from '../format'
import { useFetch } from '../useFetch'

interface Person { id: number; name: string; role: string; role_label: string; mobile: string | null; has_mobile: boolean; linked: boolean; note: string | null }
interface Dept { id: number; name: string; name_local: string | null; people: Person[] }
interface Ghat { id: number; name: string; name_local: string | null; color: string | null; heads: Person[]; departments: Dept[]; counts: { departments: number; people: number } }
interface Tree {
  event: { id: number; title: string; starts_at: string; ends_at: string }
  ghats: Ghat[]
  roles: Record<string, string>
  totals: { ghats: number; departments: number; people: number; linked: number; no_phone: number }
}

const HEAD_ROLES = ['ghat_pramukh', 'ghat_saha_pramukh', 'ghat_palak']
const DEPT_ROLES = ['pramukh', 'saha_pramukh', 'volunteer']
const wa = (m: string) => `https://wa.me/${m.replace(/\D/g, '')}`

/** The conference volunteer structure as an org chart: ghats → departments → people. */
export default function ConferenceTeam() {
  const conf = useFetch<{ id: number; title: string } | null>('/conference')
  const id = conf.data?.id
  const tree = useFetch<Tree>(id ? `/admin/events/${id}/conference-teams` : null)
  const [open, setOpen] = useState<number | null>(null)
  const [q, setQ] = useState('')
  const [missing, setMissing] = useState(false)
  const [tool, setTool] = useState<'import' | 'ghat' | null>(null)
  const [loadingSheet, setLoadingSheet] = useState(false)
  const [sheetErr, setSheetErr] = useState<unknown>(null)
  const loadSheet = async () => {
    if (!id || !confirm('Load the 17 ghats, their departments and the names from the organising sheets? Nothing is duplicated and phones already entered stay as they are.')) return
    setLoadingSheet(true); setSheetErr(null)
    try { await api.post(`/admin/events/${id}/conference-teams/load-sheet`); tree.reload() } catch (e) { setSheetErr(e) } finally { setLoadingSheet(false) }
  }

  const term = q.trim().toLowerCase()
  const match = (p: Person) => (!missing || !p.has_mobile) && (!term || p.name.toLowerCase().includes(term) || (p.mobile ?? '').includes(term))
  const ghats = useMemo(() => (tree.data?.ghats ?? []).map((g) => {
    const hit = !term || g.name.toLowerCase().includes(term)
    const departments = g.departments.filter((d) => hit || d.name.toLowerCase().includes(term) || d.people.some(match))
    const visible = hit || departments.length > 0 || g.heads.some(match)
    return { g, departments, visible: missing ? (g.heads.some(match) || g.departments.some((d) => d.people.some(match))) && visible : visible }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [tree.data, term, missing])
  const selected = tree.data?.ghats.find((g) => g.id === open) ?? null

  if (!conf.loading && !conf.error && conf.data === null) return <main className="content"><h1>Conference team</h1><Empty>No published conference yet. Create it under Events first.</Empty></main>
  const t = tree.data?.totals

  return (
    <main className="content">
      <div className="page-head">
        <div>
          <h1>Conference team</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>{tree.data ? `${tree.data.event.title} · ${fmtDate(tree.data.event.starts_at)} – ${fmtDate(tree.data.event.ends_at)}` : conf.error || tree.error ? '' : 'Loading…'}</p>
        </div>
        <div className="toolbar">
          {id && <button className="btn" disabled={loadingSheet} onClick={loadSheet}>{loadingSheet ? 'Loading…' : 'Load from sheet'}</button>}
          <button className="btn" onClick={() => setTool(tool === 'ghat' ? null : 'ghat')}>+ Ghat</button>
          <button className="btn" onClick={() => setTool(tool === 'import' ? null : 'import')}>Import CSV</button>
          {id && <button className="btn" onClick={() => download(`/admin/events/${id}/conference-teams/export`, 'conference-team.csv')}>Download CSV</button>}
        </div>
      </div>
      <ErrorBox error={conf.error ?? tree.error ?? sheetErr} />
      {t && (
        <div className="ct-stats">
          <div><b>{t.ghats}</b><span>Ghats</span></div>
          <div><b>{t.departments}</b><span>Departments</span></div>
          <div><b>{t.people}</b><span>People</span></div>
          <div><b>{t.linked}</b><span>Using the app</span></div>
          <button className={`ct-missing ${missing ? 'on' : ''}`} onClick={() => setMissing(!missing)}><b>{t.no_phone}</b><span>No phone yet{missing ? ' · showing' : ''}</span></button>
        </div>
      )}
      {tool === 'ghat' && id && <AddTeam eventId={id} onDone={() => { setTool(null); tree.reload() }} />}
      {tool === 'import' && id && <ImportBox eventId={id} onDone={() => tree.reload()} />}
      <input className="input" style={{ maxWidth: 420, margin: '4px 0 14px' }} placeholder="Find a person, phone or department – e.g. parking" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search the team" />

      <div className="grid2" style={{ gridTemplateColumns: selected ? 'minmax(0,1.25fr) minmax(0,1fr)' : '1fr', alignItems: 'start' }}>
        <section className="ct-grid">
          {!tree.data ? (conf.error || tree.error ? null : <Skeleton rows={6} />) : tree.data.ghats.length === 0 ? <Empty>No ghats yet. Press “Load from sheet” to add the 17 ghats and names from the organising sheets.</Empty> : ghats.filter((x) => x.visible).map(({ g, departments }) => (
            <button key={g.id} className={`ct-card ${open === g.id ? 'on' : ''}`} style={{ ['--c' as string]: g.color ?? '#E3620C' }} onClick={() => setOpen(open === g.id ? null : g.id)}>
              <div className="ct-card-head">
                <b>{g.name}</b>
                <span>{g.counts.departments} dept · {g.counts.people} people</span>
              </div>
              <div className="ct-heads">
                {HEAD_ROLES.map((r) => {
                  const h = g.heads.filter((x) => x.role === r)
                  return (
                    <div key={r} className="ct-head">
                      <Avatar name={h[0]?.name ?? '?'} size={30} />
                      <span><small>{tree.data!.roles[r]}</small>{h.length ? h.map((x) => x.name).join(', ') : <i className="muted">Not set</i>}</span>
                      {h.some((x) => !x.has_mobile) && <em title="No phone yet">●</em>}
                    </div>
                  )
                })}
              </div>
              <div className="ct-depts">
                {departments.map((d) => (
                  <span key={d.id} className={d.people.length ? '' : 'empty'} title={d.people.map((p) => p.name).join(', ') || 'No one yet'}>
                    {d.name}<b>{d.people.length}</b>
                  </span>
                ))}
              </div>
            </button>
          ))}
        </section>
        {selected && id && <GhatPanel key={selected.id} ghat={selected} roles={tree.data!.roles} eventId={id} onClose={() => setOpen(null)} onChanged={tree.reload} />}
      </div>
    </main>
  )
}

function AddTeam({ eventId, parentId, onDone }: { eventId: number; parentId?: number; onDone: () => void }) {
  const [name, setName] = useState('')
  const [err, setErr] = useState<unknown>(null)
  async function save(e: FormEvent) {
    e.preventDefault(); setErr(null)
    try { await api.post(`/admin/events/${eventId}/conference-teams`, { name: name.trim(), parent_id: parentId }); setName(''); onDone() } catch (x) { setErr(x) }
  }
  return (
    <form className="toolbar" onSubmit={save} style={{ marginBottom: 10 }}>
      <input className="input" style={{ maxWidth: 320 }} placeholder={parentId ? 'New department name' : 'New ghat name'} value={name} onChange={(e) => setName(e.target.value)} required autoFocus />
      <button className="btn primary small" disabled={!name.trim()}>Add</button>
      <ErrorBox error={err} />
    </form>
  )
}

function ImportBox({ eventId, onDone }: { eventId: number; onDone: () => void }) {
  const [csv, setCsv] = useState('ghat,department,role,name,mobile\n')
  const [res, setRes] = useState<{ ghats: number; departments: number; people: number; updated: number; skipped: string[] } | null>(null)
  const [err, setErr] = useState<unknown>(null)
  async function run() {
    setErr(null); setRes(null)
    try { const r = await api.post<typeof res>(`/admin/events/${eventId}/conference-teams/import`, { csv }); setRes(r.data); onDone() } catch (x) { setErr(x) }
  }
  return (
    <section className="card" style={{ display: 'grid', gap: 10, marginBottom: 14 }}>
      <b>Paste rows from Excel or Google Sheets</b>
      <span className="muted" style={{ fontSize: 13 }}>Columns: ghat, department (empty for ghat heads), role (Ghat Pramukh, Ghat Saha Pramukh, Ghat Palak, Pramukh, Saha Pramukh, Volunteer), name, mobile. New ghats and departments are created; people already listed get their phone filled in.</span>
      <textarea className="input mono" style={{ minHeight: 140 }} value={csv} onChange={(e) => setCsv(e.target.value)} aria-label="CSV rows" />
      <div className="toolbar"><button className="btn primary small" onClick={run}>Import</button></div>
      <ErrorBox error={err} />
      {res && <div className="notice">Added {res.ghats} ghats, {res.departments} departments, {res.people} people; phones filled for {res.updated}.{res.skipped.length ? ` Skipped: ${res.skipped.join('; ')}` : ''}</div>}
    </section>
  )
}

/** One ghat: its heads and every department with its people. Add, edit, move and remove people. */
function GhatPanel({ ghat, roles, eventId, onClose, onChanged }: { ghat: Ghat; roles: Record<string, string>; eventId: number; onClose: () => void; onChanged: () => void }) {
  const [adding, setAdding] = useState<number | null>(null)
  const [addingDept, setAddingDept] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  async function removeTeam(id: number, name: string) {
    if (!confirm(`Remove ${name} and everyone listed in it?`)) return
    try { await api.del(`/admin/conference-teams/${id}`); onChanged(); if (id === ghat.id) onClose() } catch (x) { setErr(x) }
  }
  return (
    <section className="card ct-panel" style={{ ['--c' as string]: ghat.color ?? '#E3620C' }}>
      <div className="page-head">
        <div><span className="ct-dot" /> <h2 style={{ display: 'inline', fontSize: 20 }}>{ghat.name}</h2><div className="muted" style={{ fontSize: 13 }}>{ghat.counts.departments} departments · {ghat.counts.people} people</div></div>
        <button className="btn small" onClick={onClose}>Close</button>
      </div>
      <ErrorBox error={err} />
      <h3 className="ct-sub">Ghat heads</h3>
      {ghat.heads.map((p) => <PersonRow key={p.id} p={p} roleChoices={HEAD_ROLES} roles={roles} onChanged={onChanged} />)}
      {adding === ghat.id ? <AddPerson teamId={ghat.id} roleChoices={HEAD_ROLES} roles={roles} onDone={() => { setAdding(null); onChanged() }} /> : <button className="btn small ghost" onClick={() => setAdding(ghat.id)}>+ Add ghat head</button>}

      {ghat.departments.map((d) => (
        <div key={d.id} className="ct-dept">
          <div className="ct-dept-head"><b>{d.name}</b><span className="muted">{d.people.length}</span><button className="btn small ghost" onClick={() => removeTeam(d.id, d.name)} title="Remove department">×</button></div>
          {d.people.length === 0 && <span className="muted" style={{ fontSize: 13 }}>No one yet.</span>}
          {d.people.map((p) => <PersonRow key={p.id} p={p} roleChoices={DEPT_ROLES} roles={roles} onChanged={onChanged} />)}
          {adding === d.id ? <AddPerson teamId={d.id} roleChoices={DEPT_ROLES} roles={roles} onDone={() => { setAdding(null); onChanged() }} /> : <button className="btn small ghost" onClick={() => setAdding(d.id)}>+ Add person</button>}
        </div>
      ))}
      {addingDept ? <AddTeam eventId={eventId} parentId={ghat.id} onDone={() => { setAddingDept(false); onChanged() }} /> : <button className="btn small" onClick={() => setAddingDept(true)}>+ Department</button>}
      <button className="btn small danger" style={{ justifySelf: 'start' }} onClick={() => removeTeam(ghat.id, ghat.name)}>Remove this ghat</button>
    </section>
  )
}

interface Found { user_id: number; name: string; mobile: string; member_id: string | null; area: string | null }

function AddPerson({ teamId, roleChoices, roles, onDone }: { teamId: number; roleChoices: string[]; roles: Record<string, string>; onDone: () => void }) {
  const [f, setF] = useState({ name: '', mobile: '', role: roleChoices[roleChoices.length - 1] })
  const [idq, setIdq] = useState('')
  const [found, setFound] = useState<Found | null>(null)
  const [finding, setFinding] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  async function find() {
    if (idq.trim().length < 4) return
    setErr(null); setFinding(true)
    try {
      const r = await api.get<Found>(`/team-members/lookup?q=${encodeURIComponent(idq.trim())}`)
      setFound(r.data); setF({ ...f, name: r.data.name, mobile: r.data.mobile.replace(/^\+91/, '') })
    } catch (x) { setFound(null); setErr(x) } finally { setFinding(false) }
  }
  async function save(e: FormEvent) {
    e.preventDefault(); setErr(null)
    try {
      await api.post(`/teams/${teamId}/members`, { ...f, mobile: f.mobile || null, member_id: found ? (found.member_id ?? found.mobile) : null })
      onDone()
    } catch (x) { setErr(x) }
  }
  return (
    <form className="ct-form" onSubmit={save}>
      <div className="ct-find">
        <input className="input" placeholder="Member ID or mobile – e.g. ABVP-TG-000123" value={idq} autoFocus
          onChange={(e) => { setIdq(e.target.value); setFound(null) }}
          onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); find() } }} aria-label="Member ID or mobile" />
        <button type="button" className="btn small" onClick={find} disabled={finding || idq.trim().length < 4}>{finding ? 'Finding…' : 'Find'}</button>
      </div>
      {found && <div className="ct-found">✓ Found <b>{found.name}</b>{found.member_id && <> · <span className="mono">{found.member_id}</span></>}{found.area && <> · {found.area}</>}</div>}
      <input className="input" placeholder="Name" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} required />
      <input className="input" placeholder="Mobile" inputMode="tel" value={f.mobile} onChange={(e) => { setF({ ...f, mobile: e.target.value }); setFound(null) }} />
      <select className="input" value={f.role} onChange={(e) => setF({ ...f, role: e.target.value })}>{roleChoices.map((r) => <option key={r} value={r}>{roles[r]}</option>)}</select>
      <button className="btn primary small">Add</button>
      <button type="button" className="btn small" onClick={onDone}>Cancel</button>
      {err != null && <div style={{ gridColumn: '1 / -1' }}><ErrorBox error={err instanceof ApiError && err.fields ? new ApiError(422, 'X', Object.values(err.fields)[0][0]) : err} /></div>}
    </form>
  )
}

function PersonRow({ p, roleChoices, roles, onChanged }: { p: Person; roleChoices: string[]; roles: Record<string, string>; onChanged: () => void }) {
  const [edit, setEdit] = useState(false)
  const [f, setF] = useState({ name: p.name, mobile: p.mobile ?? '', role: p.role })
  const [err, setErr] = useState<unknown>(null)
  async function save(e: FormEvent) {
    e.preventDefault(); setErr(null)
    try { await api.patch(`/team-members/${p.id}`, { ...f, mobile: f.mobile || null }); setEdit(false); onChanged() } catch (x) { setErr(x) }
  }
  async function remove() {
    if (!confirm(`Remove ${p.name}?`)) return
    try { await api.del(`/team-members/${p.id}`); onChanged() } catch (x) { setErr(x) }
  }
  if (edit) return (
    <form className="ct-form" onSubmit={save}>
      <input className="input" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} required aria-label="Name" />
      <input className="input" placeholder="Mobile" inputMode="tel" value={f.mobile} onChange={(e) => setF({ ...f, mobile: e.target.value })} aria-label="Mobile" autoFocus />
      <select className="input" value={f.role} onChange={(e) => setF({ ...f, role: e.target.value })} aria-label="Role">{roleChoices.map((r) => <option key={r} value={r}>{roles[r]}</option>)}</select>
      <button className="btn primary small">Save</button>
      <button type="button" className="btn small" onClick={() => setEdit(false)}>Cancel</button>
      {err != null && <div style={{ gridColumn: '1 / -1' }}><ErrorBox error={err} /></div>}
    </form>
  )
  return (
    <div className="ct-person">
      <Avatar name={p.name} size={34} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <b>{p.name}</b> <span className="pill mute">{p.role_label}</span>
        <div className="muted" style={{ fontSize: 12.5 }}>
          {p.mobile ? <><a href={`tel:${p.mobile}`}>{p.mobile}</a> · <a href={wa(p.mobile)} target="_blank" rel="noreferrer">WhatsApp</a></> : 'No phone yet'}
          {' · '}{p.linked ? <span className="ok-text">Using the app</span> : p.mobile ? 'Not signed in yet' : ''}
        </div>
      </div>
      <button className="btn small ghost" onClick={() => setEdit(true)}>{p.mobile ? 'Edit' : 'Add phone'}</button>
      <button className="btn small ghost" onClick={remove} aria-label={`Remove ${p.name}`}>×</button>
      <ErrorBox error={err} />
    </div>
  )
}
