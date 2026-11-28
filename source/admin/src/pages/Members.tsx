import { useState, type FormEvent } from 'react'
import { api, ApiError } from '../api'
import { useAuth } from '../auth'
import { VerifiedBadge } from '../components/icons'
import { qs } from '../api'
import { Avatar, Empty, ErrorBox, Skeleton } from '../components/ui'
import { fmtDate } from '../format'
import type { Profile } from '../types'
import { useFetch } from '../useFetch'

interface Account {
  user_id: number; name: string | null; mobile: string; email: string | null; prant: string | null; area: string | null
  institution: string | null; occupation: string | null; membership: string; member_id: string | null; profile_id: number | null
  delegate: boolean; signed_up_at: string | null; last_login_at: string | null; status: string
  verified?: boolean; photo_url?: string | null
}

const ACCOUNT_FILTERS: [string, string][] = [['all', 'Everyone'], ['verified', 'Verified ✓'], ['unverified', 'Not verified'], ['delegate', 'Delegates']]

/** Everyone who signed up – website, app, Google or delegate registration – member or not. */
function Accounts() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('all')
  const [page, setPage] = useState(1)
  const [open, setOpen] = useState<number | null>(null)
  const [adding, setAdding] = useState(false)
  const { data, meta, error, loading, reload } = useFetch<Account[]>(`/admin/accounts${qs({ q: search, status: filter, page })}`)
  const lastPage = Number(meta.last_page ?? 1)
  return (
    <>
      {adding && <AddAccount onClose={() => setAdding(false)} onCreated={reload} onAdded={(id) => { setAdding(false); setFilter('all'); setSearch(''); setQ(''); setPage(1); reload(); setOpen(id) }} />}
      <div className="toolbar" style={{ justifyContent: 'space-between', marginBottom: 14 }}>
        <div className="chips" role="tablist" aria-label="Filter accounts">
          {ACCOUNT_FILTERS.map(([k, l]) => <button key={k} role="tab" aria-selected={filter === k} className={`chip ${filter === k ? 'on' : ''}`} onClick={() => { setFilter(k); setPage(1) }}>{l}</button>)}
        </div>
        <form onSubmit={(e) => { e.preventDefault(); setPage(1); setSearch(q) }}>
          <input className="input" style={{ width: 280 }} placeholder="Name, mobile or email" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search accounts" />
        </form>
        {!adding && <button className="btn primary" onClick={() => setAdding(true)}>+ Add member</button>}
      </div>
      <ErrorBox error={error} />
      <div className="grid2" style={{ gridTemplateColumns: open ? 'minmax(0,1.5fr) minmax(0,1fr)' : '1fr', alignItems: 'start' }}>
      <section className="card">
        <div className="table-wrap">
          <table>
            <thead><tr><th>Name</th><th>Mobile</th><th>Area</th><th>College / work</th><th>Member ID</th><th>Signed up</th><th>Last sign-in</th></tr></thead>
            <tbody>
              {data?.map((a) => {
                return (
                  <tr key={a.user_id} className={`click ${open === a.user_id ? 'on' : ''}`} onClick={() => setOpen(a.user_id)}>
                    <td>
                      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                        <Avatar name={a.name ?? '?'} src={a.photo_url} size={32} />
                        <div><b className="name-badge">{a.name ?? <span className="muted">No name yet</span>}{a.verified && <VerifiedBadge />}</b>{a.email && <div className="muted" style={{ fontSize: 12 }}>{a.email}</div>}</div>
                      </div>
                    </td>
                    <td className="mono"><a href={`tel:${a.mobile}`} onClick={(e) => e.stopPropagation()}>{a.mobile}</a></td>
                    <td>{a.area ?? a.prant ?? <span className="muted">–</span>}</td>
                    <td>{[a.institution, a.occupation].filter(Boolean).join(' · ') || <span className="muted">–</span>}</td>
                    <td>{a.status === 'suspended' && <div><span className="pill bad" style={{ marginBottom: 4 }}>Blocked</span></div>}<span className="mono" style={{ fontSize: 12.5 }}>{a.member_id ?? '–'}</span>{a.delegate && <div><span className="pill info" style={{ marginTop: 4 }}>Delegate</span></div>}</td>
                    <td>{fmtDate(a.signed_up_at)}</td>
                    <td>{a.last_login_at ? fmtDate(a.last_login_at) : <span className="muted">–</span>}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          {data?.length === 0 && <Empty>No accounts match.</Empty>}
          {loading && !data && <Skeleton />}
        </div>
        <div className="pager">
          <span className="muted">{String(meta.total ?? 0)} members</span>
          <button className="btn small" disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button>
          <button className="btn small" disabled={page >= lastPage} onClick={() => setPage(page + 1)}>Next</button>
        </div>
      </section>
      {open && <AccountCard key={open} id={open} onClose={() => setOpen(null)} onChanged={reload} />}
      </div>
      <p className="muted" style={{ fontSize: 13, marginTop: 10 }}>Everyone who signs up on the website or app is a member with a member ID. Open a member to check their details and give the blue tick (verified).</p>
    </>
  )
}

interface AccountDetail {
  user_id: number; name: string | null; mobile: string; email: string | null; prant: string | null; occupation: string | null
  gender: string | null; institution: string | null; status: string; has_password: boolean; google_linked: boolean; mobile_verified: boolean
  signed_up_at: string | null; last_login_at: string | null; profile: Profile | null
  application: { status: string; submitted_at: string | null; decision_note: string | null; office: string | null } | null
  roles: { label: string; org_unit: string }[]; events: { title: string; starts_at: string | null; kind: string; status: string }[]
  posts: number; can_manage: boolean; can_edit?: boolean; verified?: boolean; verified_at?: string | null
  delegate: Delegate | null
}
interface Delegate {
  event: { id: number; title: string }
  registration: { status: string; details: Record<string, string | null>; travel: { mode: string; reference: string | null; arrival_point: string | null; arriving_at: string | null; departing_at: string | null } | null } | null
  options: { prants: string[]; arrival_points: string[]; modes: { key: string; label: string }[] }
  prefill: Record<string, string | null>
}

/** Everything about one account, with Block / Unblock and Delete. */
function AccountCard({ id, onClose, onChanged }: { id: number; onClose: () => void; onChanged: () => void }) {
  const { data, error, reload } = useFetch<AccountDetail>(`/admin/accounts/${id}`)
  const [confirmName, setConfirmName] = useState('')
  const [deleting, setDeleting] = useState(false)
  const [editing, setEditing] = useState(false)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  if (error) return <section className="card"><ErrorBox error={error} /><button className="btn small" onClick={onClose}>Close</button></section>
  if (!data) return <section className="card"><Skeleton /></section>
  const p = data.profile
  const blocked = data.status === 'suspended'

  async function verify(v: boolean) {
    setBusy(true); setErr(null)
    try { await api.post(`/admin/accounts/${id}/verify`, { verified: v }); reload(); onChanged() } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  async function photo(file?: File) {
    if (!file) return
    const fd = new FormData(); fd.append('photo', file)
    setBusy(true); setErr(null)
    try { await api.post(`/admin/accounts/${id}/photo`, fd); reload(); onChanged() } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  async function removePhoto() {
    if (!confirm('Remove this photo?')) return
    setBusy(true); setErr(null)
    try { await api.del(`/admin/accounts/${id}/photo`); reload(); onChanged() } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  async function block(b: boolean) {
    setBusy(true); setErr(null)
    try { await api.post(`/admin/accounts/${id}/block`, { blocked: b }); reload(); onChanged() } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  async function remove() {
    setBusy(true); setErr(null)
    try { await api.del(`/admin/accounts/${id}`); onChanged(); onClose() } catch (x) { setErr(x); setBusy(false) }
  }

  return (
    <section className="card account-card" aria-label="Account details">
      <div className="page-head">
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <Avatar name={data.name ?? '?'} src={p?.photo_url} size={56} />
          <div>
            <h2 style={{ fontSize: 18 }} className="name-badge">{data.name ?? 'No name yet'}{p?.verified && <VerifiedBadge size={18} />}</h2>
            <span className="mono muted">{p?.member_id ?? 'No ID'}</span>
          </div>
        </div>
        <button className="btn small" onClick={onClose}>Close</button>
      </div>
      <div className="toolbar">
        {blocked ? <span className="pill bad">Blocked</span> : <span className="pill ok">Active</span>}
        {data.verified ? <span className="pill info">✓ Verified</span> : <span className="pill mute">Not verified</span>}
        {data.delegate?.registration && <span className="pill warn">Delegate</span>}
        {data.roles.map((r) => <span key={r.label + r.org_unit} className="pill info">{r.label}, {r.org_unit}</span>)}
      </div>

      <div className="verify-box">
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <span style={{ flex: 1, minWidth: 180 }}>{data.verified ? <>Blue tick given{data.verified_at ? ` on ${fmtDate(data.verified_at)}` : ''}. Their name shows with ✓ everywhere.</> : 'Check their details and photo, then give the blue tick.'}</span>
          {data.verified
            ? <button className="btn small" disabled={busy} onClick={() => verify(false)}>Remove blue tick</button>
            : <button className="btn small primary" disabled={busy} onClick={() => verify(true)}>✓ Verify (blue tick)</button>}
        </div>
        {data.can_edit && (
          <div className="toolbar">
            <label className="btn small">{p?.photo_url ? 'Change photo' : 'Add photo'}<input type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={(e) => { photo(e.target.files?.[0]); e.target.value = '' }} /></label>
            {p?.photo_url && <button className="btn small" disabled={busy} onClick={removePhoto}>Remove photo</button>}
            <button className="btn small" onClick={() => setEditing(!editing)}>{editing ? 'Close editing' : 'Edit details'}</button>
          </div>
        )}
      </div>
      {editing && <EditDetails id={id} data={data} onSaved={() => { setEditing(false); reload(); onChanged() }} />}
      <div className="dl"><span>Mobile</span><b className="mono"><a href={`tel:${data.mobile}`}>{data.mobile}</a>{data.mobile_verified ? ' · verified' : ' · not verified'}</b></div>
      <div className="dl"><span>Email</span><b>{data.email ?? '–'}</b></div>
      <div className="dl"><span>Area</span><b>{p?.org_unit?.label ?? data.prant ?? '–'}</b></div>
      <div className="dl"><span>Date of birth · gender</span><b>{[p?.date_of_birth ? fmtDate(p.date_of_birth) : null, data.gender].filter(Boolean).join(' · ') || '–'}</b></div>
      <div className="dl"><span>College / work</span><b>{[data.institution, p?.course, p?.study_year, data.occupation].filter(Boolean).join(' · ') || '–'}</b></div>
      <div className="dl"><span>Vibhags</span><b>{p?.vibhags?.map((v) => v.name).join(', ') || '–'}</b></div>
      {p?.bio && <div className="dl"><span>About</span><b style={{ fontWeight: 500 }}>{p.bio}</b></div>}
      <div className="dl"><span>Sign-in</span><b>{[data.has_password ? 'Password' : null, data.google_linked ? 'Google' : null, 'SMS code'].filter(Boolean).join(' · ')}</b></div>
      <div className="dl"><span>Signed up · last sign-in</span><b>{fmtDate(data.signed_up_at)} · {data.last_login_at ? fmtDate(data.last_login_at) : 'never'}</b></div>
      <div className="dl"><span>Events</span>{data.events.length === 0 ? <b>–</b> : data.events.map((e, i) => <b key={i}>{e.title} <span className="muted">({e.kind}, {e.status})</span></b>)}</div>
      <div className="dl"><span>Community posts</span><b>{data.posts}</b></div>
      {data.delegate && <DelegateBox id={id} d={data.delegate} canEdit={!!data.can_edit} onSaved={() => { reload(); onChanged() }} />}

      <ErrorBox error={err} />
      {data.can_manage ? (
        <div className="verify-box">
          {!blocked ? (
            <>
              <span className="muted">Blocking signs them out everywhere and stops them signing in. You can unblock any time.</span>
              <div className="toolbar">
                <button className="btn small danger" disabled={busy} onClick={() => block(true)}>Block account</button>
              </div>
            </>
          ) : <div className="toolbar"><span className="muted" style={{ flex: 1 }}>This account is blocked.</span><button className="btn small good" disabled={busy} onClick={() => block(false)}>Unblock</button></div>}
          {!deleting ? (
            <button className="btn small danger" style={{ justifySelf: 'start' }} onClick={() => setDeleting(true)}>Delete account…</button>
          ) : (
            <div style={{ display: 'grid', gap: 8 }}>
              <span className="bad-text" style={{ fontWeight: 600 }}>This deletes their details, photo, posts and comments for good. Their mobile number can register again. Type the name to confirm.</span>
              <div className="toolbar">
                <input className="input" style={{ flex: 1, minWidth: 160 }} placeholder={data.name ?? ''} value={confirmName} onChange={(e) => setConfirmName(e.target.value)} aria-label="Type the name to confirm" />
                <button className="btn small danger" disabled={busy || confirmName.trim() !== (data.name ?? '').trim()} onClick={remove}>Delete for good</button>
                <button className="btn small" onClick={() => { setDeleting(false); setConfirmName('') }}>Cancel</button>
              </div>
            </div>
          )}
        </div>
      ) : <p className="muted" style={{ fontSize: 13 }}>Admins, super admins and your own account cannot be blocked or deleted here.</p>}
    </section>
  )
}

export default function Members() {
  return (
    <main className="content">
      <div className="page-head">
        <div>
          <h1>Members</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>Everyone who signed up. Verified members carry the blue tick ✓.</p>
        </div>
      </div>
      <Accounts />
    </main>
  )
}

/** Change what the person entered. */
function EditDetails({ id, data, onSaved }: { id: number; data: AccountDetail; onSaved: () => void }) {
  const p = data.profile
  const [f, setF] = useState({
    full_name: data.name ?? '', gender: data.gender ?? '', date_of_birth: p?.date_of_birth ?? '', email: data.email ?? '',
    institution: data.institution ?? '', course: p?.course ?? '', occupation: data.occupation ?? '', bio: p?.bio ?? '',
  })
  const [area, setArea] = useState<number | null>(null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF({ ...f, [k]: e.target.value })
  async function save(e: FormEvent) {
    e.preventDefault(); setBusy(true); setErr(null)
    const body: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(f)) body[k] = v.trim() === '' ? null : v.trim()
    if (!body.full_name) delete body.full_name
    if (area) body.org_unit_id = area
    try { await api.patch(`/admin/accounts/${id}`, body); onSaved() } catch (x) { setErr(x instanceof ApiError && x.fields ? new ApiError(422, 'X', Object.values(x.fields)[0][0]) : x) } finally { setBusy(false) }
  }
  return (
    <form className="card" style={{ display: 'grid', gap: 10, background: 'var(--surface-2, #fafafa)' }} onSubmit={save}>
      <b>Edit details</b>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 10 }}>
        <div className="field"><label>Full name</label><input className="input" value={f.full_name} onChange={set('full_name')} /></div>
        <div className="field"><label>Gender</label><select className="input" value={f.gender} onChange={set('gender')}><option value="">–</option><option value="male">Male</option><option value="female">Female</option><option value="other">Other</option></select></div>
        <div className="field"><label>Date of birth</label><input type="date" className="input" value={f.date_of_birth} onChange={set('date_of_birth')} /></div>
        <div className="field"><label>Email</label><input className="input" value={f.email} onChange={set('email')} /></div>
        <div className="field"><label>College</label><input className="input" value={f.institution} onChange={set('institution')} /></div>
        <div className="field"><label>Course</label><input className="input" value={f.course} onChange={set('course')} /></div>
        <div className="field"><label>Occupation</label><input className="input" value={f.occupation} onChange={set('occupation')} /></div>
      </div>
      <div className="field"><label>Area – now {p?.org_unit?.label || data.prant || 'not set'}; choose to change</label><AreaChain onChange={setArea} /></div>
      <div className="field"><label>About</label><textarea className="input" rows={2} value={f.bio} onChange={set('bio')} /></div>
      <ErrorBox error={err} />
      <div><button className="btn primary small" disabled={busy}>{busy ? 'Saving…' : 'Save details'}</button></div>
    </form>
  )
}

const local = (iso: string | null | undefined) => {
  if (!iso) return ''
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/** The delegate form for the current conference: see it, change it, or fill it in for them. */
function DelegateBox({ id, d, canEdit, onSaved }: { id: number; d: Delegate; canEdit: boolean; onSaved: () => void }) {
  const r = d.registration
  const det = r?.details ?? {}
  const t = r?.travel
  const pick = (k: string) => (det[k] ?? d.prefill[k] ?? '') as string
  const [open, setOpen] = useState(false)
  const [f, setF] = useState({
    first_name: pick('first_name'), surname: pick('surname'), mobile: pick('mobile').replace(/^\+91/, ''), email: pick('email'),
    gender: pick('gender'), prant: pick('prant'), responsibility: pick('responsibility'),
    arriving_at: local(t?.arriving_at), arrival_point: t?.arrival_point ?? '', departing_at: local(t?.departing_at),
    mode: t?.mode ?? '', reference: t?.reference ?? '',
  })
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF({ ...f, [k]: e.target.value })
  async function save(e: FormEvent) {
    e.preventDefault(); setBusy(true); setErr(null)
    try {
      await api.put(`/admin/accounts/${id}/delegate`, {
        ...f, email: f.email || null, reference: f.reference || null,
        arriving_at: f.arriving_at ? new Date(f.arriving_at).toISOString() : null,
        departing_at: f.departing_at ? new Date(f.departing_at).toISOString() : null,
      })
      setOpen(false); onSaved()
    } catch (x) { setErr(x instanceof ApiError && x.fields ? new ApiError(422, 'X', Object.values(x.fields)[0][0]) : x) } finally { setBusy(false) }
  }
  const when = (iso: string | null | undefined) => (iso ? new Date(iso).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }) : '–')
  const mode = d.options.modes.find((m) => m.key === t?.mode)?.label ?? t?.mode
  return (
    <div className="verify-box">
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <b style={{ flex: 1 }}>Delegate form · {d.event.title}</b>
        {canEdit && <button className="btn small" onClick={() => setOpen(!open)}>{open ? 'Close' : r ? 'Edit delegate form' : 'Fill delegate form'}</button>}
      </div>
      {!r && !open && <span className="muted">Not registered as a delegate yet.</span>}
      {r && !open && (
        <>
          <div className="dl"><span>Name</span><b>{[det.first_name, det.surname].filter(Boolean).join(' ') || '–'}</b></div>
          <div className="dl"><span>Mobile · email</span><b>{[det.mobile, det.email].filter(Boolean).join(' · ') || '–'}</b></div>
          <div className="dl"><span>Gender · prant</span><b>{[det.gender, det.prant].filter(Boolean).join(' · ') || '–'}</b></div>
          <div className="dl"><span>Responsibility</span><b>{det.responsibility || '–'}</b></div>
          <div className="dl"><span>Arrival</span><b>{when(t?.arriving_at)} · {t?.arrival_point ?? '–'}</b></div>
          <div className="dl"><span>Departure</span><b>{when(t?.departing_at)}</b></div>
          <div className="dl"><span>Travel</span><b>{[mode, t?.reference].filter(Boolean).join(' · ') || '–'}</b></div>
        </>
      )}
      {open && (
        <form style={{ display: 'grid', gap: 10 }} onSubmit={save}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: 10 }}>
            <div className="field"><label>First name</label><input className="input" required value={f.first_name} onChange={set('first_name')} /></div>
            <div className="field"><label>Surname</label><input className="input" required value={f.surname} onChange={set('surname')} /></div>
            <div className="field"><label>Mobile</label><input className="input" required value={f.mobile} onChange={set('mobile')} /></div>
            <div className="field"><label>Email (optional)</label><input className="input" value={f.email} onChange={set('email')} /></div>
            <div className="field"><label>Gender</label><select className="input" required value={f.gender} onChange={set('gender')}><option value="">Choose…</option><option value="male">Male</option><option value="female">Female</option><option value="other">Other</option></select></div>
            <div className="field"><label>Prant</label><select className="input" required value={f.prant} onChange={set('prant')}><option value="">Choose…</option>{d.options.prants.map((x) => <option key={x}>{x}</option>)}</select></div>
            <div className="field"><label>Responsibility</label><input className="input" required value={f.responsibility} onChange={set('responsibility')} /></div>
            <div className="field"><label>Arrival</label><input type="datetime-local" className="input" required value={f.arriving_at} onChange={set('arriving_at')} /></div>
            <div className="field"><label>Arrival place</label><input className="input" required list="arr-points" value={f.arrival_point} onChange={set('arrival_point')} /><datalist id="arr-points">{d.options.arrival_points.map((x) => <option key={x} value={x} />)}</datalist></div>
            <div className="field"><label>Departure</label><input type="datetime-local" className="input" required value={f.departing_at} onChange={set('departing_at')} /></div>
            <div className="field"><label>Coming by</label><select className="input" required value={f.mode} onChange={set('mode')}><option value="">Choose…</option>{d.options.modes.map((m) => <option key={m.key} value={m.key}>{m.label}</option>)}</select></div>
          </div>
          <ErrorBox error={err} />
          <div><button className="btn primary small" disabled={busy}>{busy ? 'Saving…' : 'Save delegate form'}</button></div>
        </form>
      )}
    </div>
  )
}

interface Unit { id: number; name: string; type?: string }

/** State → district → … : each choice opens the areas inside it. */
function AreaChain({ onChange }: { onChange: (id: number | null) => void }) {
  const { me } = useAuth()
  const scope = me?.roles[0]?.org_unit ?? null
  const [path, setPath] = useState<Unit[]>([])
  const parent = path.length ? path[path.length - 1] : scope
  const kids = useFetch<Unit[]>(parent ? `/org/units?parent_id=${parent.id}` : null)
  function pick(level: number, id: string, list: Unit[]) {
    const u = list.find((x) => String(x.id) === id)
    const next = [...path.slice(0, level), ...(u ? [u] : [])]
    setPath(next)
    onChange(next.length ? next[next.length - 1].id : scope?.id ?? null)
  }
  return (
    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
      {path.map((u, i) => (
        <span key={u.id} className="pill">{u.name} <button type="button" style={{ border: 0, background: 'none', cursor: 'pointer', padding: '0 2px' }} aria-label={`Change ${u.name}`} onClick={() => pick(i, '', [])}>×</button></span>
      ))}
      {kids.data && kids.data.length > 0 && (
        <select className="input" style={{ maxWidth: 240 }} value="" onChange={(e) => pick(path.length, e.target.value, kids.data!)} aria-label="Area">
          <option value="">{path.length === 0 ? `Choose state / area in ${scope?.name ?? 'India'}…` : `Inside ${parent?.name}…`}</option>
          {kids.data.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
        </select>
      )}
    </div>
  )
}

/** Add a person directly: they get an account, a member ID and (optionally) a password. */
function AddAccount({ onClose, onAdded, onCreated }: { onClose: () => void; onAdded: (id: number) => void; onCreated: () => void }) {
  const [f, setF] = useState({ name: '', mobile: '', password: '', approve: true })
  const { me } = useAuth()
  const [area, setArea] = useState<number | null>(me?.roles[0]?.org_unit?.id ?? null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [done, setDone] = useState<{ user_id: number; name: string; member_id: string | null } | null>(null)
  async function save(e: FormEvent) {
    e.preventDefault(); setErr(null); setBusy(true)
    try {
      const r = await api.post<{ user_id: number; name: string; member_id: string | null }>('/admin/accounts', { ...f, password: f.password || null, org_unit_id: area })
      setDone(r.data); onCreated()
    } catch (x) { setErr(x instanceof ApiError && x.fields ? new ApiError(422, 'X', Object.values(x.fields)[0][0]) : x) } finally { setBusy(false) }
  }
  if (done) return (
    <section className="card" style={{ marginBottom: 14 }}>
      <h2 style={{ marginTop: 0 }}>{done.name} added</h2>
      <p>Member ID <b className="mono">{done.member_id ?? '—'}</b>. They can sign in with their mobile{f.password ? ' and the password you set' : ''}.</p>
      <div className="toolbar"><button className="btn primary" onClick={() => onAdded(done.user_id)}>Open profile</button><button className="btn" onClick={() => { setDone(null); setF({ name: '', mobile: '', password: '', approve: true }) }}>Add another</button></div>
    </section>
  )
  return (
    <form className="card" style={{ marginBottom: 14, display: 'grid', gap: 12 }} onSubmit={save}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><h2 style={{ margin: 0 }}>Add member</h2><button type="button" className="btn small" onClick={onClose}>Close</button></div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12 }}>
        <div className="field"><label htmlFor="am-name">Full name</label><input id="am-name" className="input" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} required minLength={2} autoFocus /></div>
        <div className="field"><label htmlFor="am-mob">Mobile</label><input id="am-mob" className="input" inputMode="tel" placeholder="10-digit number" value={f.mobile} onChange={(e) => setF({ ...f, mobile: e.target.value })} required /></div>
        <div className="field"><label htmlFor="am-pw">Password (optional)</label><input id="am-pw" className="input" type="text" minLength={8} placeholder="At least 8 characters" value={f.password} onChange={(e) => setF({ ...f, password: e.target.value })} /></div>
      </div>
      <div className="field"><label>Area</label><AreaChain onChange={setArea} /></div>
      <label style={{ display: 'flex', gap: 8, alignItems: 'center' }}><input type="checkbox" checked={f.approve} onChange={(e) => setF({ ...f, approve: e.target.checked })} /> Approve as member straight away</label>
      <ErrorBox error={err} />
      <div><button className="btn primary" disabled={busy}>{busy ? 'Adding…' : 'Add member'}</button></div>
    </form>
  )
}
