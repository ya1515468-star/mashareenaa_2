import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "npm:@supabase/supabase-js/cors";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const secretKeysRaw = Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}";
const secretKeys = JSON.parse(secretKeysRaw);
const secretKey = secretKeys["default"] ?? "";
if (!supabaseUrl || !secretKey) throw new Error("Missing Supabase server environment variables");

const supabaseAdmin = createClient(supabaseUrl, secretKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getClientIp(req: Request): string | null {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim();
    if (first) return first;
  }
  return req.headers.get("x-real-ip")?.trim() || null;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

const SIGNAL_RISK: Record<string, number> = {
  app_tamper_detected: 35,
  integrity_mismatch: 35,
  replayed_request: 25,
  impossible_state: 25,
  auth_anomaly: 20,
  automation_suspected: 15,
  debugger_detected: 10,
  emulator_detected: 5,
  rate_limit_triggered: 10,
  session_anomaly: 15,
};

const SIGNAL_SEVERITY: Record<string, string> = {
  app_tamper_detected: "critical",
  integrity_mismatch: "critical",
  replayed_request: "fatal",
  impossible_state: "fatal",
  auth_anomaly: "error",
  automation_suspected: "error",
  debugger_detected: "warning",
  emulator_detected: "warning",
  rate_limit_triggered: "warning",
  session_anomaly: "error",
};

function normalizeText(value: unknown, max: number): string | null {
  const text = value?.toString().trim();
  return text ? text.slice(0, max) : null;
}

async function readBody(req: Request): Promise<Record<string, unknown>> {
  try {
    if ((req.headers.get("content-type") ?? "").includes("application/json")) {
      const value = await req.json();
      return value && typeof value === "object"
        ? value as Record<string, unknown>
        : {};
    }
  } catch (_) {}
  return {};
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json({ error: "AUTH_REQUIRED" }, 401);
  }

  const accessToken = authorization.substring("Bearer ".length).trim();
  const body = await readBody(req);

  const supabaseUser = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: { Authorization: "Bearer " + accessToken },
      },
      auth: { autoRefreshToken: false, persistSession: false },
    },
  );

  const { data: { user }, error: userError } =
    await supabaseUser.auth.getUser();

  if (userError || !user) return json({ error: "INVALID_SESSION" }, 401);

  const ip = getClientIp(req);
  const ipHash = ip ? await sha256(ip) : null;
  const eventType = normalizeText(body.event_type, 64);
  const screen = normalizeText(body.screen, 120);
  const appVersion = normalizeText(body.app_version, 40);
  const details = normalizeText(body.details, 1200);
  const deviceIdHash = normalizeText(body.device_id_hash, 128);
  const sessionIdHash = normalizeText(body.session_id_hash, 128);
  const riskDelta = eventType ? SIGNAL_RISK[eventType] ?? 0 : 0;
  const eventSeverity = eventType
    ? SIGNAL_SEVERITY[eventType] ?? "warning"
    : "warning";

  const { data: currentIdentity, error: identityError } =
    await supabaseAdmin
      .from("user_security_identity")
      .select("risk_score")
      .eq("user_id", user.id)
      .maybeSingle();

  if (identityError) return json({ error: "IDENTITY_LOOKUP_FAILED" }, 500);

  const currentScore = Math.max(
    0,
    Math.min(100, Number(currentIdentity?.risk_score ?? 0)),
  );
  const nextScore = Math.max(0, Math.min(100, currentScore + riskDelta));
  const riskState =
    nextScore >= 80
      ? "critical"
      : nextScore >= 60
        ? "high"
        : nextScore >= 35
          ? "elevated"
          : "normal";
  const now = new Date().toISOString();

  const { error: updateError } = await supabaseAdmin
    .from("user_security_identity")
    .upsert({
      user_id: user.id,
      last_ip_hash: ipHash,
      device_id_hash: deviceIdHash,
      session_id_hash: sessionIdHash,
      last_seen_at: now,
      updated_at: now,
      risk_score: nextScore,
      risk_state: riskState,
    }, { onConflict: "user_id" });

  if (updateError) return json({ error: "IDENTITY_UPDATE_FAILED" }, 500);

  if (eventType && riskDelta > 0) {
    const evidence = {
      source: "security-risk",
      signal: eventType,
      screen,
      app_version: appVersion,
      details,
      ip_hash: ipHash,
      device_id_hash: deviceIdHash,
      session_id_hash: sessionIdHash,
    };
    const eventKey = await sha256(
      user.id + ":" + eventType + ":" + (screen ?? "") + ":" +
      (appVersion ?? "") + ":" + new Date().toISOString().slice(0, 16),
    );

    await supabaseAdmin.from("security_events").insert({
      user_id: user.id,
      event_type: eventType,
      severity: eventSeverity,
      description: details ?? ("Security signal: " + eventType),
      metadata: {
        ...evidence,
        risk_score_before: currentScore,
        risk_score_after: nextScore,
        alert_key: eventKey,
      },
      user_agent: req.headers.get("user-agent")?.slice(0, 800) ?? null,
      resolved: false,
    });

    await supabaseAdmin.from("security_alerts").upsert({
      alert_key: "security-risk:" + eventKey,
      event_type: eventType,
      severity: eventSeverity,
      user_id: user.id,
      risk_score_before: currentScore,
      risk_score_after: nextScore,
      source: "security-risk",
      ip_hash: ipHash,
      device_id_hash: deviceIdHash,
      session_id_hash: sessionIdHash,
      evidence,
      state: "open",
      created_at: now,
    }, { onConflict: "alert_key", ignoreDuplicates: true });

    if (nextScore >= 80) {
      await supabaseAdmin.from("audit_logs").insert({
        action: "security_risk_threshold_crossed",
        resource_type: "user_security_identity",
        resource_id: user.id,
        target_id: user.id,
        request_id: crypto.randomUUID(),
        result: "critical",
        metadata: {
          risk_score_before: currentScore,
          risk_score_after: nextScore,
          event_type: eventType,
        },
        created_at: now,
      });
    }
  }

  return json({
    ok: true,
    ip_recorded: Boolean(ipHash),
    event_recorded: Boolean(eventType && riskDelta > 0),
    risk_state: riskState,
  });
});
