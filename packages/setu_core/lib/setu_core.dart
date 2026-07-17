/// Shared core for Project Setu's Flutter apps.
///
/// See docs/prd/03-prd-part3-execution.html Section 18 for why this exists
/// as one package rather than duplicated code in each app.
library setu_core;

export 'src/region/region.dart';
export 'src/region/region_config_client.dart';

export 'src/consent/consent_category.dart';
export 'src/consent/consent_grant.dart';
export 'src/consent/consent_gate.dart';

export 'src/supabase/setu_supabase_client.dart';

export 'src/routing/go_router_refresh_stream.dart';

export 'src/design/design_tokens.dart';
export 'src/design/ui_helpers.dart';

export 'src/models/elder_profile.dart';
export 'src/models/caregiver.dart';
export 'src/models/service.dart';
export 'src/models/booking.dart';
export 'src/models/family_link.dart';
