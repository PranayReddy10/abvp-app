import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../auth'
import { Avatar, ErrorBox, Icon, KIND, Orbs, Reveal, Skeleton, fmtDate, grad, telHref, useCountdown, waHref } from '../components/ui'
import type { Contact, GuideItem, Hub } from '../types'
import { useFetch } from '../useFetch'

function When({ starts, ends }: { starts: string; ends: string }) {
  const c = useCountdown(starts)
  const live = c.done && Date.now() < new Date(ends).getTime()
  return <span className="chip" style={{ background: 'rgba(255,255,255,.18)', color: '#fff' }}>{live ? <><span className="live-dot" style={{ marginRight: 8 }} />Live now</> : `${fmtDate(starts)} · in ${c.d} days`}</span>
}

export function GuideHub() {
  const { id } = useParams()
  const { data: hub, error } = useFetch<Hub>(`/events/${id}/guide`)
  const navigate = useNavigate()
  if (error) return <div className="page wrap"><ErrorBox error={error} /></div>
  if (!hub) return <div className="page wrap"><Skeleton h={180} n={3} /></div>
  const e = hub.event
  const stay = hub.my_stays[0]
  const lead = stay?.contacts.find((c) => c.is_lead)
  return (
    <div style={{ paddingBottom: 60 }}>
      <section className="hero" style={{ minHeight: 0, padding: '120px 0 110px' }}>
        <Orbs />
        <div className="wrap" style={{ display: 'block' }}>
          <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} style={{ display: 'grid', gap: 14, maxWidth: 760 }}>
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <When starts={e.starts_at} ends={e.ends_at} />
              {e.helpline && <a className="chip" href={telHref(e.helpline)} style={{ background: '#fff', color: 'var(--ink)' }}><Icon name="phone" size={15} />&nbsp;Helpline {e.helpline}</a>}
            </div>
            <span style={{ opacity: .85, fontWeight: 600 }}>Conference guide · <span className="hi">अधिवेशन मार्गदर्शिका</span></span>
            <h1 style={{ fontSize: 'clamp(34px, 5vw, 58px)', fontWeight: 800 }}>{e.title}</h1>
            <p style={{ display: 'flex', gap: 8, opacity: .9 }}><Icon name="pin" /> {e.venue}</p>
            {e.delegate_registration_open && <div><Link to={`/conference/${e.id}/register`} className="btn" style={{ background: '#fff', color: 'var(--deep)' }}>Register as delegate <Icon name="arrow" size={18} /></Link></div>}
          </motion.div>
        </div>
      </section>
      <div className="wrap" style={{ marginTop: -60, position: 'relative', zIndex: 3 }}>
        <Reveal>
          <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap', cursor: 'pointer' }} onClick={() => navigate(`/guide/${id}/stay`)}>
            <span className="tile ic" style={{ width: 56, height: 56, borderRadius: 18, display: 'grid', placeItems: 'center', color: '#fff', background: grad('stay') }}><Icon name="bed" size={26} /></span>
            <div style={{ flex: 1, minWidth: 200 }}>
              {stay ? <>
                <small style={{ color: KIND.stay.b, fontWeight: 800, letterSpacing: '.06em' }}>YOUR STAY · {hub.my_region?.toUpperCase()}</small>
                <div style={{ fontWeight: 800, fontSize: 19 }}>{stay.title}</div>
                <div className="muted">{[stay.location, lead && `Lead: ${lead.name}`].filter(Boolean).join(' · ')}</div>
              </> : <>
                <div style={{ fontWeight: 800, fontSize: 19 }}>Where am I staying?</div>
                <div className="muted">Pick your prant to see your stay and its lead{hub.signed_in ? '' : ' – or sign in to see it here'}</div>
              </>}
            </div>
            {lead?.phone ? <a className="call" href={telHref(lead.phone)} onClick={(ev) => ev.stopPropagation()} aria-label={`Call ${lead.name}`}><Icon name="phone" size={18} /></a> : <Icon name="arrow" />}
          </div>
        </Reveal>
        <Reveal i={1}><h2 style={{ fontSize: 28, fontWeight: 800, margin: '36px 0 16px' }}>Everything you need</h2></Reveal>
        <div className="tiles">
          {[...hub.sections, { kind: 'support', title: 'Support', hindi: 'सहायता', count: hub.open_tickets }].map((s, i) => (
            <motion.button key={s.kind} className="tile" onClick={() => navigate(s.kind === 'support' ? `/support/${id}` : `/guide/${id}/${s.kind}`)}
              initial={{ opacity: 0, scale: .9, y: 16 }} animate={{ opacity: 1, scale: 1, y: 0 }} transition={{ delay: .1 + i * .05, type: 'spring', stiffness: 260, damping: 22 }}
              style={s.kind === 'emergency' ? { background: '#FFF4F4' } : undefined}>
              <span className="top">
                <span className="ic" style={{ background: grad(s.kind) }}><Icon name={KIND[s.kind]?.icon ?? 'sparkle'} size={26} /></span>
                {s.count > 0 && <span className="count" style={{ color: KIND[s.kind]?.b }}>{s.count}</span>}
              </span>
              <span><b>{s.title}</b><span className="hi">{s.hindi}</span></span>
            </motion.button>
          ))}
        </div>
      </div>
    </div>
  )
}

