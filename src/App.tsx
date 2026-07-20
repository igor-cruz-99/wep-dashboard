import { Dashboard } from './pages/Dashboard'
import { Login } from './pages/Login'
import { useAuth } from './hooks/useAuth'
import { supabaseAuth } from './lib/supabase'

function Loader() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <span className="inline-block h-5 w-5 animate-spin rounded-full border-2 border-line border-t-gold" />
    </div>
  )
}

function App() {
  const { session, loading } = useAuth()

  const logout = () => supabaseAuth?.auth.signOut()

  if (loading) return <Loader />
  if (!session) return <Login />

  // Projeto de auth contém só os funcionários → logado = autorizado.
  return <Dashboard userEmail={session.user.email ?? undefined} onLogout={logout} />
}

export default App
