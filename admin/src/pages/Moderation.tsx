import { useState } from 'react'
import { api, ApiError } from '../api'
import { Icon, VerifiedBadge } from '../components/icons'
import { Avatar, Empty, ErrorBox, Skeleton } from '../components/ui'
import { fmtNum, fmtTime } from '../format'
import { useFetch } from '../useFetch'

interface Flagged {
  id: number
  body: string | null
  photo_urls: string[]
  author: { name: string | null; member_id: string | null; place: string | null; verified: boolean }
  audience: string
  likes: number
  comments: number
  reports_count: number
  reasons: { reason: string; count: number }[]
  notes: string[]
  hidden: boolean
  hidden_reason: string | null
  at: string
}

const TABS = [
  { key: 'reported', label: 'Reported' },
  { key: 'hidden', label: 'Hidden' },
]

const AUDIENCE: Record<string, string> = { members: 'All members', area: 'District only', vibhag: 'Vibhag' }

/** Community posts members reported, from authors inside the admin's area. */
export default function Moderation() {
  const [status, setStatus] = useState('reported')
  const list = useFetch<Flagged[]>(`/admin/moderation?status=${status}`)
  const [busy, setBusy] = useState<number | null>(null)
  const [reasons, setReasons] = useState<Record<number, string>>({})
  const [flash, setFlash] = useState<string | null>(null)
  const [error, setError] = useState<unknown>(null)

  async function act(p: Flagged, action: 'hide' | 'restore' | 'dismiss') {
    setBusy(p.id)
    setError(null)
    try {
      await api.post(`/admin/moderation/posts/${p.id}`, { action, reason: action === 'hide' ? reasons[p.id] : undefined })
      setFlash(action === 'hide' ? 'Post hidden. The author has been told why.' : action === 'restore' ? 'Post is visible again.' : 'Reports dismissed. The post stays up.')
      list.reload()
    } catch (e) {
      setError(e instanceof ApiError && e.fields?.reason ? new ApiError(422, 'REASON', 'Write a short reason before hiding – the author will see it.') : e)
    } finally {
      setBusy(null)
    }
  }

  return (
    <main className="content">
      <div className="page-head">
        <div>
          <h1>Community moderation</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>Posts from members in your area that others reported. Five reports hide a post automatically until someone reviews it.</p>
        </div>
      </div>
      <div className="chips" role="tablist">
        {TABS.map((t) => (
          <button key={t.key} role="tab" aria-selected={status === t.key} className={`chip ${status === t.key ? 'on' : ''}`} onClick={() => { setStatus(t.key); setFlash(null) }}>
            {t.label}{status === t.key && list.data ? ` · ${list.data.length}` : ''}
          </button>
        ))}
      </div>
      <ErrorBox error={list.error ?? error} />
      {flash && <div className="notice" role="status">{flash}</div>}
      {!list.data && !list.error && <section className="card"><Skeleton rows={4} /></section>}
      {list.data?.length === 0 && (
        <section className="card"><Empty>{status === 'reported' ? 'Nothing waiting for review. 🎉' : 'No hidden posts.'}</Empty></section>
      )}
      <div className="mod-list">
        {list.data?.map((p) => (
          <article key={p.id} className="card mod-card">
            <header className="mod-head">
              <Avatar name={p.author.name} size={40} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <b>{p.author.name}</b> {p.author.verified && <VerifiedBadge />}
                <div className="muted" style={{ fontSize: 12.5 }}>{p.author.member_id} · {p.author.place} · {fmtTime(p.at)} · {AUDIENCE[p.audience] ?? p.audience}</div>
              </div>
              {p.hidden ? <span className="pill bad">Hidden</span> : <span className="pill warn">{fmtNum(p.reports_count)} report{p.reports_count === 1 ? '' : 's'}</span>}
            </header>
            {p.body && <p className="mod-body">{p.body}</p>}
            {p.photo_urls.length > 0 && (
              <div className="photos">{p.photo_urls.map((u, i) => <a key={i} href={u} target="_blank" rel="noreferrer"><img src={u} alt={`Photo ${i + 1}`} /></a>)}</div>
            )}
            <div className="mod-meta">
              {p.reasons.map((r) => <span key={r.reason} className="pill mute">{r.reason} · {r.count}</span>)}
              <span className="muted" style={{ fontSize: 12.5 }}>♥ {fmtNum(p.likes)} · 💬 {fmtNum(p.comments)}</span>
            </div>
            {p.notes.length > 0 && <ul className="mod-notes">{p.notes.map((n, i) => <li key={i}>“{n}”</li>)}</ul>}
            {p.hidden && p.hidden_reason && <p className="muted" style={{ fontSize: 13 }}><Icon name="audit" size={14} /> {p.hidden_reason}</p>}
            <footer className="mod-actions">
              {!p.hidden && (
                <>
                  <input className="input" placeholder="Reason shown to the author (needed to hide)" aria-label={`Reason for hiding post ${p.id}`}
                    value={reasons[p.id] ?? ''} onChange={(e) => setReasons({ ...reasons, [p.id]: e.target.value })} />
                  <button className="btn danger" disabled={busy === p.id || !(reasons[p.id] ?? '').trim()} onClick={() => act(p, 'hide')}>Hide post</button>
                  <button className="btn" disabled={busy === p.id} onClick={() => act(p, 'dismiss')}>Keep, dismiss reports</button>
                </>
              )}
              {p.hidden && <button className="btn good" disabled={busy === p.id} onClick={() => act(p, 'restore')}>Restore post</button>}
            </footer>
          </article>
        ))}
      </div>
    </main>
  )
}
