import { motion } from 'framer-motion'
import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react'
import { Link, Navigate } from 'react-router-dom'
import { api, ApiError } from '../api'
import { nameOf, useAuth } from '../auth'
import { Avatar, ErrorBox, Icon, Orbs, Skeleton } from '../components/ui'
import type { OrgUnit, Vibhag } from '../types'
import { useFetch } from '../useFetch'

const OCCUPATIONS = ['Student', 'Teacher', 'Professional', 'Other']
const fieldErr = (e: unknown, k: string) => (e instanceof ApiError ? e.fields?.[k]?.[0] : undefined)

function Section({ title, sub, children, id }: { title: string; sub?: string; children: ReactNode; id?: string }) {
  return (
    <motion.section id={id} className="card" style={{ display: 'grid', gap: 16 }} initial={{ opacity: 0, y: 16 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }}>
      <div><h2 style={{ fontSize: 22, fontWeight: 800 }}>{title}</h2>{sub && <p className="muted" style={{ marginTop: 4 }}>{sub}</p>}</div>
      {children}
    </motion.section>
  )
}

/** Edit your details, area (state → district), Vibhags, photo and password; apply for membership. */
export default function Profile() {
  const { me, loading, refresh } = useAuth()
  const states = useFetch<OrgUnit[]>('/org/units')
  const vibhags = useFetch<Vibhag[]>('/vibhags')
  const [f, setF] = useState({ full_name: '', email: '', gender: '', date_of_birth: '', occupation: 'Student', institution: '', course: '', study_year: '', prant: '', bio: '' })
  const [stateId, setStateId] = useState<number | ''>('')
  const [districtId, setDistrictId] = useState<number | ''>('')
  const [districts, setDistricts] = useState<OrgUnit[] | null>(null)
  const [vibs, setVibs] = useState<number[]>([])
  const [busy, setBusy] = useState<string | null>(null)
  const [err, setErr] = useState<unknown>(null)
  const [saved, setSaved] = useState('')
  const photoInput = useRef<HTMLInputElement>(null)
  const loaded = useRef(false)

  // Fill the form once from the account.
  useEffect(() => {
    if (!me || loaded.current) return
    loaded.current = true
    const p = me.profile
    setF({
      full_name: p?.full_name || me.name || '', email: me.email ?? '', gender: p?.gender ?? me.gender ?? '', date_of_birth: p?.date_of_birth ?? '',
      occupation: me.occupation ?? 'Student', institution: p?.institution ?? me.institution ?? '', course: p?.course ?? '', study_year: p?.study_year ?? '',
      prant: me.prant ?? '', bio: p?.bio ?? '',
    })
    setVibs(p?.vibhags?.map((v) => v.id) ?? [])
    if (p?.org_unit) {
      setDistrictId(p.org_unit.id)
      api.get<OrgUnit[]>(`/org/units?type=district`).then((r) => {
        const d = r.data.find((x) => x.id === p.org_unit!.id)
        if (d?.parent_id) setStateId(d.parent_id)
      }).catch(() => null)
    }
  }, [me])

  // Districts of the chosen state.
  useEffect(() => {
    if (!stateId) { setDistricts(null); return }
    setDistricts(null)
    api.get<OrgUnit[]>(`/org/units?parent_id=${stateId}`).then((r) => setDistricts(r.data)).catch(() => setDistricts([]))
  }, [stateId])

  if (!loading && !me) return <Navigate to="/login?next=/me/edit" replace />
  if (!me) return <div className="page wrap"><Skeleton /></div>

  const set = (p: Partial<typeof f>) => setF({ ...f, ...p })
  const status = me.profile?.membership_status ?? 'draft'
  const approved = me.is_member
  const areaLocked = approved
  const chosenState = states.data?.find((s) => s.id === stateId)

  async function save(e?: FormEvent) {
    e?.preventDefault()
    setBusy('save'); setErr(null); setSaved('')
    try {
      await api.patch('/me/profile', {
        full_name: f.full_name, email: f.email || null, gender: f.gender || null, date_of_birth: f.date_of_birth || null,
        occupation: f.occupation, institution: f.institution || null, course: f.course || null, study_year: f.study_year || null,
        prant: f.prant || chosenState?.name || null, bio: f.bio || null, vibhag_ids: vibs,
        ...(districtId && !areaLocked ? { org_unit_id: districtId } : {}),
      })
      await refresh()
      setSaved('Your details are saved.')
      return true
    } catch (x) { setErr(x); return false } finally { setBusy(null) }
  }

  async function uploadPhoto(file: File) {
    setBusy('photo'); setErr(null); setSaved('')
    try {
      if (!me?.profile) { const ok = await save(); if (!ok) return }
      const fd = new FormData(); fd.append('photo', file)
      await api.post('/me/photo', fd)
      await refresh()
      setSaved('Photo updated.')
    } catch (x) { setErr(x) } finally { setBusy(null) }
  }

  return (
    <div className="page wrap" style={{ maxWidth: 860 }}>
      <div className="banner" style={{ background: 'linear-gradient(135deg, #3E8BF0, #2563C9 45%, #14161F)' }}>
        <Orbs />
        <div style={{ position: 'relative', zIndex: 2, display: 'flex', gap: 20, alignItems: 'center', flexWrap: 'wrap' }}>
          <button type="button" onClick={() => photoInput.current?.click()} className="avatar-edit" aria-label="Change photo" disabled={busy === 'photo'}>
            <Avatar name={nameOf(me) || '?'} src={me.profile?.photo_url} size={96} />
            <span className="cam"><Icon name="camera" size={16} /></span>
          </button>
          <input ref={photoInput} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={(e) => { const file = e.target.files?.[0]; if (file) uploadPhoto(file); e.target.value = '' }} />
          <div>
            <p style={{ opacity: .85 }}>{busy === 'photo' ? 'Uploading photo…' : 'Edit profile'}</p>
            <h1>{nameOf(me) || 'Your profile'}</h1>
            <p style={{ opacity: .85 }}>{me.profile?.org_unit?.label ?? 'Area not chosen yet'}{me.profile?.member_id ? ` · ${me.profile.member_id}` : ''}</p>
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gap: 18 }}>
        {saved && <div className="notice" role="status">{saved}</div>}
        <ErrorBox error={err instanceof ApiError && err.fields ? null : err} />

        <form onSubmit={save} style={{ display: 'grid', gap: 18 }}>
          <Section title="Your details">
            <div className="form-grid">
              <div className="field"><label htmlFor="n">Full name *</label><input id="n" className="input" required minLength={2} value={f.full_name} onChange={(e) => set({ full_name: e.target.value })} />{fieldErr(err, 'full_name') && <small className="bad-text">{fieldErr(err, 'full_name')}</small>}</div>
              <div className="field"><label htmlFor="em">Email</label><input id="em" className="input" type="email" value={f.email} onChange={(e) => set({ email: e.target.value })} />{fieldErr(err, 'email') && <small className="bad-text">{fieldErr(err, 'email')}</small>}</div>
              <div className="field"><label htmlFor="dob">Date of birth</label><input id="dob" className="input" type="date" value={f.date_of_birth} onChange={(e) => set({ date_of_birth: e.target.value })} />{fieldErr(err, 'date_of_birth') && <small className="bad-text">{fieldErr(err, 'date_of_birth')}</small>}</div>
              <div className="field"><label>Mobile</label><input className="input" value={me.mobile} disabled /></div>
            </div>
            <div className="field"><label>Gender</label>
              <div className="seg" role="radiogroup">{[['male', 'Male'], ['female', 'Female'], ['other', 'Other']].map(([k, l]) => <button key={k} type="button" role="radio" aria-checked={f.gender === k} className={f.gender === k ? 'on' : ''} onClick={() => set({ gender: k })}>{l}</button>)}</div>
            </div>
            <div className="field"><label>You are a</label>
              <div className="seg">{OCCUPATIONS.map((o) => <button key={o} type="button" className={f.occupation === o ? 'on' : ''} onClick={() => set({ occupation: o })}>{o}</button>)}</div>
            </div>
            <div className="form-grid">
              <div className="field"><label htmlFor="inst">{f.occupation === 'Student' || f.occupation === 'Teacher' ? 'College / university' : 'Organisation'}</label><input id="inst" className="input" value={f.institution} onChange={(e) => set({ institution: e.target.value })} /></div>
              {f.occupation === 'Student' && <>
                <div className="field"><label htmlFor="course">Course</label><input id="course" className="input" placeholder="B.Sc. Computers" value={f.course} onChange={(e) => set({ course: e.target.value })} /></div>
                <div className="field"><label htmlFor="yr">Year</label><input id="yr" className="input" placeholder="2nd year" maxLength={16} value={f.study_year} onChange={(e) => set({ study_year: e.target.value })} /></div>
              </>}
            </div>
            <div className="field"><label htmlFor="bio">About you</label><textarea id="bio" className="input" style={{ minHeight: 90, paddingTop: 12 }} maxLength={500} value={f.bio} onChange={(e) => set({ bio: e.target.value })} /></div>
          </Section>

          <Section id="area" title="Your area" sub={areaLocked ? 'Approved members change their area through their district office.' : 'Choose your state and district. Your district office reviews your membership and you see posts and events from your area.'}>
            <div className="form-grid">
              <div className="field"><label htmlFor="st">State (prant)</label>
                <select id="st" className="input" disabled={areaLocked} value={stateId} onChange={(e) => { setStateId(e.target.value ? Number(e.target.value) : ''); setDistrictId('') }}>
                  <option value="">Choose your state</option>
                  {states.data?.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              </div>
              <div className="field"><label htmlFor="di">District</label>
                <select id="di" className="input" disabled={areaLocked || !stateId || !districts} value={districtId} onChange={(e) => setDistrictId(e.target.value ? Number(e.target.value) : '')}>
                  <option value="">{!stateId ? 'Choose a state first' : !districts ? 'Loading…' : districts.length ? 'Choose your district' : 'No districts listed yet'}</option>
                  {districts?.map((d) => <option key={d.id} value={d.id}>{d.name}</option>)}
                </select>
                {fieldErr(err, 'org_unit_id') && <small className="bad-text">{fieldErr(err, 'org_unit_id')}</small>}
              </div>
            </div>
            {me.profile?.org_unit && <p className="muted" style={{ fontSize: 14 }}>Now: <b>{me.profile.org_unit.label}</b></p>}
          </Section>

          <Section title="Vibhags" sub="Areas of work you are part of. Join as many as you like.">
            {vibhags.data ? (
              <div className="chips">{vibhags.data.map((v) => {
                const on = vibs.includes(v.id)
                return <button key={v.id} type="button" className={`chip-btn ${on ? 'on' : ''}`} aria-pressed={on} title={v.description ?? undefined} onClick={() => setVibs(on ? vibs.filter((x) => x !== v.id) : [...vibs, v.id])}>{on && '✓ '}{v.name}</button>
              })}</div>
            ) : <Skeleton h={42} n={1} />}
          </Section>

          <div className="sticky-save">
            <button className="btn primary" disabled={busy === 'save'}>{busy === 'save' ? 'Saving…' : 'Save details'}</button>
            <Link to="/me" className="btn ghost">Back to My space</Link>
          </div>
        </form>

        <PasswordCard hasPassword={!!me.has_password} onDone={refresh} />
        <MembershipCard status={status} approved={approved} note={me.application?.decision_note ?? null} office={me.application?.reviewing_office ?? null}
          missing={[!me.profile?.full_name && 'name', !me.profile?.date_of_birth && 'date of birth', !me.profile?.org_unit && 'district'].filter(Boolean) as string[]}
          onDone={refresh} />
      </div>
    </div>
  )
}

