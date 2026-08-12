import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (request) => {
  const url = Deno.env.get("SUPABASE_URL")!;
  const authorization = request.headers.get("Authorization") ?? "";
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } }
  });
  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) return new Response("Unauthorized", { status: 401 });

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  // Keep the Apple transaction record but remove its association; a verified
  // purchaser can claim it again after creating a new Backword account.
  await admin.from("user_entitlements").update({ user_id: null }).eq("user_id", user.id);
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) return new Response(error.message, { status: 400 });
  return Response.json({ ok: true });
});
