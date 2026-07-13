// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'సేతు';

  @override
  String get loginPhoneLabel => 'ఫోన్ నంబర్';

  @override
  String get loginSendCode => 'కోడ్ పంపండి';

  @override
  String get loginVerifyCode => 'కోడ్ ధృవీకరించండి';

  @override
  String loginCodeSentTo(String phone) {
    return 'మేము $phoneకి ఒక కోడ్ పంపాము';
  }

  @override
  String get elderHomeCallForHelp => 'సహాయం కోసం కాల్ చేయండి';

  @override
  String get elderHomeBookHelp => 'సహాయం బుక్ చేయండి';

  @override
  String get elderHomeTodaysVisit => 'ఈరోజు విజిట్';

  @override
  String get elderHomeNoVisitToday => 'ఈరోజు ఎలాంటి విజిట్ నిర్ణయించలేదు';

  @override
  String get sosScreenTitle => 'అత్యవసర పరిస్థితి';

  @override
  String get sosCall108 => '108కి కాల్ చేయండి (అత్యవసరం)';

  @override
  String get sosNotifyPlatform => 'కుటుంబం మరియు సేతుకు కూడా తెలియజేయండి';

  @override
  String get sosDisclaimer =>
      'అత్యవసర వైద్య సహాయం కోసం 108కి కాల్ చేయడం అత్యంత వేగవంతమైన మార్గం. సేతుకు తెలియజేయడం వల్ల మీ కుటుంబం మరియు మా టీమ్‌కు ఒకేసారి తెలుస్తుంది — ఇది 108కి కాల్ చేయడానికి ప్రత్యామ్నాయం కాదు.';

  @override
  String get sosNotifiedConfirmation =>
      'మీ కుటుంబం మరియు మా టీమ్‌కు తెలియజేయబడింది.';

  @override
  String get familyDashboardTitle => 'కుటుంబ డాష్‌బోర్డ్';

  @override
  String get familyDashboardUpcomingVisit => 'రాబోయే విజిట్';

  @override
  String get familyDashboardManageConsent => 'మీరు ఏమి చూడగలరో నిర్వహించండి';

  @override
  String consentScreenTitle(String name) {
    return '$name మీతో ఏమి పంచుకుంటారు';
  }

  @override
  String get consentCategoryLocationLive => 'ప్రత్యక్ష స్థానం';

  @override
  String get consentCategoryLocationHistory => 'స్థాన చరిత్ర';

  @override
  String get consentCategoryHealthNotes => 'ఆరోగ్య గమనికలు';

  @override
  String get consentCategoryMedicationList => 'మందుల జాబితా';

  @override
  String get consentCategoryVisitHistory => 'పూర్తి విజిట్ చరిత్ర';

  @override
  String get consentCategoryBilling => 'బిల్లింగ్ వివరాలు';

  @override
  String consentGrantedByElderOnly(String name) {
    return 'దీన్ని $name మాత్రమే మార్చగలరు';
  }

  @override
  String get bookingServiceSelectTitle => 'ఎలాంటి సహాయం కావాలి?';

  @override
  String get bookingConfirm => 'బుకింగ్ నిర్ధారించండి';

  @override
  String get bookingStatusRequested => 'అభ్యర్థించారు';

  @override
  String get bookingStatusMatched => 'కేర్‌గివర్ కేటాయించారు';

  @override
  String get bookingStatusInProgress => 'విజిట్ జరుగుతోంది';

  @override
  String get bookingStatusCompleted => 'పూర్తయింది';
}
