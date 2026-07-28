// POST /functions/v1/reminders-dispatch-sweep
//
// PRD Part 5, Batch 2, Module 8 (Smart Reminder System) — the single
// shared delivery engine Modules 5-7 all enqueue into. No user JWT —
// triggered externally (n8n/cron), shared-secret header, same pattern as
// checkins-escalation-sweep and medications-generate-doses.
//
// Delivery is two things, in this order, and the order matters.
//
// First an insert into `notifications`, which is the durable record — it
// survives a phone that was off, it fills the in-app inbox, and it is what the
// app reads when it opens.
//
// Then an actual FCM push, which is what reaches somebody whose phone is in
// their pocket. That second half did not exist until now: the app registered a
// device token into `user_devices` and nothing ever sent to it, so a reminder
// only appeared if the app happened to be open. For a medicine reminder that
// is indistinguishable from having no reminder at all.
//
// The push is fire-and-forget and never fails the sweep. A dose was still due
// whether or not Google accepted the message, and the row above is already
// written.
//
// SMS fallback remains unbuilt — real, named future work, not silently
// dropped.
//
// Also deviates on snooze-expiry: the PRD says the sweep must "skip
// anything snoozed," full stop — it doesn't describe re-surfacing a
// reminder once snoozed_until passes. This sweep does exactly what's
// specified (skip snoozed rows entirely) rather than invent a re-surface
// rule the PRD never stated; a snoozed reminder staying snoozed
// indefinitely is a real UX gap worth a follow-up decision, flagged here
// rather than solved by guessing.
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { sendPush } from "../_shared/fcm.ts";

const REMINDERS_SWEEP_SHARED_SECRET = Deno.env.get("REMINDERS_SWEEP_SHARED_SECRET")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const providedSecret = req.headers.get("x-reminders-sweep-secret");
  if (providedSecret !== REMINDERS_SWEEP_SHARED_SECRET) return errorResponse("Invalid credentials", 401);

  const admin = supabaseAdmin();
  const nowIso = new Date().toISOString();

  const { data: due, error } = await admin
    .from("reminders")
    .select("id, elder_id, source_type, source_id, recipient_scope")
    .eq("status", "pending")
    .lte("remind_at", nowIso);
  if (error) return errorResponse(error.message, 500);

  const results: Array<{ id: string; outcome: "sent" | "cancelled" | "skipped" }> = [];

  for (const reminder of due ?? []) {
    // Re-check the source still warrants sending — a medication stopped
    // or an appointment cancelled after its reminder was enqueued but
    // before the sweep runs must not fire a stale reminder (PRD §13).
    const stillWarranted = await sourceStillWarrantsReminder(admin, reminder.source_type, reminder.source_id);
    if (!stillWarranted) {
      await admin.from("reminders").update({ status: "cancelled" }).eq("id", reminder.id);
      results.push({ id: reminder.id, outcome: "cancelled" });
      continue;
    }

    const recipientIds = await resolveRecipients(admin, reminder.elder_id, reminder.recipient_scope);
    if (recipientIds.length === 0) {
      results.push({ id: reminder.id, outcome: "skipped" });
      continue;
    }

    const { error: notifyErr } = await admin.from("notifications").insert(
      recipientIds.map((uid) => ({
        user_id: uid,
        type: `reminder_${reminder.source_type}`,
        payload: { reminder_id: reminder.id, elder_id: reminder.elder_id, source_id: reminder.source_id },
      })),
    );
    if (notifyErr) {
      results.push({ id: reminder.id, outcome: "skipped" });
      continue;
    }

    // The words that actually land on a lock screen. Deliberately plain and
    // never alarming: this fires several times a day, every day, and a
    // reminder that reads like an emergency stops being read at all.
    const push = pushCopy(reminder.source_type);
    await sendPush(admin, recipientIds, {
      title: push.title,
      body: push.body,
      channelId: "carehive_reminders",
      data: {
        type: `reminder_${reminder.source_type}`,
        reminder_id: reminder.id,
        elder_id: reminder.elder_id,
        source_id: reminder.source_id,
      },
    });

    await admin.from("reminders").update({ status: "sent" }).eq("id", reminder.id);
    results.push({ id: reminder.id, outcome: "sent" });
  }

  return jsonResponse({ processed: results.length, results });
});

async function sourceStillWarrantsReminder(
  admin: ReturnType<typeof supabaseAdmin>,
  sourceType: string,
  sourceId: string,
): Promise<boolean> {
  if (sourceType === "medication_dose") {
    const { data } = await admin.from("medication_doses").select("status").eq("id", sourceId).maybeSingle();
    return data?.status === "pending";
  }
  if (sourceType === "appointment") {
    const { data } = await admin.from("appointments").select("status").eq("id", sourceId).maybeSingle();
    return data?.status === "scheduled";
  }
  if (sourceType === "hospital_stay_gap") {
    // A discharged or cancelled stay has no coverage to worry about; the
    // gap-sweep itself handles "gap since filled" by never re-enqueueing
    // while one is open, so active-stay status is the right staleness check.
    const { data } = await admin.from("hospital_stays").select("status").eq("id", sourceId).maybeSingle();
    return data?.status === "active";
  }
  // Unrecognized source_type — fail closed, same guardrail philosophy as
  // required_consent_for_source() treating an unknown type as "deny."
  return false;
}

function pushCopy(sourceType: string): { title: string; body: string } {
  switch (sourceType) {
    case "medication_dose":
      return {
        title: "Time for your medicine",
        body: "Tap to see which one, and to mark it taken.",
      };
    case "appointment":
      return {
        title: "Appointment coming up",
        body: "Tap for the time and place.",
      };
    case "hospital_stay":
      return {
        title: "Hospital stay needs attention",
        body: "Tap to review the details.",
      };
    default:
      return { title: "CareHive reminder", body: "Tap to see what's due." };
  }
}

async function resolveRecipients(
  admin: ReturnType<typeof supabaseAdmin>,
  elderId: string,
  recipientScope: string,
): Promise<string[]> {
  const recipientIds: string[] = [];

  if (recipientScope === "elder" || recipientScope === "both") {
    const { data: elder } = await admin.from("elder_profiles").select("auth_user_id").eq("id", elderId).maybeSingle();
    if (elder?.auth_user_id) recipientIds.push(elder.auth_user_id);
  }

  if (recipientScope === "family" || recipientScope === "both") {
    const { data: familyLinks } = await admin
      .from("family_links")
      .select("family_user_id")
      .eq("elder_id", elderId)
      .eq("status", "active");
    recipientIds.push(...(familyLinks ?? []).map((f) => f.family_user_id));
  }

  return recipientIds;
}
