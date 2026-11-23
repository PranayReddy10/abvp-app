import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './auth'
import Layout from './components/Layout'
import { Login, Signup } from './pages/Auth'
import Community from './pages/Community'
import Delegate from './pages/Delegate'
import { GuideHub, GuideSection } from './pages/Guide'
import Home from './pages/Home'
import Me from './pages/Me'
import Profile from './pages/Profile'
import { EventPage, Events } from './pages/Events'
import Support from './pages/Support'
import './styles.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route element={<Layout />}>
            <Route index element={<Home />} />
            <Route path="guide/:id" element={<GuideHub />} />
            <Route path="guide/:id/:kind" element={<GuideSection />} />
            <Route path="conference/:id/register" element={<Delegate />} />
            <Route path="support/:id" element={<Support />} />
            <Route path="community" element={<Community />} />
            <Route path="events" element={<Events />} />
            <Route path="events/:id" element={<EventPage />} />
            <Route path="me" element={<Me />} />
            <Route path="me/edit" element={<Profile />} />
            <Route path="login" element={<Login />} />
            <Route path="signup" element={<Signup />} />
            <Route path="*" element={<Home />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  </StrictMode>,
)
