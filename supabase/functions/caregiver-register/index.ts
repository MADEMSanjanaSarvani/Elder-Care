// POST /functions/v1/caregiver-register
//
// Caregiver self-onboarding. Creates (or updates) the caller's caregiver
// record from a professional application and files it for admin verification.
// The caregiver is created INACTIVE (active=false, bgv 'not_started',
// probationary tier) — an admin activates it after checks, exactly like the
// existing ops-created path. Runs with the service role because it spans
// profiles + caregivers + profile details + application details, each with
// their own RLS.
import { supabaseAdmin, requireUser } from "../_shared/supabaseAdmin.ts";
import { corsHeaders, jsonResponse, errorResponse } from "../_shared/cors.ts";

const SUB_ROLES = [
  "nurse", "physiotherapist", "hospital_attendant", "companion",
  "home_service_maid", "home_service_electrician", "home_service_plumber",
  "home_service_general",
];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const user = await requireUser(req);
    const b = await req.json().catch(() => ({}));

    const fullName = (b.full_name ?? "").toString().trim();
    if (!fullName) return errorResponse("Your full name is required", 400);

    const caregiverType = b.caregiver_type === "clinical" ? "clinical" : "non_clinical";
    const subRole = SUB_ROLES.includes(b.sub_role) ? b.sub_role : "companion";
    const councilRegNo = (b.professional_council_reg_no ?? "").toString().trim() || null;
    if (caregiverType === "clinical" && !councilRegNo) {
      return errorResponse(
        "Clinical roles need a professional council registration number", 400);
    }

    const regionCode = (b.region_code ?? "vizag-ap-in").toString();
    const admin = supabaseAdmin();

    // Profile (caregiver role) — self-heal / set the name.
    await admin.from("profiles").upsert(
      { id: user.id, role: "caregiver", phone: user.phone ?? null, display_name: fullName },
      { onConflict: "id" },
    );

    const { data: region, error: regionErr } = await admin
      .from("regions").select("id").eq("code", regionCode).maybeSingle();
    if (regionErr) return errorResponse(regionErr.message, 500);
    if (!region) return errorResponse(`Unknown region: ${regionCode}`, 400);

    // Reuse an existing caregiver row (re-application) or create a new one,
    // always inactive and unverified — an admin activates it.
    const { data: existing } = await admin
      .from("caregivers").select("id").eq("user_id", user.id).maybeSingle();

    let caregiverId: string;
    if (existing) {
      caregiverId = existing.id;
      await admin.from("caregivers").update({
        caregiver_type: caregiverType,
        sub_role: subRole,
        professional_council_reg_no: councilRegNo,
      }).eq("id", caregiverId);
    } else {
      const { data: created, error: cErr } = await admin
        .from("caregivers").insert({
          region_id: region.id,
          user_id: user.id,
          caregiver_type: caregiverType,
          sub_role: subRole,
          bgv_status: "not_started",
          police_verification_status: "not_started",
          trust_tier: "probationary",
          active: false,
          insurance_on_file: false,
          professional_council_reg_no: councilRegNo,
        }).select("id").single();
      if (cErr) return errorResponse(cErr.message, 500);
      caregiverId = created.id;
    }

    const bio = (b.bio ?? "").toString().trim() || null;
    const serviceRadius = b.service_radius_km != null ? Number(b.service_radius_km) : null;
    const latitude = b.latitude != null ? Number(b.latitude) : null;
    const longitude = b.longitude != null ? Number(b.longitude) : null;
    await admin.from("caregiver_profile_details").upsert(
      {
        caregiver_id: caregiverId,
        bio,
        service_radius_km: serviceRadius,
        // Base location so families can find this caregiver by distance.
        ...(latitude != null && longitude != null ? { latitude, longitude } : {}),
      },
      { onConflict: "caregiver_id" },
    );

    const toArray = (v: unknown): string[] =>
      Array.isArray(v) ? v.map((x) => String(x)).filter((x) => x.length > 0) : [];

    const { error: appErr } = await admin.from("caregiver_application_details").upsert({
      caregiver_id: caregiverId,
      date_of_birth: b.date_of_birth ? String(b.date_of_birth) : null,
      gender: b.gender ? String(b.gender) : null,
      address: b.address ?? {},
      government_id: b.government_id ? String(b.government_id) : null,
      qualification: b.qualification ? String(b.qualification) : null,
      experience_years: b.experience_years != null ? Number(b.experience_years) : null,
      certifications: b.certifications ? String(b.certifications) : null,
      languages: toArray(b.languages),
      skills: toArray(b.skills),
      preferred_hours: b.preferred_hours ? String(b.preferred_hours) : null,
      expected_charge: b.expected_charge != null ? Number(b.expected_charge) : null,
      emergency_contact_name: b.emergency_contact_name ? String(b.emergency_contact_name) : null,
      emergency_contact_phone: b.emergency_contact_phone ? String(b.emergency_contact_phone) : null,
      updated_at: new Date().toISOString(),
    }, { onConflict: "caregiver_id" });
    if (appErr) return errorResponse(appErr.message, 500);

    // Notify verification agents that a new application is waiting.
    const { data: agents } = await admin
      .from("admin_scopes").select("profile_id")
      .in("scope", ["verification_agent", "super_admin"]);
    if (agents?.length) {
      await admin.from("notifications").insert(
        agents.map((a) => ({
          user_id: a.profile_id,
          type: "caregiver_application_submitted",
          payload: { caregiver_id: caregiverId },
        })),
      );
    }

    await admin.from("audit_log").insert({
      actor_user_id: user.id,
      action: "write",
      resource_type: "caregiver",
      resource_id: caregiverId,
      metadata: { event: "self_registration" },
    });

    return jsonResponse({ caregiver_id: caregiverId, status: "pending_review" }, 201);
  } catch (err) {
    return errorResponse((err as Error).message, 401);
  }
});
