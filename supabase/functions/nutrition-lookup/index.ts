// Supabase Edge Function — nutrition lookup via Gemini.
//
// Takes a food name (e.g. "куриная грудка 200 г"), asks Gemini for
// approximate calories and macronutrients, returns structured JSON.
// Uses the same GEMINI_API_KEY env var as the recommendations function.
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
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return json({ error: "GEMINI_API_KEY is not set" }, 500);

    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const name = (body?.name as string | undefined)?.trim();
    if (!name) return json({ error: "missing 'name' field" }, 400);

    const prompt =
`Ты — нутрициолог. Оцени средние пищевые показатели для следующего блюда или продукта:
"${name}"

Если в названии не указана масса/порция — считай 1 стандартную порцию (~100 г для большинства продуктов; для готовых блюд — типичную порцию).

Верни СТРОГО валидный JSON, без markdown, без пояснений:
{"calories":<int>,"protein":<int>,"carbs":<int>,"fat":<int>}

Все значения — целые числа в граммах (для калорий — ккал). Если блюдо не распознано или это не еда, верни {"calories":0,"protein":0,"carbs":0,"fat":0}.`;

    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const reqBody = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: "application/json",
        temperature: 0.2,
      },
    });

    // Same retry policy as recommendations: 3 attempts on 503/429.
    let geminiRes: Response | null = null;
    for (let attempt = 0; attempt < 3; attempt++) {
      geminiRes = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: reqBody,
      });
      if (geminiRes.ok) break;
      if (
        (geminiRes.status === 503 || geminiRes.status === 429) && attempt < 2
      ) {
        await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
        continue;
      }
      break;
    }

    if (!geminiRes || !geminiRes.ok) {
      const detail = geminiRes ? await geminiRes.text() : "no response";
      console.error("Gemini error:", geminiRes?.status, detail);
      return json(
        { error: "gemini_error", status: geminiRes?.status ?? 0, detail },
        502,
      );
    }

    const gj = await geminiRes.json();
    const text = gj?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    // deno-lint-ignore no-explicit-any
    let parsed: any;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = { calories: 0, protein: 0, carbs: 0, fat: 0 };
    }

    // Coerce to integers, clamp to non-negative.
    const out = {
      calories: Math.max(0, Math.round(Number(parsed.calories) || 0)),
      protein: Math.max(0, Math.round(Number(parsed.protein) || 0)),
      carbs: Math.max(0, Math.round(Number(parsed.carbs) || 0)),
      fat: Math.max(0, Math.round(Number(parsed.fat) || 0)),
    };

    return json(out, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
