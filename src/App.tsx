import { Dashboard } from './pages/Dashboard'
import { Login } from './pages/Login'
import { useAuth } from './hooks/useAuth'
import { supabaseAuth } from './lib/supabase'
import { DEV_SKIP_AUTH } from './lib/devAuth'

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

  if (loading && !DEV_SKIP_AUTH) return <Loader />
  if (!session && !DEV_SKIP_AUTH) return <Login />

  // Projeto de auth contém só os funcionários → logado = autorizado.
  return <Dashboard userEmail={session?.user.email ?? undefined} onLogout={logout} />
}

export default App
