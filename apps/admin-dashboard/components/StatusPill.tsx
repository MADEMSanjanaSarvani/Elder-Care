const TONE_CLASSES: Record<"neutral" | "good" | "warning" | "critical", string> = {
  neutral: "bg-paper-raised text-muted border-border",
  good: "bg-verified/10 text-verified border-verified/30",
  warning: "bg-warning/10 text-warning border-warning/30",
  critical: "bg-sos/10 text-sos border-sos/30",
};

/**
 * Semantic status color, deliberately distinct from the accent color used
 * for primary actions elsewhere — this dashboard is scanned, not read, so
 * state needs to register before the label does.
 */
export function StatusPill({ label, tone }: { label: string; tone: "neutral" | "good" | "warning" | "critical" }) {
  return (
    <span className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium ${TONE_CLASSES[tone]}`}>
      {label}
    </span>
  );
}
