import { AnimatePresence, motion } from 'framer-motion'
import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth'
import { ErrorBox, Icon, Orbs, ago, fmtTime, grad } from '../components/ui'
import type { Help, Hub } from '../types'
import { useFetch } from '../useFetch'

const CATS: [string, string][] = [['stay', 'Stay'], ['food', 'Food'], ['transport', 'Transport'], ['venue', 'Venue or directions'], ['registration', 'Registration'], ['lost', 'Lost and found'], ['medical', 'Medical'], ['other', 'Something else']]
const STATUS: Record<string, [string, string]> = { open: ['New', 'var(--deep)'], in_progress: ['Being handled', 'var(--info)'], resolved: ['Resolved', 'var(--ok)'], closed: ['Closed', 'var(--ok)'] }

function Chat({ eventId, helpId, onBack }: { eventId: string; helpId: number | null; onBack: () => void }) {
  const [id, setId] = useState(helpId)
  const [h, setH] = useState<Help | null>(null)
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const end = useRef<HTMLDivElement>(null)

  const load = useCallback(async () => {
    if (!id) return
    try { setH((await api.get<Help>(`/help/${id}`)).data) } catch { /* next poll retries */ }
  }, [id])
  useEffect(() => { load(); const t = setInterval(load, 5000); return () => clearInterval(t) }, [load])
  useEffect(() => { end.current?.scrollIntoView({ behavior: 'smooth' }) }, [h?.replies.length])

  async function send(e: FormEvent) {
    e.preventDefault()
    if (!text.trim()) return
    setBusy(true); setErr(null)
    try {
      const r = id ? await api.post<Help>(`/help/${id}/reply`, { body: text.trim() }) : await api.post<Help>(`/events/${eventId}/help`, { category: 'chat', message: text.trim() })
      setH(r.data); setId(r.data.id); setText('')
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  const msgs = h ? [{ id: 0, mine: true, by: null, body: h.message, at: h.at, from_team: false }, ...h.replies] : []
  return (
    <div className="chat">
      <div className="chat-head">
        <button className="icon-btn" onClick={onBack} aria-label="Back"><Icon name="back" /></button>
        <span style={{ width: 44, height: 44, borderRadius: 22, display: 'grid', placeItems: 'center', color: '#fff', background: grad('support') }}><Icon name="support" /></span>
        <div><b>Help desk</b>{h && <div style={{ fontSize: 13, color: STATUS[h.status]?.[1] }}>{STATUS[h.status]?.[0]}</div>}</div>
      </div>
      <div className="chat-body">
        {msgs.length === 0 && (
          <motion.div initial={{ opacity: 0, scale: .9 }} animate={{ opacity: 1, scale: 1 }} style={{ margin: 'auto', textAlign: 'center', display: 'grid', gap: 10, justifyItems: 'center', maxWidth: 360 }}>
            <span style={{ width: 80, height: 80, borderRadius: 40, display: 'grid', placeItems: 'center', color: '#fff', background: grad('support') }}><Icon name="chat" size={36} /></span>
            <b style={{ fontSize: 20 }}>Chat with the help desk</b>
            <span className="muted">Ask anything – which bus, where is my block, I lost something…</span>
          </motion.div>
        )}
        <AnimatePresence initial={false}>
          {msgs.map((m) => (
            <motion.div key={`${m.id}-${m.at}`} className={`bubble ${m.mine ? 'me' : 'them'}`} initial={{ opacity: 0, x: m.mine ? 20 : -20 }} animate={{ opacity: 1, x: 0 }}>
              {m.from_team && <span className="by">{m.by}</span>}
              {m.body}<small>{fmtTime(m.at)}</small>
            </motion.div>
          ))}
        </AnimatePresence>
        {msgs.length > 0 && msgs.every((m) => m.mine) && <p className="muted" style={{ textAlign: 'center', fontSize: 13 }}>Sent. A volunteer will reply here soon.</p>}
        <div ref={end} />
      </div>
      <form className="chat-input" onSubmit={send}>
        <ErrorBox error={err} />
        <input className="input" placeholder="Type a message" value={text} onChange={(e) => setText(e.target.value)} maxLength={1000} aria-label="Message" />
        <button className="btn primary" disabled={busy || !text.trim()} aria-label="Send"><Icon name="send" size={18} /></button>
      </form>
    </div>
  )
}

function Ticket({ eventId, onDone, onBack }: { eventId: string; onDone: (id: number) => void; onBack: () => void }) {
  const [cat, setCat] = useState('stay')
  const [msg, setMsg] = useState('')
  const [where, setWhere] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  return (
    <motion.form className="card" style={{ display: 'grid', gap: 16, maxWidth: 680 }} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }}
      onSubmit={async (e) => {
        e.preventDefault(); setBusy(true); setErr(null)
        try { onDone((await api.post<Help>(`/events/${eventId}/help`, { category: cat, message: msg, location: where || null })).data.id) } catch (x) { setErr(x) } finally { setBusy(false) }
      }}>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}><button type="button" className="icon-btn" onClick={onBack} aria-label="Back"><Icon name="back" /></button><h2 style={{ fontSize: 24, fontWeight: 800 }}>Raise a ticket</h2></div>
      <ErrorBox error={err} />
      <div className="chips">{CATS.map(([k, l]) => <button type="button" key={k} className={`chip-btn ${cat === k ? 'on' : ''}`} onClick={() => setCat(k)}>{l}</button>)}</div>
      {cat === 'medical' && <div className="error" style={{ display: 'flex', gap: 12, alignItems: 'center' }}>For a medical emergency call 108 now. This also alerts the event team.<a className="btn sm" href="tel:108" style={{ marginLeft: 'auto' }}>Call 108</a></div>}
      <div className="field"><label htmlFor="msg">What do you need? *</label><textarea id="msg" className="input" required minLength={5} maxLength={1000} value={msg} onChange={(e) => setMsg(e.target.value)} /></div>
      <div className="field"><label htmlFor="where">Where are you? (optional)</label><input id="where" className="input" maxLength={160} value={where} onChange={(e) => setWhere(e.target.value)} /></div>
      <button className="btn primary" disabled={busy || msg.trim().length < 5}>{busy ? 'Sending…' : 'Send to the help desk'}</button>
    </motion.form>
  )
}

