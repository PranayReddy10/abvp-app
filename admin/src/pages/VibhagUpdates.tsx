import { useState, type FormEvent } from 'react'
import { api } from '../api'
import AreaPicker, { VibhagPicker } from '../components/AreaPicker'
import { Empty, ErrorBox } from '../components/ui'
import { fmtTime } from '../format'
import { useFetch } from '../useFetch'

interface Post { id: number; body: string; author: string | null; place: string | null; at: string }

export default function VibhagUpdates() {
  const [vibhag, setVibhag] = useState('')
  const [unit, setUnit] = useState('')
  const [body, setBody] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<unknown>(null)
  const { data: posts, reload } = useFetch<Post[]>(vibhag ? `/spaces/${vibhag}/posts` : null)

  async function post(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setErr(null)
    try {
      await api.post(`/spaces/${vibhag}/posts`, { body, org_unit_id: unit ? Number(unit) : undefined })
      setBody('')
      reload()
    } catch (x) { setErr(x) } finally { setBusy(false) }
  }

  return (
    <main className="content">
      <div className="page-head"><h1>Vibhag updates</h1></div>
      <div className="grid2" style={{ gridTemplateColumns: 'minmax(0,1fr) minmax(0,1.3fr)' }}>
        <form className="card" onSubmit={post}>
          <h3>Post an update</h3>
          <p className="muted">Shows in the Vibhag's space in the app for members in the chosen area.</p>
          <ErrorBox error={err} />
          <div className="row2">
            <div className="field"><label htmlFor="pv">Vibhag</label><VibhagPicker id="pv" required value={vibhag} onChange={setVibhag} /></div>
            <div className="field"><label htmlFor="pa">Area</label><AreaPicker id="pa" value={unit} onChange={setUnit} /></div>
          </div>
          <div className="field"><label htmlFor="pb">Update</label><textarea id="pb" className="input" required style={{ minHeight: 120 }} value={body} onChange={(e) => setBody(e.target.value)} placeholder="Lake clean-up at Saroornagar done. 86 students joined from 4 colleges." /></div>
          <button className="btn primary" disabled={busy || !vibhag}>{busy ? 'Posting…' : 'Post update'}</button>
        </form>
        <section className="card">
          <h3>Recent updates</h3>
          {!vibhag && <Empty>Choose a Vibhag to see its updates.</Empty>}
          <div className="feed">
            {posts?.map((p) => <div className="post" key={p.id}><span className="who">{p.author} · {p.place} · {fmtTime(p.at)}</span><span>{p.body}</span></div>)}
            {vibhag && posts?.length === 0 && <Empty>No updates yet.</Empty>}
          </div>
        </section>
      </div>
    </main>
  )
}
