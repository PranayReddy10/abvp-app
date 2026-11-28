import { motion } from 'framer-motion'
import { useEffect, useState, type FormEvent } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { api } from '../api'
import { track } from '../analytics'
import { useAuth } from '../auth'
import { Avatar, ErrorBox, Icon, KIND, Skeleton, Tick, ago, fmtDate, grad, telHref } from '../components/ui'
import { useSeo } from '../seo'

interface Results {
  q: string
  signed_in: boolean
  events: { id: number; title: string; venue: string; starts_at: string; ends_at: string }[]
  guide: { id: number; event_id: number; kind: string; kind_label: string; title: string; subtitle: string | null; region: string | null }[]
  people: { id: number; name: string; role: string; team: string | null; ghat: string | null; mobile: string | null; member_id: string | null; verified: boolean }[]
  members: { member_id: string; name: string; verified: boolean; place: string | null; photo_url: string | null }[]
  posts: { id: number; body: string; author: string | null; verified: boolean; at: string }[]
}

/** One search for the whole site: events, guide places, volunteers, members and community posts. */
export default function Search() {
  const [params, setParams] = useSearchParams()
  const { me } = useAuth()
  const q = params.get('q') ?? ''
  const [text, setText] = useState(q)
  const [data, setData] = useState<Results | null>(null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  useSeo({ title: q ? `Search: ${q}` : 'Search', description: 'Search ABVP Connect for events, conference guide places, volunteers, members and posts.', noindex: true })

  useEffect(() => {
    setText(q)
    if (q.trim().length < 2) { setData(null); return }
    let live = true
    setBusy(true); setErr(null)
    api.get<Results>(`/search?q=${encodeURIComponent(q.trim())}`)
      .then((r) => { if (live) { setData(r.data); track('search', { search_term: q.trim() }) } })
      .catch((x) => { if (live) setErr(x) })
      .finally(() => { if (live) setBusy(false) })
    return () => { live = false }
  }, [q, me])

  function submit(e: FormEvent) {
    e.preventDefault()
    setParams(text.trim() ? { q: text.trim() } : {})
  }

  const total = data ? data.events.length + data.guide.length + data.people.length + data.members.length + data.posts.length : 0

  return (
    <div className="page wrap" style={{ maxWidth: 920 }}>
      <h1 style={{ fontSize: 'clamp(30px, 4vw, 44px)', fontWeight: 800, marginBottom: 16 }}>Search</h1>
      <form className="search-box" onSubmit={submit} role="search">
        <Icon name="search" />
        <input autoFocus className="input" placeholder="Events, places, people, posts…" value={text} onChange={(e) => setText(e.target.value)} aria-label="Search" maxLength={60} />
        <button className="btn primary" disabled={text.trim().length < 2}>Search</button>
      </form>
      <ErrorBox error={err} />
      {!me && <div className="hint" style={{ marginTop: 14 }}><Link to={`/login?next=${encodeURIComponent(`/search?q=${q}`)}`} style={{ fontWeight: 700 }}>Sign in</Link> to also find volunteers, members, posts and – after the delegate form – places in the conference guide.</div>}
      {busy && <div style={{ marginTop: 20 }}><Skeleton h={80} n={3} /></div>}
      {data && !busy && (
        <div style={{ display: 'grid', gap: 28, marginTop: 24 }}>
          {total === 0 && <p className="muted">Nothing found for “{data.q}”. Try another word – a name, place or department.</p>}

          {data.guide.length > 0 && <Group title="Conference guide">
            {data.guide.map((g) => (
              <Link key={g.id} to={`/guide/${g.event_id}/${g.kind}`} className="card s-row">
                <span className="s-ic" style={{ background: grad(g.kind) }}><Icon name={KIND[g.kind]?.icon ?? 'sparkle'} size={20} /></span>
                <span className="s-body"><b>{g.title}</b><span className="muted">{[g.kind_label, g.region, g.subtitle].filter(Boolean).join(' · ')}</span></span>
                <Icon name="arrow" />
              </Link>
            ))}
          </Group>}

          {data.people.length > 0 && <Group title="Volunteers">
            {data.people.map((p) => (
              <div key={p.id} className="card s-row">
                <Avatar name={p.name} size={42} />
                <span className="s-body"><b>{p.name}{p.verified && <Tick size={16} />}</b><span className="muted">{[p.role, p.team, p.ghat].filter(Boolean).join(' · ')}</span></span>
                {p.mobile && <a className="call" href={telHref(p.mobile)} aria-label={`Call ${p.name}`}><Icon name="phone" size={17} /></a>}
              </div>
            ))}
          </Group>}

          {data.events.length > 0 && <Group title="Events">
            {data.events.map((e) => (
              <Link key={e.id} to={`/events/${e.id}`} className="card s-row">
                <span className="s-ic" style={{ background: grad('session') }}><Icon name="calendar" size={20} /></span>
                <span className="s-body"><b>{e.title}</b><span className="muted">{fmtDate(e.starts_at)} · {e.venue}</span></span>
                <Icon name="arrow" />
              </Link>
            ))}
          </Group>}

          {data.members.length > 0 && <Group title="Members">
            {data.members.map((m) => (
              <div key={m.member_id} className="card s-row">
                <Avatar name={m.name} src={m.photo_url} size={42} />
                <span className="s-body"><b>{m.name}{m.verified && <Tick size={16} />}</b><span className="muted">{[m.member_id, m.place].filter(Boolean).join(' · ')}</span></span>
              </div>
            ))}
          </Group>}

          {data.posts.length > 0 && <Group title="Community posts">
            {data.posts.map((p) => (
              <Link key={p.id} to="/community" className="card s-row">
                <span className="s-body"><b>{p.author}{p.verified && <Tick size={16} />} <span className="muted" style={{ fontWeight: 500 }}>· {ago(p.at)}</span></b><span>{p.body}</span></span>
              </Link>
            ))}
          </Group>}
        </div>
      )}
    </div>
  )
}

function Group({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <motion.section initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}>
      <h2 style={{ fontSize: 22, fontWeight: 800, marginBottom: 10 }}>{title}</h2>
      <div style={{ display: 'grid', gap: 10 }}>{children}</div>
    </motion.section>
  )
}
