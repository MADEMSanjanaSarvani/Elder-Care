import { requireAdmin, requireScope } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { approveAiInteraction, rejectAiInteraction } from "@/actions/aiReviewActions";

export default async function AiReviewQueuePage() {
  const admin = await requireAdmin();
  requireScope(admin, "ops_admin");

  const supabase = await createClient();
  const { data: interactions, error } = await supabase
    .from("ai_interactions")
    .select("*, elder_profiles(display_name)")
    .eq("flagged", true)
    .eq("human_reviewed", false)
    .order("created_at", { ascending: true });

  return (
    <div>
      <h1 className="mb-1 text-2xl font-semibold">AI review queue</h1>
      <p className="mb-6 text-sm text-muted">
        Outputs the guardrail (PRD Part 2 §14) flagged as possibly containing a diagnosis or dosage instruction.
        Nothing here has reached a family member yet.
      </p>

      {error && <p className="text-sos">{error.message}</p>}
      {interactions?.length === 0 && <p className="text-sm text-muted">Nothing pending review.</p>}

      <div className="flex flex-col gap-4">
        {interactions?.map((interaction) => (
          <div key={interaction.id} className="rounded border border-warning/40 bg-warning/5 p-5">
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="font-medium">
                {(interaction.elder_profiles as unknown as { display_name: string } | null)?.display_name} ·{" "}
                {interaction.interaction_type}
              </span>
              <span className="text-muted">{new Date(interaction.created_at).toLocaleString()}</span>
            </div>
            <div className="mb-4 whitespace-pre-wrap rounded bg-paper-raised p-3 text-sm">
              {interaction.output_text}
            </div>
            <div className="flex gap-2">
              <form action={approveAiInteraction}>
                <input type="hidden" name="interaction_id" value={interaction.id} />
                <button type="submit" className="rounded bg-verified px-3 py-1.5 text-sm font-medium text-white">
                  Approve & deliver
                </button>
              </form>
              <form action={rejectAiInteraction}>
                <input type="hidden" name="interaction_id" value={interaction.id} />
                <button type="submit" className="rounded border border-sos px-3 py-1.5 text-sm font-medium text-sos">
                  Reject
                </button>
              </form>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
