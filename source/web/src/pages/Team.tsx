import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth'
import { Avatar, ErrorBox, Icon, Orbs, Skeleton, ago, fmtDate, telHref, waHref } from '../components/ui'
import { useFetch } from '../useFetch'

export interface Person { id: number; name: string; role: string; role_label: string; mobile: string | null; has_mobile: boolean; linked: boolean; photo_url: string | null }
interface Dept { id: number; name: string; people: Person[] }
interface Ghat { id: number; name: string; color: string | null; heads: Person[]; departments: Dept[]; counts: { departments: number; people: number } }
interface Tree { event: { id: number; title: string; starts_at: string; ends_at: string; venue: string }; ghats: Ghat[]; signed_in: boolean }

function PersonRow({ p }: { p: Person }) {
  return (
    <div className="tm-person">
      <Avatar name={p.name} src={p.photo_url} size={38} />
      <div style={{ flex: 1, minWidth: 0 }}><b>{p.name}</b><div className="muted" style={{ fontSize: 13 }}>{p.role_label}</div></div>
      {p.mobile && <>
        <a className="tm-act call" href={telHref(p.mobile)} aria-label={`Call ${p.name}`}><Icon name="phone" size={16} /></a>
        <a className="tm-act wa" href={waHref(p.mobile)} target="_blank" rel="noreferrer" aria-label={`WhatsApp ${p.name}`}>WA</a>
      </>}
    </div>
  )
}

