import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { createPortal } from 'react-dom'
import { api } from '../api'
import { ErrorBox, Skeleton } from '../components/ui'
import { useFetch } from '../useFetch'

interface Contact { id?: number; name: string; role: string | null; phone: string | null; is_lead: boolean; member_id: string | null; verified?: boolean }
interface Item {
  id: number; kind: string; title: string; subtitle: string | null; region: string | null; description: string | null
  location: string | null; landmark: string | null; color: string | null; timings: string | null; tags: string[]; steps: string[]
  map_url: string | null; lat: number | null; lng: number | null; distance_km: number | null; distance_is_road: boolean
  travel_time: string | null; photo_urls: string[]; contacts: Contact[]
  videos?: Video[]
}
interface Video { url: string | null; title: string | null; kind: 'file' | 'youtube' | 'link'; thumb_url: string | null }
interface Kind { kind: string; title: string; hindi: string }
interface Guide {
  settings: { guide_enabled: boolean; delegate_registration_open?: boolean; venue_lat: number | null; venue_lng: number | null; helpline_phone: string | null }
  kinds: Kind[]; prants: string[]; items: Item[]
}

const EMOJI: Record<string, string> = { stay: '🛏️', arrival: '🚌', food: '🍛', office: '🏢', session: '🎤', exhibit: '🖼️', facility: '🅿️', tourist: '🛕', emergency: '🚑', gallery: '📷' }
const HINT: Record<string, string> = {
  stay: 'Where each prant stays, and who to call there.',
  arrival: 'Airport, stations and bus stands: the desk, its lead and how to reach the venue.',
  food: 'Halls and stalls with a colour and a landmark so people can spot them.',
  office: 'Which office handles what, and where it is.',
  session: 'The programme: what happens when and where.',
  exhibit: 'Digital showcase: history, pictures and stories.',
  facility: 'Parking, washrooms, water, cloak room.',
  tourist: 'Places to visit nearby.',
  gallery: 'Event gallery: add an album (title + photos) for each day or programme. Delegates see it in the guide.',
  emergency: 'Emergency numbers (108, 112…: put the number as the contact phone) and each hall with its emergency lead members – write the hall in “Where exactly”.',
}

type Draft = Omit<Item, 'id' | 'photo_urls' | 'distance_is_road' | 'tags' | 'steps' | 'lat' | 'lng' | 'distance_km'> & { tags: string; steps: string; lat: string; lng: string; distance_km: string }

const blank = (kind: string): Draft => ({
  kind, title: '', subtitle: '', region: '', description: '', location: '', landmark: '', color: null, timings: '', tags: '', steps: '',
  map_url: '', lat: '', lng: '', distance_km: '', travel_time: '', contacts: [{ name: '', role: 'Lead', phone: '', is_lead: true, member_id: '' }],
})

const toDraft = (i: Item): Draft => ({
  ...i, tags: i.tags.join(', '), steps: i.steps.join('\n'), lat: i.lat?.toString() ?? '', lng: i.lng?.toString() ?? '',
  distance_km: i.distance_is_road && i.distance_km !== null ? String(i.distance_km) : '',
  contacts: i.contacts.map((c) => ({ ...c, phone: c.member_id ? '' : c.phone })),
})

