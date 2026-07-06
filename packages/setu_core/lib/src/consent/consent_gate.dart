import 'consent_category.dart';
import 'consent_grant.dart';

/// Client-side mirror of the Postgres `has_consent()` function (PRD Part 2
/// §13) — for UI purposes only. It decides whether to *show* a control
/// (e.g. the medication-list tab); it is never the actual security
/// boundary. The real enforcement is the RLS policy on the server, which
/// re-checks this independently and will simply return no rows (or a 403
/// from an Edge Function) regardless of what the client believes.
class ConsentGate {
  ConsentGate(List<ConsentGrant> grants)
      : _activeCategories = grants.where((g) => g.isActive).map((g) => g.category).toSet();

  final Set<ConsentCategory> _activeCategories;

  bool canView(ConsentCategory category) => _activeCategories.contains(category);
}
