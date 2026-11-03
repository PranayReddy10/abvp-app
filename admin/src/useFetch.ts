import { useCallback, useEffect, useState } from 'react'
import { api } from './api'

/** GET a path; re-runs when the path changes. */
export function useFetch<T>(path: string | null) {
  const [data, setData] = useState<T | null>(null)
  const [meta, setMeta] = useState<Record<string, unknown>>({})
  const [error, setError] = useState<unknown>(null)
  const [loading, setLoading] = useState(!!path)

  const load = useCallback(async () => {
    if (!path) return
    setLoading(true)
    try {
      const r = await api.get<T>(path)
      setData(r.data)
      setMeta(r.meta)
      setError(null)
    } catch (e) {
      setError(e)
    } finally {
      setLoading(false)
    }
  }, [path])

  useEffect(() => { load() }, [load])

  return { data, meta, error, loading, reload: load }
}
