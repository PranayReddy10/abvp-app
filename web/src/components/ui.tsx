import { motion, useMotionValue, useSpring, useTransform, type Variants } from 'framer-motion'
import { useEffect, useState, type ReactNode } from 'react'
import { ApiError } from '../api'

const P = {
  bed: 'M3 18v-6a3 3 0 013-3h12a3 3 0 013 3v6M3 18h18M3 14h18M7 9V6h4v3',
  bus: 'M5 17V6a3 3 0 013-3h8a3 3 0 013 3v11M5 11h14M7 17v2M17 17v2M8 14h.01M16 14h.01',
  food: 'M7 3v8a2 2 0 002 2v8M11 3v6M3 3v6a4 4 0 004 4M17 21V3c2 1 4 4 4 8h-4',
  office: 'M4 21V5a2 2 0 012-2h8a2 2 0 012 2v16M16 9h3a1 1 0 011 1v11M3 21h18M8 7h4M8 11h4M8 15h4',
  mic: 'M12 3a3 3 0 013 3v6a3 3 0 01-6 0V6a3 3 0 013-3zM5 11a7 7 0 0014 0M12 18v3',
  image: 'M4 5h16v14H4zM4 15l4-4 5 5 3-3 4 4M15 9h.01',
  parking: 'M6 21V3h7a5 5 0 010 10H6',
  temple: 'M12 2l2 3h-4zM7 9h10l-1-3H8zM5 21V12h14v9M9 21v-5h6v5M3 21h18M5 12h14',
  emergency: 'M12 4v16M4.5 8l15 8M19.5 8l-15 8',
  support: 'M4 13v-1a8 8 0 0116 0v1M4 13a2 2 0 002 2h1v-5H6a2 2 0 00-2 2M20 13a2 2 0 01-2 2h-1v-5h1a2 2 0 012 2M17 15v1a3 3 0 01-3 3h-2',
  phone: 'M22 16.9v3a2 2 0 01-2.2 2 19.8 19.8 0 01-8.6-3.1 19.5 19.5 0 01-6-6A19.8 19.8 0 012.1 4.2 2 2 0 014.1 2h3a2 2 0 012 1.7c.1 1 .4 1.9.7 2.8a2 2 0 01-.5 2.1L8 9.9a16 16 0 006 6l1.3-1.3a2 2 0 012.1-.4c.9.3 1.8.6 2.8.7a2 2 0 011.7 2z',
  chat: 'M21 12a8 8 0 01-11.6 7.1L4 20l1-4.4A8 8 0 1121 12z',
  pin: 'M12 22s7-6.2 7-12a7 7 0 10-14 0c0 5.8 7 12 7 12zM12 12.5a2.5 2.5 0 100-5 2.5 2.5 0 000 5z',
  clock: 'M12 22a10 10 0 100-20 10 10 0 000 20zM12 6v6l4 2',
  eye: 'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12zM12 15a3 3 0 100-6 3 3 0 000 6z',
  route: 'M6 19a2 2 0 100-4 2 2 0 000 4zM18 9a2 2 0 100-4 2 2 0 000 4zM6 15V9a4 4 0 014-4h4M18 9v6a4 4 0 01-4 4h-4',
  arrow: 'M5 12h14M13 6l6 6-6 6',
  back: 'M19 12H5M11 18l-6-6 6-6',
  ne: 'M7 17L17 7M8 7h9v9',
  close: 'M6 6l12 12M18 6L6 18',
  menu: 'M4 7h16M4 12h16M4 17h16',
  user: 'M20 21a8 8 0 00-16 0M12 13a5 5 0 100-10 5 5 0 000 10z',
  ticket: 'M3 8a2 2 0 002-2h14a2 2 0 002 2 2 2 0 000 4 2 2 0 000 4 2 2 0 00-2 2H5a2 2 0 00-2-2 2 2 0 000-4 2 2 0 000-4zM12 6v12',
  send: 'M22 2L11 13M22 2l-7 20-4-9-9-4z',
  heart: 'M20.8 4.6a5.5 5.5 0 00-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 00-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 000-7.8z',
  reply: 'M21 12a8 8 0 01-11.6 7.1L4 20l1-4.4A8 8 0 1121 12z',
  repeat: 'M17 2l4 4-4 4M3 11v-1a4 4 0 014-4h14M7 22l-4-4 4-4M21 13v1a4 4 0 01-4 4H3',
  check: 'M20 6L9 17l-5-5',
  globe: 'M12 22a10 10 0 100-20 10 10 0 000 20zM2 12h20M12 2a15 15 0 010 20M12 2a15 15 0 000 20',
  sparkle: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9z',
  locate: 'M12 19a7 7 0 100-14 7 7 0 000 14zM12 15a3 3 0 100-6 3 3 0 000 6zM12 2v3M12 19v3M2 12h3M19 12h3',
  logout: 'M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9',
  fire: 'M12 22c4 0 7-2.7 7-6.8 0-3.4-2.2-5.9-4-7.7-.4 2.3-1.6 3.5-3 4 .5-3.4-1-6.6-3.5-9 0 4-4.5 6.6-4.5 12.2C4 19.3 8 22 12 22z',
} as const
export type IconName = keyof typeof P

