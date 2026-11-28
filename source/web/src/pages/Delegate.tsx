import { motion } from 'framer-motion'
import { useEffect, useState, type FormEvent } from 'react'
import { Link, Navigate, useLocation, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth'
import { ErrorBox, Icon, Orbs, Skeleton, fmtDate } from '../components/ui'
import type { Delegate as D } from '../types'
import { useFetch } from '../useFetch'
import { Celebrate } from './Auth'

const toLocal = (iso: string | null | undefined) => (iso ? new Date(new Date(iso).getTime() - new Date().getTimezoneOffset() * 6e4).toISOString().slice(0, 16) : '')

/**
 * The delegate form, the same as in the app: everything required except email.
 * Once sent, the Delegate tile opens the guide directly; the form is reached again with ?edit=1.
 */
export default function Delegate() {
  const { id } = useParams()
  const [params] = useSearchParams()
  const nav = useNavigate()
  const { me, loading } = useAuth()
  const { pathname } = useLocation()
  const { data, error } = useFetch<D>(me ? `/events/${id}/delegate` : null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [done, setDone] = useState(false)
  const [otherPoint, setOtherPoint] = useState(false)
  const [f, setF] = useState({
    first_name: '', surname: '', mobile: '', email: '', gender: '', prant: '', responsibility: '',
    arriving_at: '', arrival_point: '', departing_at: '', mode: '',
  })
  const set = (p: Partial<typeof f>) => setF((x) => ({ ...x, ...p }))

  useEffect(() => {
    if (!data) return
    const d = (data.registration?.details ?? {}) as Record<string, string | null | undefined>
    const p = data.prefill as Record<string, string | null | undefined>
    const t = data.registration?.travel
    const pick = (k: string) => d[k] ?? p[k] ?? ''
    setF({
      first_name: pick('first_name'), surname: pick('surname'), mobile: String(pick('mobile')).replace(/^\+91/, ''),
      email: pick('email'), gender: pick('gender'), prant: pick('prant'), responsibility: pick('responsibility'),
      arriving_at: toLocal(t?.arriving_at), arrival_point: t?.arrival_point ?? '', departing_at: toLocal(t?.departing_at), mode: t?.mode ?? '',
    })
    if (t?.arrival_point && !data.options.arrival_points.includes(t.arrival_point)) setOtherPoint(true)
  }, [data])

  if (!loading && !me) return <Navigate to={`/signup?next=${encodeURIComponent(pathname)}`} replace />
  if (error) return <div className="page wrap"><ErrorBox error={error} /></div>
  if (!data) return <div className="page wrap"><Skeleton h={200} n={2} /></div>

  const reg = data.registration
  const e = data.event
  const editing = params.get('edit') === '1'

  // Registered: the guide is the place to be.
  if (reg && !editing && !done) return <Navigate to={`/guide/${id}`} replace />

  const header = (
    <div className="banner" style={{ background: 'linear-gradient(135deg, #F6A04D, #E3620C 45%, #B84C04)' }}>
      <Orbs />
      <div style={{ position: 'relative', zIndex: 2, display: 'grid', gap: 8 }}>
        <span style={{ opacity: .9, fontWeight: 700 }}>{reg ? 'Edit my delegate form' : 'Delegate registration'} · <span className="hi">प्रतिनिधि पंजीकरण</span></span>
        <h1>{e.title}</h1>
        <p style={{ opacity: .9 }}>{e.venue} · {fmtDate(e.starts_at)} – {fmtDate(e.ends_at)}</p>
      </div>
    </div>
  )

  if (!data.open) {
    return (
      <div className="page wrap" style={{ maxWidth: 820 }}>
        {header}
        <div className="card closed">
          <span className="ic"><Icon name="clock" size={26} /></span>
          <div>
            <h2>Delegate registration is closed</h2>
            <p className="muted">{reg ? 'Your form is in, but it cannot be changed now. Call the helpline if something is wrong.' : 'Registration is not open right now. Please check again soon, or call the helpline.'}</p>
          </div>
          <Link to={reg ? `/guide/${id}` : '/me'} className="btn dark">{reg ? 'Open the guide' : 'Back'}</Link>
        </div>
      </div>
    )
  }

  async function submit(ev: FormEvent) {
    ev.preventDefault()
    if (!f.mode) { setErr(new Error('Choose how you are coming.')); return }
    if (f.departing_at && f.arriving_at && new Date(f.departing_at) <= new Date(f.arriving_at)) { setErr(new Error('Departure must be after arrival.')); return }
    setBusy(true); setErr(null)
    try {
      await api.put(`/events/${id}/delegate`, {
        ...f, first_name: f.first_name.trim(), surname: f.surname.trim(), email: f.email.trim() || null,
        responsibility: f.responsibility.trim(), arrival_point: f.arrival_point.trim(),
        arriving_at: new Date(f.arriving_at).toISOString(), departing_at: new Date(f.departing_at).toISOString(),
      })
      setDone(true)
      setTimeout(() => nav(`/guide/${id}`), 1500)
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  const input = (k: keyof typeof f, label: string, props: React.InputHTMLAttributes<HTMLInputElement> = {}) => (
    <div className="field"><label htmlFor={k}>{label}</label><input id={k} className="input" value={f[k]} onChange={(ev) => set({ [k]: ev.target.value } as Partial<typeof f>)} required {...props} /></div>
  )
  const Step = ({ n, t }: { n: number; t: string }) => <h2 className="step-h"><span>{n}</span>{t}</h2>

  return (
    <div className="page wrap" style={{ maxWidth: 820 }}>
      {header}
      <motion.form className="card" style={{ display: 'grid', gap: 16, padding: 30 }} onSubmit={submit}
        initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
        <p className="muted">All fields are required except email. Details from your profile are filled in – change anything that is not right.</p>
        <ErrorBox error={err} />

        <Step n={1} t="About you" />
        <div className="row2">
          {input('first_name', 'First name')}
          {input('surname', 'Surname')}
        </div>
        <div className="row2">
          {input('mobile', 'Mobile number', { inputMode: 'tel', pattern: '[0-9]{10}', title: 'Enter a 10-digit mobile number' })}
          {input('email', 'Email (optional)', { type: 'email', required: false })}
        </div>
        <div className="field"><label>Gender</label><div className="seg">{[['male', 'Male'], ['female', 'Female'], ['other', 'Other']].map(([k, l]) => <button type="button" key={k} className={f.gender === k ? 'on' : ''} onClick={() => set({ gender: k })}>{l}</button>)}</div></div>
        <div className="row2">
          <div className="field"><label htmlFor="prant">Prant</label>
            <select id="prant" className="input" required value={f.prant} onChange={(ev) => set({ prant: ev.target.value })}>
              <option value="">Choose…</option>
              {data.options.prants.map((p) => <option key={p}>{p}</option>)}
            </select>
          </div>
          {input('responsibility', 'Responsibility', { placeholder: 'e.g. Zilla Sanghatan Mantri' })}
        </div>

        <Step n={2} t="Arrival and departure" />
        <div className="row2">
          {input('arriving_at', 'Arrival date and time', { type: 'datetime-local' })}
          <div className="field"><label htmlFor="ap">Arrival place</label>
            <select id="ap" className="input" required={!otherPoint} value={otherPoint ? '__other' : f.arrival_point} onChange={(ev) => { const v = ev.target.value; if (v === '__other') { setOtherPoint(true); set({ arrival_point: '' }) } else { setOtherPoint(false); set({ arrival_point: v }) } }}>
              <option value="">Station, airport or bus stand</option>
              {data.options.arrival_points.map((p) => <option key={p} value={p}>{p}</option>)}
              <option value="__other">Somewhere else</option>
            </select>
            {otherPoint && <input className="input" required placeholder="Where will you arrive?" value={f.arrival_point} onChange={(ev) => set({ arrival_point: ev.target.value })} style={{ marginTop: 8 }} />}
          </div>
        </div>
        {input('departing_at', 'Departure date and time', { type: 'datetime-local' })}

        <Step n={3} t="How you are coming" />
        <div className="seg">{data.options.modes.map((o) => <button type="button" key={o.key} className={f.mode === o.key ? 'on' : ''} onClick={() => set({ mode: o.key })}>{o.label}</button>)}</div>
        {!f.mode && <small className="muted">Choose one</small>}

        <div style={{ display: 'flex', gap: 10, marginTop: 10, flexWrap: 'wrap' }}>
          {reg && <Link to={`/guide/${id}`} className="btn ghost">Cancel</Link>}
          <div className="grow" />
          <button className="btn primary" disabled={busy || !f.gender || !f.mode}>{busy ? 'Saving…' : reg ? 'Save changes' : 'Register as delegate'}</button>
        </div>
      </motion.form>
      {done && <Celebrate text={reg ? 'Saved!' : 'You are registered!'} />}
    </div>
  )
}