function PasswordCard({ hasPassword, onDone }: { hasPassword: boolean; onDone: () => Promise<void> }) {
  const [cur, setCur] = useState('')
  const [pw, setPw] = useState('')
  const [pw2, setPw2] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [ok, setOk] = useState(false)
  const mismatch = pw2.length > 0 && pw !== pw2
  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setErr(null); setOk(false)
    try {
      await api.put('/me/password', { current_password: hasPassword ? cur : undefined, password: pw, password_confirmation: pw2 })
      setCur(''); setPw(''); setPw2(''); setOk(true); await onDone()
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  return (
    <form onSubmit={submit}>
      <Section title={hasPassword ? 'Change password' : 'Set a password'} sub="Sign in with your mobile number and password – handy when SMS codes are slow.">
        {ok && <div className="notice">Password saved. You were signed out on your other devices.</div>}
        <ErrorBox error={err instanceof ApiError && err.fields ? null : err} />
        <div className="form-grid">
          {hasPassword && <div className="field"><label htmlFor="cp">Current password</label><input id="cp" className="input" type="password" autoComplete="current-password" required value={cur} onChange={(e) => setCur(e.target.value)} />{fieldErr(err, 'current_password') && <small className="bad-text">{fieldErr(err, 'current_password')}</small>}</div>}
          <div className="field"><label htmlFor="np">New password</label><input id="np" className="input" type="password" autoComplete="new-password" minLength={8} required value={pw} onChange={(e) => setPw(e.target.value)} /><small>At least 8 characters.</small></div>
          <div className="field"><label htmlFor="np2">Type it again</label><input id="np2" className="input" type="password" autoComplete="new-password" required value={pw2} onChange={(e) => setPw2(e.target.value)} />{mismatch && <small className="bad-text">The two passwords don't match.</small>}</div>
        </div>
        <div><button className="btn dark" disabled={busy || mismatch || pw.length < 8}>{busy ? 'Saving…' : hasPassword ? 'Change password' : 'Set password'}</button></div>
      </Section>
    </form>
  )
}

const STATUS: Record<string, [string, string]> = {
  draft: ['Not applied yet', 'mute'],
  submitted: ['With your district office', 'info'],
  more_info: ['Returned for correction', 'warn'],
  approved: ['Approved member', 'ok'],
  rejected: ['Not approved', 'bad'],
}

function MembershipCard({ status, approved, note, office, missing, onDone }: { status: string; approved: boolean; note: string | null; office: string | null; missing: string[]; onDone: () => Promise<void> }) {
  const [agree, setAgree] = useState(false)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [label, tone] = STATUS[status] ?? [status, 'mute']
  const canApply = !approved && status !== 'submitted'
  async function apply() {
    setBusy(true); setErr(null)
    try { await api.post('/membership/application', { confirm: true }); await onDone() } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  return (
    <Section title="ABVP membership" sub="Members get a member ID and QR pass, can register for member events and join Vibhag spaces.">
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <span className={`status-pill ${tone}`}>{label}</span>
        {office && status === 'submitted' && <span className="muted">Reviewed by {office}</span>}
      </div>
      {status === 'more_info' && note && <div className="hint">Your office says: {note}</div>}
      {status === 'rejected' && note && <div className="error">{note}</div>}
      {canApply && (
        missing.length > 0 ? (
          <div className="hint">To apply, add your {missing.join(', ')} above and save.</div>
        ) : (
          <div style={{ display: 'grid', gap: 12 }}>
            <label style={{ display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 15 }}>
              <input type="checkbox" checked={agree} onChange={(e) => setAgree(e.target.checked)} style={{ marginTop: 4, width: 18, height: 18 }} />
              <span>The details I gave are correct, and I want to become a member of Akhil Bharatiya Vidyarthi Parishad.</span>
            </label>
            <ErrorBox error={err} />
            <div><button className="btn primary" disabled={!agree || busy} onClick={apply}>{busy ? 'Sending…' : status === 'more_info' ? 'Send again' : 'Apply for membership'} <Icon name="arrow" size={18} /></button></div>
          </div>
        )
      )}
    </Section>
  )
}