function Leads({ contacts, kind }: { contacts: Contact[]; kind: string }) {
  const leads = contacts.filter((c) => c.is_lead)
  const team = contacts.filter((c) => !c.is_lead)
  return (
    <div>
      {leads.map((c) => (
        <div key={c.id} className="lead-big" style={{ background: grad(kind), marginBottom: 8 }}>
          <span className="avatar">{c.name.split(' ').map((w) => w[0]).slice(0, 2).join('')}</span>
          <div style={{ flex: 1 }}><small style={{ opacity: .8, fontWeight: 700 }}>★ {c.role ?? 'Lead'}</small><div style={{ fontWeight: 800, fontSize: 17 }}>{c.name}</div>{c.phone && <small style={{ opacity: .8 }}>{c.phone}</small>}</div>
          {c.phone && c.phone.replace(/\D/g, '').length > 5 && <a className="wa" href={waHref(c.phone)} target="_blank" rel="noreferrer" aria-label={`WhatsApp ${c.name}`}><Icon name="chat" size={18} /></a>}
          {c.phone && <a className="call" href={telHref(c.phone)} aria-label={`Call ${c.name}`}><Icon name="phone" size={18} /></a>}
        </div>
      ))}
      {team.length > 0 && (
        <div className="team">
          {team.map((c) => (
            <div key={c.id} className="lead-row" style={{ background: '#fff' }}>
              <Avatar name={c.name} size={36} />
              <div style={{ flex: 1 }}><b>{c.name}</b><div className="muted" style={{ fontSize: 13.5 }}>{[c.role, c.phone].filter(Boolean).join(' · ')}</div></div>
              {c.phone && <a className="wa" href={waHref(c.phone)} target="_blank" rel="noreferrer" aria-label={`WhatsApp ${c.name}`}><Icon name="chat" size={17} /></a>}
              {c.phone && <a className="call" href={telHref(c.phone)} aria-label={`Call ${c.name}`}><Icon name="phone" size={17} /></a>}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function ItemSheet({ item, onClose }: { item: GuideItem; onClose: () => void }) {
  useEffect(() => {
    const k = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', k)
    document.body.style.overflow = 'hidden'
    return () => { window.removeEventListener('keydown', k); document.body.style.overflow = '' }
  }, [onClose])
  const accent = item.color ?? KIND[item.kind]?.a
  return (
    <motion.div className="overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <motion.aside className="sheet" role="dialog" aria-label={item.title} initial={{ x: 80, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: 80, opacity: 0 }} transition={{ type: 'spring', stiffness: 260, damping: 30 }}>
        <div className="cover" style={{ background: item.color ? `linear-gradient(135deg, ${item.color}, #14161F)` : grad(item.kind) }}>
          {item.photo_urls[0] && <img src={item.photo_urls[0]} alt="" />}
          <button className="icon-btn" onClick={onClose} aria-label="Close" style={{ position: 'absolute', top: 16, right: 16, zIndex: 2, color: 'var(--ink)' }}><Icon name="close" /></button>
          <div>
            {item.region && <small style={{ fontWeight: 800, letterSpacing: '.08em' }}>{item.region.toUpperCase()}</small>}
            <h2 style={{ fontSize: 30, fontWeight: 800 }}>{item.title}</h2>
            {item.subtitle && <p style={{ opacity: .9 }}>{item.subtitle}</p>}
          </div>
        </div>
        <div className="body">
          {item.tags.length > 0 && <div className="chips">{item.tags.map((t) => <span key={t} className="chip" style={{ background: `${accent}1f`, color: KIND[item.kind]?.b }}>{t}</span>)}</div>}
          <div className="info">
            {item.location && <div><Icon name="pin" /><span><small>Where</small><b>{item.location}</b></span></div>}
            {item.landmark && <div><Icon name="eye" /><span><small>{item.kind === 'emergency' ? 'Note' : 'Look for'}</small><b>{item.color && <i style={{ display: 'inline-block', width: 12, height: 12, borderRadius: 6, background: item.color, marginRight: 6 }} />}{item.landmark}</b></span></div>}
            {item.timings && <div><Icon name="clock" /><span><small>Timings</small><b>{item.timings}</b></span></div>}
            {(item.distance_km !== null || item.travel_time) && <div><Icon name="route" /><span><small>{item.kind === 'arrival' ? 'To the venue' : 'From the venue'}</small><b>{[item.distance_km !== null && `${item.distance_km} km${item.distance_is_road ? '' : ' (straight line)'}`, item.travel_time].filter(Boolean).join(' · ')}</b></span></div>}
          </div>
          {item.directions_url && <a className="btn primary block" href={item.directions_url} target="_blank" rel="noreferrer"><Icon name="route" /> {item.kind === 'arrival' ? 'Route to venue' : 'Directions'}</a>}
          {item.description && <p style={{ fontSize: 16, lineHeight: 1.6 }}>{item.description}</p>}
          {item.steps.length > 0 && (
            <div>
              <h3 style={{ fontSize: 20, fontWeight: 800, marginBottom: 12 }}>{item.kind === 'arrival' ? 'How to reach the venue' : 'How to get there'}</h3>
              <div className="timeline">
                {item.steps.map((s, i) => (
                  <motion.div key={i} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: .15 + i * .08 }}>
                    <span className="n" style={{ background: grad(item.kind) }}>{i + 1}</span><span style={{ paddingTop: 4 }}>{s}</span>
                  </motion.div>
                ))}
              </div>
            </div>
          )}
          {item.photo_urls.length > 1 && <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>{item.photo_urls.slice(1).map((u) => <img key={u} src={u} alt="" style={{ borderRadius: 16, height: 140, width: '100%', objectFit: 'cover' }} />)}</div>}
          {item.contacts.length > 0 && <><h3 style={{ fontSize: 20, fontWeight: 800 }}>{item.kind === 'emergency' ? 'Lead members' : 'Who to contact'}</h3><Leads contacts={item.contacts} kind={item.kind} /></>}
        </div>
      </motion.aside>
    </motion.div>
  )
}

function ItemCard({ item, onOpen, i, extra }: { item: GuideItem; onOpen: () => void; i: number; extra?: string }) {
  const lead = item.contacts.find((c) => c.is_lead)
  const accent = item.color ?? KIND[item.kind]?.a
  return (
    <Reveal i={i % 6}>
      <motion.article className="item" onClick={onOpen} whileHover={{ y: -4 }} tabIndex={0} onKeyDown={(e) => { if (e.key === 'Enter') onOpen() }}>
        {item.photo_urls[0] ? <img src={item.photo_urls[0]} alt="" /> : <span className="bar" style={{ background: accent }} />}
        <div className="in">
          {extra && <span className="chip" style={{ background: `${accent}22`, color: KIND[item.kind]?.b, justifySelf: 'start' }}>{extra}</span>}
          <h3>{item.title}</h3>
          {item.subtitle && <span className="muted">{item.subtitle}</span>}
          {item.location && item.kind !== 'arrival' && <span className="line" style={{ color: 'var(--ink)' }}><Icon name="pin" size={16} />{item.location}</span>}
          {item.landmark && <span className="line"><Icon name="eye" size={16} />{item.kind === 'emergency' ? item.landmark : `Look for: ${item.landmark}`}</span>}
          {item.timings && <span className="line"><Icon name="clock" size={16} />{item.timings}</span>}
          {item.kind === 'arrival' && (item.distance_km !== null || item.travel_time) && <span className="line"><Icon name="route" size={16} />{[item.distance_km !== null && `${item.distance_km} km to venue`, item.travel_time].filter(Boolean).join(' · ')}</span>}
          {item.tags.length > 0 && <div className="chips" style={{ marginTop: 4 }}>{item.tags.slice(0, 4).map((t) => <span key={t} className="chip" style={{ background: `${accent}1f`, color: KIND[item.kind]?.b }}>{t}</span>)}</div>}
          {lead && (
            <div className="lead-row" style={{ marginTop: 8 }}>
              <Avatar name={lead.name} size={34} />
              <div style={{ flex: 1 }}><b style={{ fontSize: 15 }}>{lead.name}</b><div className="muted" style={{ fontSize: 13 }}>{lead.role ?? 'Lead'}</div></div>
              {lead.phone && <a className="call" href={telHref(lead.phone)} onClick={(e) => e.stopPropagation()} aria-label={`Call ${lead.name}`}><Icon name="phone" size={17} /></a>}
            </div>
          )}
        </div>
      </motion.article>
    </Reveal>
  )
}

const km = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => {
  const r = (d: number) => d * Math.PI / 180
  const x = Math.sin(r(b.lat - a.lat) / 2) ** 2 + Math.cos(r(a.lat)) * Math.cos(r(b.lat)) * Math.sin(r(b.lng - a.lng) / 2) ** 2
  return 6371 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x))
}

export function GuideSection() {
  const { id, kind = 'stay' } = useParams()
  const { me } = useAuth()
  const { data, error } = useFetch<GuideItem[]>(`/events/${id}/guide/${kind}`)
  const [open, setOpen] = useState<GuideItem | null>(null)
  const [q, setQ] = useState('')
  const [prant, setPrant] = useState<string | null>(null)
  const [tag, setTag] = useState<string | null>(null)
  const [here, setHere] = useState<{ lat: number; lng: number } | null>(null)
  const [locErr, setLocErr] = useState(false)
  const k = KIND[kind] ?? KIND.stay

  const items = useMemo(() => data ?? [], [data])
  const prants = useMemo(() => {
    const m = new Map<string, number>()
    items.forEach((i) => i.region && m.set(i.region, (m.get(i.region) ?? 0) + 1))
    return [...m.entries()].sort((a, b) => (a[0] === me?.prant ? -1 : b[0] === me?.prant ? 1 : a[0].localeCompare(b[0])))
  }, [items, me])

  let body
  if (error) body = <ErrorBox error={error} />
  else if (!data) body = <Skeleton h={160} />
  else if (kind === 'stay' && !prant) {
    const list = prants.filter(([p]) => p.toLowerCase().includes(q.toLowerCase()))
    body = (
      <>
        <input className="input" placeholder="Search your prant: Delhi, Konkan, Kerala…" value={q} onChange={(e) => setQ(e.target.value)} style={{ maxWidth: 520, marginBottom: 18 }} aria-label="Search prant" />
        <div className="tiles">
          {list.map(([p, n], i) => (
            <motion.button key={p} className="tile" onClick={() => setPrant(p)} initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: Math.min(i, 16) * .025 }}
              style={p === me?.prant ? { background: grad('stay'), color: '#fff' } : undefined}>
              <span className="top"><span className="ic" style={{ background: p === me?.prant ? 'rgba(255,255,255,.22)' : '#EEEBFF', color: p === me?.prant ? '#fff' : KIND.stay.b, fontWeight: 800, fontSize: 20 }}>{p[0]}</span>{p === me?.prant ? <span className="chip" style={{ background: 'rgba(255,255,255,.2)', color: '#fff' }}>Your prant</span> : <Icon name="ne" />}</span>
              <span><b>{p}</b><span style={{ opacity: .75, fontSize: 14 }}>{n} place{n === 1 ? '' : 's'}</span></span>
            </motion.button>
          ))}
        </div>
      </>
    )
  } else if (kind === 'emergency') {
    const isNum = (i: GuideItem) => i.contacts.length > 0 && i.contacts.every((c) => (c.phone ?? '').replace(/\D/g, '').length < 6)
    const nums = items.filter(isNum)
    const halls = items.filter((i) => !isNum(i))
    const sos = nums[0]?.contacts[0]?.phone
    body = (
      <>
        {sos && <a className="sos" href={telHref(sos)} aria-label={`Call ${nums[0].title} ${sos}`}><i /><i /><i /><b><span>📞<br />{sos}<small>{nums[0].title}</small></span></b></a>}
        <p className="muted" style={{ textAlign: 'center' }}>Tap to call. Then tell the nearest volunteer.</p>
        <div className="chips" style={{ justifyContent: 'center', margin: '18px 0 34px' }}>
          {nums.map((n) => <a key={n.id} className="btn" href={telHref(n.contacts[0].phone!)} style={{ color: 'var(--bad)' }}><Icon name="phone" size={16} /> <b>{n.contacts[0].phone}</b> {n.title}</a>)}
        </div>
        <h2 style={{ fontSize: 26, fontWeight: 800 }}>Emergency leads by hall</h2>
        <p className="muted" style={{ margin: '4px 0 18px' }}>Go to the nearest one or call them – they know where the doctor and ambulance are.</p>
        <div className="items">
          {halls.map((h, i) => (
            <Reveal key={h.id} i={i % 6}>
              <div className="item" style={{ cursor: 'default' }}>
                <div style={{ background: grad('emergency'), color: '#fff', padding: 18, cursor: 'pointer' }} onClick={() => setOpen(h)}>
                  <h3 style={{ fontSize: 21 }}>{h.location ?? h.title}</h3><span style={{ opacity: .85 }}>{h.title}</span>
                </div>
                <div className="in">{h.landmark && <span className="line" style={{ color: 'var(--ink)' }}><Icon name="eye" size={16} />{h.landmark}</span>}<Leads contacts={h.contacts} kind="emergency" /></div>
              </div>
            </Reveal>
          ))}
        </div>
      </>
    )
  } else {
    let list = kind === 'stay' ? items.filter((i) => i.region === prant) : items
    const tags = [...new Set(items.flatMap((i) => i.tags))]
    if (tag) list = list.filter((i) => i.tags.includes(tag))
    if (kind === 'arrival' && here) list = [...list].sort((a, b) => (a.lat ? km(here, { lat: a.lat, lng: a.lng! }) : 1e9) - (b.lat ? km(here, { lat: b.lat, lng: b.lng! }) : 1e9))
    body = (
      <>
        {kind === 'stay' && <button className="btn sm" onClick={() => setPrant(null)} style={{ marginBottom: 16 }}><Icon name="back" size={16} /> All prants</button>}
        {kind === 'arrival' && (
          <motion.button className="card" whileHover={{ y: -3 }} style={{ border: 0, width: '100%', display: 'flex', gap: 14, alignItems: 'center', background: 'var(--ink)', color: '#fff', cursor: 'pointer', marginBottom: 18, textAlign: 'left' }}
            onClick={() => navigator.geolocation?.getCurrentPosition((p) => { setHere({ lat: p.coords.latitude, lng: p.coords.longitude }); setLocErr(false) }, () => setLocErr(true))}>
            <span className="ic" style={{ width: 48, height: 48, borderRadius: 24, display: 'grid', placeItems: 'center', background: grad('arrival') }}><Icon name="locate" /></span>
            <span style={{ flex: 1 }}><small style={{ opacity: .7 }}>{here ? 'Nearest help desk' : 'Just arrived?'}</small><b style={{ display: 'block', fontSize: 17 }}>{here && list[0]?.lat ? `${list[0].title} · ${km(here, { lat: list[0].lat, lng: list[0].lng! }).toFixed(1)} km away` : 'Find the desk nearest to me'}</b></span>
            <Icon name="arrow" />
          </motion.button>
        )}
        {locErr && <div className="hint" style={{ marginBottom: 14 }}>Could not get your location. Allow location in the browser, or pick your station below.</div>}
        {tags.length > 1 && kind !== 'stay' && (
          <div className="chips" style={{ marginBottom: 18 }}>
            <button className={`chip-btn ${!tag ? 'on' : ''}`} onClick={() => setTag(null)}>All</button>
            {tags.map((t) => <button key={t} className={`chip-btn ${tag === t ? 'on' : ''}`} onClick={() => setTag(t)}>{t}</button>)}
          </div>
        )}
        {list.length === 0 ? <p className="muted">Nothing here yet.</p> : (
          <div className="items">
            {list.map((it, i) => <ItemCard key={it.id} item={it} i={i} onOpen={() => setOpen(it)} extra={kind === 'arrival' && here && i === 0 ? 'Nearest to you' : kind === 'session' ? it.timings ?? undefined : undefined} />)}
          </div>
        )}
      </>
    )
  }

  return (
    <div className="page" style={{ paddingTop: 0 }}>
      <div className="banner" style={{ background: grad(kind), borderRadius: '0 0 36px 36px', padding: '120px 0 44px', marginBottom: 30 }}>
        <Orbs />
        <div className="wrap" style={{ position: 'relative', zIndex: 2, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 20 }}>
          <div>
            <Link to={`/guide/${id}`} className="btn glass sm" style={{ marginBottom: 18 }}><Icon name="back" size={16} /> Guide</Link>
            <div className="hi" style={{ fontSize: 22, opacity: .85, fontWeight: 600 }}>{k.hindi}</div>
            <h1>{kind === 'stay' && prant ? prant : k.title}</h1>
            {data && <p style={{ opacity: .85 }}>{kind === 'stay' && !prant ? `${prants.length} prants · ${items.length} places` : `${kind === 'stay' ? items.filter((i) => i.region === prant).length : items.length} places`}</p>}
          </div>
          <motion.span initial={{ scale: .6, rotate: -15, opacity: 0 }} animate={{ scale: 1, rotate: 0, opacity: 1 }} transition={{ type: 'spring', stiffness: 200, damping: 14 }}
            style={{ width: 88, height: 88, borderRadius: 28, background: 'rgba(255,255,255,.2)', display: 'grid', placeItems: 'center' }}><Icon name={k.icon} size={44} /></motion.span>
        </div>
      </div>
      <div className="wrap">{body}</div>
      <AnimatePresence>{open && <ItemSheet item={open} onClose={() => setOpen(null)} />}</AnimatePresence>
    </div>
  )
}
