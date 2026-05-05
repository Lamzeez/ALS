import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Initialize Supabase Client with SERVICE ROLE KEY
    // This allows creating users without email confirmation and without session conflicts
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('ADMIN_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    )

    const { registration_id } = await req.json()

    // 2. Fetch registration details
    const { data: reg, error: fetchError } = await supabaseAdmin
      .from('als_center_registrations')
      .select('*')
      .eq('id', registration_id)
      .single()

    if (fetchError || !reg) throw new Error('Registration not found')
    if (reg.status !== 'pending') throw new Error('Request already processed')

    // 3. Create the Center Admin user in Supabase Auth
    const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: reg.admin_email,
      password: reg.admin_password,
      email_confirm: true, // Auto-confirm the email
      user_metadata: {
        full_name: reg.admin_full_name,
        role: 'center_admin',
      }
    })

    if (authError || !authUser.user) throw authError

    // 4. Call our SQL function to create the ALS Center record
    const { error: rpcError } = await supabaseAdmin.rpc('approve_center_registration', {
      p_registration_id: registration_id
    })

    if (rpcError) throw rpcError

    // 5. Get the newly created center ID
    const { data: center, error: centerError } = await supabaseAdmin
      .from('als_centers')
      .select('id')
      .eq('registration_id', registration_id)
      .single()

    if (centerError) throw centerError

    // 6. Link the user to the center in the profiles table
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .update({
        als_center_id: center.id,
        role: 'center_admin',
        is_active: true,
        approval_status: 'approved'
      })
      .eq('id', authUser.user.id)

    if (profileError) throw profileError

    // 7. Cleanup: Clear the temporary password for security
    await supabaseAdmin
      .from('als_center_registrations')
      .update({ admin_password: null })
      .eq('id', registration_id)

    return new Response(
      JSON.stringify({ success: true, message: 'Center and Admin account created successfully.' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