/** Conference guide editor: everything delegates see in the app's guide. */
export default function GuideTab({ id }: { id: number }) {
  const { data, error, reload } = useFetch<Guide>(`/admin/events/${id}/guide`)
  const [kind, setKind] = useState('stay')
  const [q, setQ] = useState('')
  const [editing, setEditing] = useState<{ item: Item | null; draft: Draft } | null>(null)
  const [msg, setMsg] = useState('')

  const counts = useMemo(() => {
    const c: Record<string, number> = {}
    data?.items.forEach((i) => { c[i.kind] = (c[i.kind] ?? 0) + 1 })
    return c
  }, [data])
  const list = (data?.items ?? []).filter((i) => i.kind === kind && (!q || `${i.title} ${i.region ?? ''} ${i.location ?? ''}`.toLowerCase().includes(q.toLowerCase())))

  if (!data) return <section className="card"><ErrorBox error={error} />{!error && <Skeleton rows={6} />}</section>

  const k = data.kinds.find((x) => x.kind === kind)!
  return (
    <div className="guide-admin">
      <Settings guide={data} id={id} onSaved={(m) => { setMsg(m); reload() }} />
      {msg && <div className="notice" role="status">{msg}</div>}

      <div className="guide-kinds" role="tablist" aria-label="Guide sections">
        {data.kinds.map((x) => (
          <button key={x.kind} role="tab" aria-selected={kind === x.kind} className={`gk ${kind === x.kind ? 'on' : ''}`} onClick={() => { setKind(x.kind); setQ('') }}>
            <span className="gk-emoji" aria-hidden="true">{EMOJI[x.kind]}</span>
            <span className="gk-text"><b>{x.title}</b><small>{x.hindi}</small></span>
            <span className="gk-count">{counts[x.kind] ?? 0}</span>
          </button>
        ))}
      </div>

      <section className="card">
        <div className="card-head">
          <div><h3>{EMOJI[kind]} {k.title} <span className="muted" style={{ fontWeight: 500 }}>· {k.hindi}</span></h3><p className="sub">{HINT[kind]}</p></div>
          <div className="toolbar">
            <input className="input" style={{ width: 220 }} placeholder={kind === 'stay' ? 'Search prant or place' : 'Search'} value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search this section" />
            <button className="btn primary" onClick={() => setEditing({ item: null, draft: blank(kind) })}>+ Add {k.title.toLowerCase().replace(/s$/, '')}</button>
          </div>
        </div>
        {list.length === 0 ? (
          <div className="empty">Nothing here yet. Add the first one – delegates see it in the app straight away.</div>
        ) : (
          <div className="gi-grid">
            {list.map((i) => (
              <button key={i.id} className="gi" onClick={() => setEditing({ item: i, draft: toDraft(i) })} style={{ ['--gi' as string]: i.color ?? 'var(--saffron)' }}>
                {i.photo_urls[0] ? <img src={i.photo_urls[0]} alt="" /> : <span className="gi-bar" />}
                <span className="gi-body">
                  {i.region && <span className="gi-region">{i.region}</span>}
                  <b>{i.title}</b>
                  {i.subtitle && <span className="muted">{i.subtitle}</span>}
                  {i.location && <span className="gi-loc">📍 {i.location}</span>}
                  <span className="gi-meta">
                    {i.contacts.filter((c) => c.is_lead).map((c) => <span key={c.id} className="pill info">★ {c.name}</span>)}
                    {i.contacts.length > 0 && <span className="pill mute">{i.contacts.length} contact{i.contacts.length === 1 ? '' : 's'}</span>}
                    {i.distance_km !== null && <span className="pill mute">{i.distance_km} km</span>}
                    {i.photo_urls.length > 0 && <span className="pill mute">{i.photo_urls.length} photo{i.photo_urls.length === 1 ? '' : 's'}</span>}
                    {(i.videos?.length ?? 0) > 0 && <span className="pill mute">{i.videos!.length} video{i.videos!.length === 1 ? '' : 's'}</span>}
                  </span>
                </span>
              </button>
            ))}
          </div>
        )}
      </section>

      {editing && (
        <Editor eventId={id} kinds={data.kinds} prants={data.prants} item={editing.item} initial={editing.draft}
          onClose={() => setEditing(null)}
          onSaved={(m, keepOpen) => { setMsg(m); reload(); if (!keepOpen) setEditing(null) }} />
      )}
    </div>
  )
}

