import { AnimatePresence, motion } from 'framer-motion'
import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import { createPortal } from 'react-dom'
import { Link } from 'react-router-dom'
import { api } from '../api'
import { nameOf, useAuth } from '../auth'
import { Avatar, ErrorBox, Icon, Orbs, Reveal, Skeleton, ago } from '../components/ui'
import { useFetch } from '../useFetch'

interface Author { name: string; member_id: string | null; verified: boolean; place: string | null; photo_url: string | null }
interface Post {
  id: number; author: Author; body: string | null; audience: string; audience_label: string; photo_urls: string[]
  likes: number; comments: number; reposts: number; liked: boolean; reposted: boolean; is_mine: boolean; hidden: boolean; at: string
  repost_of: Post | null
}
interface Reply { id: number; body: string; author: Author; is_mine: boolean; at: string }

const REASONS: [string, string][] = [['abuse', 'Abusive or hateful'], ['false_info', 'False information'], ['spam', 'Spam'], ['private_info', "Shares someone's private details"], ['other', 'Something else']]
const shown = (p: Post) => (!p.body && !p.photo_urls.length && p.repost_of ? p.repost_of : p)

function Body({ text, onTag }: { text: string; onTag: (t: string) => void }) {
  return <p style={{ fontSize: 16, lineHeight: 1.6, whiteSpace: 'pre-line', overflowWrap: 'anywhere' }}>{text.split(/(#[\p{L}\p{M}\p{N}_]{2,40})/u).map((part, i) => (
    part.startsWith('#') ? <button key={i} className="tagged" onClick={(e) => { e.stopPropagation(); onTag(part.slice(1)) }}>{part}</button> : part
  ))}</p>
}

function Photos({ urls, onOpen }: { urls: string[]; onOpen: (u: string) => void }) {
  if (!urls.length) return null
  return <div className={`photos ${urls.length === 1 ? 'one' : ''}`}>{urls.slice(0, 4).map((u) => <button key={u} className="photo-btn" onClick={(e) => { e.stopPropagation(); onOpen(u) }}><img src={u} alt="" loading="lazy" /></button>)}</div>
}

function Menu({ p, onDelete, onReport }: { p: Post; onDelete: () => void; onReport: () => void }) {
  const [open, setOpen] = useState(false)
  return (
    <div style={{ position: 'relative', marginLeft: 'auto' }}>
      <button className="icon-btn sm" aria-label="More" aria-expanded={open} onClick={(e) => { e.stopPropagation(); setOpen(!open) }}>⋯</button>
      <AnimatePresence>{open && (
        <motion.div className="pop" initial={{ opacity: 0, y: -6, scale: .96 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: -6 }} onMouseLeave={() => setOpen(false)}>
          {p.is_mine ? <button onClick={() => { setOpen(false); onDelete() }}><Icon name="trash" size={16} /> Delete post</button>
            : <button onClick={() => { setOpen(false); onReport() }}><Icon name="flag" size={16} /> Report post</button>}
        </motion.div>
      )}</AnimatePresence>
    </div>
  )
}

