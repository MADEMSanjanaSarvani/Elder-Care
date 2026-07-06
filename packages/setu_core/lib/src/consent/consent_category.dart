/// Mirrors the Postgres `consent_category` enum (PRD Part 2 §11).
///
/// Kept as a closed set intentionally — adding a new sensitive-data
/// category should mean a deliberate schema + consent-copy change, not a
/// free-text string that can drift between client and database.
enum ConsentCategory {
  locationLive('location_live'),
  locationHistory('location_history'),
  healthNotes('health_notes'),
  medicationList('medication_list'),
  visitHistory('visit_history'),
  billing('billing');

  const ConsentCategory(this.wireValue);

  final String wireValue;

  static ConsentCategory fromWire(String value) {
    return ConsentCategory.values.firstWhere(
      (c) => c.wireValue == value,
      orElse: () => throw ArgumentError('Unknown consent category: $value'),
    );
  }
}
