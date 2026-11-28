import { motion, useScroll, useTransform } from 'framer-motion'
import { useRef } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../auth'
import { useConference } from '../components/Layout'
import { useSeo } from '../seo'
import { Icon, KIND, Orbs, Reveal, Tilt, fmtDate, grad, useCountdown } from '../components/ui'

const words = (s: string, delay = 0) => s.split(' ').map((w, i) => (
  <motion.span key={i} style={{ display: 'inline-block', marginRight: '.24em' }}
    initial={{ y: '110%', opacity: 0 }} animate={{ y: 0, opacity: 1 }}
    transition={{ duration: .7, delay: delay + i * .07, ease: [.2, .7, .2, 1] }}>{w}</motion.span>
))

function Countdown({ iso }: { iso: string }) {
  const c = useCountdown(iso)
  if (c.done) return <div style={{ display: 'flex', gap: 10, alignItems: 'center', fontWeight: 800, fontSize: 20 }}><span className="live-dot" /> Happening now</div>
  return (
    <div className="countdown" aria-label={`${c.d} days ${c.h} hours to go`}>
      {[[c.d, 'Days'], [c.h, 'Hours'], [c.m, 'Minutes'], [c.s, 'Seconds']].map(([v, l]) => (
        <div key={l}>
          <motion.b key={String(v)} initial={{ y: -8, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ duration: .25 }}>{String(v).padStart(2, '0')}</motion.b>
          <span>{l}</span>
        </div>
      ))}
    </div>
  )
}

