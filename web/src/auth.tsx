import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import { api, token } from './api'
import type { Me } from './types'

interface AuthState {
  me: Me | null
  loading: boolean
  signIn: (t: string, me: Me) => void
  signOut: () => Promise<void>
  refresh: () => Promise<void>
}

const Ctx = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [me, setMe] = useState<Me | null>(null)
  const [loading, setLoading] = useState(!!token.get())

  const refresh = useCallback(async () => {
    if (!token.get()) { setMe(null); setLoading(false); return }
    try { setMe((await api.get<Me>('/auth/me')).data) } catch { setMe(null) } finally { setLoading(false) }
  }, [])

  useEffect(() => {
    refresh()
    const out = () => setMe(null)
    window.addEventListener('abvp-web:signed-out', out)
    return () => window.removeEventListener('abvp-web:signed-out', out)
  }, [refresh])

  const signIn = useCallback((t: string, m: Me) => { token.set(t); setMe(m) }, [])
  const signOut = useCallback(async () => {
    await api.post('/auth/logout').catch(() => null)
    token.clear()
    setMe(null)
  }, [])

  return <Ctx.Provider value={{ me, loading, signIn, signOut, refresh }}>{children}</Ctx.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthState {
  const c = useContext(Ctx)
  if (!c) throw new Error('AuthProvider missing')
  return c
}

/** Display name: profile name for members, sign-up name otherwise. */
// eslint-disable-next-line react-refresh/only-export-components
export const nameOf = (m: Me | null) => m?.profile?.full_name ?? m?.name ?? ''
