import { STATUS, initials } from '../format'

export function Pill({ status, label }: { status: string; label?: string }) {
  const s = STATUS[status] ?? { label: status, tone: 'mute' as const }
  return <span className={`pill ${s.tone}`}>{label ?? s.label}</span>
}

export function Avatar({ name, src, size = 32 }: { name?: string | null; src?: string | null; size?: number }) {
  return (
    <span className="avatar" style={{ width: size, height: size, fontSize: size * 0.36 }}>
      {src ? <img src={src} alt="" /> : initials(name)}
    </span>
  )
}

export function ErrorBox({ error }: { error: unknown }) {
  if (!error) return null
  const msg = error instanceof Error ? error.message : String(error)
  return <div className="error" role="alert">{msg}</div>
}

export function Empty({ children }: { children: React.ReactNode }) {
  return <div className="empty">{children}</div>
}

/** Animated placeholder rows shown while data loads. */
export function Skeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="skeleton" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="sk-row"><span className="sk sk-avatar" /><span className="sk sk-line" style={{ width: `${60 - (i % 3) * 12}%` }} /></div>
      ))}
    </div>
  )
}
