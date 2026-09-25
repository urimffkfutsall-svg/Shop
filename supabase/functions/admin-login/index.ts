import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const { username, password } = await req.json()
    const expectedUser = Deno.env.get('ADMIN_USERNAME')
    const expectedPassword = Deno.env.get('ADMIN_LOGIN_PASSWORD')
    if (!expectedUser || !expectedPassword || username !== expectedUser || password !== expectedPassword) {
      return new Response(JSON.stringify({ error: 'Invalid credentials' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } })
    }

    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const authEmail = Deno.env.get('ADMIN_AUTH_EMAIL')!
    const authPassword = Deno.env.get('ADMIN_AUTH_PASSWORD')!
    const supabase = createClient(url, anon)
    const { data, error } = await supabase.auth.signInWithPassword({ email: authEmail, password: authPassword })
    if (error || !data.session) throw error ?? new Error('Session not created')

    return new Response(JSON.stringify({ access_token: data.session.access_token, refresh_token: data.session.refresh_token, expires_at: data.session.expires_at }), { headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (error) {
    return new Response(JSON.stringify({ error: error?.message ?? 'Login failed' }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } })
  }
})
