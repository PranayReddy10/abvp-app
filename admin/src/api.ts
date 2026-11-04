// Thin client for the ABVP Connect API. Every response uses
// { success, data, meta } or { success: false, error: { code, message } }.

const BASE = (import.meta.env.VITE_API_URL ?? 'http://localhost:8000/api/v1').replace(/\/$/, '')
const TOKEN_KEY = 'abvp.admin.token'

export class ApiError extends Error {
  code: string
  status: number
  fields?: Record<string, string[]>
  /** The whole response body, for errors that carry extra detail (e.g. duty clashes). */
  body?: Record<string, unknown>
  constructor(status: number, code: string, message: string, fields?: Record<string, string[]>, body?: Record<string, unknown>) {
    super(message)
    this.status = status
    this.code = code
    this.fields = fields
    this.body = body
  }
}

export const token = {
  get: (): string | null => { try { return localStorage.getItem(TOKEN_KEY) } catch { return null } },
  set: (t: string) => { try { localStorage.setItem(TOKEN_KEY, t) } catch { /* private mode */ } },
  clear: () => { try { localStorage.removeItem(TOKEN_KEY) } catch { /* private mode */ } },
}

export interface Envelope<T> { data: T; meta: Record<string, unknown> }

export async function request<T>(method: string, path: string, body?: unknown): Promise<Envelope<T>> {
  const headers: Record<string, string> = { Accept: 'application/json' }
  const t = token.get()
  if (t) headers.Authorization = `Bearer ${t}`
  const isForm = body instanceof FormData
  if (body !== undefined && !isForm) headers['Content-Type'] = 'application/json'

  let res: Response
  try {
    res = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : isForm ? body : JSON.stringify(body) })
  } catch {
    throw new ApiError(0, 'NETWORK', 'Cannot reach the server. Check your connection and try again.')
  }

  const json = await res.json().catch(() => null)
  if (!res.ok || !json?.success) {
    if (res.status === 401) {
      token.clear()
      window.dispatchEvent(new Event('abvp:signed-out'))
    }
    const err = json?.error ?? {}
    throw new ApiError(res.status, err.code ?? `HTTP_${res.status}`, err.message ?? 'Request failed.', err.fields, json ?? undefined)
  }
  return { data: json.data as T, meta: json.meta ?? {} }
}

export const api = {
  get: <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body: unknown = {}) => request<T>('POST', path, body),
  patch: <T>(path: string, body: unknown) => request<T>('PATCH', path, body),
  del: <T>(path: string) => request<T>('DELETE', path),
}

export function qs(params: Record<string, string | number | undefined | null>): string {
  const p = new URLSearchParams()
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== '') p.set(k, String(v))
  const s = p.toString()
  return s ? `?${s}` : ''
}
