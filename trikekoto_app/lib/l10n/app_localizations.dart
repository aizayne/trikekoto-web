import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
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
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

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
    Locale('fil'),
  ];

  /// Landing screen strapline under the app name.
  ///
  /// In fil, this message translates to:
  /// **'Tricycle rides sa barangay mo, kahit kailan'**
  String get landingTagline;

  /// No description provided for @landingBookRide.
  ///
  /// In fil, this message translates to:
  /// **'Mag-book ng ride'**
  String get landingBookRide;

  /// No description provided for @landingStaffSignIn.
  ///
  /// In fil, this message translates to:
  /// **'Mag-sign in bilang driver o admin'**
  String get landingStaffSignIn;

  /// No description provided for @landingNeedsNumber.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ng number para makapag-book.'**
  String get landingNeedsNumber;

  /// No description provided for @signInTitle.
  ///
  /// In fil, this message translates to:
  /// **'Mag-sign in'**
  String get signInTitle;

  /// No description provided for @signInCodeTitle.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ang code'**
  String get signInCodeTitle;

  /// No description provided for @signInAskNumber.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang number mo?'**
  String get signInAskNumber;

  /// No description provided for @signInWhyNumber.
  ///
  /// In fil, this message translates to:
  /// **'Padadalhan ka namin ng code para makumpirma. Hindi ito ipapakita sa driver hangga\'t hindi ka nagbo-book.'**
  String get signInWhyNumber;

  /// No description provided for @signInNumberLabel.
  ///
  /// In fil, this message translates to:
  /// **'Mobile number'**
  String get signInNumberLabel;

  /// No description provided for @signInNumberHelper.
  ///
  /// In fil, this message translates to:
  /// **'09XX XXX XXXX'**
  String get signInNumberHelper;

  /// No description provided for @signInNumberInvalid.
  ///
  /// In fil, this message translates to:
  /// **'Maglagay ng 11-digit na number na nagsisimula sa 09'**
  String get signInNumberInvalid;

  /// No description provided for @signInSending.
  ///
  /// In fil, this message translates to:
  /// **'Ipinapadala…'**
  String get signInSending;

  /// No description provided for @signInSendCode.
  ///
  /// In fil, this message translates to:
  /// **'Ipadala ang code'**
  String get signInSendCode;

  /// No description provided for @signInCodeSentSnack.
  ///
  /// In fil, this message translates to:
  /// **'Ipinadala ang code sa {number}.'**
  String signInCodeSentSnack(String number);

  /// No description provided for @signInCodeSentTo.
  ///
  /// In fil, this message translates to:
  /// **'Anim na numero, ipinadala sa {number}.'**
  String signInCodeSentTo(String number);

  /// No description provided for @signInEnterSixDigits.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ang anim na numero mula sa message.'**
  String get signInEnterSixDigits;

  /// No description provided for @signInConfirm.
  ///
  /// In fil, this message translates to:
  /// **'Kumpirmahin'**
  String get signInConfirm;

  /// No description provided for @signInOtherNumber.
  ///
  /// In fil, this message translates to:
  /// **'Ibang number'**
  String get signInOtherNumber;

  /// No description provided for @authInvalidPhone.
  ///
  /// In fil, this message translates to:
  /// **'Mukhang hindi ito mobile number.'**
  String get authInvalidPhone;

  /// No description provided for @authWrongCode.
  ///
  /// In fil, this message translates to:
  /// **'Mali ang code. Tingnan ulit ang message.'**
  String get authWrongCode;

  /// No description provided for @authCodeExpired.
  ///
  /// In fil, this message translates to:
  /// **'Nag-expire na ang code. Humingi ng bago.'**
  String get authCodeExpired;

  /// No description provided for @authTooManyTries.
  ///
  /// In fil, this message translates to:
  /// **'Masyadong maraming subok. Maghintay ng ilang minuto bago ulitin.'**
  String get authTooManyTries;

  /// No description provided for @authQuotaExceeded.
  ///
  /// In fil, this message translates to:
  /// **'Hindi makapagpadala ng code ngayon. Subukan mamaya.'**
  String get authQuotaExceeded;

  /// No description provided for @authNoConnection.
  ///
  /// In fil, this message translates to:
  /// **'Walang connection. Tingnan ang signal mo.'**
  String get authNoConnection;

  /// No description provided for @authPhoneSignInOff.
  ///
  /// In fil, this message translates to:
  /// **'Naka-off ang phone sign-in sa project na ito.'**
  String get authPhoneSignInOff;

  /// No description provided for @authCaptchaFailed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi pumasa ang browser check. I-reload ang page at subukan ulit.'**
  String get authCaptchaFailed;

  /// No description provided for @authAppNotRegistered.
  ///
  /// In fil, this message translates to:
  /// **'Hindi pa naka-register ang app na ito para sa phone sign-in.'**
  String get authAppNotRegistered;

  /// No description provided for @authSiteNotAllowed.
  ///
  /// In fil, this message translates to:
  /// **'Wala ang site na ito sa allowed list para sa sign-in.'**
  String get authSiteNotAllowed;

  /// Fallback for an unmapped FirebaseAuthException. The code is kept because it is what makes a support message actionable.
  ///
  /// In fil, this message translates to:
  /// **'{message} [{code}]'**
  String authUnknown(String message, String code);

  /// No description provided for @authCouldNotVerify.
  ///
  /// In fil, this message translates to:
  /// **'Hindi ma-verify ang number na iyon.'**
  String get authCouldNotVerify;

  /// No description provided for @authCouldNotSend.
  ///
  /// In fil, this message translates to:
  /// **'Hindi naipadala ang code. ({detail})'**
  String authCouldNotSend(String detail);

  /// No description provided for @onboardingTitle.
  ///
  /// In fil, this message translates to:
  /// **'Konti na lang'**
  String get onboardingTitle;

  /// No description provided for @onboardingPhotoOptional.
  ///
  /// In fil, this message translates to:
  /// **'Litrato — puwedeng laktawan'**
  String get onboardingPhotoOptional;

  /// No description provided for @onboardingAskName.
  ///
  /// In fil, this message translates to:
  /// **'Anong itatawag namin sa iyo?'**
  String get onboardingAskName;

  /// No description provided for @onboardingNameWhy.
  ///
  /// In fil, this message translates to:
  /// **'Ito ang makikita ng driver kapag sinundo ka.'**
  String get onboardingNameWhy;

  /// No description provided for @onboardingStart.
  ///
  /// In fil, this message translates to:
  /// **'Simulan'**
  String get onboardingStart;

  /// No description provided for @nameLabel.
  ///
  /// In fil, this message translates to:
  /// **'Pangalan'**
  String get nameLabel;

  /// No description provided for @nameRequired.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ang pangalan mo'**
  String get nameRequired;

  /// No description provided for @nameTooLong.
  ///
  /// In fil, this message translates to:
  /// **'Masyadong mahaba'**
  String get nameTooLong;

  /// No description provided for @phoneConfirmed.
  ///
  /// In fil, this message translates to:
  /// **'{number} — nakumpirma na'**
  String phoneConfirmed(String number);

  /// No description provided for @signOut.
  ///
  /// In fil, this message translates to:
  /// **'Mag-sign out'**
  String get signOut;

  /// No description provided for @photoTake.
  ///
  /// In fil, this message translates to:
  /// **'Kumuha ng litrato'**
  String get photoTake;

  /// No description provided for @photoGallery.
  ///
  /// In fil, this message translates to:
  /// **'Pumili sa gallery'**
  String get photoGallery;

  /// No description provided for @photoRemove.
  ///
  /// In fil, this message translates to:
  /// **'Alisin ang litrato'**
  String get photoRemove;

  /// No description provided for @photoChange.
  ///
  /// In fil, this message translates to:
  /// **'Palitan ang profile photo'**
  String get photoChange;

  /// No description provided for @photoAdd.
  ///
  /// In fil, this message translates to:
  /// **'Maglagay ng profile photo'**
  String get photoAdd;

  /// No description provided for @profileTitle.
  ///
  /// In fil, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSaved.
  ///
  /// In fil, this message translates to:
  /// **'Na-save ang profile mo.'**
  String get profileSaved;

  /// No description provided for @profileNamedSavedNotPhoto.
  ///
  /// In fil, this message translates to:
  /// **'Na-save ang pangalan, pero hindi ang litrato. {error}'**
  String profileNamedSavedNotPhoto(String error);

  /// No description provided for @profileNameHelper.
  ///
  /// In fil, this message translates to:
  /// **'Ito ang makikita ng driver'**
  String get profileNameHelper;

  /// No description provided for @profilePhotoWillSave.
  ///
  /// In fil, this message translates to:
  /// **'Ise-save ang litrato pagpindot mo ng Save'**
  String get profilePhotoWillSave;

  /// No description provided for @profilePhotoTapToChange.
  ///
  /// In fil, this message translates to:
  /// **'Pindutin ang litrato para palitan'**
  String get profilePhotoTapToChange;

  /// No description provided for @profileIdVerification.
  ///
  /// In fil, this message translates to:
  /// **'ID verification'**
  String get profileIdVerification;

  /// No description provided for @profileSave.
  ///
  /// In fil, this message translates to:
  /// **'I-save'**
  String get profileSave;

  /// No description provided for @profileLoadFailedTitle.
  ///
  /// In fil, this message translates to:
  /// **'Hindi mabuksan ang profile'**
  String get profileLoadFailedTitle;

  /// No description provided for @profileLoadFailedBody.
  ///
  /// In fil, this message translates to:
  /// **'Tingnan ang signal mo, tapos subukang muli.'**
  String get profileLoadFailedBody;

  /// No description provided for @profileRetry.
  ///
  /// In fil, this message translates to:
  /// **'Subukang muli'**
  String get profileRetry;

  /// No description provided for @profileNoneTitle.
  ///
  /// In fil, this message translates to:
  /// **'Walang profile'**
  String get profileNoneTitle;

  /// No description provided for @profileNoneBody.
  ///
  /// In fil, this message translates to:
  /// **'Mag-sign in muli para makagawa ng account.'**
  String get profileNoneBody;

  /// No description provided for @deleteAccount.
  ///
  /// In fil, this message translates to:
  /// **'Burahin ang account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In fil, this message translates to:
  /// **'Burahin ang account mo?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountPermanent.
  ///
  /// In fil, this message translates to:
  /// **'Mabubura nang tuluyan:'**
  String get deleteAccountPermanent;

  /// No description provided for @deleteAccountList.
  ///
  /// In fil, this message translates to:
  /// **'• Ang pangalan at litrato mo\n• Ang ID mo, kung nagpadala ka\n• Ang mga naka-save na lugar\n• Ang account mo — kakailanganin mong magparehistro ulit'**
  String get deleteAccountList;

  /// No description provided for @deleteAccountRetained.
  ///
  /// In fil, this message translates to:
  /// **'Ang mga naunang biyahe ay mananatili bilang record ng TODA — pero tatanggalin dito ang pangalan at number mo, kaya hindi na ito maiuugnay sa iyo.'**
  String get deleteAccountRetained;

  /// No description provided for @deleteAccountIrreversible.
  ///
  /// In fil, this message translates to:
  /// **'Hindi na ito maibabalik.'**
  String get deleteAccountIrreversible;

  /// No description provided for @deleteAccountNo.
  ///
  /// In fil, this message translates to:
  /// **'Hindi'**
  String get deleteAccountNo;

  /// No description provided for @deleteAccountReauth.
  ///
  /// In fil, this message translates to:
  /// **'Para sa seguridad, mag-sign in muli bago burahin ang account.'**
  String get deleteAccountReauth;

  /// No description provided for @pickerSearchHint.
  ///
  /// In fil, this message translates to:
  /// **'Maghanap ng lugar'**
  String get pickerSearchHint;

  /// No description provided for @pickerSearch.
  ///
  /// In fil, this message translates to:
  /// **'Hanapin'**
  String get pickerSearch;

  /// No description provided for @pickerNotFound.
  ///
  /// In fil, this message translates to:
  /// **'Walang nakitang \"{query}\" malapit dito. Kung malayo ito, i-drag muna ang mapa papunta roon — o ilagay ang pin nang manu-mano.'**
  String pickerNotFound(String query);

  /// No description provided for @pickerPermissionOff.
  ///
  /// In fil, this message translates to:
  /// **'Naka-off ang location permission. I-on ito sa Settings para ma-center ang mapa sa iyo.'**
  String get pickerPermissionOff;

  /// No description provided for @pickerNeedsName.
  ///
  /// In fil, this message translates to:
  /// **'Bigyan ng pangalan ang lugar para makilala ito ng driver mo.'**
  String get pickerNeedsName;

  /// No description provided for @pickerLocating.
  ///
  /// In fil, this message translates to:
  /// **'Hinahanap…'**
  String get pickerLocating;

  /// No description provided for @pickerMyLocation.
  ///
  /// In fil, this message translates to:
  /// **'Nasa akin ngayon'**
  String get pickerMyLocation;

  /// No description provided for @pickerHelp.
  ///
  /// In fil, this message translates to:
  /// **'I-drag ang mapa para ilagay ang pin — o hanapin sa itaas, o gamitin ang location mo.'**
  String get pickerHelp;

  /// No description provided for @pickerNameLabel.
  ///
  /// In fil, this message translates to:
  /// **'Pangalanan ang lugar'**
  String get pickerNameLabel;

  /// No description provided for @pickerNameHint.
  ///
  /// In fil, this message translates to:
  /// **'hal. Plaza, Palengke, Barangay Hall'**
  String get pickerNameHint;

  /// No description provided for @pickerConfirm.
  ///
  /// In fil, this message translates to:
  /// **'Kumpirmahin ang location'**
  String get pickerConfirm;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'fil':
      return LFil();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
