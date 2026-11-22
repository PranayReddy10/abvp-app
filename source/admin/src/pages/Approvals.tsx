import { useEffect, useState } from 'react'
import { api, qs } from '../api'
import { useAuth } from '../auth'
import { Avatar, Empty, ErrorBox, Pill, Skeleton } from '../components/ui'
import { ACTION_LABEL, fmtDate, fmtTime } from '../format'
import type { ApplicationDetail, ApplicationRow } from '../types'
import { useFetch } from '../useFetch'

const TABS = [
  { key: 'submitted', label: 'Waiting' },
  { key: 'more_info_required', label: 'Returned' },
  { key: 'approved', label: 'Approved' },
  { key: 'rejected', label: 'Rejected' },
]

export default function Approvals() {
  const [status, setStatus] = useState('submitted')
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<number | null>(null)
  const [flash, setFlash] = useState<string | null>(null)
  const list = useFetch<ApplicationRow[]>(`/admin/applications${qs({ status, q: search })}`)

  useEffect(() => {
    if (list.data && !list.data.some((a) => a.id === selected)) setSelected(list.data[0]?.id ?? null)
  }, [list.data, selected])

  return (
    <main className="content">
      <div className="page-head">
        <h1>Membership approvals</h1>
        <form className="chips" onSubmit={(e) => { e.preventDefault(); setSearch(q) }}>
          <input className="input" style={{ width: 240 }} placeholder="Search name or mobile" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search applications" />
        </form>
      </div>
      <div className="chips" role="tablist">
        {TABS.map((t) => (
          <button key={t.key} role="tab" aria-selected={status === t.key} className={`chip ${status === t.key ? 'on' : ''}`}
            onClick={() => { setStatus(t.key); setSelected(null) }}>
            {t.label}{status === t.key && list.meta.total !== undefined ? ` · ${list.meta.total}` : ''}
          </button>
        ))}
      </div>
      <ErrorBox error={list.error} />
      {flash && <div className="notice" role="status">{flash}</div>}
      <div className="queue">
        <div className="card qlist">
          {list.data?.length === 0 && <Empty>No applications here.</Empty>}
          {list.data?.map((a) => (
            <button key={a.id} className={`qi ${a.id === selected ? 'on' : ''}`} onClick={() => { setSelected(a.id); setFlash(null) }}>
              <Avatar name={a.applicant.name} />
              <span><b>{a.applicant.name}</b><small>{a.org_unit.name} · {a.waiting_days ?? 0} days</small></span>
              <Pill status={a.status} />
            </button>
          ))}
        </div>
        {selected ? <Review id={selected} onDecided={(msg) => { setFlash(msg); list.reload(); window.dispatchEvent(new Event('abvp:queue-changed')) }} /> : <div className="card"><Empty>Select an application to review it.</Empty></div>}
      </div>
    </main>
  )
}

function Review({ id, onDecided }: { id: number; onDecided: (message: string) => void }) {
  const { can } = useAuth()
  const { data: a, error, reload } = useFetch<ApplicationDetail>(`/admin/applications/${id}`)
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [actionError, setActionError] = useState<unknown>(null)

  useEffect(() => { setNote(''); setActionError(null) }, [id])

  async function decide(action: 'approve' | 'return' | 'reject') {
    if (action !== 'approve' && note.trim().length < 5) {
      setActionError(new Error('Write a note for the applicant explaining what to fix or why.'))
      return
    }
    setBusy(true); setActionError(null)
    try {
      const r = await api.post<ApplicationDetail>(`/admin/applications/${id}/${action}`, { note: note.trim() || undefined })
      const name = r.data.applicant.name
      onDecided(action === 'approve'
        ? `${name} approved. Member ID ${r.data.profile?.member_id}.`
        : action === 'return' ? `${name}'s application was returned for correction.` : `${name}'s application was rejected. They can see your note.`)
      await reload()
    } catch (e) { setActionError(e) } finally { setBusy(false) }
  }

  if (error) return <div className="card"><ErrorBox error={error} /></div>
  if (!a) return <div className="card"><Skeleton /></div>
  const p = a.profile

  return (
    <section className="card review" aria-label="Application review">
      <div className="hd">
        <Avatar name={a.applicant.name} src={p?.photo_url} size={44} />
        <div><h2 style={{ fontSize: 18 }}>{a.applicant.name}</h2><span className="muted">Applied {fmtDate(a.submitted_at)} · mobile verified</span></div>
        <div style={{ marginLeft: 'auto' }}><Pill status={a.status} /></div>
      </div>
      <div className="bd">
        <div className="dl"><span>Mobile</span><b className="mono">{a.applicant.mobile}</b></div>
        <div className="dl"><span>Date of birth</span><b>{fmtDate(p?.date_of_birth)}</b></div>
        <div className="dl"><span>Area</span><b>{a.org_unit.label}</b></div>
        <div className="dl"><span>Institution</span><b>{[p?.institution, p?.course, p?.study_year].filter(Boolean).join(' · ') || '–'}</b></div>
        <div className="dl"><span>Vibhags</span><b>{p?.vibhags.map((v) => v.name).join(', ') || '–'}</b></div>
        <div className="dl"><span>Gender</span><b style={{ textTransform: 'capitalize' }}>{p?.gender ?? '–'}</b></div>
        <div className="full">
          {p?.photo_url ? <img className="photo" src={p.photo_url} alt={`Photo of ${a.applicant.name}`} /> : <span className="muted">No photo uploaded</span>}
        </div>
        <div className="full history">
          <b>History</b>
          {a.history.map((h, i) => (
            <div key={i}><span className="muted">{fmtTime(h.at)}</span><span>{ACTION_LABEL[h.action] ?? h.action}{h.actor && h.action !== 'submitted' && h.action !== 'resubmitted' ? ` by ${h.actor}` : ''}{h.note ? `: “${h.note}”` : ''}</span></div>
          ))}
        </div>
      </div>
      {a.status === 'submitted' && can('members.review') && (
        <div className="ft">
          <ErrorBox error={actionError} />
          <textarea className="input" placeholder="Note to the applicant (required to return or reject)" value={note} onChange={(e) => setNote(e.target.value)} aria-label="Note to applicant" />
          <div className="chips">
            <button className="btn good" disabled={busy} onClick={() => decide('approve')}>Approve</button>
            <button className="btn" disabled={busy} onClick={() => decide('return')}>Return for correction</button>
            <button className="btn danger" disabled={busy} onClick={() => decide('reject')}>Reject</button>
          </div>
        </div>
      )}
    </section>
  )
}