function PostCard({ p, i, onLike, onRepost, onOpen, onTag, onPhoto, onDelete, onReport }: {
  p: Post; i: number; onLike: () => void; onRepost: () => void; onOpen: () => void; onTag: (t: string) => void; onPhoto: (u: string) => void; onDelete: () => void; onReport: () => void
}) {
  const s = shown(p)
  return (
    <motion.article className="post clickable" layout initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: .97 }} transition={{ delay: Math.min(i, 6) * .04 }} onClick={onOpen}>
      {s !== p && <span className="muted" style={{ fontSize: 13, fontWeight: 700, display: 'flex', gap: 6 }}><Icon name="repeat" size={14} /> {p.is_mine ? 'You' : p.author.name} reposted</span>}
      {p.hidden && <span className="status-pill bad" style={{ justifySelf: 'start' }}>Hidden – waiting for review</span>}
      <div className="who">
        <Avatar name={s.author.name} src={s.author.photo_url} size={44} />
        <div style={{ minWidth: 0 }}>
          <b>{s.author.name}{s.author.verified && <span title="Verified" style={{ color: '#1D7BE0', marginLeft: 4 }}>✔</span>}</b>
          <div className="muted" style={{ fontSize: 13.5 }}>{[s.author.place, ago(s.at), s.audience !== 'members' ? s.audience_label : null].filter(Boolean).join(' · ')}</div>
        </div>
        <Menu p={p} onDelete={onDelete} onReport={onReport} />
      </div>
      {p !== s && p.body && <Body text={p.body} onTag={onTag} />}
      {s.body && <Body text={s.body} onTag={onTag} />}
      <Photos urls={s.photo_urls} onOpen={onPhoto} />
      <div className="acts" onClick={(e) => e.stopPropagation()}>
        <button onClick={onOpen} aria-label="Replies"><Icon name="reply" size={18} /> {s.comments || ''}</button>
        <button className={s.reposted ? 'on-green' : ''} onClick={onRepost} aria-label="Repost"><Icon name="repeat" size={18} /> {s.reposts || ''}</button>
        <motion.button className={s.liked ? 'on' : ''} onClick={onLike} whileTap={{ scale: 1.35 }} aria-label={s.liked ? 'Unlike' : 'Like'}>
          <svg width="19" height="19" viewBox="0 0 24 24" fill={s.liked ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2"><path d="M20.8 4.6a5.5 5.5 0 00-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 00-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 000-7.8z" /></svg> {s.likes || ''}
        </motion.button>
      </div>
    </motion.article>
  )
}

