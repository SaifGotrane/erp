// Edge Function: reset-employee-password
// Permet à un administrateur de réinitialiser le mot de passe d'un employé.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Authentification requise." }), { status: 401 });
    }

    const callerClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Session invalide." }), { status: 401 });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: caller } = await admin
      .from("employees")
      .select("role, active")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (!caller || caller.role !== "admin" || !caller.active) {
      return new Response(
        JSON.stringify({ error: "Seul un administrateur peut réinitialiser un mot de passe." }),
        { status: 403 },
      );
    }

    const { employee_id, new_password } = await req.json();
    if (!employee_id || !new_password) {
      return new Response(JSON.stringify({ error: "Champs obligatoires manquants." }), { status: 400 });
    }

    const { error } = await admin.auth.admin.updateUserById(employee_id, { password: new_password });
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
