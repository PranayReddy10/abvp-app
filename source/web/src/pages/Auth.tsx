import { AnimatePresence, motion } from 'framer-motion'
import { useState, type FormEvent, type ReactNode } from 'react'
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth'
import { Brand, GoogleButton } from '../components/Layout'
import { ErrorBox, Icon, Orbs } from '../components/ui'
import type { Me, OrgUnit } from '../types'
import { useSeo } from '../seo'
import { track } from '../analytics'
import { useFetch } from '../useFetch'

function Shell({ side, children }: { side: ReactNode; children: ReactNode }) {
  return (
    <div className="form-shell">
      <aside className="side">
        <Orbs />
        <div style={{ position: 'relative', zIndex: 2, display: 'grid', gap: 14 }}>{side}</div>
      </aside>
      <div className="main">{children}</div>
    </div>
  )
}

const slide = {
  initial: { opacity: 0, x: 30 },
  animate: { opacity: 1, x: 0, transition: { duration: .35, ease: [.2, .7, .2, 1] as const } },
  exit: { opacity: 0, x: -30, transition: { duration: .2 } },
}

/** Mobile number then the 6-digit code. Calls onVerified(code) when the code is entered. */
function OtpStep({ mobile, setMobile, onVerified, onPassword, newPassword = false, busy, cta }: {
  mobile: string; setMobile: (m: string) => void; onVerified: (code: string) => Promise<void>
  /** Mobile + password instead of a code: used when codes are switched off, or chosen on sign-in. */
  onPassword?: (password: string, confirm: string) => Promise<void>; newPassword?: boolean; busy: boolean; cta: string
}) {
  const [sentTo, setSentTo] = useState<string | null>(null)
  const [code, setCode] = useState('')
  const [sending, setSending] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const options = useFetch<{ otp: boolean }>('/auth/options')
  const [usePw, setUsePw] = useState(false)
  const [pw, setPw] = useState('')
  const [pw2, setPw2] = useState('')
  const otpOff = options.data?.otp === false

  async function send(e: FormEvent) {
    e.preventDefault()
    setSending(true); setErr(null)
    try { setSentTo((await api.post<{ mobile: string }>('/auth/send-otp', { mobile })).data.mobile) } catch (x) { setErr(x) } finally { setSending(false) }
  }
  async function verify(e: FormEvent) {
    e.preventDefault()
    setErr(null)
    try { await onVerified(code) } catch (x) { setErr(x) }
  }
  async function withPassword(e: FormEvent) {
    e.preventDefault()
    setErr(null)
    try { await onPassword?.(pw, pw2) } catch (x) { setErr(x) }
  }
  if ((otpOff || usePw) && onPassword) {
    const mismatch = newPassword && pw2.length > 0 && pw !== pw2
    return (
      <motion.form key="p" {...slide} onSubmit={withPassword} style={{ display: 'grid', gap: 14 }}>
        <ErrorBox error={err} />
        <div className="field">
          <label htmlFor="mobile">Mobile number</label>
          <input id="mobile" className="input" inputMode="tel" autoComplete={newPassword ? 'tel' : 'username'} placeholder="98480 12345" value={mobile} onChange={(e) => setMobile(e.target.value)} required />
        </div>
        <div className="field">
          <label htmlFor="pw">{newPassword ? 'Choose a password' : 'Password'}</label>
          <input id="pw" className="input" type="password" autoComplete={newPassword ? 'new-password' : 'current-password'} minLength={newPassword ? 8 : undefined} value={pw} onChange={(e) => setPw(e.target.value)} required />
          {newPassword && <small>At least 8 characters. You will sign in with your mobile number and this password.</small>}
        </div>
        {newPassword && (
          <div className="field">
            <label htmlFor="pw2">Type it again</label>
            <input id="pw2" className="input" type="password" autoComplete="new-password" value={pw2} onChange={(e) => setPw2(e.target.value)} required />
            {mismatch && <small style={{ color: 'var(--bad, #C92A2A)' }}>The two passwords don't match.</small>}
          </div>
        )}
        <button className="btn primary block" disabled={busy || mismatch || (newPassword && pw.length < 8)}>{busy ? 'Please wait…' : newPassword ? cta : 'Sign in'}</button>
        {!otpOff && <button type="button" className="btn ghost" onClick={() => { setUsePw(false); setErr(null) }}>Use a code on my mobile instead</button>}
      </motion.form>
    )
  }
  if (otpOff) {
    return <div className="hint" role="status">Sign-in with a code on your mobile is paused right now. Use Continue with Google, or try again later.</div>
  }
  return (
    <AnimatePresence mode="wait">
      {!sentTo ? (
        <motion.form key="m" {...slide} onSubmit={send} style={{ display: 'grid', gap: 14 }}>
          <ErrorBox error={err} />
          <div className="field">
            <label htmlFor="mobile">Mobile number</label>
            <input id="mobile" className="input" inputMode="tel" autoComplete="tel" placeholder="98480 12345" value={mobile} onChange={(e) => setMobile(e.target.value)} required />
            <small>We send a 6-digit code by SMS.</small>
          </div>
          <button className="btn primary block" disabled={sending}>{sending ? 'Sending…' : 'Send code'}</button>
          {onPassword && !newPassword && <button type="button" className="btn ghost" onClick={() => { setUsePw(true); setErr(null) }}>Sign in with password instead</button>}
        </motion.form>
      ) : (
        <motion.form key="c" {...slide} onSubmit={verify} style={{ display: 'grid', gap: 14 }}>
          <ErrorBox error={err} />
          <div className="field">
            <label htmlFor="code">Code sent to {sentTo}</label>
            <input id="code" className="input otp" inputMode="numeric" autoComplete="one-time-code" maxLength={6} autoFocus value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} required />
          </div>
          <button className="btn primary block" disabled={busy || code.length !== 6}>{busy ? 'Checking…' : cta}</button>
          <button type="button" className="btn ghost" onClick={() => { setSentTo(null); setCode('') }}>Use a different number</button>
        </motion.form>
      )}
    </AnimatePresence>
  )
}