function Composer({ onPosted }: { onPosted: (p: Post) => void }) {
  const { me } = useAuth()
  const [text, setText] = useState('')
  const [files, setFiles] = useState<File[]>([])
  const [audience, setAudience] = useState('members')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const input = useRef<HTMLInputElement>(null)
  const previews = files.map((f) => URL.createObjectURL(f))
  useEffect(() => () => previews.forEach((u) => URL.revokeObjectURL(u)))
  if (!me) return null
  const vibhags = me.profile?.vibhags ?? []

  async function post(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setErr(null)
    try {
      const fd = new FormData()
      if (text.trim()) fd.append('body', text.trim())
      const [aud, vid] = audience.split(':')
      fd.append('audience', aud)
      if (vid) fd.append('vibhag_id', vid)
      files.forEach((f) => fd.append('photos[]', f))
      const r = await api.post<Post>('/posts', fd)
      onPosted(r.data); setText(''); setFiles([])
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  return (
    <form className="post" onSubmit={post}>
      <div className="who" style={{ alignItems: 'flex-start' }}>
        <Avatar name={nameOf(me) || '?'} src={me.profile?.photo_url} size={44} />
        <textarea className="input" style={{ minHeight: 84, border: 0, background: 'var(--bg)', paddingTop: 12 }} placeholder="Share work from your unit… add #hashtags" maxLength={500} value={text} onChange={(e) => setText(e.target.value)} aria-label="New post" />
      </div>
      {previews.length > 0 && (
        <div className="photos">{previews.map((u, i) => (
          <div key={u} style={{ position: 'relative' }}><img src={u} alt="" /><button type="button" className="x-btn" aria-label="Remove photo" onClick={() => setFiles(files.filter((_, j) => j !== i))}>×</button></div>
        ))}</div>
      )}
      <ErrorBox error={err} />
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
        <button type="button" className="icon-btn" aria-label="Add photos" disabled={files.length >= 4} onClick={() => input.current?.click()}><Icon name="image" size={20} /></button>
        <input ref={input} type="file" accept="image/jpeg,image/png,image/webp" multiple hidden onChange={(e) => { setFiles([...files, ...Array.from(e.target.files ?? [])].slice(0, 4)); e.target.value = '' }} />
        <select className="input" style={{ height: 40, width: 'auto', borderRadius: 999, fontSize: 14 }} value={audience} onChange={(e) => setAudience(e.target.value)} aria-label="Who can see this">
          <option value="members">Everyone</option>
          {me.profile?.org_unit && <option value="area">Only my district</option>}
          {vibhags.map((v) => <option key={v.id} value={`vibhag:${v.id}`}>{v.name}</option>)}
        </select>
        <span className="muted" style={{ fontSize: 13, marginLeft: 'auto' }}>{500 - text.length}</span>
        <button className="btn primary sm" disabled={busy || (!text.trim() && !files.length)}>{busy ? 'Posting…' : 'Post'}</button>
      </div>
    </form>
  )
}

function Drawer({ children, onClose }: { children: React.ReactNode; onClose: () => void }) {
  useEffect(() => {
    const k = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', k)
    return () => window.removeEventListener('keydown', k)
  }, [onClose])
  return createPortal(
    <motion.div className="scrim" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose}>
      <motion.div className="modal" role="dialog" aria-modal="true" initial={{ y: 40, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 40, opacity: 0 }} transition={{ type: 'spring', stiffness: 260, damping: 26 }} onClick={(e) => e.stopPropagation()}>
        <button className="icon-btn sm" style={{ position: 'absolute', right: 14, top: 14 }} onClick={onClose} aria-label="Close"><Icon name="close" size={18} /></button>
        {children}
      </motion.div>
    </motion.div>, document.body)
}

function Thread({ id, onClose, onChanged, onTag, onPhoto }: { id: number; onClose: () => void; onChanged: (postId: number, delta: number) => void; onTag: (t: string) => void; onPhoto: (u: string) => void }) {
  const d = useFetch<Post & { replies: Reply[] }>(`/posts/${id}`)
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [replies, setReplies] = useState<Reply[] | null>(null)
  useEffect(() => { if (d.data) setReplies(d.data.replies) }, [d.data])
  async function reply(e: FormEvent) {
    e.preventDefault(); setBusy(true); setErr(null)
    try { const r = await api.post<Reply>(`/posts/${id}/comments`, { body: text }); setReplies([...(replies ?? []), r.data]); setText(''); onChanged(id, 1) } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  async function remove(c: Reply) {
    await api.del(`/comments/${c.id}`); setReplies((replies ?? []).filter((x) => x.id !== c.id)); onChanged(id, -1)
  }
  return (
    <Drawer onClose={onClose}>
      {!d.data ? <><ErrorBox error={d.error} />{!d.error && <Skeleton h={120} n={2} />}</> : (
        <div style={{ display: 'grid', gap: 14 }}>
          <div className="who"><Avatar name={d.data.author.name} src={d.data.author.photo_url} size={48} /><div><b>{d.data.author.name}</b><div className="muted" style={{ fontSize: 13.5 }}>{[d.data.author.place, ago(d.data.at)].filter(Boolean).join(' · ')}</div></div></div>
          {d.data.body && <Body text={d.data.body} onTag={(t) => { onClose(); onTag(t) }} />}
          <Photos urls={d.data.photo_urls} onOpen={onPhoto} />
          <h3 style={{ fontSize: 17, fontWeight: 800, marginTop: 6 }}>Replies</h3>
          {replies?.length === 0 && <p className="muted">No replies yet. Be the first.</p>}
          <AnimatePresence>{replies?.map((c) => (
            <motion.div key={c.id} layout initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0 }} className="reply">
              <Avatar name={c.author.name} src={c.author.photo_url} size={34} />
              <div style={{ flex: 1, minWidth: 0 }}><b style={{ fontSize: 14.5 }}>{c.author.name}</b> <span className="muted" style={{ fontSize: 12.5 }}>{ago(c.at)}</span><p style={{ overflowWrap: 'anywhere' }}>{c.body}</p></div>
              {(c.is_mine || d.data!.is_mine) && <button className="icon-btn sm" aria-label="Remove reply" onClick={() => remove(c)}><Icon name="trash" size={15} /></button>}
            </motion.div>
          ))}</AnimatePresence>
          <ErrorBox error={err} />
          <form onSubmit={reply} style={{ display: 'flex', gap: 10 }}>
            <input className="input" placeholder="Write a reply…" maxLength={500} value={text} onChange={(e) => setText(e.target.value)} aria-label="Reply" />
            <button className="btn primary" disabled={busy || !text.trim()}>Reply</button>
          </form>
        </div>
      )}
    </Drawer>
  )
}

