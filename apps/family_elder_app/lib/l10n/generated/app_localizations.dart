import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te')
  ];

  /// App name shown in the OS task switcher — not user-facing chrome
  ///
  /// In en, this message translates to:
  /// **'SETU'**
  String get appTitle;

  /// No description provided for @loginPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get loginPhoneLabel;

  /// No description provided for @loginSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get loginSendCode;

  /// No description provided for @loginVerifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get loginVerifyCode;

  /// No description provided for @loginCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {phone}'**
  String loginCodeSentTo(String phone);

  /// No description provided for @elderHomeCallForHelp.
  ///
  /// In en, this message translates to:
  /// **'Call for Help'**
  String get elderHomeCallForHelp;

  /// No description provided for @elderHomeBookHelp.
  ///
  /// In en, this message translates to:
  /// **'Book Help'**
  String get elderHomeBookHelp;

  /// No description provided for @elderHomeTodaysVisit.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Visit'**
  String get elderHomeTodaysVisit;

  /// No description provided for @elderHomeNoVisitToday.
  ///
  /// In en, this message translates to:
  /// **'No visit scheduled today'**
  String get elderHomeNoVisitToday;

  /// No description provided for @sosScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get sosScreenTitle;

  /// No description provided for @sosCall108.
  ///
  /// In en, this message translates to:
  /// **'Call 108 (Emergency)'**
  String get sosCall108;

  /// No description provided for @sosNotifyPlatform.
  ///
  /// In en, this message translates to:
  /// **'Also notify family & SETU'**
  String get sosNotifyPlatform;

  /// No description provided for @sosDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Calling 108 is the fastest way to get emergency medical help. Notifying SETU alerts your family and our on-call team at the same time — it does not replace calling 108.'**
  String get sosDisclaimer;

  /// No description provided for @sosNotifiedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Your family and our on-call team have been notified.'**
  String get sosNotifiedConfirmation;

  /// No description provided for @familyDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Dashboard'**
  String get familyDashboardTitle;

  /// No description provided for @familyDashboardUpcomingVisit.
  ///
  /// In en, this message translates to:
  /// **'Upcoming visit'**
  String get familyDashboardUpcomingVisit;

  /// No description provided for @familyDashboardManageConsent.
  ///
  /// In en, this message translates to:
  /// **'Manage what you can see'**
  String get familyDashboardManageConsent;

  /// No description provided for @consentScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'What {name} shares with you'**
  String consentScreenTitle(String name);

  /// No description provided for @consentCategoryLocationLive.
  ///
  /// In en, this message translates to:
  /// **'Live location'**
  String get consentCategoryLocationLive;

  /// No description provided for @consentCategoryLocationHistory.
  ///
  /// In en, this message translates to:
  /// **'Location history'**
  String get consentCategoryLocationHistory;

  /// No description provided for @consentCategoryHealthNotes.
  ///
  /// In en, this message translates to:
  /// **'Health notes'**
  String get consentCategoryHealthNotes;

  /// No description provided for @consentCategoryMedicationList.
  ///
  /// In en, this message translates to:
  /// **'Medication list'**
  String get consentCategoryMedicationList;

  /// No description provided for @consentCategoryVisitHistory.
  ///
  /// In en, this message translates to:
  /// **'Full visit history'**
  String get consentCategoryVisitHistory;

  /// No description provided for @consentCategoryBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing details'**
  String get consentCategoryBilling;

  /// No description provided for @consentGrantedByElderOnly.
  ///
  /// In en, this message translates to:
  /// **'Only {name} can change this'**
  String consentGrantedByElderOnly(String name);

  /// No description provided for @bookingServiceSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'What kind of help?'**
  String get bookingServiceSelectTitle;

  /// No description provided for @bookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get bookingConfirm;

  /// No description provided for @bookingStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get bookingStatusRequested;

  /// No description provided for @bookingStatusMatched.
  ///
  /// In en, this message translates to:
  /// **'Caregiver assigned'**
  String get bookingStatusMatched;

  /// No description provided for @bookingStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'Visit in progress'**
  String get bookingStatusInProgress;

  /// No description provided for @bookingStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingStatusCompleted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
