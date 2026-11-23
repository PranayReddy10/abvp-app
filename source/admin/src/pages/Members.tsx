import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api'
import { VerifiedBadge } from '../components/icons'
import { qs } from '../api'
import { Avatar, Empty, ErrorBox, Pill, Skeleton } from '../components/ui'
import { fmtDate } from '../format'
import type { Profile } from '../types'
import { useFetch } from '../useFetch'

interface Row {
  user_id: number; member_id: string; full_name: string; verified: boolean; mobile: string; org_unit: string | null
  institution: string | null; vibhags: string[]; approved_at: string | null
}
interface Detail { user_id: number; mobile: string; profile: Profile; roles: { id: number; label: string; org_unit: string }[]; verified_by: string | null; verification_note: string | null; can_verify: boolean }

interface Account {
  user_id: number; name: string | null; mobile: string; email: string | null; prant: string | null; area: string | null
  institution: string | null; occupation: string | null; membership: string; member_id: string | null; profile_id: number | null
  delegate: boolean; signed_up_at: string | null; last_login_at: string | null; status: string
}

const ACCOUNT_FILTERS: [string, string][] = [['all', 'Everyone'], ['not_applied', 'Not applied'], ['submitted', 'Applied'], ['approved', 'Members'], ['delegate', 'Delegates']]
const MEMBERSHIP: Record<string, [string, string]> = {
  draft: ['Not applied', 'mute'], submitted: ['Applied', 'warn'], more_info_required: ['Needs correction', 'warn'], approved: ['Member', 'ok'], rejected: ['Not approved', 'bad'], suspended: ['Suspended', 'bad'],
}