export default function Support() {
  const { id = '' } = useParams()
  const { me } = useAuth()
  const hub = useFetch<Hub>(`/events/${id}/guide`)
  const list = useFetch<Help[]>(me ? '/me/help' : null)
  const [view, setView] = useState<{ t: 'list' } | { t: 'chat'; id: number | null } | { t: 'ticket' }>({ t: 'list' })
  const mine = (list.data ?? []).filter((h) => String(h.event.id) === id)
  const helpline = hub.data?.event.helpline

  return (
    <div className="page wrap" style={{ maxWidth: 900 }}>
      <div className="banner" style={{ background: 'linear-gradient(135deg, #F6A04D, #E3620C 50%, #B84C04)' }}>
        <Orbs />
        <div style={{ position: 'relative', zIndex: 2 }}>
          <button onClick={() => history.length > 1 ? history.back() : undefined} className="btn glass sm" style={{ marginBottom: 14 }}><Icon name="back" size={16} /> Back</button>
          <div className="hi" style={{ fontSize: 20, opacity: .85 }}>सहायता · आपातकाल</div>
          <h1>Help and emergency</h1>
          <p style={{ opacity: .9 }}>{hub.data?.event.title}</p>
        </div>
      </div>
      <div className="sos-card">
        <span className="ic"><Icon name="emergency" size={28} /></span>
        <div style={{ flex: 1, minWidth: 200 }}><b>Emergency – call now</b><span>Ambulance 108 · Police 112 · Women helpline 181{helpline ? ` · Helpline ${helpline}` : ''}</span></div>
        <div className="sos-btns">
          <a className="btn" href="tel:108"><Icon name="phone" size={16} /> 108</a>
          {helpline && <a className="btn" href={`tel:${helpline}`}><Icon name="phone" size={16} /> Helpline</a>}
          {me && <Link className="btn ghost" to={`/guide/${id}/emergency`}>Leads by hall</Link>}
        </div>
      </div>
      {!me ? (
        <div className="card" style={{ display: 'grid', gap: 14, maxWidth: 560 }}>
          <h2 style={{ fontSize: 24, fontWeight: 800 }}>Need help?</h2>
          <p className="muted">Call the helpline now, or sign in to chat with the help desk.</p>
          {helpline && <a className="btn primary" href={`tel:${helpline}`}><Icon name="phone" /> Call helpline {helpline}</a>}
          <Link className="btn" to={`/login?next=/support/${id}`}>Sign in to chat</Link>
        </div>
      ) : view.t === 'chat' ? <Chat eventId={id} helpId={view.id} onBack={() => { setView({ t: 'list' }); list.reload() }} />
        : view.t === 'ticket' ? <Ticket eventId={id} onBack={() => setView({ t: 'list' })} onDone={(hid) => setView({ t: 'chat', id: hid })} />
          : (
            <div style={{ display: 'grid', gap: 14 }}>
              <motion.button className="card" whileHover={{ y: -3 }} onClick={() => setView({ t: 'chat', id: null })} style={{ border: 0, display: 'flex', gap: 16, alignItems: 'center', color: '#fff', background: grad('support'), cursor: 'pointer', textAlign: 'left' }}>
                <span style={{ width: 52, height: 52, borderRadius: 18, display: 'grid', placeItems: 'center', background: 'rgba(255,255,255,.22)' }}><Icon name="chat" /></span>
                <span style={{ flex: 1 }}><b style={{ fontSize: 18, display: 'block' }}>Chat with the help desk</b><span style={{ opacity: .85 }}>Quick questions – a volunteer replies here</span></span><Icon name="arrow" />
              </motion.button>
              <motion.button className="card" whileHover={{ y: -3 }} onClick={() => setView({ t: 'ticket' })} style={{ border: 0, display: 'flex', gap: 16, alignItems: 'center', cursor: 'pointer', textAlign: 'left' }}>
                <span style={{ width: 52, height: 52, borderRadius: 18, display: 'grid', placeItems: 'center', background: 'var(--soft)', color: 'var(--deep)' }}><Icon name="ticket" /></span>
                <span style={{ flex: 1 }}><b style={{ fontSize: 18, display: 'block' }}>Raise a ticket</b><span className="muted">Stay, food, transport, lost and found, medical</span></span><Icon name="arrow" />
              </motion.button>
              <h2 style={{ fontSize: 24, fontWeight: 800, marginTop: 14 }}>My conversations</h2>
              {mine.length === 0 && <p className="muted">No conversations yet. Start a chat – the help desk is here for you.</p>}
              {mine.map((h, i) => {
                const last = h.replies[h.replies.length - 1]
                return (
                  <motion.button key={h.id} className="card" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * .05 }} onClick={() => setView({ t: 'chat', id: h.id })}
                    style={{ border: 0, display: 'grid', gap: 4, textAlign: 'left', cursor: 'pointer', padding: 18 }}>
                    <span style={{ display: 'flex', justifyContent: 'space-between' }}><b>{h.category === 'chat' ? 'Chat' : h.category_label}</b><span className="muted" style={{ fontSize: 13 }}>{ago(h.at)}</span></span>
                    <span className={last?.from_team ? '' : 'muted'} style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{last?.from_team ? `Help desk: ${last.body}` : (last?.body ?? h.message)}</span>
                    <span className="chip" style={{ justifySelf: 'start', color: STATUS[h.status]?.[1] }}>{STATUS[h.status]?.[0]}</span>
                  </motion.button>
                )
              })}
            </div>
          )}
    </div>
  )
}
