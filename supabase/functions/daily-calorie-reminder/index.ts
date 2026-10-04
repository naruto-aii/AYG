import { handleDailyReminder, liveReminderDeps } from "../_shared/daily_calorie_reminder.ts";

Deno.serve((req) => {
  return handleDailyReminder(
    req,
    liveReminderDeps({
      env: Deno.env.toObject(),
      now: () => new Date(),
    }),
  ).catch(() => {
    console.error("daily-calorie-reminder failed");
    return new Response(JSON.stringify({ ok: false }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  });
});