/** The conference volunteer structure: ghats → departments → people. Phones only when signed in. */
export default function Team() {
  const { me } = useAuth()
  const conf = useFetch<{ id: number } | null>('/conference')
  const tree = useFetch<Tree>(conf.data ? `/events/${conf.data.id}/teams` : null)
  const [open, setOpen] = useState<number | null>(null)
  const [q, setQ] = useState('')
  const term = q.trim().toLowerCase()

  const ghats = useMemo(() => (tree.data?.ghats ?? []).filter((g) => {
    if (!term) return true
    return g.name.toLowerCase().includes(term) || g.heads.some((p) => p.name.toLowerCase().includes(term))
      || g.departments.some((d) => d.name.toLowerCase().includes(term) || d.people.some((p) => p.name.toLowerCase().includes(term) || (p.mobile ?? '').includes(term)))
  }), [tree.data, term])
  const selected = tree.data?.ghats.find((g) => g.id === open) ?? null

  return (
    <div className="page wrap">
      <div className="banner" style={{ background: 'linear-gradient(135deg, #F08A3C, #E3620C 45%, #13235B)' }}>
        <Orbs />
        <div style={{ position: 'relative', zIndex: 2 }}>
          <span style={{ opacity: .85, fontWeight: 700 }}>Conference team</span>
          <h1>Who does what</h1>
          <p style={{ opacity: .9, maxWidth: 620 }}>{tree.data ? `${tree.data.event.title} · ${fmtDate(tree.data.event.starts_at)} – ${fmtDate(tree.data.event.ends_at)}. ` : ''}Every ghat, its heads and departments – find the right person in seconds.</p>
        </div>
      </div>
      <ErrorBox error={conf.error ?? tree.error} />
      {!me && <div className="hint" style={{ marginBottom: 16 }}><Link to="/login?next=/conference/team" style={{ fontWeight: 700 }}>Sign in</Link> to see phone numbers and call or WhatsApp anyone in the team.</div>}
      <input className="input" style={{ maxWidth: 460, marginBottom: 18 }} placeholder="Find a person, department or ghat – e.g. parking" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search the team" />
      {!tree.data ? <Skeleton h={180} n={3} /> : (
        <div className="tm-grid">
          {ghats.map((g, i) => (
            <motion.button key={g.id} className="tm-card" style={{ ['--c' as string]: g.color ?? '#E3620C' }} onClick={() => setOpen(g.id)}
              initial={{ opacity: 0, y: 18 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: Math.min(i, 10) * .04 }} whileHover={{ y: -4 }}>
              <div className="tm-head"><b>{g.name}</b><span>{g.counts.departments} departments · {g.counts.people} people</span></div>
              <div className="tm-heads">{g.heads.map((h) => <span key={h.id}><small>{h.role_label}</small>{h.name}</span>)}</div>
              <div className="tm-depts">{g.departments.map((d) => <span key={d.id}>{d.name}</span>)}</div>
            </motion.button>
          ))}
        </div>
      )}
      <AnimatePresence>
        {selected && (
          <motion.div className="scrim" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setOpen(null)}>
            <motion.div className="modal tm-modal" style={{ ['--c' as string]: selected.color ?? '#E3620C' }} initial={{ y: 40, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 40, opacity: 0 }} onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" aria-label={selected.name}>
              <button className="icon-btn sm" style={{ position: 'absolute', right: 14, top: 14 }} onClick={() => setOpen(null)} aria-label="Close"><Icon name="close" size={18} /></button>
              <h2 style={{ fontSize: 26, fontWeight: 800 }}><span className="tm-dot" />{selected.name}</h2>
              <h3 className="tm-sub">Ghat heads</h3>
              {selected.heads.map((p) => <PersonRow key={p.id} p={p} />)}
              <h3 className="tm-sub">Departments</h3>
              {selected.departments.map((d) => (
                <div key={d.id} className="tm-dept">
                  <b>{d.name}</b>
                  {d.people.length ? d.people.map((p) => <PersonRow key={p.id} p={p} />) : <span className="muted" style={{ fontSize: 14 }}>To be announced</span>}
                </div>
              ))}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

interface Seva {
  places: { member_id: number; role_label: string; team: { id: number; name: string; color: string | null }; ghat: { name: string } | null }[]
  chats: { team_id: number; name: string; kind: string; color: string | null; last: { body: string; by: string; at: string } | null }[]
  meetings: { id: number; title: string; link: string | null; venue: string | null; starts_at: string; team: string | null }[]
  announcements: { id: number; team: string; body: string; by: string; at: string }[]
}
interface Msg { id: number; body: string; announcement: boolean; by: string; mine: boolean; at: string }

/** My seva for My space: role, team chats (with a chat window), meetings and announcements. */
export function MySeva() {
  const seva = useFetch<Seva>('/me/seva')
  const [chat, setChat] = useState<number | null>(null)
  if (!seva.data || seva.data.places.length === 0) return null
  const s = seva.data
  return (
    <section style={{ marginBottom: 34 }}>
      <h2 style={{ fontSize: 28, fontWeight: 800, marginBottom: 12 }}>My seva</h2>
      <div className="chips" style={{ marginBottom: 14 }}>
        {s.places.map((p) => <span key={p.member_id} className="status-pill" style={{ background: `${p.team.color ?? '#E3620C'}22`, color: p.team.color ?? '#B84C04' }}>{p.role_label} · {p.team.name}{p.ghat ? ` · ${p.ghat.name}` : ''}</span>)}
      </div>
      <div className="tiles" style={{ marginBottom: 14 }}>
        {s.chats.map((c) => (
          <button key={c.team_id} className="tile" style={{ textAlign: 'left', border: 0, cursor: 'pointer' }} onClick={() => setChat(c.team_id)}>
            <span className="top"><span className="ic" style={{ background: c.color ?? '#E3620C' }}><Icon name="chat" size={22} /></span><Icon name="ne" /></span>
            <span><b>{c.name}{c.kind === 'ghat' ? ' ghat' : ''}</b><span className="muted" style={{ fontSize: 14, display: 'block' }}>{c.last ? `${c.last.by}: ${c.last.body}` : 'Team chat'}</span></span>
          </button>
        ))}
      </div>
      {s.meetings.map((m) => (
        <div key={m.id} className="card" style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 10 }}>
          <Icon name="calendar" /><div style={{ flex: 1 }}><b>{m.title}</b><div className="muted" style={{ fontSize: 14 }}>{fmtDate(m.starts_at)}{m.team ? ` · ${m.team}` : ''}{m.venue ? ` · ${m.venue}` : ''}</div></div>
          {m.link && <a className="btn primary sm" href={m.link} target="_blank" rel="noreferrer">Join</a>}
        </div>
      ))}
      {s.announcements.length > 0 && (
        <div className="card" style={{ background: 'var(--soft)', display: 'grid', gap: 10 }}>
          <b style={{ color: 'var(--deep)' }}>📣 Announcements</b>
          {s.announcements.slice(0, 4).map((a) => <div key={a.id}><p>{a.body}</p><small className="muted">{a.by} · {a.team} · {ago(a.at)}</small></div>)}
        </div>
      )}
      <AnimatePresence>{chat && <ChatWindow key={chat} teamId={chat} onClose={() => { setChat(null); seva.reload() }} />}</AnimatePresence>
    </section>
  )
}

function ChatWindow({ teamId, onClose }: { teamId: number; onClose: () => void }) {
  const [msgs, setMsgs] = useState<Msg[]>([])
  const [team, setTeam] = useState<{ name: string; color: string | null } | null>(null)
  const [canManage, setCanManage] = useState(false)
  const [text, setText] = useState('')
  const [announce, setAnnounce] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  useEffect(() => {
    let last = 0
    let stop = false
    const load = async () => {
      try {
        const r = await api.get<{ team: { name: string; color: string | null }; can_manage: boolean; messages: Msg[] }>(`/teams/${teamId}/messages${last ? `?after=${last}` : ''}`)
        if (stop) return
        setTeam(r.data.team); setCanManage(r.data.can_manage)
        if (r.data.messages.length) { last = r.data.messages[r.data.messages.length - 1].id; setMsgs((m) => [...m, ...r.data.messages]) }
      } catch (x) { setErr(x) }
    }
    load()
    const t = setInterval(load, 5000)
    return () => { stop = true; clearInterval(t) }
  }, [teamId])
  async function send(e: FormEvent) {
    e.preventDefault(); setErr(null)
    try { await api.post(`/teams/${teamId}/messages`, { body: text, announcement: announce }); setText(''); setAnnounce(false) } catch (x) { setErr(x) }
  }
  return (
    <motion.div className="scrim" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose}>
      <motion.div className="modal tm-chat" initial={{ y: 40, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 40, opacity: 0 }} onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
        <div className="tm-chat-head" style={{ background: team?.color ?? 'var(--saffron)' }}><b>{team?.name ?? 'Team chat'}</b><button className="icon-btn sm" onClick={onClose} aria-label="Close"><Icon name="close" size={18} /></button></div>
        <div className="tm-msgs">
          {msgs.length === 0 && <p className="muted">No messages yet. Say namaste to your team!</p>}
          {msgs.map((m) => <div key={m.id} className={`tm-msg ${m.mine ? 'mine' : ''} ${m.announcement ? 'ann' : ''}`}>{(!m.mine || m.announcement) && <b>{m.announcement ? '📣 ' : ''}{m.by}</b>}<p>{m.body}</p><small>{ago(m.at)}</small></div>)}
        </div>
        <ErrorBox error={err} />
        <form onSubmit={send} style={{ display: 'grid', gap: 8 }}>
          {canManage && <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 14 }}><input type="checkbox" checked={announce} onChange={(e) => setAnnounce(e.target.checked)} /> Send as announcement (notifies the whole team)</label>}
          <div style={{ display: 'flex', gap: 8 }}><input className="input" placeholder="Message your team" value={text} onChange={(e) => setText(e.target.value)} maxLength={2000} /><button className="btn primary" disabled={!text.trim()}>Send</button></div>
        </form>
      </motion.div>
    </motion.div>
  )
}
