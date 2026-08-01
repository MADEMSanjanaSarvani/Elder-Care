/// In-app legal text. Google Play requires a Privacy Policy that is reachable
/// both from the store listing (a hosted URL) and inside the app; these are
/// the in-app copies. Keep them in sync with docs/legal/*.md and the hosted
/// versions linked in the Play Console.
///
/// Rewritten when the caregiver marketplace was removed. The old text promised
/// background-verified caregivers, bookings, subscriptions and refunds — none
/// of which exist. A privacy policy describing data the app does not collect
/// and a terms page describing a service it does not provide are worse than no
/// document at all: they are the two pages a regulator reads first.
library;

const String kPrivacyPolicyUpdated = 'Updated 1 August 2026';

const String kPrivacyPolicy = '''
CareHive holds your family's medicine record, so we treat privacy as a
core feature, not fine print.

WHAT WE COLLECT
• Account details: your name, email and/or mobile number, and password
  (stored only as a secure one-way hash — we never see it).
• The people you care for: names, and the health details you choose to
  add (medicines, dose times, appointments, notes, vitals, documents).
• The record itself: which doses were marked taken, which were marked not
  taken, when each mark was made and who made it.
• Device data needed to run the app: a notification token so reminders can
  reach the phone, and — only with your permission, and only when an SOS
  is raised — your location.

WHAT WE DO NOT COLLECT
We do not track your location in the background. Location is read at the
moment you raise an SOS and at no other time.

HOW WE USE IT
• To remind you: dose alarms are scheduled on your own phone and fire
  without sending anything to us.
• To keep the record: so it can be shown to a doctor, or read off a locked
  phone in an emergency.
• To alert your family: check-ins and SOS.
• We do NOT sell your data and do NOT use health information for
  advertising. There is no advertising in CareHive.

CONSENT AND ACCESS
Access to an elder's sensitive information is controlled by explicit,
category-by-category consent. A family member sees only what consent
allows. You can review and change these grants at any time from
"What you can see" and the Privacy Centre.

YOUR RIGHTS (DPDP Act, 2023)
• Access & export: download a copy of your data any time.
• Correction: edit your information in the app.
• Erasure: request deletion of your account and data.
Some records (safety incidents, audit logs) may be retained where the law
requires, even after an erasure request.

SECURITY
Data is encrypted in transit (HTTPS) and protected by row-level security
so each person can reach only what they're entitled to. Uploaded medical
files are stored privately and served through short-lived signed links.

CONTACT
Questions or requests: sanjanasarvani2111@gmail.com
''';

const String kTermsOfService = '''
By using CareHive you agree to these terms.

THE SERVICE
CareHive keeps a record of the medicines a person takes: it reminds them
at each dose time, records what was actually taken, and puts that record
— along with allergies, conditions and blood group — on one screen for a
doctor or a paramedic. It also carries daily check-ins and an emergency
SOS that alerts the family.

CareHive is free. There is no subscription, no booking and no payment.
Nobody is sent to your home; no staff or carers are supplied.

NOT A MEDICAL OR EMERGENCY SERVICE
CareHive does not provide medical advice, diagnosis or treatment, and is
not a substitute for professional care. Never change a dose or a
prescription because of anything this app shows you.

In an emergency, always call 108 (or your local emergency number) first —
the in-app SOS notifies your family in parallel, never instead of the
emergency services.

WHAT THE RECORD DOES AND DOES NOT MEAN
A dose is marked taken only when somebody says so. A dose nobody marked is
shown as having no record — not as a missed dose — because the app cannot
know which it was. Do not read an unmarked dose as evidence a medicine was
skipped.

REMINDERS ARE BEST EFFORT
Dose reminders are alarms scheduled on the phone. A phone that is switched
off, out of battery, or on which notification or exact-alarm permission has
been refused will not ring. Do not rely on CareHive as the only thing
standing between someone and a missed medicine.

YOUR RESPONSIBILITIES
• Give accurate information and keep your login secure.
• Only add another person's health details where you are entitled to.
• Use the app only for lawful purposes.

CHANGES & TERMINATION
We may update these terms and will notify you of material changes. You may
stop using CareHive and request account deletion at any time.

CONTACT
sanjanasarvani2111@gmail.com
''';
