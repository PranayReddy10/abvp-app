import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useState, type FormEvent } from 'react'
import { Link, Navigate, useLocation, useParams } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth'
import PassCard from '../components/PassCard'
import { ErrorBox, Icon, Orbs, Skeleton, fmtDate, fmtDateTime } from '../components/ui'
import type { Delegate as D } from '../types'
import { useFetch } from '../useFetch'
import { Celebrate } from './Auth'

const STEPS = ['About you', 'Travel', 'Stay', 'Review']
const toLocal = (iso: string | null | undefined) => (iso ? new Date(new Date(iso).getTime() - new Date().getTimezoneOffset() * 6e4).toISOString().slice(0, 16) : '')

function Toggle({ on, set, title, sub }: { on: boolean; set: (v: boolean) => void; title: string; sub: string }) {
  return (
    <button type="button" className={`toggle ${on ? 'on' : ''}`} role="switch" aria-checked={on} onClick={() => set(!on)} style={{ textAlign: 'left' }}>
      <span><b style={{ display: 'block' }}>{title}</b><span className="muted" style={{ fontSize: 14 }}>{sub}</span></span>
      <span className="sw"><i /></span>
    </button>
  )
}

export default function Delegate() {
  const { id } = useParams()
  const { me, loading } = useAuth()
  const { pathname } = useLocation()
  const { data, error, reload } = useFetch<D>(me ? `/events/${id}/delegate` : null)
  const [step, setStep] = useState(0)
  const [editing, setEditing] = useState(false)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [done, setDone] = useState(false)
  const [otherPoint, setOtherPoint] = useState(false)
  const [f, setF] = useState({
    full_name: '', gender: '', prant: '', institution: '', food: 'veg', emergency_name: '', emergency_phone: '',
    mode: 'train', reference: '', arrival_point: '', arriving_at: '', departing_at: '', needs_pickup: true, needs_stay: true, notes: '',
  })
  const set = (p: Partial<typeof f>) => setF((x) => ({ ...x, ...p }))

  useEffect(() => {
    if (!data) return
    const r = data.registration
    setF((x) => ({
      ...x,
      full_name: r?.full_name ?? data.prefill.full_name ?? '', gender: r?.details.gender ?? data.prefill.gender ?? '',
      prant: r?.details.prant ?? data.prefill.prant ?? '', institution: r?.details.institution ?? data.prefill.institution ?? '',
      food: r?.details.food ?? 'veg', emergency_name: r?.details.emergency_name ?? '', emergency_phone: r?.details.emergency_phone ?? '',
      mode: r?.travel?.mode ?? 'train', reference: r?.travel?.reference ?? '', arrival_point: r?.travel?.arrival_point ?? '',
      arriving_at: toLocal(r?.travel?.arriving_at), departing_at: toLocal(r?.travel?.departing_at),
      needs_pickup: r?.travel?.needs_pickup ?? true, needs_stay: r?.travel?.needs_stay ?? true, notes: r?.travel?.notes ?? '',
    }))
    if (r?.travel?.arrival_point && !data.options.arrival_points.includes(r.travel.arrival_point)) setOtherPoint(true)
  }, [data])

  if (!loading && !me) return <Navigate to={`/signup?next=${encodeURIComponent(pathname)}`} replace />
  if (error) return <div className="page wrap"><ErrorBox error={error} /></div>
  if (!data) return <div className="page wrap"><Skeleton h={200} n={2} /></div>

  const reg = data.registration
  const e = data.event

  async function submit(ev?: FormEvent) {
    ev?.preventDefault()
    setBusy(true); setErr(null)
    try {
      await api.put(`/events/${id}/delegate`, {
        ...f, institution: f.institution || null, reference: f.reference || null, notes: f.notes || null,
        arriving_at: new Date(f.arriving_at).toISOString(), departing_at: f.departing_at ? new Date(f.departing_at).toISOString() : null,
      })
      setDone(true)
      setTimeout(() => { setDone(false); setEditing(false); setStep(0); reload() }, 1600)
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  const header = (
    <div className="banner" style={{ background: 'linear-gradient(135deg, #F08A3C, #E3620C 40%, #14161F)' }}>
      <Orbs />
      <div style={{ position: 'relative', zIndex: 2, display: 'grid', gap: 8 }}>
        <span style={{ opacity: .85, fontWeight: 700 }}>Delegate registration · <span className="hi">प्रतिनिधि पंजीकरण</span></span>
        <h1>{e.title}</h1>
        <p style={{ opacity: .9 }}>{e.venue} · {fmtDate(e.starts_at)} – {fmtDate(e.ends_at)}</p>
      </div>
    </div>
  )

  if (reg && !editing) {
    return (
      <div className="page wrap">
        {header}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 24, alignItems: 'start' }}>
          <PassCard title={e.title} venue={e.venue} starts={e.starts_at} name={reg.full_name} kind={reg.kind} token={reg.pass_token} status={reg.status} />
          <div style={{ display: 'grid', gap: 14 }}>
            <div className="notice">{reg.status === 'registered' ? 'You are registered. Show this pass at the gate.' : 'You are on the waitlist. We will tell you when a place opens.'}</div>
            <div className="review">
              <div><span>Prant</span><b>{reg.details.prant}</b></div>
              <div><span>Arriving</span><b>{reg.travel ? `${fmtDateTime(reg.travel.arriving_at)} · ${reg.travel.arrival_point}` : '–'}</b></div>
              <div><span>By</span><b>{reg.travel ? `${data.options.modes.find((m) => m.key === reg.travel!.mode)?.label}${reg.travel.reference ? ` · ${reg.travel.reference}` : ''}` : '–'}</b></div>
              <div><span>Pickup</span><b>{reg.travel?.needs_pickup ? 'Yes, please' : 'No'}</b></div>
              <div><span>Stay</span><b>{reg.travel?.needs_stay ? 'Needed' : 'Not needed'}</b></div>
              <div><span>Food</span><b>{data.options.food.find((x) => x.key === reg.details.food)?.label}</b></div>
            </div>
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <button className="btn" onClick={() => setEditing(true)} disabled={!data.open}>Edit details</button>
              <Link to={`/guide/${id}`} className="btn dark">Open the guide</Link>
              <Link to="/me" className="btn ghost">My space</Link>
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (!data.open) return <div className="page wrap">{header}<div className="hint">Delegate registration is not open yet. Please check again soon, or call the helpline.</div></div>

  const canNext = [
    f.full_name.length > 1 && f.gender && f.prant && f.emergency_name && f.emergency_phone.replace(/\D/g, '').length >= 6,
    f.mode && f.arrival_point && f.arriving_at,
    true,
    true,
  ][step]
  const field = (k: keyof typeof f, label: string, props: React.InputHTMLAttributes<HTMLInputElement> = {}) => (
    <div className="field"><label htmlFor={k}>{label}</label><input id={k} className="input" value={String(f[k])} onChange={(ev) => set({ [k]: ev.target.value } as Partial<typeof f>)} {...props} /></div>
  )

  return (
    <div className="page wrap" style={{ maxWidth: 820 }}>
      {header}
      <div className="card" style={{ display: 'grid', gap: 20, padding: 30 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          {STEPS.map((s, i) => (
            <button key={s} type="button" onClick={() => i < step && setStep(i)} style={{ flex: 1, border: 0, background: 'none', padding: 0, cursor: i < step ? 'pointer' : 'default', textAlign: 'left' }}>
              <motion.i animate={{ background: i <= step ? '#E3620C' : '#E8E9EF' }} style={{ display: 'block', height: 6, borderRadius: 6 }} />
              <small style={{ fontWeight: 700, color: i === step ? 'var(--deep)' : 'var(--muted)' }}>{i + 1}. {s}</small>
            </button>
          ))}
        </div>
        <ErrorBox error={err} />
        <form onSubmit={(ev) => { ev.preventDefault(); if (step < 3) { if (canNext) setStep(step + 1) } else submit() }}>
          <AnimatePresence mode="wait">
            <motion.div key={step} initial={{ opacity: 0, x: 30 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -30 }} transition={{ duration: .3 }} style={{ display: 'grid', gap: 16 }}>
              {step === 0 && <>
                <h2 style={{ fontSize: 26, fontWeight: 800 }}>About you</h2>
                {field('full_name', 'Full name *', { required: true })}
                <div className="field"><label>Gender *</label><div className="seg">{[['male', 'Male'], ['female', 'Female'], ['other', 'Other']].map(([k, l]) => <button type="button" key={k} className={f.gender === k ? 'on' : ''} onClick={() => set({ gender: k })}>{l}</button>)}</div><small>Used to plan separate stay for girls and boys.</small></div>
                <div className="row2">
                  <div className="field"><label htmlFor="prant">Prant *</label><input id="prant" className="input" list="dprants" required value={f.prant} onChange={(ev) => set({ prant: ev.target.value })} /><datalist id="dprants">{data.options.prants.map((p) => <option key={p} value={p} />)}</datalist></div>
                  {field('institution', 'College / organisation')}
                </div>
                <div className="field"><label>Food</label><div className="seg">{data.options.food.map((o) => <button type="button" key={o.key} className={f.food === o.key ? 'on' : ''} onClick={() => set({ food: o.key })}>{o.label}</button>)}</div></div>
                <div className="row2">
                  {field('emergency_name', 'Emergency contact name *', { required: true })}
                  {field('emergency_phone', 'Emergency contact phone *', { required: true, inputMode: 'tel' })}
                </div>
              </>}
              {step === 1 && <>
                <h2 style={{ fontSize: 26, fontWeight: 800 }}>How will you travel?</h2>
                <div className="field"><label>Coming by *</label><div className="seg">{data.options.modes.map((o) => <button type="button" key={o.key} className={f.mode === o.key ? 'on' : ''} onClick={() => set({ mode: o.key })}>{o.label}</button>)}</div></div>
                {f.mode !== 'own' && field('reference', f.mode === 'train' ? 'Train number and name' : f.mode === 'flight' ? 'Flight number' : 'Bus / details', { placeholder: f.mode === 'train' ? '12723 Telangana Express' : '' })}
                <div className="field"><label htmlFor="ap">Arriving at *</label>
                  <select id="ap" className="input" value={otherPoint ? '__other' : f.arrival_point} onChange={(ev) => { const v = ev.target.value; if (v === '__other') { setOtherPoint(true); set({ arrival_point: '' }) } else { setOtherPoint(false); set({ arrival_point: v }) } }}>
                    <option value="">Choose your station, airport or bus stand</option>
                    {data.options.arrival_points.map((p) => <option key={p} value={p}>{p}</option>)}
                    <option value="__other">Somewhere else</option>
                  </select>
                  {otherPoint && <input className="input" placeholder="Where will you arrive?" value={f.arrival_point} onChange={(ev) => set({ arrival_point: ev.target.value })} style={{ marginTop: 8 }} />}
                </div>
                <div className="row2">
                  {field('arriving_at', 'Arrival date and time *', { type: 'datetime-local', required: true })}
                  {field('departing_at', 'Leaving on', { type: 'datetime-local' })}
                </div>
                <Toggle on={f.needs_pickup} set={(v) => set({ needs_pickup: v })} title="I need pickup" sub="A volunteer meets you at the help desk and takes you to the venue." />
              </>}
              {step === 2 && <>
                <h2 style={{ fontSize: 26, fontWeight: 800 }}>Stay</h2>
                <Toggle on={f.needs_stay} set={(v) => set({ needs_stay: v })} title="I need a place to stay" sub="Your prant's stay and its lead appear in the conference guide." />
                <div className="field"><label htmlFor="notes">Anything we should know?</label><textarea id="notes" className="input" placeholder="Medical needs, travelling with a group, arriving late at night…" value={f.notes} onChange={(ev) => set({ notes: ev.target.value })} /></div>
              </>}
              {step === 3 && <>
                <h2 style={{ fontSize: 26, fontWeight: 800 }}>Check and submit</h2>
                <div className="review">
                  <div><span>Name</span><b>{f.full_name}</b></div>
                  <div><span>Prant</span><b>{f.prant}</b></div>
                  <div><span>Arriving</span><b>{f.arriving_at && fmtDateTime(new Date(f.arriving_at).toISOString())} · {f.arrival_point}</b></div>
                  <div><span>By</span><b>{data.options.modes.find((m) => m.key === f.mode)?.label}{f.reference ? ` · ${f.reference}` : ''}</b></div>
                  <div><span>Pickup</span><b>{f.needs_pickup ? 'Yes' : 'No'}</b></div>
                  <div><span>Stay</span><b>{f.needs_stay ? 'Needed' : 'Not needed'}</b></div>
                  <div><span>Food</span><b>{data.options.food.find((x) => x.key === f.food)?.label}</b></div>
                  <div><span>Emergency contact</span><b>{f.emergency_name} · {f.emergency_phone}</b></div>
                </div>
              </>}
            </motion.div>
          </AnimatePresence>
          <div style={{ display: 'flex', gap: 10, marginTop: 24 }}>
            {step > 0 && <button type="button" className="btn" onClick={() => setStep(step - 1)}><Icon name="back" size={16} /> Back</button>}
            {reg && step === 0 && <button type="button" className="btn ghost" onClick={() => setEditing(false)}>Cancel</button>}
            <div className="grow" />
            <button className="btn primary" disabled={!canNext || busy}>{step < 3 ? <>Next <Icon name="arrow" size={18} /></> : busy ? 'Submitting…' : reg ? 'Save changes' : 'Register and get my pass'}</button>
          </div>
        </form>
      </div>
      {done && <Celebrate text={reg ? 'Saved!' : 'You are registered!'} />}
    </div>
  )
}
