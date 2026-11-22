import { motion } from 'framer-motion'
import { QRCodeSVG } from 'qrcode.react'
import { fmtDay, fmtTime } from './ui'

export default function PassCard({ title, venue, starts, name, kind, token, status }: { title: string; venue: string; starts: string; name: string; kind: string; token: string | null; status: string }) {
  return (
    <motion.div className="pass" initial={{ opacity: 0, y: 30, rotateX: 12 }} animate={{ opacity: 1, y: 0, rotateX: 0 }} transition={{ type: 'spring', stiffness: 120, damping: 16 }} style={{ transformPerspective: 900 }}>
      <div className="top">
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10 }}>
          <div>
            <small style={{ color: 'var(--deep)', fontWeight: 800, letterSpacing: '.1em' }}>EVENT PASS</small>
            <h3 style={{ fontSize: 21, fontWeight: 800 }}>{title}</h3>
          </div>
          <span className="chip" style={{ background: 'var(--soft)', color: 'var(--deep)', textTransform: 'capitalize' }}>{kind}</span>
        </div>
        <div className="meta">
          <div><small>Date</small><b>{fmtDay(starts)}</b></div>
          <div><small>Time</small><b>{fmtTime(starts)}</b></div>
          <div style={{ textAlign: 'right' }}><small>Venue</small><b>{venue.split(',')[0]}</b></div>
        </div>
      </div>
      <div className="cut" />
      <div className="qr">
        {token ? <QRCodeSVG value={token} size={200} fgColor="#14161F" /> : (
          <div className="hint" style={{ textAlign: 'center' }}>{status === 'waitlisted' ? 'You are on the waitlist. Your pass appears here when a place opens.' : 'Waiting for approval – your pass appears here.'}</div>
        )}
      </div>
      <div className="strip"><span>{name}</span><span style={{ opacity: .8, fontSize: 13, letterSpacing: '.08em' }}>{status === 'registered' ? 'CONFIRMED' : status.toUpperCase()}</span></div>
    </motion.div>
  )
}
