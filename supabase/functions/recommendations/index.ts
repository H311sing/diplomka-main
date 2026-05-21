// Supabase Edge Function — AI nutrition & workout recommendations.
//
// Reads the signed-in user's profile and recent logs, sends them to
// Google Gemini, and returns personalised tips as JSON. The Gemini key
// lives server-side (GEMINI_API_KEY), never in the app.
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

// deno-lint-ignore no-explicit-any
const sum = (arr: any[], k: string) =>
  arr.reduce((s, m) => s + (Number(m[k]) || 0), 0);

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

    const today = new Date().toISOString().split("T")[0];
    const weekAgo =
      new Date(Date.now() - 6 * 864e5).toISOString().split("T")[0];

    const [profileRes, mealsRes, exRes, workoutsRes] = await Promise.all([
      supabase.from("profiles")
        .select("full_name, weight, height, age").eq("id", user.id)
        .maybeSingle(),
      supabase.from("nutrition_logs")
        .select("meal_name, calories, protein, carbs, fat")
        .eq("user_id", user.id).eq("meal_date", today),
      supabase.from("workout_exercises")
        .select("name, muscle_group, is_done").eq("user_id", user.id),
      supabase.from("workout_logs")
        .select("name, duration_minutes, calories_burned")
        .eq("user_id", user.id).gte("workout_date", weekAgo),
    ]);

    // deno-lint-ignore no-explicit-any
    const p: any = profileRes.data ?? {};
    const meals = mealsRes.data ?? [];
    const exercises = exRes.data ?? [];
    const workouts = workoutsRes.data ?? [];

    const intake = {
      calories: sum(meals, "calories"),
      protein: sum(meals, "protein"),
      carbs: sum(meals, "carbs"),
      fat: sum(meals, "fat"),
    };

    let bmi: number | null = null;
    if (p.weight && p.height) {
      const h = Number(p.height) / 100;
      bmi = +(Number(p.weight) / (h * h)).toFixed(1);
    }

    const profileText = [
      p.weight ? `вес ${p.weight} кг` : null,
      p.height ? `рост ${p.height} см` : null,
      p.age ? `возраст ${p.age}` : null,
      bmi ? `ИМТ ${bmi}` : null,
    ].filter(Boolean).join(", ") || "профиль не заполнен";

    const planText = exercises.length
      // deno-lint-ignore no-explicit-any
      ? exercises.map((e: any) =>
        `${e.name} (${e.muscle_group}${e.is_done ? ", сделано" : ""})`
      ).join("; ")
      : "пусто";

    const prompt =
`Ты — опытный фитнес-тренер и нутрициолог. На основе данных пользователя дай персональные рекомендации на сегодня.
Профиль: ${profileText}.
Съедено сегодня: ${intake.calories} ккал, белки ${intake.protein} г, углеводы ${intake.carbs} г, жиры ${intake.fat} г.
Тренировок за последнюю неделю: ${workouts.length}.
План упражнений: ${planText}.

Верни СТРОГО валидный JSON по схеме (без markdown, без пояснений вокруг):
{"summary":"одно короткое предложение-вывод о состоянии пользователя",
 "nutrition":[{"title":"короткий заголовок","detail":"конкретный совет"}],
 "exercises":[{"title":"короткий заголовок","detail":"конкретный совет"}]}
Дай ровно 3 совета по питанию и 3 по тренировкам. Пиши кратко и конкретно, по-русски.`;

    const geminiRes = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" +
        apiKey,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.7,
          },
        }),
      },
    );

    if (!geminiRes.ok) {
      return json({ error: "gemini_error", detail: await geminiRes.text() }, 502);
    }

    const gj = await geminiRes.json();
    const text = gj?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    // deno-lint-ignore no-explicit-any
    let parsed: any;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = { summary: "", nutrition: [], exercises: [] };
    }

    return json(parsed, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