/** Everyone who signed up – website, app, Google or delegate registration – member or not. */
function Accounts() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('all')
  const [page, setPage] = useState(1)
  const { data, meta, error, loading } = useFetch<Account[]>(`/admin/accounts${qs({ q: search, status: filter, page })}`)
  const lastPage = Number(meta.last_page ?? 1)
  return (
    <>
      <div className="toolbar" style={{ justifyContent: 'space-between', marginBottom: 14 }}>
        <div className="chips" role="tablist" aria-label="Filter accounts">
          {ACCOUNT_FILTERS.map(([k, l]) => <button key={k} role="tab" aria-selected={filter === k} className={`chip ${filter === k ? 'on' : ''}`} onClick={() => { setFilter(k); setPage(1) }}>{l}</button>)}
        </div>
        <form onSubmit={(e) => { e.preventDefault(); setPage(1); setSearch(q) }}>
          <input className="input" style={{ width: 280 }} placeholder="Name, mobile or email" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search accounts" />
        </form>
      </div>
      <ErrorBox error={error} />
      <section className="card">
        <div className="table-wrap">
          <table>
            <thead><tr><th>Name</th><th>Mobile</th><th>Prant / area</th><th>College / work</th><th>Membership</th><th>Signed up</th><th>Last sign-in</th></tr></thead>
            <tbody>
              {data?.map((a) => {
                const [label, tone] = MEMBERSHIP[a.membership] ?? [a.membership, 'mute']
                return (
                  <tr key={a.user_id}>
                    <td>
                      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                        <Avatar name={a.name ?? '?'} size={32} />
                        <div><b>{a.name ?? <span className="muted">No name yet</span>}</b>{a.email && <div className="muted" style={{ fontSize: 12 }}>{a.email}</div>}</div>
                      </div>
                    </td>
                    <td className="mono"><a href={`tel:${a.mobile}`}>{a.mobile}</a></td>
                    <td>{a.area ?? a.prant ?? <span className="muted">–</span>}</td>
                    <td>{[a.institution, a.occupation].filter(Boolean).join(' · ') || <span className="muted">–</span>}</td>
                    <td><span className={`pill ${tone}`}>{label}</span>{a.member_id && <div className="mono muted" style={{ fontSize: 12 }}>{a.member_id}</div>}{a.delegate && <div><span className="pill info" style={{ marginTop: 4 }}>Delegate</span></div>}</td>
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
          <span className="muted">{String(meta.total ?? 0)} accounts</span>
          <button className="btn small" disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button>
          <button className="btn small" disabled={page >= lastPage} onClick={() => setPage(page + 1)}>Next</button>
        </div>
      </section>
      <p className="muted" style={{ fontSize: 13, marginTop: 10 }}>Everyone who created an account on the website or app. They show in Approvals once they apply for membership, and under Members once approved.</p>
    </>
  )
}

export default function Members() {
  const [params] = useSearchParams()
  const [view, setView] = useState<'members' | 'accounts'>(params.get('view') === 'accounts' ? 'accounts' : 'members')
  const [q, setQ] = useState(params.get('q') ?? '')
  const [search, setSearch] = useState(params.get('q') ?? '')
  const [page, setPage] = useState(1)
  const [open, setOpen] = useState<number | null>(null)
  const { data, meta, error, loading } = useFetch<Row[]>(view === 'members' ? `/admin/members${qs({ q: search, page })}` : null)
  const lastPage = Number(meta.last_page ?? 1)

  return (
    <main className="content">
      <div className="page-head">
        <div style={{ display: 'flex', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
          <h1>{view === 'members' ? 'Members' : 'All accounts'}</h1>
          <div className="login-tabs" role="tablist" aria-label="Members or all accounts" style={{ minWidth: 300 }}>
            <button type="button" role="tab" aria-selected={view === 'members'} className={view === 'members' ? 'on' : ''} onClick={() => setView('members')}>Approved members</button>
            <button type="button" role="tab" aria-selected={view === 'accounts'} className={view === 'accounts' ? 'on' : ''} onClick={() => setView('accounts')}>All accounts</button>
          </div>
        </div>
        {view === 'members' && (
          <form onSubmit={(e) => { e.preventDefault(); setPage(1); setSearch(q) }}>
            <input className="input" style={{ width: 280 }} placeholder="Name, Member ID or mobile" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search members" />
          </form>
        )}
      </div>
      {view === 'accounts' ? <Accounts /> : <>
      <ErrorBox error={error} />
      <div className="grid2" style={{ gridTemplateColumns: open ? 'minmax(0,1.5fr) minmax(0,1fr)' : '1fr' }}>
        <section className="card">
          <div className="table-wrap">
            <table>
              <thead><tr><th>Name</th><th>Member ID</th><th>Unit</th><th>Vibhags</th><th>Approved</th></tr></thead>
              <tbody>
                {data?.map((m) => (
                  <tr key={m.user_id} className="click" onClick={() => setOpen(m.user_id)}>
                    <td><b className="name-badge">{m.full_name}{m.verified && <VerifiedBadge />}</b><div className="muted" style={{ fontSize: 12 }}>{m.institution}</div></td>
                    <td className="mono">{m.member_id}</td>
                    <td>{m.org_unit}</td>
                    <td>{m.vibhags.join(', ')}</td>
                    <td>{fmtDate(m.approved_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {data?.length === 0 && <Empty>No members match.</Empty>}
            {loading && !data && <Skeleton />}
          </div>
          <div className="pager">
            <span className="muted">{String(meta.total ?? 0)} members</span>
            <button className="btn small" disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button>
            <button className="btn small" disabled={page >= lastPage} onClick={() => setPage(page + 1)}>Next</button>
          </div>
        </section>
        {open && <MemberCard id={open} onClose={() => setOpen(null)} />}
      </div>
      </>}
    </main>
  )
}

function MemberCard({ id, onClose }: { id: number; onClose: () => void }) {
  const { data, error, reload } = useFetch<Detail>(`/admin/members/${id}`)
  const [note, setNote] = useState('')
  const [err, setErr] = useState<unknown>(null)
  async function setVerified(verified: boolean) {
    setErr(null)
    try { await api.post(`/admin/members/${id}/verify`, { verified, note: note || null }); setNote(''); reload() } catch (x) { setErr(x) }
  }
  if (error) return <section className="card"><ErrorBox error={error} /></section>
  if (!data) return <section className="card"><Skeleton /></section>
  const p = data.profile

  return (
    <section className="card" aria-label="Member details">
      <div className="page-head">
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <Avatar name={p.full_name} src={p.photo_url} size={48} />
          <div><h2 style={{ fontSize: 18 }} className="name-badge">{p.full_name}{p.verified && <VerifiedBadge size={18} />}</h2><span className="mono muted">{p.member_id}</span></div>
        </div>
        <button className="btn small" onClick={onClose}>Close</button>
      </div>
      <div className="toolbar">{p.verified ? <VerifiedBadge label /> : <Pill status={p.membership_status} />}</div>
      <section className="verify-box">
        {p.verified ? (
          <>
            <span>Identity verified{data.verified_by ? ` by ${data.verified_by}` : ''}{p.verified_at ? ` on ${fmtDate(p.verified_at)}` : ''}.{data.verification_note ? ` “${data.verification_note}”` : ''}</span>
            {data.can_verify && <button className="btn small danger" onClick={() => setVerified(false)}>Remove tick</button>}
          </>
        ) : data.can_verify ? (
          <>
            <span className="muted">Checked their ID or met them in person? Give them the blue tick.</span>
            <div className="toolbar"><input className="input" style={{ flex: 1, minWidth: 160 }} placeholder="How you checked (optional)" value={note} onChange={(e) => setNote(e.target.value)} aria-label="Verification note" />
              <button className="btn small verify-btn" onClick={() => setVerified(true)}><VerifiedBadge size={14} />Verify identity</button></div>
          </>
        ) : <span className="muted">Not verified yet. State or district admins can verify.</span>}
        <ErrorBox error={err} />
      </section>
      <div className="dl"><span>Mobile</span><b className="mono">{data.mobile}</b></div>
      <div className="dl"><span>Unit</span><b>{p.org_unit?.label}</b></div>
      <div className="dl"><span>Institution</span><b>{[p.institution, p.course].filter(Boolean).join(' · ') || '–'}</b></div>
      <div className="dl"><span>Vibhags</span><b>{p.vibhags.map((v) => v.name).join(', ') || '–'}</b></div>
      <div className="dl"><span>Dayitva</span>
        {p.responsibilities.length === 0 ? <b>–</b> : p.responsibilities.map((r) => (
          <b key={r.id}>{r.title}{r.org_unit ? `, ${r.org_unit.name}` : ''} <span className="muted">({r.starts_on.slice(0, 4)}–{r.ends_on?.slice(0, 4) ?? ''})</span></b>
        ))}
      </div>
      <div className="dl"><span>Admin roles</span>{data.roles.length === 0 ? <b>None</b> : data.roles.map((r) => <b key={r.id}>{r.label}, {r.org_unit}</b>)}</div>
    </section>
  )
}
