import { useAuth } from '../auth'
import { useFetch } from '../useFetch'

interface Unit { id: number; name: string }

/** The admin's own area plus the areas directly inside it. */
export default function AreaPicker({ id, value, onChange }: { id: string; value: string; onChange: (v: string) => void }) {
  const { me } = useAuth()
  const scope = me?.roles[0]?.org_unit
  const { data: units } = useFetch<Unit[]>(scope ? `/org/units?parent_id=${scope.id}` : null)
  return (
    <select id={id} className="input" required value={value} onChange={(e) => onChange(e.target.value)}>
      <option value="">Choose…</option>
      {scope && <option value={scope.id}>{scope.name} (whole area)</option>}
      {units?.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
    </select>
  )
}

export function VibhagPicker({ id, value, onChange, required }: { id: string; value: string; onChange: (v: string) => void; required?: boolean }) {
  const { data } = useFetch<{ id: number; name: string }[]>('/vibhags')
  return (
    <select id={id} className="input" value={value} required={required} onChange={(e) => onChange(e.target.value)}>
      <option value="">{required ? 'Choose…' : 'All Vibhags'}</option>
      {data?.map((v) => <option key={v.id} value={v.id}>{v.name}</option>)}
    </select>
  )
}
