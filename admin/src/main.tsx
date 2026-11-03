import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './auth'
import Layout from './components/Layout'
import Approvals from './pages/Approvals'
import AuditLog from './pages/AuditLog'
import Dashboard from './pages/Dashboard'
import Login from './pages/Login'
import Members from './pages/Members'
import Roles from './pages/Roles'
import Vibhags from './pages/Vibhags'
import './styles.css'

function App() {
  const { me, loading } = useAuth()
  if (loading) return <div className="login"><p className="muted">Loading…</p></div>
  if (!me) return <Login />

  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Dashboard />} />
        <Route path="approvals" element={<Approvals />} />
        <Route path="members" element={<Members />} />
        <Route path="vibhags" element={<Vibhags />} />
        <Route path="roles" element={<Roles />} />
        <Route path="audit" element={<AuditLog />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
)
