// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SETU';

  @override
  String get loginPhoneLabel => 'Phone number';

  @override
  String get loginSendCode => 'Send code';

  @override
  String get loginVerifyCode => 'Verify code';

  @override
  String loginCodeSentTo(String phone) {
    return 'We sent a code to $phone';
  }

  @override
  String get elderHomeCallForHelp => 'Call for Help';

  @override
  String get elderHomeBookHelp => 'Book Help';

  @override
  String get elderHomeTodaysVisit => 'Today\'s Visit';

  @override
  String get elderHomeNoVisitToday => 'No visit scheduled today';

  @override
  String get sosScreenTitle => 'Emergency';

  @override
  String get sosCall108 => 'Call 108 (Emergency)';

  @override
  String get sosNotifyPlatform => 'Also notify family & SETU';

  @override
  String get sosDisclaimer =>
      'Calling 108 is the fastest way to get emergency medical help. Notifying SETU alerts your family and our on-call team at the same time — it does not replace calling 108.';

  @override
  String get sosNotifiedConfirmation =>
      'Your family and our on-call team have been notified.';

  @override
  String get familyDashboardTitle => 'Family Dashboard';

  @override
  String get familyDashboardUpcomingVisit => 'Upcoming visit';

  @override
  String get familyDashboardManageConsent => 'Manage what you can see';

  @override
  String consentScreenTitle(String name) {
    return 'What $name shares with you';
  }

  @override
  String get consentCategoryLocationLive => 'Live location';

  @override
  String get consentCategoryLocationHistory => 'Location history';

  @override
  String get consentCategoryHealthNotes => 'Health notes';

  @override
  String get consentCategoryMedicationList => 'Medication list';

  @override
  String get consentCategoryVisitHistory => 'Full visit history';

  @override
  String get consentCategoryBilling => 'Billing details';

  @override
  String consentGrantedByElderOnly(String name) {
    return 'Only $name can change this';
  }

  @override
  String get bookingServiceSelectTitle => 'What kind of help?';

  @override
  String get bookingConfirm => 'Confirm booking';

  @override
  String get bookingStatusRequested => 'Requested';

  @override
  String get bookingStatusMatched => 'Caregiver assigned';

  @override
  String get bookingStatusInProgress => 'Visit in progress';

  @override
  String get bookingStatusCompleted => 'Completed';
}
