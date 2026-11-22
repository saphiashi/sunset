// Deletes the calling user: revokes their Sign in with Apple token (when the app sends a
// fresh authorization code), deletes their rows, empties their Storage folder, then
// deletes the auth user.
//
// Secrets (supabase secrets set ...): APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID
// (the app's bundle ID), APPLE_PRIVATE_KEY (contents of the .p8 key).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const BUCKET = "sunset-photos";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function appleClientSecret(): Promise<{ clientID: string; secret: string } | null> {
  const teamID = Deno.env.get("APPLE_TEAM_ID");
  const keyID = Deno.env.get("APPLE_KEY_ID");
  const clientID = Deno.env.get("APPLE_CLIENT_ID");
  const pem = Deno.env.get("APPLE_PRIVATE_KEY");
  if (!teamID || !keyID || !clientID || !pem) return null;
  const key = await importPKCS8(pem.replace(/\\n/g, "\n"), "ES256");
  const secret = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyID })
    .setIssuer(teamID)
    .setSubject(clientID)
    .setAudience("https://appleid.apple.com")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
  return { clientID, secret };
}

async function revokeApple(authorizationCode: string): Promise<boolean> {
  const creds = await appleClientSecret();
  if (!creds) {
    console.warn("Apple secrets not set; skipping token revocation");
    return false;
  }
  const tokenResponse = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: creds.clientID,
      client_secret: creds.secret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenResponse.ok) {
    console.error("Apple token exchange failed", tokenResponse.status, await tokenResponse.text());
    return false;
  }
  const tokens = await tokenResponse.json();
  const token = tokens.refresh_token ?? tokens.access_token;
  const hint = tokens.refresh_token ? "refresh_token" : "access_token";
  const revokeResponse = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: creds.clientID,
      client_secret: creds.secret,
      token,
      token_type_hint: hint,
    }),
  });
  if (!revokeResponse.ok) {
    console.error("Apple revoke failed", revokeResponse.status, await revokeResponse.text());
  }
  return revokeResponse.ok;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: { user }, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !user) return json({ error: "not signed in" }, 401);

  const body = await req.json().catch(() => ({}));
  let appleRevoked = false;
  if (typeof body?.apple_authorization_code === "string") {
    try {
      appleRevoked = await revokeApple(body.apple_authorization_code);
    } catch (error) {
      console.error("Apple revoke threw", error);
    }
  }

  // Order matters: Supabase refuses to delete an auth user who still owns Storage objects,
  // so rows go first (cascading from profiles), then photos, then the auth user. A failure
  // at any step leaves nothing visible, and calling the function again finishes the job.
  const { error: rowsError } = await admin.from("profiles").delete().eq("id", user.id);
  if (rowsError) return json({ error: rowsError.message }, 500);

  const bucket = admin.storage.from(BUCKET);
  for (let round = 0; round < 50; round++) {
    const { data: files, error } = await bucket.list(user.id, { limit: 1000 });
    if (error) return json({ error: error.message }, 500);
    if (!files?.length) break;
    const { error: removeError } = await bucket.remove(files.map((f) => `${user.id}/${f.name}`));
    if (removeError) return json({ error: removeError.message }, 500);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return json({ error: deleteError.message }, 500);

  return json({ deleted: true, apple_revoked: appleRevoked });
});
