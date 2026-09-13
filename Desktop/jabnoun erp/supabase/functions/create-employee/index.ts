// Edge Function: create-employee
// Crée un utilisateur Auth Supabase puis la ligne `employees` correspondante.
// Doit être appelée uniquement par un administrateur connecté (vérifié via
// le JWT de la requête). Utilise la clé service_role côté serveur — ne
// jamais exposer cette clé côté client.

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
        JSON.stringify({ error: "Seul un administrateur peut créer un employé." }),
        { status: 403 },
      );
    }

    const body = await req.json();
    const { full_name, email, password, role, phone, depot_id, showroom_id } = body;

    if (!full_name || !email || !password) {
      return new Response(JSON.stringify({ error: "Champs obligatoires manquants." }), { status: 400 });
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (createError || !created.user) {
      return new Response(
        JSON.stringify({ error: createError?.message ?? "Impossible de créer le compte." }),
        { status: 400 },
      );
    }

    const { error: insertError } = await admin.from("employees").insert({
      id: created.user.id,
      full_name,
      email,
      phone: phone ?? null,
      role: role ?? "employee",
      depot_id: depot_id ?? null,
      showroom_id: showroom_id ?? null,
      active: true,
    });

    if (insertError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return new Response(JSON.stringify({ error: insertError.message }), { status: 400 });
    }

    return new Response(JSON.stringify({ id: created.user.id }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
