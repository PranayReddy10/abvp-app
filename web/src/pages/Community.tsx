import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api'
import { nameOf, useAuth } from '../auth'
import { Avatar, ErrorBox, Icon, Orbs, Reveal, Skeleton, ago } from '../components/ui'

interface Post {
  id: number
  author: { name: string; member_id: string; verified: boolean; place: string | null; photo_url: string | null }
  body: string | null
  photo_urls: string[]
  likes: number
  comments: number
  reposts: number
  liked: boolean
  at: string
  repost_of: Post | null
}

const withTags = (t: string) => t.split(/(#[\p{L}\p{M}\p{N}_]{2,40})/u).map((p, i) => (p.startsWith('#') ? <span key={i} className="tagged">{p}</span> : p))

function PostCard({ p, i, onLike }: { p: Post; i: number; onLike: () => void }) {
  const show = !p.body && !p.photo_urls.length && p.repost_of ? p.repost_of : p
  return (
    <motion.article className="post" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: Math.min(i, 6) * .05 }} layout>
      {show !== p && <span className="muted" style={{ fontSize: 13, fontWeight: 700 }}><Icon name="repeat" size={14} /> {p.author.name} reposted</span>}
      <div className="who">
        <Avatar name={show.author.name} src={show.author.photo_url} size={44} />
        <div><b>{show.author.name}{show.author.verified && <span title="Verified" style={{ color: '#1D7BE0', marginLeft: 4 }}>✔</span>}</b><div className="muted" style={{ fontSize: 13.5 }}>{[show.author.place, ago(show.at)].filter(Boolean).join(' · ')}</div></div>
      </div>
      {show.body && <p style={{ fontSize: 16, lineHeight: 1.55 }}>{withTags(show.body)}</p>}
      {show.photo_urls.length > 0 && <div className={`photos ${show.photo_urls.length === 1 ? 'one' : ''}`}>{show.photo_urls.slice(0, 4).map((u) => <img key={u} src={u} alt="" loading="lazy" />)}</div>}
      <div className="acts">
        <span style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}><Icon name="reply" size={18} /> {show.comments || ''}</span>
        <span style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}><Icon name="repeat" size={18} /> {show.reposts || ''}</span>
        <motion.button className={show.liked ? 'on' : ''} onClick={onLike} whileTap={{ scale: 1.3 }} aria-label={show.liked ? 'Unlike' : 'Like'}>
          <svg width="19" height="19" viewBox="0 0 24 24" fill={show.liked ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2"><path d="M20.8 4.6a5.5 5.5 0 00-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 00-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 000-7.8z" /></svg> {show.likes || ''}
        </motion.button>
      </div>
    </motion.article>
  )
}

export default function Community() {
  const { me } = useAuth()
  const [posts, setPosts] = useState<Post[] | null>(null)
  const [tab, setTab] = useState<'for_you' | 'following'>('for_you')
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)

  useEffect(() => {
    if (!me?.is_member) return
    setPosts(null)
    api.get<Post[]>(`/feed?tab=${tab}`).then((r) => setPosts(r.data)).catch((e) => setErr(e))
  }, [me, tab])

  async function post(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setErr(null)
    try { const r = await api.post<Post>('/posts', { body: text, audience: 'members' }); setPosts([r.data, ...(posts ?? [])]); setText('') } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  async function like(p: Post) {
    const target = !p.body && !p.photo_urls.length && p.repost_of ? p.repost_of : p
    const r = await api.post<{ liked: boolean; likes_count: number }>(`/posts/${target.id}/like`)
    setPosts((ps) => ps?.map((x) => {
      const t = x.id === target.id ? x : x.repost_of?.id === target.id ? x.repost_of : null
      if (!t) return x
      const upd = { ...t, liked: r.data.liked, likes: r.data.likes_count }
      return x.id === target.id ? upd : { ...x, repost_of: upd }
    }) ?? null)
  }

  return (
    <div className="page wrap" style={{ maxWidth: 760 }}>
      <div className="banner" style={{ background: 'linear-gradient(135deg, #F06AAE, #B72F72 45%, #14161F)' }}>
        <Orbs />
        <div style={{ position: 'relative', zIndex: 2 }}><span style={{ opacity: .85, fontWeight: 700 }}>Community</span><h1>What’s happening</h1><p style={{ opacity: .9 }}>Work from units across the country, shared by members.</p></div>
      </div>
      {!me ? (
        <Reveal><div className="card" style={{ display: 'grid', gap: 12 }}><h2 style={{ fontSize: 24, fontWeight: 800 }}>Sign in to see the community</h2><p className="muted">Posts are shared among ABVP members.</p><div style={{ display: 'flex', gap: 10 }}><Link to="/login?next=/community" className="btn dark">Sign in</Link><Link to="/signup?next=/community" className="btn primary">Sign up</Link></div></div></Reveal>
      ) : !me.is_member ? (
        <Reveal><div className="card" style={{ display: 'grid', gap: 10 }}><h2 style={{ fontSize: 24, fontWeight: 800 }}>For approved members</h2><p className="muted">The community feed is shared among approved ABVP members. Apply for membership in the ABVP Connect app; your district office reviews it. Meanwhile, the conference guide, registration and help desk are all open to you.</p></div></Reveal>
      ) : (
        <div style={{ display: 'grid', gap: 14 }}>
          <form className="post" onSubmit={post}>
            <div className="who"><Avatar name={nameOf(me)} src={me.profile?.photo_url} size={44} /><textarea className="input" style={{ minHeight: 70, border: 0, background: 'var(--bg)' }} placeholder="Share work from your unit… add #hashtags" maxLength={500} value={text} onChange={(e) => setText(e.target.value)} aria-label="New post" /></div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><span className="muted" style={{ fontSize: 13 }}>{500 - text.length}</span><button className="btn primary sm" disabled={busy || !text.trim()}>{busy ? 'Posting…' : 'Post'}</button></div>
          </form>
          <ErrorBox error={err} />
          <div className="chips">{([['for_you', 'For you'], ['following', 'Following']] as const).map(([k, l]) => <button key={k} className={`chip-btn ${tab === k ? 'on' : ''}`} onClick={() => setTab(k)}>{l}</button>)}</div>
          {!posts ? <Skeleton h={160} /> : posts.length === 0 ? <p className="muted">No posts yet.</p> : (
            <AnimatePresence>{posts.map((p, i) => <PostCard key={p.id} p={p} i={i} onLike={() => like(p)} />)}</AnimatePresence>
          )}
        </div>
      )}
    </div>
  )
}
