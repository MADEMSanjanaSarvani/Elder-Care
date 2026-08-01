// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'CareHive';

  @override
  String get loginPhoneLabel => 'फ़ोन नंबर';

  @override
  String get loginSendCode => 'कोड भेजें';

  @override
  String get loginVerifyCode => 'कोड सत्यापित करें';

  @override
  String loginCodeSentTo(String phone) {
    return 'हमने $phone पर एक कोड भेजा है';
  }

  @override
  String get elderHomeCallForHelp => 'मदद के लिए कॉल करें';

  @override
  String get elderHomeBookHelp => 'मदद बुक करें';

  @override
  String get elderHomeTodaysVisit => 'आज की विज़िट';

  @override
  String get elderHomeNoVisitToday => 'आज कोई विज़िट तय नहीं है';

  @override
  String get sosScreenTitle => 'आपातकाल';

  @override
  String get sosCall108 => '108 पर कॉल करें (आपातकाल)';

  @override
  String get sosNotifyPlatform => 'मेरे परिवार को भी सूचित करें';

  @override
  String get sosDisclaimer =>
      'आपातकालीन चिकित्सा सहायता के लिए 108 पर कॉल करना सबसे तेज़ तरीका है। CareHive उसी समय आपके परिवार को सूचित करता है — यह 108 पर कॉल करने का विकल्प नहीं है।';

  @override
  String get sosNotifiedConfirmation => 'आपके परिवार को सूचित कर दिया गया है।';

  @override
  String get familyDashboardTitle => 'परिवार डैशबोर्ड';

  @override
  String get familyDashboardUpcomingVisit => 'आगामी विज़िट';

  @override
  String get familyDashboardManageConsent =>
      'आप क्या देख सकते हैं, प्रबंधित करें';

  @override
  String consentScreenTitle(String name) {
    return '$name आपके साथ क्या साझा करते हैं';
  }

  @override
  String get consentCategoryLocationLive => 'लाइव लोकेशन';

  @override
  String get consentCategoryLocationHistory => 'लोकेशन इतिहास';

  @override
  String get consentCategoryHealthNotes => 'स्वास्थ्य नोट्स';

  @override
  String get consentCategoryMedicationList => 'दवाओं की सूची';

  @override
  String get consentCategoryVisitHistory => 'पूरा विज़िट इतिहास';

  @override
  String get consentCategoryBilling => 'बिलिंग विवरण';

  @override
  String consentGrantedByElderOnly(String name) {
    return 'इसे केवल $name बदल सकते हैं';
  }

  @override
  String get bookingServiceSelectTitle => 'किस तरह की मदद चाहिए?';

  @override
  String get bookingConfirm => 'बुकिंग की पुष्टि करें';

  @override
  String get bookingStatusRequested => 'अनुरोध किया गया';

  @override
  String get bookingStatusMatched => 'देखभालकर्ता नियुक्त';

  @override
  String get bookingStatusInProgress => 'विज़िट जारी है';

  @override
  String get bookingStatusCompleted => 'पूर्ण';
}