export function Icon({ name, size = 20, stroke = 2 }: { name: IconName; size?: number; stroke?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={P[name]} />
    </svg>
  )
}

export const KIND: Record<string, { icon: IconName; a: string; b: string; title: string; hindi: string }> = {
  stay: { icon: 'bed', a: '#8B7BFF', b: '#5A46D6', title: 'Accommodation', hindi: 'निवास' },
  arrival: { icon: 'bus', a: '#4A9BFF', b: '#1E5FD0', title: 'Transport', hindi: 'यातायात' },
  food: { icon: 'food', a: '#FFA24C', b: '#E3620C', title: 'Food', hindi: 'भोजन' },
  office: { icon: 'office', a: '#2CC7B4', b: '#0E8577', title: 'Offices', hindi: 'कार्यालय' },
  session: { icon: 'mic', a: '#7B88FF', b: '#3B47C4', title: 'Sessions', hindi: 'बैठक' },
  exhibit: { icon: 'image', a: '#F06AAE', b: '#B72F72', title: 'Exhibition', hindi: 'प्रदर्शनी' },
  facility: { icon: 'parking', a: '#7C8BA3', b: '#3B4659', title: 'Campus', hindi: 'परिसर' },
  tourist: { icon: 'temple', a: '#F5B83D', b: '#C07F00', title: 'Tourist places', hindi: 'पर्यटन' },
  emergency: { icon: 'emergency', a: '#FF6363', b: '#C81E1E', title: 'Emergency', hindi: 'आपातकाल' },
  support: { icon: 'support', a: '#3DD68C', b: '#138A4F', title: 'Support', hindi: 'सहायता' },
}
export const grad = (k: string) => `linear-gradient(135deg, ${KIND[k]?.a ?? '#F08A3C'}, ${KIND[k]?.b ?? '#E3620C'})`

/** Drifting translucent circles behind gradient headers. */
export function Orbs({ seed = 0 }: { seed?: number }) {
  const orbs = [
    { s: 420, x: '72%', y: '-18%', d: 18, ring: false },
    { s: 260, x: '-6%', y: '55%', d: 22, ring: true },
    { s: 180, x: '40%', y: '70%', d: 16, ring: false },
    { s: 120, x: '18%', y: '8%', d: 14, ring: false },
    { s: 300, x: '88%', y: '62%', d: 20, ring: true },
  ]
  return (
    <div className="orbs" aria-hidden="true">
      {orbs.map((o, i) => (
        <motion.i key={i} className={o.ring ? 'ring' : ''} style={{ width: o.s, height: o.s, left: o.x, top: o.y }}
          animate={{ x: [0, 24 * ((i + seed) % 2 ? 1 : -1), 0], y: [0, 18 * (i % 3 ? -1 : 1), 0] }}
          transition={{ duration: o.d, repeat: Infinity, ease: 'easeInOut' }} />
      ))}
    </div>
  )
}

