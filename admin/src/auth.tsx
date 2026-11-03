import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import { api, token } from './api'
import type { Me } from './types'

interface AuthState {
  me: Me | null
  loading: boolean
  signIn: (token: string, me: Me) => void
  signOut: () => Promise<void>
  can: (permission: string) => boolean
}

const Ctx = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [me, setMe] = useState<Me | null>(null)
  const [loading, setLoading] = useState(!!token.get())

  useEffect(() => {
    if (!token.get()) return
    api.get<Me>('/auth/me').then((r) => setMe(r.data)).catch(() => setMe(null)).finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    const out = () => setMe(null)
    window.addEventListener('abvp:signed-out', out)
    return () => window.removeEventListener('abvp:signed-out', out)
  }, [])

  const signIn = useCallback((t: string, m: Me) => { token.set(t); setMe(m) }, [])
  const signOut = useCallback(async () => {
    try { await api.post('/auth/logout') } catch { /* token may already be gone */ }
    token.clear()
    setMe(null)
  }, [])
  const can = useCallback((p: string) => !!me?.permissions.includes(p), [me])

  return <Ctx.Provider value={{ me, loading, signIn, signOut, can }}>{children}</Ctx.Provider>
}

export function useAuth(): AuthState {
  const v = useContext(Ctx)
  if (!v) throw new Error('useAuth outside AuthProvider')
  return v
}