function Settings({ guide, id, onSaved }: { guide: Guide; id: number; onSaved: (m: string) => void }) {
  const [s, setS] = useState({ guide_enabled: guide.settings.guide_enabled, delegate_registration_open: !!guide.settings.delegate_registration_open, venue_lat: guide.settings.venue_lat?.toString() ?? '', venue_lng: guide.settings.venue_lng?.toString() ?? '', helpline_phone: guide.settings.helpline_phone ?? '' })
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  async function save(e?: FormEvent, enabled = s.guide_enabled, delegates = s.delegate_registration_open) {
    e?.preventDefault()
    setBusy(true)
    setErr(null)
    try {
      await api.put(`/admin/events/${id}/guide/settings`, { guide_enabled: enabled, delegate_registration_open: delegates, venue_lat: s.venue_lat || null, venue_lng: s.venue_lng || null, helpline_phone: s.helpline_phone || null })
      onSaved(`${enabled ? 'Guide is on.' : 'Guide is off.'} Delegate registration is ${delegates ? 'open on the website and app' : 'closed'}.`)
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }
  return (
    <form className="card guide-settings" onSubmit={save}>
      <div className="gs-switch">
        <button type="button" role="switch" aria-checked={s.guide_enabled} className={`switch ${s.guide_enabled ? 'on' : ''}`} disabled={busy}
          onClick={() => { const v = !s.guide_enabled; setS({ ...s, guide_enabled: v }); save(undefined, v) }}><i /></button>
        <div><b>Conference guide {s.guide_enabled ? 'is on' : 'is off'}</b><span className="muted">{s.guide_enabled ? 'Everyone who opens the app sees it – no sign-in needed.' : 'Fill it in first; switch on when ready.'}</span></div>
      </div>
      <div className="gs-switch">
        <button type="button" role="switch" aria-checked={s.delegate_registration_open} className={`switch ${s.delegate_registration_open ? 'on' : ''}`} disabled={busy}
          onClick={() => { const v = !s.delegate_registration_open; setS({ ...s, delegate_registration_open: v }); save(undefined, s.guide_enabled, v) }}><i /></button>
        <div><b>Delegate registration {s.delegate_registration_open ? 'is open' : 'is closed'}</b><span className="muted">{s.delegate_registration_open ? 'Anyone can register on abvpconnect.org and get a pass.' : 'Open it when the form should go live.'}</span></div>
      </div>
      <div className="field"><label htmlFor="g-hl">Helpline</label><input id="g-hl" className="input" placeholder="24x7 number" value={s.helpline_phone} onChange={(e) => setS({ ...s, helpline_phone: e.target.value })} /></div>
      <div className="field"><label htmlFor="g-lat">Venue latitude</label><input id="g-lat" className="input" inputMode="decimal" placeholder="17.385" value={s.venue_lat} onChange={(e) => setS({ ...s, venue_lat: e.target.value })} /></div>
      <div className="field"><label htmlFor="g-lng">Venue longitude</label><input id="g-lng" className="input" inputMode="decimal" placeholder="78.4867" value={s.venue_lng} onChange={(e) => setS({ ...s, venue_lng: e.target.value })} /></div>
      <button className="btn" disabled={busy}>Save</button>
      <ErrorBox error={err} />
    </form>
  )
}

function Editor({ eventId, kinds, prants, item: initialItem, initial, onClose, onSaved }: {
  eventId: number; kinds: Kind[]; prants: string[]; item: Item | null; initial: Draft
  onClose: () => void; onSaved: (msg: string, keepOpen?: boolean) => void
}) {
  // After "Add", the drawer stays open on the new item so photos and videos can be added at once.
  const [item, setItem] = useState<Item | null>(initialItem)
  const [pending, setPending] = useState<File[]>([])
  const [d, setD] = useState<Draft>(initial)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const [photos, setPhotos] = useState<string[]>(initialItem?.photo_urls ?? [])
  const [videos, setVideos] = useState<Video[]>(initialItem?.videos ?? [])
  const [vTitle, setVTitle] = useState('')
  const [vUrl, setVUrl] = useState('')
  const [progress, setProgress] = useState<string | null>(null)
  const gallery = d.kind === 'gallery'
  const maxPhotos = gallery ? 60 : 8
  const kindLabel = kinds.find((k) => k.kind === d.kind)?.title ?? d.kind
  const set = (patch: Partial<Draft>) => setD({ ...d, ...patch })
  const setContact = (i: number, patch: Partial<Contact>) => set({ contacts: d.contacts.map((c, j) => (j === i ? { ...c, ...patch } : c)) })

  useEffect(() => {
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', esc)
    return () => window.removeEventListener('keydown', esc)
  }, [onClose])

  async function save(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setErr(null)
    const body = {
      ...d,
      tags: d.tags.split(',').map((t) => t.trim()).filter(Boolean),
      steps: d.steps.split('\n').map((t) => t.trim()).filter(Boolean),
      lat: d.lat || null, lng: d.lng || null, distance_km: d.distance_km || null, color: d.color || null,
      contacts: d.contacts.filter((c) => c.name || c.member_id).map((c) => ({ name: c.name || null, role: c.role || null, phone: c.phone || null, member_id: c.member_id || null, is_lead: c.is_lead })),
    }
    try {
      if (item) {
        await api.patch(`/admin/guide-items/${item.id}`, body)
        onSaved(`Saved “${d.title}”.`)
      } else {
        const r = await api.post<Item>(`/admin/events/${eventId}/guide/items`, body)
        setItem(r.data)
        if (pending.length) {
          const files = pending
          setPending([])
          await upload(files, r.data)
        }
        onSaved(d.kind === 'gallery' ? `Added album “${d.title}”. Add more photos and videos below.` : `Added “${d.title}”.`, true)
      }
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  async function upload(files: File[], target: Item | null = item) {
    if (!files.length) return
    if (!target) {
      // Not saved yet: keep the files and upload them right after "Add".
      setPending([...pending, ...files].slice(0, maxPhotos))
      return
    }
    setBusy(true); setErr(null)
    try {
      for (const [n, file] of files.slice(0, maxPhotos - photos.length).entries()) {
        setProgress(`Uploading photo ${n + 1} of ${files.length}…`)
        const form = new FormData()
        form.append('photo', file)
        const r = await api.post<Item>(`/admin/guide-items/${target.id}/photos`, form)
        setPhotos(r.data.photo_urls)
      }
      onSaved(files.length > 1 ? `${files.length} photos added.` : 'Photo added.', true)
    } catch (x) { setErr(x) } finally { setBusy(false); setProgress(null) }
  }
  async function addVideo(file?: File) {
    if (!item || (!file && !vUrl.trim())) return
    const form = new FormData()
    if (file) form.append('video', file)
    else form.append('url', vUrl.trim())
    if (vTitle.trim()) form.append('title', vTitle.trim())
    setBusy(true); setErr(null)
    if (file) setProgress(`Uploading ${file.name} (${Math.round(file.size / 1048576)} MB)… keep this window open.`)
    try {
      const r = await api.post<Item>(`/admin/guide-items/${item.id}/videos`, form)
      setVideos(r.data.videos ?? []); setVTitle(''); setVUrl('')
      onSaved('Video added.', true)
    } catch (x) { setErr(x) } finally { setBusy(false); setProgress(null) }
  }
  async function removeVideo(i: number) {
    if (!item || !confirm('Remove this video?')) return
    const r = await api.del<Item>(`/admin/guide-items/${item.id}/videos/${i}`)
    setVideos(r.data.videos ?? [])
    onSaved('Video removed.', true)
  }
  async function removePhoto(i: number) {
    if (!item) return
    const r = await api.del<Item>(`/admin/guide-items/${item.id}/photos/${i}`)
    setPhotos(r.data.photo_urls)
    onSaved('Photo removed.', true)
  }
  async function remove() {
    if (!item || !confirm(`Delete “${item.title}” from the guide?`)) return
    await api.del(`/admin/guide-items/${item.id}`)
    onSaved(`Deleted “${item.title}”.`)
  }

  const maps = ['arrival', 'stay', 'tourist', 'facility', 'office'].includes(d.kind)
  // Each section asks only what it needs.
  const k = d.kind
  const show = {
    where: k !== 'gallery',
    timings: !['gallery', 'emergency'].includes(k),
    landmark: !['gallery', 'exhibit', 'session', 'emergency', 'tourist'].includes(k),
    color: ['food', 'office', 'facility', 'stay', 'exhibit', 'session'].includes(k),
    tags: !['gallery', 'exhibit'].includes(k),
    contacts: k !== 'gallery',
  }
  const photoFirst = k === 'gallery' || k === 'exhibit'
  const labels = {
    title: k === 'gallery' ? 'Album name *' : k === 'exhibit' ? 'Exhibit / stall name *' : 'Name *',
    sub: k === 'gallery' ? 'Date or programme' : k === 'exhibit' ? 'Theme – one line' : 'Short line',
    about: k === 'gallery' ? 'About this album' : k === 'exhibit' ? 'What it is – the story visitors read' : 'About',
    where: k === 'exhibit' ? 'Hall and stall number' : 'Where exactly',
  }
  const photoBlock = (
    <fieldset className="fs">
      <legend>{k === 'gallery' ? 'Photos' : k === 'exhibit' ? 'Pictures of the exhibit' : 'Photos'}</legend>
      <div className="ph-grid">
        {photos.map((u, i) => (
          <div key={u} className="ph"><img src={u} alt={`Photo ${i + 1}`} /><button type="button" onClick={() => removePhoto(i)} aria-label={`Remove photo ${i + 1}`}>✕</button></div>
        ))}
        {pending.map((f, i) => (
          <div key={`p${i}`} className="ph"><img src={URL.createObjectURL(f)} alt={f.name} /><button type="button" onClick={() => setPending(pending.filter((_, j) => j !== i))} aria-label={`Remove ${f.name}`}>✕</button></div>
        ))}
        {photos.length + pending.length < maxPhotos && <label className="ph add">+<input type="file" accept="image/jpeg,image/png,image/webp" multiple hidden onChange={(e) => { upload(Array.from(e.target.files ?? [])); e.target.value = '' }} /></label>}
      </div>
      {!item && pending.length > 0 && <small className="muted">{pending.length} photo{pending.length === 1 ? '' : 's'} will upload when you press “Add to guide”.</small>}
      {gallery && <small className="muted">Up to {maxPhotos} photos per album – pick many at once. {photos.length}/{maxPhotos}</small>}
      {progress && <div className="notice" role="status">{progress}</div>}
    </fieldset>
  )
  // Portal: the page wrapper animates with a transform, which would trap a fixed overlay inside it.
  return createPortal(
    <div className="drawer-wrap" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <form className="drawer" onSubmit={save} aria-label={`${item ? 'Edit' : 'Add'} ${kindLabel}`}>
        <header className="drawer-head">
          <div><small className="muted">{EMOJI[d.kind]} {kindLabel}</small><h2>{item ? 'Edit' : 'Add'} {d.title || kindLabel.toLowerCase()}</h2></div>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Close">✕</button>
        </header>
        <div className="drawer-body">
          <ErrorBox error={err} />
          {d.kind === 'stay' && (
            <div className="field"><label htmlFor="gi-region">Prant (state) *</label>
              <input id="gi-region" className="input" list="prants" required value={d.region ?? ''} onChange={(e) => set({ region: e.target.value })} placeholder="Konkan (Mumbai)" />
              <datalist id="prants">{prants.map((p) => <option key={p} value={p} />)}</datalist>
            </div>
          )}
          <div className="field"><label htmlFor="gi-title">{labels.title}</label><input id="gi-title" className="input" required value={d.title} onChange={(e) => set({ title: e.target.value })} placeholder={d.kind === 'stay' ? 'SVIT Engineering College' : d.kind === 'arrival' ? 'RGI Airport' : 'Name'} /></div>
          <div className="field"><label htmlFor="gi-sub">{labels.sub}</label><input id="gi-sub" className="input" value={d.subtitle ?? ''} onChange={(e) => set({ subtitle: e.target.value })} placeholder={k === 'food' ? 'What is served' : k === 'gallery' ? '24 Dec · Inauguration' : k === 'exhibit' ? 'ABVP – 75 years of student movement' : 'One line under the name'} /></div>
          {photoFirst && photoBlock}
          {photoFirst && <div className="field"><label htmlFor="gi-desc">{labels.about}</label><textarea id="gi-desc" className="input" rows={k === 'exhibit' ? 6 : 3} value={d.description ?? ''} onChange={(e) => set({ description: e.target.value })} placeholder={k === 'exhibit' ? 'What visitors see here, the history behind it, who made it…' : ''} /></div>}
          {(show.where || show.timings) && <div className="row2">
            {show.where && <div className="field"><label htmlFor="gi-loc">{labels.where}</label><input id="gi-loc" className="input" value={d.location ?? ''} onChange={(e) => set({ location: e.target.value })} placeholder="Hall B, Stall 7, left of the stage" /></div>}
            {show.timings && <div className="field"><label htmlFor="gi-time">Timings</label><input id="gi-time" className="input" value={d.timings ?? ''} onChange={(e) => set({ timings: e.target.value })} placeholder="7 AM – 10 PM" /></div>}
          </div>}
          {(show.landmark || show.color) && <div className="row2">
            {show.landmark && <div className="field"><label htmlFor="gi-mark">How to spot it</label><input id="gi-mark" className="input" value={d.landmark ?? ''} onChange={(e) => set({ landmark: e.target.value })} placeholder="Green flag with a lotus" /></div>}
            {show.color && <div className="field"><label htmlFor="gi-color">Colour</label>
              <div className="color-row">
                <input id="gi-color" type="color" value={d.color ?? '#E3620C'} onChange={(e) => set({ color: e.target.value.toUpperCase() })} />
                {d.color ? <button type="button" className="btn small ghost" onClick={() => set({ color: null })}>No colour</button> : <span className="muted">Optional</span>}
              </div>
            </div>}
          </div>}
          {show.tags && <div className="field"><label htmlFor="gi-tags">Tags</label><input id="gi-tags" className="input" value={d.tags} onChange={(e) => set({ tags: e.target.value })} placeholder="Veg, Jain, Girls, 24x7 – separated by commas" /></div>}
          {!photoFirst && <div className="field"><label htmlFor="gi-desc">{labels.about}</label><textarea id="gi-desc" className="input" rows={3} value={d.description ?? ''} onChange={(e) => set({ description: e.target.value })} /></div>}

          {maps && (
            <fieldset className="fs">
              <legend>Map and how to reach</legend>
              <div className="row3">
                <div className="field"><label htmlFor="gi-lat">Latitude</label><input id="gi-lat" className="input" inputMode="decimal" value={d.lat} onChange={(e) => set({ lat: e.target.value })} placeholder="17.2403" /></div>
                <div className="field"><label htmlFor="gi-lng">Longitude</label><input id="gi-lng" className="input" inputMode="decimal" value={d.lng} onChange={(e) => set({ lng: e.target.value })} placeholder="78.4294" /></div>
                <div className="field"><label htmlFor="gi-km">Road km to venue</label><input id="gi-km" className="input" inputMode="decimal" value={d.distance_km} onChange={(e) => set({ distance_km: e.target.value })} placeholder="32" /></div>
              </div>
              <div className="row2">
                <div className="field"><label htmlFor="gi-tt">Travel time</label><input id="gi-tt" className="input" value={d.travel_time ?? ''} onChange={(e) => set({ travel_time: e.target.value })} placeholder="50 min by shuttle" /></div>
                <div className="field"><label htmlFor="gi-map">Map link (optional)</label><input id="gi-map" className="input" value={d.map_url ?? ''} onChange={(e) => set({ map_url: e.target.value })} placeholder="https://maps.google.com/…" /></div>
              </div>
              <div className="field"><label htmlFor="gi-steps">Steps to reach (one per line)</label><textarea id="gi-steps" className="input" rows={4} value={d.steps} onChange={(e) => set({ steps: e.target.value })} placeholder={'Exit at Gate 4\nFind the saffron ABVP desk\nBoard the shuttle'} /></div>
              <small className="muted">Tip: in Google Maps, long-press a spot to copy its latitude and longitude. Without road km, the app shows straight-line distance from the venue pin.</small>
            </fieldset>
          )}

          {show.contacts && <fieldset className="fs">
            <legend>{k === 'exhibit' ? 'Guide at the stall (optional)' : 'Who to contact'}</legend>
            {d.contacts.map((c, i) => (
              <div key={i} className={`contact-row ${c.is_lead ? 'lead' : ''}`}>
                <label className="lead-toggle" title="Lead"><input type="checkbox" checked={c.is_lead} onChange={(e) => setContact(i, { is_lead: e.target.checked })} />★</label>
                <input className="input" placeholder="Name" value={c.name} onChange={(e) => setContact(i, { name: e.target.value })} aria-label={`Contact ${i + 1} name`} />
                <input className="input" placeholder="Role" value={c.role ?? ''} onChange={(e) => setContact(i, { role: e.target.value })} aria-label={`Contact ${i + 1} role`} />
                <input className="input" placeholder="Phone" value={c.phone ?? ''} onChange={(e) => setContact(i, { phone: e.target.value })} aria-label={`Contact ${i + 1} phone`} />
                <input className="input mono" placeholder="Member ID" value={c.member_id ?? ''} onChange={(e) => setContact(i, { member_id: e.target.value })} aria-label={`Contact ${i + 1} member ID`} title="Optional: link a member; their mobile is used if phone is empty" />
                <button type="button" className="btn small ghost" onClick={() => set({ contacts: d.contacts.filter((_, j) => j !== i) })} aria-label={`Remove contact ${i + 1}`}>✕</button>
              </div>
            ))}
            <button type="button" className="btn small" onClick={() => set({ contacts: [...d.contacts, { name: '', role: 'Team', phone: '', is_lead: false, member_id: '' }] })}>+ Add person</button>
            <small className="muted">★ marks the lead, shown first. These numbers are public: anyone who opens the guide can call them. Add a Member ID to link someone; their verified badge and mobile are used.</small>
          </fieldset>}

          {!photoFirst && photoBlock}
          {gallery && !item && <p className="muted" style={{ fontSize: 13 }}>Videos can be added right after you press “Add to guide”.</p>}
          {item && gallery && (
            <fieldset className="fs">
              <legend>Videos</legend>
              {videos.length > 0 && (
                <div className="vid-list">
                  {videos.map((v, i) => (
                    <div key={i} className="vid">
                      <a href={v.url ?? '#'} target="_blank" rel="noreferrer" className="vid-thumb" style={v.thumb_url ? { backgroundImage: `url(${v.thumb_url})` } : undefined}>▶</a>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <b>{v.title || (v.kind === 'file' ? 'Video' : 'Video link')}</b>
                        <div className="muted" style={{ fontSize: 12 }}>{v.kind === 'file' ? 'Uploaded clip' : v.kind === 'youtube' ? 'YouTube' : 'Link'}</div>
                      </div>
                      <button type="button" className="btn small" onClick={() => removeVideo(i)}>Remove</button>
                    </div>
                  ))}
                </div>
              )}
              <input className="input" placeholder="Video title (optional) – e.g. Inauguration speech" value={vTitle} onChange={(e) => setVTitle(e.target.value)} aria-label="Video title" />
              <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                <input className="input" placeholder="YouTube or other video link" value={vUrl} onChange={(e) => setVUrl(e.target.value)} aria-label="Video link" />
                <button type="button" className="btn" disabled={busy || !vUrl.trim()} onClick={() => addVideo()}>Add link</button>
              </div>
              <label className="btn" style={{ marginTop: 8, display: 'inline-flex' }}>
                ⬆ Upload a video (mp4, up to 100 MB)
                <input type="file" accept="video/mp4,video/quicktime,video/webm" hidden onChange={(e) => { addVideo(e.target.files?.[0]); e.target.value = '' }} />
              </label>
              <small className="muted" style={{ display: 'block', marginTop: 6 }}>Long videos: upload them to YouTube (they can be unlisted) and add the link – they play smoothly on every phone.</small>
            </fieldset>
          )}
        </div>
        <footer className="drawer-foot">
          {item && <button type="button" className="btn danger" onClick={remove}>Delete</button>}
          <div className="grow" />
          <button type="button" className="btn" onClick={onClose}>Cancel</button>
          <button className="btn primary" disabled={busy}>{busy ? 'Saving…' : item ? 'Save changes' : 'Add to guide'}</button>
        </footer>
      </form>
    </div>,
    document.body,
  )
}