export default function Home() {
  const { conf } = useConference()
  const { me } = useAuth()
  const hero = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: hero, offset: ['start start', 'end start'] })
  const phonesY = useTransform(scrollYProgress, [0, 1], [0, 140])
  const textY = useTransform(scrollYProgress, [0, 1], [0, 60])
  const fade = useTransform(scrollYProgress, [0, .8], [1, 0])
  const e = conf?.event
  useSeo({ title: 'ABVP Connect – Rashtriya Adhiveshan app, delegate registration and help desk', path: '/', jsonLd: e ? {
    '@type': 'Event', name: e.title, startDate: e.starts_at, endDate: e.ends_at,
    eventStatus: 'https://schema.org/EventScheduled', eventAttendanceMode: 'https://schema.org/OfflineEventAttendanceMode',
    location: { '@type': 'Place', name: e.venue, address: { '@type': 'PostalAddress', streetAddress: e.venue, addressCountry: 'IN' } },
    organizer: { '@type': 'Organization', name: 'Akhil Bharatiya Vidyarthi Parishad', url: 'https://abvpconnect.org/' },
    image: 'https://abvpconnect.org/og-image.jpg', url: `https://abvpconnect.org/events/${e.id}`,
  } : null })
  const regLink = e ? (me ? `/conference/${e.id}/register` : `/signup?next=/conference/${e.id}/register`) : '/signup'

  return (
    <>
      <section className="hero" ref={hero}>
        <Orbs />
        <div className="wrap">
          <motion.div style={{ y: textY, opacity: fade }}>
            <motion.span className="tag" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: .5 }}>
              <span className="live-dot" /> {e ? `${e.title} · ${fmtDate(e.starts_at)}` : 'Akhil Bharatiya Vidyarthi Parishad'}
            </motion.span>
            <h1 style={{ marginTop: 22 }}>
              <span className="hl">{words('One app for', .1)}</span>
              <span className="hl">{words('every karyakarta.', .35)}</span>
            </h1>
            <motion.p className="lead" initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: .8, duration: .6 }}>
              Your stay, transport, food, help desks and emergency contacts for the national conference – with a real person to call for each. Fill the delegate form once and the whole guide opens for you.
            </motion.p>
            <motion.p className="hi" style={{ fontSize: 18, opacity: .85, marginTop: 10 }} initial={{ opacity: 0 }} animate={{ opacity: .85 }} transition={{ delay: 1 }}>
              एक सदस्य · एक पहचान · हर कार्यक्रम
            </motion.p>
            <motion.div className="actions" initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 1.05, duration: .5 }}>
              {e?.delegate_registration_open && <Link to={regLink} className="btn primary" style={{ background: '#fff', color: 'var(--deep)' }}>Register as delegate <Icon name="arrow" size={18} /></Link>}
              {e && <Link to={`/guide/${e.id}`} className="btn glass">Open the conference guide</Link>}
              {!e && <Link to="/signup" className="btn primary">Create your account</Link>}
            </motion.div>
          </motion.div>
          <motion.div className="hero-phones" style={{ y: phonesY }}>
            <motion.div className="phone" style={{ left: '4%', top: 40, rotate: -8, zIndex: 2 }}
              initial={{ opacity: 0, y: 80, rotate: -16 }} animate={{ opacity: 1, y: [0, -12, 0], rotate: -8 }}
              transition={{ opacity: { delay: .4, duration: .8 }, rotate: { delay: .4, duration: .9 }, y: { delay: 1.3, duration: 6, repeat: Infinity, ease: 'easeInOut' } }}>
              <img src="/img/app-home.jpg" alt="Home in the ABVP Connect app" />
            </motion.div>
            <motion.div className="phone" style={{ right: '2%', top: 110, rotate: 7, zIndex: 1 }}
              initial={{ opacity: 0, y: 100, rotate: 16 }} animate={{ opacity: 1, y: [0, 14, 0], rotate: 7 }}
              transition={{ opacity: { delay: .6, duration: .8 }, rotate: { delay: .6, duration: .9 }, y: { delay: 1.5, duration: 7, repeat: Infinity, ease: 'easeInOut' } }}>
              <img src="/img/app-guide.jpg" alt="The conference guide in the app" />
            </motion.div>
          </motion.div>
        </div>
        <div className="scroll-hint" aria-hidden="true" />
      </section>

      {e && (
        <section className="block" style={{ paddingBottom: 30 }}>
          <div className="wrap">
            <Reveal>
              <div className="conf">
                <Orbs seed={1} />
                <div className="wrap-in">
                  <div style={{ display: 'grid', gap: 14 }}>
                    <span className="eyebrow" style={{ color: '#FFD9BF' }}>National conference</span>
                    <h2 style={{ fontSize: 'clamp(30px, 4vw, 46px)', fontWeight: 800 }}>{e.title}</h2>
                    <p style={{ opacity: .9, display: 'flex', gap: 8 }}><Icon name="pin" /> {e.venue}</p>
                    <p style={{ opacity: .9, display: 'flex', gap: 8 }}><Icon name="clock" /> {fmtDate(e.starts_at)} – {fmtDate(e.ends_at)}</p>
                    <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginTop: 8 }}>
                      {e.delegate_registration_open && <Link to={regLink} className="btn" style={{ background: '#fff', color: 'var(--ink)' }}>Register now</Link>}
                      <Link to={`/guide/${e.id}`} className="btn glass">Conference guide</Link>
                    </div>
                  </div>
                  <div style={{ display: 'grid', gap: 14, justifyItems: 'start' }}>
                    <b style={{ opacity: .85 }}>Starts in</b>
                    <Countdown iso={e.starts_at} />
                    {e.helpline && <a href={`tel:${e.helpline}`} className="btn glass sm"><Icon name="phone" size={16} /> Helpline {e.helpline}</a>}
                  </div>
                </div>
              </div>
            </Reveal>
          </div>
        </section>
      )}

      <section className="block">
        <div className="wrap">
          <Reveal><span className="eyebrow">At the conference</span></Reveal>
          <Reveal i={1}><h2 className="h2">Everything you need, and who to call.</h2></Reveal>
          <Reveal i={2}><p className="sub">Every place in the guide has a lead and a team with Call and WhatsApp buttons. No searching, no calling around.</p></Reveal>
          <div className="grid-3" style={{ marginTop: 36 }}>
            {(['stay', 'arrival', 'food', 'emergency', 'gallery', 'support'] as const).map((k, i) => (
              <Reveal key={k} i={i}>
                <Tilt className="card feature" style={{ height: '100%' }}>
                  <span className="ic" style={{ background: grad(k) }}><Icon name={KIND[k].icon} size={26} /></span>
                  <h3>{KIND[k].title} <span className="hi">· {KIND[k].hindi}</span></h3>
                  <p className="muted">{{
                    stay: 'Pick your prant and see your hostel or hotel, block and rooms – with the Nivas lead to call.',
                    arrival: 'A help desk at the airport, every station and bus stand, with the desk lead and step-by-step route to the venue.',
                    food: 'Every hall and state stall by name, where it is and how to spot it.',
                    emergency: 'One tap for 108, and the emergency lead of every hall.',
                    gallery: 'Albums of photos and videos from every day of the conference.',
                    support: 'Chat with the help desk or raise a ticket – replies arrive in seconds.',
                  }[k]}</p>
                </Tilt>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="block" style={{ background: '#fff' }}>
        <div className="wrap" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 50, alignItems: 'center' }}>
          <div>
            <Reveal><span className="eyebrow">How it works</span></Reveal>
            <Reveal i={1}><h2 className="h2">Three steps to the conference.</h2></Reveal>
            <div className="steps" style={{ gridTemplateColumns: '1fr', marginTop: 30 }}>
              {[
                ['Create your account', 'Name, mobile, password, gender and your area. Everyone who signs up is a member, with a member ID.'],
                ['Fill the delegate form', 'Your details, when you arrive and leave, and how you are coming – train, bus, flight or own vehicle.'],
                ['Open the guide', 'Stay, transport, food, sessions, gallery and help – with a real person to call for each.'],
              ].map(([t, d], i) => (
                <Reveal key={t} i={i}><div className="card"><span className="num">{i + 1}</span><h3 style={{ fontSize: 20, fontWeight: 800 }}>{t}</h3><p className="muted" style={{ marginTop: 6 }}>{d}</p></div></Reveal>
              ))}
            </div>
          </div>
          <Reveal i={2}>
            <div className="how-phones">
              <motion.div className="phone" whileHover={{ y: -10, rotate: -2 }}><img src="/img/app-volunteer-ghats.jpg" alt="Volunteer: ghats and departments" /></motion.div>
              <motion.div className="phone" style={{ marginTop: 60 }} whileHover={{ y: -10, rotate: 2 }}><img src="/img/app-help.jpg" alt="Help and emergency" /></motion.div>
            </div>
          </Reveal>
        </div>
      </section>

      <section className="block">
        <div className="wrap">
          <Reveal>
            <div className="card" style={{ display: 'flex', gap: 24, alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', padding: 34 }}>
              <div>
                <h2 style={{ fontSize: 30, fontWeight: 800 }}>For members, all year.</h2>
                <p className="muted" style={{ marginTop: 6, maxWidth: 560 }}>Share work from your unit in the Community, see events, and find every volunteer in the conference team. Verified members carry the blue tick.</p>
              </div>
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                <Link to="/conference/team" className="btn">Volunteer</Link>
                <Link to="/community" className="btn dark">Visit the community</Link>
                {!me && <Link to="/signup" className="btn primary">Sign up</Link>}
              </div>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  )
}