export function Login() {
  useSeo({ title: 'Sign in', description: 'Sign in to ABVP Connect with your mobile number.', noindex: true })
  const { signIn } = useAuth()
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const next = params.get('next') ?? '/me'
  const [mobile, setMobile] = useState('')
  const [busy, setBusy] = useState(false)

  return (
    <Shell side={<>
      <span className="eyebrow" style={{ color: '#FFD9BF' }}>Welcome back</span>
      <h2>Your conference, your team and your help desk – in one place.</h2>
      <p className="hi" style={{ fontSize: 18, opacity: .85 }}>एक सदस्य · एक पहचान · हर कार्यक्रम</p>
    </>}>
      <motion.div className="form-card" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }}>
        <Brand />
        <div><h1>Sign in</h1><p className="muted">New here? <Link to={`/signup?next=${encodeURIComponent(next)}`} style={{ color: 'var(--deep)', fontWeight: 700 }}>Create an account</Link></p></div>
        <OtpStep mobile={mobile} setMobile={setMobile} busy={busy} cta="Verify and sign in" onVerified={async (code) => {
          setBusy(true)
          try {
            const r = await api.post<{ token: string; user: Me }>('/auth/verify-otp', { mobile, code, device_name: 'web' })
            signIn(r.data.token, r.data.user)
            track('login', { method: 'sms_code' })
            navigate(r.data.user.name || r.data.user.profile ? next : `/signup?complete=1&next=${encodeURIComponent(next)}`)
          } finally { setBusy(false) }
        }} onPassword={async (password) => {
          setBusy(true)
          try {
            const r = await api.post<{ token: string; user: Me }>('/auth/password', { login: mobile, password, device_name: 'web' })
            signIn(r.data.token, r.data.user)
            track('login', { method: 'password' })
            navigate(r.data.user.name || r.data.user.profile ? next : `/signup?complete=1&next=${encodeURIComponent(next)}`)
          } finally { setBusy(false) }
        }} />
        <div className="or">or</div>
        <GoogleButton onNew={(d) => navigate(`/signup?next=${encodeURIComponent(next)}`, { state: d })} />
      </motion.div>
    </Shell>
  )
}

const OCCUPATIONS = ['Student', 'Teacher', 'Professional', 'Other']

