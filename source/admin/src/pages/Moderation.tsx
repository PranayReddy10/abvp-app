import { useRef, useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api, ApiError } from '../api'
import { Icon, VerifiedBadge } from '../components/icons'
import { Avatar, Empty, ErrorBox, Skeleton } from '../components/ui'
import { fmtNum, fmtTime } from '../format'
import { useFetch } from '../useFetch'

interface Flagged {
  id: number
  body: string | null
  photo_urls: string[]
  author: { name: string | null; member_id: string | null; place: string | null; verified: boolean; mobile?: string }
  is_repost?: boolean
  reposts?: number
  audience: string
  likes: number
  comments: number
  reports_count: number
  reasons: { reason: string; count: number }[]
  notes: string[]
  hidden: boolean
  pending?: boolean
  hidden_reason: string | null
  at: string
}

const TABS = [
  { key: 'pending', label: 'Waiting approval' },
  { key: 'all', label: 'All posts' },
  { key: 'reported', label: 'Reported' },
  { key: 'hidden', label: 'Hidden' },
]

const AUDIENCE: Record<string, string> = { members: 'Everyone', area: 'District only', vibhag: 'Vibhag' }

/** Community posts members reported, from authors inside the admin's area. */
export default function Moderation() {
  const [params] = useSearchParams()
  const [status, setStatus] = useState(params.get('status') ?? 'all')
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const settings = useFetch<{ approval_required: boolean; pending: number; ready?: boolean }>('/admin/moderation/settings')
  const list = useFetch<Flagged[]>(`/admin/moderation?status=${status}${search ? `&q=${encodeURIComponent(search)}` : ''}`)
  const [busy, setBusy] = useState<number | null>(null)
  const [reasons, setReasons] = useState<Record<number, string>>({})
  const [flash, setFlash] = useState<string | null>(null)
  const [error, setError] = useState<unknown>(null)

  async function toggleApproval() {
    setError(null)
    try {
      await api.put('/admin/moderation/settings', { approval_required: !settings.data?.approval_required })
      settings.reload()
    } catch (e) { setError(e) }
  }

  async function act(p: Flagged, action: 'hide' | 'restore' | 'dismiss' | 'approve') {
    setBusy(p.id)
    setError(null)
    try {
      await api.post(`/admin/moderation/posts/${p.id}`, { action, reason: action === 'hide' ? reasons[p.id] : undefined })
      settings.reload()
      setFlash(action === 'approve' ? 'Approved. The post is live and the author has been told.' : action === 'hide' ? (p.pending ? 'Not approved. The author has been told why.' : 'Post hidden. The author has been told why.') : action === 'restore' ? 'Post is visible again.' : 'Reports dismissed. The post stays up.')
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
          <h1>Community</h1>
          <p className="muted" style={{ margin: '4px 0 0' }}>Every post in your area – members, delegates and guests. Several reports hide a post automatically until someone reviews it.</p>
        </div>
        <form onSubmit={(e) => { e.preventDefault(); setSearch(q) }}>
          <input className="input" style={{ width: 260 }} placeholder="Search post text" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search posts" />
        </form>
      </div>
      <section className="card mod-settings">
        <div style={{ flex: 1 }}>
          <b>Posts need approval</b>
          <div className="muted" style={{ fontSize: 13 }}>
            {settings.data?.approval_required
              ? 'On: new posts from members wait here until an admin approves them. Admins’ own posts go live straight away.'
              : 'Off: posts go live straight away. Reports still hide a post until someone reviews it.'}
          </div>
          {settings.data?.ready === false && (
            <div className="notice" style={{ marginTop: 8 }}>
              The server needs its database update before approval can be switched on. On the server run:
              <code style={{ display: 'block', marginTop: 4 }}>cd ~/domains/abvpconnect.org/public_html/api && php artisan migrate --force && php artisan optimize</code>
            </div>
          )}
        </div>
        <button type="button" role="switch" aria-checked={!!settings.data?.approval_required} aria-label="Posts need approval"
          className={`switch ${settings.data?.approval_required ? 'on' : ''}`} disabled={settings.loading} onClick={toggleApproval}><i /></button>
      </section>
      <Composer onPosted={() => { setStatus('all'); list.reload() }} />
      <div className="chips" role="tablist">
        {TABS.map((t) => (
          <button key={t.key} role="tab" aria-selected={status === t.key} className={`chip ${status === t.key ? 'on' : ''}`} onClick={() => { setStatus(t.key); setFlash(null) }}>
            {t.label}{t.key === 'pending' && settings.data?.pending ? ` · ${settings.data.pending}` : status === t.key && list.data ? ` · ${list.data.length}` : ''}
          </button>
        ))}
      </div>
      <ErrorBox error={settings.error ?? list.error ?? error} />
      {flash && <div className="notice" role="status">{flash}</div>}
      {!list.data && !list.error && <section className="card"><Skeleton rows={4} /></section>}
      {list.data?.length === 0 && (
        <section className="card"><Empty>{status === 'pending' ? 'No posts waiting for approval. 🎉' : status === 'all' ? 'No posts yet.' : status === 'reported' ? 'Nothing waiting for review. 🎉' : 'No hidden posts.'}</Empty></section>
      )}
      <div className="mod-list">
        {list.data?.map((p) => (
          <article key={p.id} className="card mod-card">
            <header className="mod-head">
              <Avatar name={p.author.name} size={40} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <b>{p.author.name}</b> {p.author.verified && <VerifiedBadge />}
                <div className="muted" style={{ fontSize: 12.5 }}>{[p.author.member_id ?? 'Not a member', p.author.place, p.author.mobile, fmtTime(p.at), AUDIENCE[p.audience] ?? p.audience].filter(Boolean).join(' · ')}</div>
              </div>
              {p.pending ? <span className="pill warn">Waiting approval</span> : p.hidden ? <span className="pill bad">Hidden</span> : p.reports_count > 0 ? <span className="pill warn">{fmtNum(p.reports_count)} report{p.reports_count === 1 ? '' : 's'}</span> : p.is_repost ? <span className="pill mute">Repost</span> : null}
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
            {p.hidden && !p.pending && p.hidden_reason && <p className="muted" style={{ fontSize: 13 }}><Icon name="audit" size={14} /> {p.hidden_reason}</p>}
            <footer className="mod-actions">
              {p.pending && (
                <>
                  <button className="btn good" disabled={busy === p.id} onClick={() => act(p, 'approve')}>Approve</button>
                  <input className="input" placeholder="Reason if not approving (the author sees it)" aria-label={`Reason for not approving post ${p.id}`}
                    value={reasons[p.id] ?? ''} onChange={(e) => setReasons({ ...reasons, [p.id]: e.target.value })} />
                  <button className="btn danger" disabled={busy === p.id || !(reasons[p.id] ?? '').trim()} onClick={() => act(p, 'hide')}>Don’t approve</button>
                </>
              )}
              {!p.hidden && (
                <>
                  <input className="input" placeholder="Reason shown to the author (needed to hide)" aria-label={`Reason for hiding post ${p.id}`}
                    value={reasons[p.id] ?? ''} onChange={(e) => setReasons({ ...reasons, [p.id]: e.target.value })} />
                  <button className="btn danger" disabled={busy === p.id || !(reasons[p.id] ?? '').trim()} onClick={() => act(p, 'hide')}>Hide post</button>
                  {p.reports_count > 0 && <button className="btn" disabled={busy === p.id} onClick={() => act(p, 'dismiss')}>Keep, dismiss reports</button>}
                </>
              )}
              {p.hidden && !p.pending && <button className="btn good" disabled={busy === p.id} onClick={() => act(p, 'restore')}>Restore post</button>}
            </footer>
          </article>
        ))}
      </div>
    </main>
  )
}

/** Admins post to the community from here – text and up to 4 photos, live straight away. */
function Composer({ onPosted }: { onPosted: () => void }) {
  const [body, setBody] = useState('')
  const [files, setFiles] = useState<File[]>([])
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [done, setDone] = useState(false)
  const input = useRef<HTMLInputElement>(null)
  async function post(e: FormEvent) {
    e.preventDefault()
    if (!body.trim() && files.length === 0) return
    setBusy(true); setErr(null); setDone(false)
    try {
      const fd = new FormData()
      if (body.trim()) fd.append('body', body.trim())
      fd.append('audience', 'members')
      files.forEach((f) => fd.append('photos[]', f))
      await api.post('/posts', fd)
      setBody(''); setFiles([]); setDone(true); onPosted()
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  return (
    <form className="card composer" onSubmit={post}>
      <b>Post to the community</b>
      <textarea className="input" rows={3} maxLength={500} placeholder="Share an update, an announcement or photos with everyone…" value={body} onChange={(e) => setBody(e.target.value)} aria-label="Post text" />
      {files.length > 0 && (
        <div className="photos">{files.map((f, i) => <img key={i} src={URL.createObjectURL(f)} alt={f.name} />)}</div>
      )}
      <ErrorBox error={err} />
      {done && <div className="notice" role="status">Posted. Everyone can see it now.</div>}
      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
        <input ref={input} type="file" accept="image/jpeg,image/png,image/webp" multiple hidden onChange={(e) => setFiles(Array.from(e.target.files ?? []).slice(0, 4))} />
        <button type="button" className="btn" onClick={() => input.current?.click()}>📷 Photos{files.length ? ` · ${files.length}` : ''}</button>
        <span className="muted" style={{ fontSize: 12.5, flex: 1 }}>{body.length}/500 · everyone sees it</span>
        <button className="btn primary" disabled={busy || (!body.trim() && files.length === 0)}>{busy ? 'Posting…' : 'Post'}</button>
      </div>
    </form>
  )
}