function ReportBox({ post, onClose, onDone }: { post: Post; onClose: () => void; onDone: () => void }) {
  const [reason, setReason] = useState('')
  const [note, setNote] = useState('')
  const [err, setErr] = useState<unknown>(null)
  async function send() {
    try { await api.post(`/posts/${shown(post).id}/report`, { reason, note: note || null }); onDone() } catch (x) { setErr(x) }
  }
  return (
    <Drawer onClose={onClose}>
      <div style={{ display: 'grid', gap: 12 }}>
        <h2 style={{ fontSize: 22, fontWeight: 800 }}>Report this post</h2>
        <p className="muted">An admin reviews every report. Posts several people report are hidden until then.</p>
        {REASONS.map(([k, l]) => <button key={k} className={`choice ${reason === k ? 'on' : ''}`} onClick={() => setReason(k)}>{l}</button>)}
        <textarea className="input" style={{ minHeight: 70, paddingTop: 10 }} placeholder="Anything else? (optional)" maxLength={300} value={note} onChange={(e) => setNote(e.target.value)} />
        <ErrorBox error={err} />
        <button className="btn primary" disabled={!reason} onClick={send}>Send report</button>
      </div>
    </Drawer>
  )
}

/** One community for everyone who signs in: posts with photos, replies, likes, reposts, hashtags and reports. */
export default function Community() {
  const { me } = useAuth()
  const [posts, setPosts] = useState<Post[] | null>(null)
  const [next, setNext] = useState<number | null>(null)
  const [tab, setTab] = useState<'for_you' | 'following'>('for_you')
  const [tag, setTag] = useState<string | null>(null)
  const [err, setErr] = useState<unknown>(null)
  const [open, setOpen] = useState<number | null>(null)
  const [photo, setPhoto] = useState<string | null>(null)
  const [reporting, setReporting] = useState<Post | null>(null)
  const [toast, setToast] = useState('')
  const trending = useFetch<{ tag: string; posts: number }[]>(me ? '/feed/trending' : null)

  const load = useCallback(async (before?: number) => {
    const q = new URLSearchParams({ tab, ...(tag ? { tag } : {}), ...(before ? { before: String(before) } : {}) })
    try {
      const r = await api.get<Post[]>(`/feed?${q}`)
      setPosts((ps) => (before ? [...(ps ?? []), ...r.data] : r.data))
      setNext((r.meta.next_before as number | null) ?? null)
    } catch (x) { setErr(x) }
  }, [tab, tag])

  useEffect(() => { if (me) { setPosts(null); load() } }, [me, load])
  useEffect(() => { if (!toast) return; const t = setTimeout(() => setToast(''), 2600); return () => clearTimeout(t) }, [toast])

  const patch = (id: number, f: (p: Post) => Post) => setPosts((ps) => ps?.map((x) => (x.id === id ? f(x) : x.repost_of?.id === id ? { ...x, repost_of: f(x.repost_of) } : x)) ?? null)

  async function like(p: Post) {
    const t = shown(p)
    const r = await api.post<{ liked: boolean; likes_count: number }>(`/posts/${t.id}/like`)
    patch(t.id, (x) => ({ ...x, liked: r.data.liked, likes: r.data.likes_count }))
  }
  async function repost(p: Post) {
    const t = shown(p)
    if (t.reposted) { setToast('You have already reposted this.'); return }
    try {
      const r = await api.post<Post>('/posts', { repost_of_id: t.id, audience: 'members' })
      setPosts((ps) => [r.data, ...(ps ?? [])]); patch(t.id, (x) => ({ ...x, reposted: true, reposts: x.reposts + 1 })); setToast('Reposted.')
    } catch (x) { setErr(x) }
  }
  async function remove(p: Post) {
    if (!confirm('Delete this post?')) return
    await api.del(`/posts/${p.id}`); setPosts((ps) => ps?.filter((x) => x.id !== p.id) ?? null); setToast('Post deleted.')
  }

  return (
    <div className="page wrap" style={{ maxWidth: 1080 }}>
      <div className="banner" style={{ background: 'linear-gradient(135deg, #F06AAE, #B72F72 45%, #14161F)' }}>
        <Orbs />
        <div style={{ position: 'relative', zIndex: 2 }}><span style={{ opacity: .85, fontWeight: 700 }}>Community</span><h1>What’s happening</h1><p style={{ opacity: .9 }}>Work from units across the country – one community for everyone in ABVP Connect.</p></div>
      </div>
      {!me ? (
        <Reveal><div className="card" style={{ display: 'grid', gap: 12 }}><h2 style={{ fontSize: 24, fontWeight: 800 }}>Sign in to join the community</h2><p className="muted">Share photos and updates, reply, like and repost.</p><div style={{ display: 'flex', gap: 10 }}><Link to="/login?next=/community" className="btn dark">Sign in</Link><Link to="/signup?next=/community" className="btn primary">Sign up</Link></div></div></Reveal>
      ) : (
        <div className="feed-layout">
          <div style={{ display: 'grid', gap: 14, alignContent: 'start', minWidth: 0 }}>
            {nameOf(me) ? <Composer onPosted={(p) => setPosts([p, ...(posts ?? [])])} /> : <div className="hint">Add your name in <Link to="/me/edit">your profile</Link> to start posting.</div>}
            <ErrorBox error={err} />
            <div className="chips">
              {([['for_you', 'For you'], ['following', 'Following']] as const).map(([k, l]) => <button key={k} className={`chip-btn ${tab === k && !tag ? 'on' : ''}`} onClick={() => { setTag(null); setTab(k) }}>{l}</button>)}
              {tag && <button className="chip-btn on" onClick={() => setTag(null)}>#{tag} ×</button>}
            </div>
            {!posts ? <Skeleton h={160} /> : posts.length === 0 ? <div className="card"><p className="muted">{tag ? `No posts with #${tag} yet.` : tab === 'following' ? 'Follow people to see their posts here.' : 'No posts yet. Share the first one!'}</p></div> : (
              <AnimatePresence initial={false}>{posts.map((p, i) => (
                <PostCard key={p.id} p={p} i={i} onLike={() => like(p)} onRepost={() => repost(p)} onOpen={() => setOpen(shown(p).id)} onTag={(t) => setTag(t.toLowerCase())}
                  onPhoto={setPhoto} onDelete={() => remove(p)} onReport={() => setReporting(p)} />
              ))}</AnimatePresence>
            )}
            {next && <button className="btn" onClick={() => load(next)}>Show more</button>}
          </div>
          <aside className="card trends" style={{ display: 'grid', gap: 10, alignContent: 'start' }}>
            <h3 style={{ fontSize: 18, fontWeight: 800 }}>Trending</h3>
            {trending.data?.length ? trending.data.map((t) => (
              <button key={t.tag} className="trend" onClick={() => setTag(t.tag)}><b>#{t.tag}</b><span className="muted">{t.posts} post{t.posts === 1 ? '' : 's'}</span></button>
            )) : <p className="muted" style={{ fontSize: 14 }}>Hashtags people use this week show here.</p>}
          </aside>
        </div>
      )}
      <AnimatePresence>
        {open && <Thread key="t" id={open} onClose={() => setOpen(null)} onTag={setTag} onPhoto={setPhoto} onChanged={(id, d) => patch(id, (x) => ({ ...x, comments: Math.max(0, x.comments + d) }))} />}
        {reporting && <ReportBox key="r" post={reporting} onClose={() => setReporting(null)} onDone={() => { setReporting(null); setToast('Thanks. An admin will look at it.') }} />}
        {photo && createPortal(<motion.div key="p" className="scrim" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setPhoto(null)}><motion.img src={photo} alt="" className="lightbox" initial={{ scale: .92 }} animate={{ scale: 1 }} /></motion.div>, document.body)}
        {toast && <motion.div key="toast" className="toast" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 20 }}>{toast}</motion.div>}
      </AnimatePresence>
    </div>
  )
}
