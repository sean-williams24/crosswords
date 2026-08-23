import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const authorization = request.headers.get("Authorization") ?? "";
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } }
  });
  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  // Keep the Apple transaction record but remove its association; a verified
  // purchaser can claim it again after creating a new Backword account.
  await admin
    .from("user_entitlements")
    .update({ user_id: null, app_account_token: null })
    .eq("user_id", user.id);
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) return new Response(error.message, { status: 400, headers: corsHeaders });
  return Response.json({ ok: true }, { headers: corsHeaders });
});
