// Supabase Edge Function — admin actions over users.
// Verifies the caller is an admin (via public.is_current_user_admin),
// then uses the SERVICE_ROLE client to call auth.admin.* methods.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// deno-lint-ignore no-explicit-any
function json(obj: any, status: number) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1) User-scoped client to identify the caller and check their role.
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const { data: isAdminRow, error: adminCheckErr } = await userClient.rpc(
      "is_current_user_admin",
    );
    if (adminCheckErr) {
      return json({ error: "admin_check_failed", detail: adminCheckErr.message }, 500);
    }
    if (isAdminRow !== true) return json({ error: "forbidden" }, 403);

    // 2) Service-role client — has full auth admin powers.
    const admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const body = await req.json().catch(() => ({}));
    const action = body?.action as string | undefined;

    switch (action) {
      case "list": {
        // List up to 200 users (basic pagination would be added in a
        // real product — this is plenty for the diploma demo).
        const { data, error } = await admin.auth.admin.listUsers({
          page: 1,
          perPage: 200,
        });
        if (error) return json({ error: error.message }, 500);

        // Pull admin flags from profiles so the UI can show them.
        const ids = data.users.map((u) => u.id);
        const { data: profiles } = await admin
          .from("profiles")
          .select("id, full_name, is_admin")
          .in("id", ids);
        const profileMap = new Map<string, {full_name?: string; is_admin: boolean}>();
        for (const p of profiles ?? []) {
          profileMap.set(p.id as string, {
            full_name: p.full_name as string | undefined,
            is_admin: p.is_admin as boolean,
          });
        }

        return json({
          users: data.users.map((u) => ({
            id: u.id,
            email: u.email,
            full_name: profileMap.get(u.id)?.full_name ?? "",
            is_admin: profileMap.get(u.id)?.is_admin ?? false,
            created_at: u.created_at,
            last_sign_in_at: u.last_sign_in_at,
            // banned_until is on the auth user row.
            // deno-lint-ignore no-explicit-any
            banned_until: (u as any).banned_until ?? null,
          })),
        }, 200);
      }

      case "ban": {
        const id = body?.userId as string | undefined;
        const duration = (body?.duration as string | undefined) ?? "24h";
        if (!id) return json({ error: "missing userId" }, 400);
        if (id === user.id) {
          return json({ error: "cannot ban yourself" }, 400);
        }
        const { error } = await admin.auth.admin.updateUserById(id, {
          ban_duration: duration,
        });
        if (error) return json({ error: error.message }, 500);
        return json({ ok: true }, 200);
      }

      case "unban": {
        const id = body?.userId as string | undefined;
        if (!id) return json({ error: "missing userId" }, 400);
        const { error } = await admin.auth.admin.updateUserById(id, {
          ban_duration: "none",
        });
        if (error) return json({ error: error.message }, 500);
        return json({ ok: true }, 200);
      }

      case "delete": {
        const id = body?.userId as string | undefined;
        if (!id) return json({ error: "missing userId" }, 400);
        if (id === user.id) {
          return json({ error: "cannot delete yourself" }, 400);
        }
        const { error } = await admin.auth.admin.deleteUser(id);
        if (error) return json({ error: error.message }, 500);
        return json({ ok: true }, 200);
      }

      default:
        return json(
          { error: "unknown action — expected list / ban / unban / delete" },
          400,
        );
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