export function Signup() {
  useSeo({ title: 'Create your account', description: 'Join ABVP Connect: everyone who signs up is a member with a member ID. Then fill the delegate form for the national conference.', noindex: true })
  const { signIn } = useAuth()
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const next = params.get('next') ?? '/me'
  const google = (useLocation().state ?? null) as { link_token: string; email: string; name: string | null } | null
  const [link, setLink] = useState(google)
  const { data: states } = useFetch<OrgUnit[]>('/org/units')
  const [stateId, setStateId] = useState<number | null>(null)
  const { data: districts } = useFetch<OrgUnit[]>(stateId ? `/org/units?parent_id=${stateId}` : null)
  const [districtId, setDistrictId] = useState<number | null>(null)
  const [step, setStep] = useState(0)
  const [busy, setBusy] = useState(false)
  const [mobile, setMobile] = useState('')
  const [f, setF] = useState({ name: google?.name ?? '', email: google?.email ?? '', gender: '', institution: '', occupation: 'Student' })
  const set = (p: Partial<typeof f>) => setF({ ...f, ...p })
  const otpOff = useFetch<{ otp: boolean }>('/auth/options').data?.otp === false
  const details = () => ({
    mobile, name: f.name, email: f.email || null, gender: f.gender || null,
    prant: states?.find((x) => x.id === stateId)?.name ?? null, org_unit_id: districtId ?? stateId,
    institution: f.institution || null, occupation: f.occupation, device_name: 'web', google_link_token: link?.link_token,
  })
  async function create(extra: Record<string, string>) {
    setBusy(true)
    try {
      const r = await api.post<{ token: string; user: Me }>('/auth/register', { ...details(), ...extra })
      signIn(r.data.token, r.data.user)
      track('sign_up', { method: link ? 'google' : 'mobile' })
      setStep(2)
      setTimeout(() => navigate(next), 1400)
    } finally { setBusy(false) }
  }

  return (
    <Shell side={<>
      <span className="eyebrow" style={{ color: '#FFD9BF' }}>Join ABVP Connect</span>
      <h2>Create your account in a minute.</h2>
      <p style={{ opacity: .9, fontSize: 17 }}>Everyone who signs up is a member straight away, with a member ID. Fill the delegate form for the national conference and the guide opens for you.</p>
      <div style={{ display: 'grid', gap: 10, marginTop: 10 }}>
        {['Your details', otpOff ? 'Mobile and password' : 'Verify your mobile', 'You are in'].map((t, i) => (
          <motion.div key={t} animate={{ opacity: step >= i ? 1 : .55, x: step === i ? 8 : 0 }} style={{ display: 'flex', gap: 12, alignItems: 'center', fontWeight: 700 }}>
            <span style={{ width: 32, height: 32, borderRadius: 16, display: 'grid', placeItems: 'center', background: step > i ? '#fff' : 'rgba(255,255,255,.2)', color: step > i ? 'var(--deep)' : '#fff' }}>{step > i ? <Icon name="check" size={16} /> : i + 1}</span>{t}
          </motion.div>
        ))}
      </div>
    </>}>
      <div className="form-card">
        <Brand />
        <div className="progress" aria-hidden="true"><i className={step >= 0 ? 'on' : ''} /><i className={step >= 1 ? 'on' : ''} /></div>
        <AnimatePresence mode="wait">
          {step === 0 ? (
            <motion.form key="d" {...slide} style={{ display: 'grid', gap: 14 }} onSubmit={(e) => { e.preventDefault(); setStep(1) }}>
              <div><h1>{params.get('complete') ? 'A few details' : 'Sign up'}</h1><p className="muted">Already have an account? <Link to={`/login?next=${encodeURIComponent(next)}`} style={{ color: 'var(--deep)', fontWeight: 700 }}>Sign in</Link></p></div>
              {link ? <div className="notice">Google account {link.email} connected. Add your details{otpOff ? ' and choose a password' : ' and verify your mobile once'}.</div> : (
                <><GoogleButton onNew={(d) => { setLink(d); set({ name: f.name || d.name || '', email: f.email || d.email }) }} /><div className="or">or fill in the form</div></>
              )}
              <div className="field"><label htmlFor="name">Full name *</label><input id="name" className="input" required minLength={2} autoComplete="name" value={f.name} onChange={(e) => set({ name: e.target.value })} /></div>
              <div className="field"><label htmlFor="email">Email (optional)</label><input id="email" className="input" type="email" autoComplete="email" value={f.email} onChange={(e) => set({ email: e.target.value })} /></div>
              <div className="field"><label>Gender *</label>
                <div className="seg" role="radiogroup">{[['male', 'Male'], ['female', 'Female'], ['other', 'Other']].map(([k, l]) => <button key={k} type="button" role="radio" aria-checked={f.gender === k} className={f.gender === k ? 'on' : ''} onClick={() => set({ gender: k })}>{l}</button>)}</div>
              </div>
              <div className="row2">
                <div className="field"><label htmlFor="state">State / Prant *</label>
                  <select id="state" className="input" required value={stateId ?? ''} onChange={(e) => { setStateId(e.target.value ? Number(e.target.value) : null); setDistrictId(null) }}>
                    <option value="">{states ? 'Choose your state' : 'Loading…'}</option>
                    {states?.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
                  </select>
                </div>
                <div className="field"><label htmlFor="district">District {districts?.length ? '*' : ''}</label>
                  <select id="district" className="input" required={!!districts?.length} disabled={!districts?.length} value={districtId ?? ''} onChange={(e) => setDistrictId(e.target.value ? Number(e.target.value) : null)}>
                    <option value="">{stateId ? (districts ? (districts.length ? 'Choose your district' : 'No districts') : 'Loading…') : 'Choose a state first'}</option>
                    {districts?.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
                  </select>
                </div>
              </div>
              <div className="field"><label>You are a</label>
                <div className="seg">{OCCUPATIONS.map((o) => <button key={o} type="button" className={f.occupation === o ? 'on' : ''} onClick={() => set({ occupation: o })}>{o}</button>)}</div>
              </div>
              <div className="field"><label htmlFor="inst">{f.occupation === 'Student' || f.occupation === 'Teacher' ? 'College / university' : 'Organisation'}</label><input id="inst" className="input" value={f.institution} onChange={(e) => set({ institution: e.target.value })} /></div>
              <button className="btn primary block" disabled={!f.gender}>Continue <Icon name="arrow" size={18} /></button>
            </motion.form>
          ) : (
            <motion.div key="v" {...slide} style={{ display: 'grid', gap: 14 }}>
              <div><h1>{otpOff ? 'Your mobile and a password' : 'Verify your mobile'}</h1><p className="muted">Hi {f.name.split(' ')[0]}, one last step.</p></div>
              <OtpStep mobile={mobile} setMobile={setMobile} busy={busy} cta="Create my account" newPassword
                onVerified={(code) => create({ code })}
                onPassword={(password, confirm) => create({ password, password_confirmation: confirm })} />
              <button className="btn ghost" onClick={() => setStep(0)}><Icon name="back" size={16} /> Edit details</button>
            </motion.div>
          )}
        </AnimatePresence>
        {step === 2 && <Celebrate text={`Welcome, ${f.name.split(' ')[0]}!`} />}
      </div>
    </Shell>
  )
}

/** Full-screen check mark with a burst of saffron dots. */
export function Celebrate({ text }: { text: string }) {
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} style={{ position: 'fixed', inset: 0, zIndex: 80, display: 'grid', placeItems: 'center', background: 'rgba(255,255,255,.92)', backdropFilter: 'blur(6px)' }}>
      <div style={{ position: 'relative', display: 'grid', justifyItems: 'center', gap: 16 }}>
        {Array.from({ length: 18 }, (_, i) => {
          const a = (i / 18) * Math.PI * 2
          return <motion.i key={i} style={{ position: 'absolute', top: 50, width: 10, height: 10, borderRadius: 5, background: i % 3 ? '#E3620C' : '#14161F' }}
            initial={{ x: 0, y: 0, opacity: 1, scale: 1 }} animate={{ x: Math.cos(a) * 140, y: Math.sin(a) * 140, opacity: 0, scale: .4 }} transition={{ duration: 1, ease: 'easeOut', delay: .15 }} />
        })}
        <motion.span initial={{ scale: 0, rotate: -30 }} animate={{ scale: 1, rotate: 0 }} transition={{ type: 'spring', stiffness: 260, damping: 14 }}
          style={{ width: 100, height: 100, borderRadius: 50, background: 'linear-gradient(135deg, #F08A3C, #E3620C)', color: '#fff', display: 'grid', placeItems: 'center', boxShadow: '0 20px 40px -14px rgba(227,98,12,.8)' }}>
          <Icon name="check" size={48} stroke={3} />
        </motion.span>
        <motion.h2 initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: .3 }} style={{ fontSize: 30, fontWeight: 800 }}>{text}</motion.h2>
      </div>
    </motion.div>
  )
}
