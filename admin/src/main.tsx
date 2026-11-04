import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './auth'
import Layout from './components/Layout'
import Analytics from './pages/Analytics'
import Approvals from './pages/Approvals'
import Circulars from './pages/Circulars'
import EventDetail from './pages/EventDetail'
import Events from './pages/Events'
import Meetings from './pages/Meetings'
import Reports from './pages/Reports'
import VibhagUpdates from './pages/VibhagUpdates'
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
        <Route path="analytics" element={<Analytics />} />
        <Route path="meetings" element={<Meetings />} />
        <Route path="events" element={<Events />} />
        <Route path="events/:id" element={<EventDetail />} />
        <Route path="circulars" element={<Circulars />} />
        <Route path="reports" element={<Reports />} />
        <Route path="updates" element={<VibhagUpdates />} />
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