export const fadeUp: Variants = {
  hidden: { opacity: 0, y: 26 },
  show: (i: number = 0) => ({ opacity: 1, y: 0, transition: { duration: .6, delay: i * .07, ease: [.2, .7, .2, 1] } }),
}

/** Fades up when scrolled into view. */
export function Reveal({ children, i = 0, className, style }: { children: ReactNode; i?: number; className?: string; style?: React.CSSProperties }) {
  return (
    <motion.div className={className} style={style} variants={fadeUp} initial="hidden" whileInView="show" viewport={{ once: true, margin: '-60px' }} custom={i}>
      {children}
    </motion.div>
  )
}

/** Tilts toward the pointer. */
export function Tilt({ children, className, style }: { children: ReactNode; className?: string; style?: React.CSSProperties }) {
  const x = useMotionValue(0)
  const y = useMotionValue(0)
  const rx = useSpring(useTransform(y, [-.5, .5], [8, -8]), { stiffness: 150, damping: 15 })
  const ry = useSpring(useTransform(x, [-.5, .5], [-10, 10]), { stiffness: 150, damping: 15 })
  return (
    <motion.div className={className} style={{ ...style, rotateX: rx, rotateY: ry, transformPerspective: 900 }}
      onPointerMove={(e) => { const r = e.currentTarget.getBoundingClientRect(); x.set((e.clientX - r.left) / r.width - .5); y.set((e.clientY - r.top) / r.height - .5) }}
      onPointerLeave={() => { x.set(0); y.set(0) }}>
      {children}
    </motion.div>
  )
}

export function ErrorBox({ error }: { error: unknown }) {
  if (!error) return null
  const msg = error instanceof ApiError ? (error.fields ? Object.values(error.fields)[0]?.[0] ?? error.message : error.message) : 'Something went wrong. Try again.'
  return <motion.div className="error" role="alert" initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }}>{msg}</motion.div>
}

export function Skeleton({ h = 120, n = 3 }: { h?: number; n?: number }) {
  return <div style={{ display: 'grid', gap: 14 }}>{Array.from({ length: n }, (_, i) => <div key={i} className="skeleton" style={{ height: h }} />)}</div>
}

export const initials = (n: string) => n.trim().split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? '').join('')

export function Avatar({ name, src, size = 40 }: { name: string; src?: string | null; size?: number }) {
  return <span className="avatar" style={{ width: size, height: size, fontSize: size * .34, overflow: 'hidden' }}>{src ? <img src={src} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : initials(name)}</span>
}

export const telHref = (p: string) => `tel:${p.replace(/[^0-9+]/g, '')}`
export const waHref = (p: string) => { let d = p.replace(/\D/g, ''); if (d.length === 10) d = '91' + d; return `https://wa.me/${d}` }

/** Days, hours, minutes, seconds to a date; ticks every second. */
export function useCountdown(iso: string) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => { const t = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(t) }, [])
  const diff = Math.max(0, new Date(iso).getTime() - now)
  return { d: Math.floor(diff / 864e5), h: Math.floor(diff / 36e5) % 24, m: Math.floor(diff / 6e4) % 60, s: Math.floor(diff / 1e3) % 60, done: diff === 0 }
}

export const fmtDate = (iso: string) => new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(iso))
export const fmtDay = (iso: string) => new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short' }).format(new Date(iso))
export const fmtTime = (iso: string) => new Intl.DateTimeFormat('en-IN', { hour: 'numeric', minute: '2-digit' }).format(new Date(iso))
export const fmtDateTime = (iso: string) => `${fmtDay(iso)}, ${fmtTime(iso)}`
export function ago(iso: string) {
  const m = Math.round((Date.now() - new Date(iso).getTime()) / 6e4)
  if (m < 1) return 'just now'
  if (m < 60) return `${m} min ago`
  if (m < 1440) return `${Math.round(m / 60)} h ago`
  return fmtDay(iso)
}
