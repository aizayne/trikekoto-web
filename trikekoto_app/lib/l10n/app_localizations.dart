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

  /// No description provided for @bookTitle.
  ///
  /// In fil, this message translates to:
  /// **'Mag-book ng ride'**
  String get bookTitle;

  /// No description provided for @bookWhereTo.
  ///
  /// In fil, this message translates to:
  /// **'Saan tayo?'**
  String get bookWhereTo;

  /// No description provided for @bookNearestFirst.
  ///
  /// In fil, this message translates to:
  /// **'Ino-offer muna namin ang ride mo sa pinakamalapit na driver.'**
  String get bookNearestFirst;

  /// No description provided for @bookCurrentLocation.
  ///
  /// In fil, this message translates to:
  /// **'Kasalukuyang location'**
  String get bookCurrentLocation;

  /// No description provided for @bookSetPickup.
  ///
  /// In fil, this message translates to:
  /// **'Itakda ang sundo'**
  String get bookSetPickup;

  /// No description provided for @bookSetDropoff.
  ///
  /// In fil, this message translates to:
  /// **'Itakda ang babaan'**
  String get bookSetDropoff;

  /// No description provided for @bookSetBoth.
  ///
  /// In fil, this message translates to:
  /// **'Itakda sa mapa ang sundo at babaan mo.'**
  String get bookSetBoth;

  /// No description provided for @bookPickup.
  ///
  /// In fil, this message translates to:
  /// **'Sundo'**
  String get bookPickup;

  /// No description provided for @bookDropoff.
  ///
  /// In fil, this message translates to:
  /// **'Babaan'**
  String get bookDropoff;

  /// No description provided for @bookLocating.
  ///
  /// In fil, this message translates to:
  /// **'Hinahanap ang location mo…'**
  String get bookLocating;

  /// No description provided for @bookSetOnMap.
  ///
  /// In fil, this message translates to:
  /// **'Itakda sa mapa'**
  String get bookSetOnMap;

  /// No description provided for @bookYourName.
  ///
  /// In fil, this message translates to:
  /// **'Pangalan mo'**
  String get bookYourName;

  /// No description provided for @bookEnterName.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ang pangalan mo'**
  String get bookEnterName;

  /// No description provided for @bookNumberHelper.
  ///
  /// In fil, this message translates to:
  /// **'Para matawagan ka ng driver mo.'**
  String get bookNumberHelper;

  /// No description provided for @bookNumberInvalid.
  ///
  /// In fil, this message translates to:
  /// **'Maglagay ng number na matatawagan ng driver'**
  String get bookNumberInvalid;

  /// No description provided for @bookFinding.
  ///
  /// In fil, this message translates to:
  /// **'Naghahanap ng driver…'**
  String get bookFinding;

  /// No description provided for @bookFindDriver.
  ///
  /// In fil, this message translates to:
  /// **'Maghanap ng driver'**
  String get bookFindDriver;

  /// No description provided for @bookProfile.
  ///
  /// In fil, this message translates to:
  /// **'Profile'**
  String get bookProfile;

  /// No description provided for @bookReportProblem.
  ///
  /// In fil, this message translates to:
  /// **'Mag-report ng problema'**
  String get bookReportProblem;

  /// No description provided for @bookExit.
  ///
  /// In fil, this message translates to:
  /// **'Lumabas'**
  String get bookExit;

  /// No description provided for @trackTitle.
  ///
  /// In fil, this message translates to:
  /// **'Live tracking'**
  String get trackTitle;

  /// No description provided for @trackOnTheWay.
  ///
  /// In fil, this message translates to:
  /// **'Papunta na sa babaan mo'**
  String get trackOnTheWay;

  /// No description provided for @trackKmAway.
  ///
  /// In fil, this message translates to:
  /// **'{km} km ang layo'**
  String trackKmAway(String km);

  /// No description provided for @trackWorkingRoute.
  ///
  /// In fil, this message translates to:
  /// **'Kinakalkula ang ruta…'**
  String get trackWorkingRoute;

  /// No description provided for @trackTrip.
  ///
  /// In fil, this message translates to:
  /// **'Biyahe'**
  String get trackTrip;

  /// No description provided for @trackTripSummary.
  ///
  /// In fil, this message translates to:
  /// **'{km} km{minutes}'**
  String trackTripSummary(String km, String minutes);

  /// No description provided for @trackAboutMinutes.
  ///
  /// In fil, this message translates to:
  /// **' · mga {minutes} min'**
  String trackAboutMinutes(String minutes);

  /// No description provided for @trackApproximate.
  ///
  /// In fil, this message translates to:
  /// **'Tinatantiya — hindi maabot ang route service'**
  String get trackApproximate;

  /// No description provided for @trackTryAgain.
  ///
  /// In fil, this message translates to:
  /// **'Subukang muli'**
  String get trackTryAgain;

  /// No description provided for @statusSearching.
  ///
  /// In fil, this message translates to:
  /// **'Naghahanap ng driver…'**
  String get statusSearching;

  /// No description provided for @statusAccepted.
  ///
  /// In fil, this message translates to:
  /// **'Papunta na ang driver'**
  String get statusAccepted;

  /// No description provided for @statusInTransit.
  ///
  /// In fil, this message translates to:
  /// **'Papunta na sa babaan mo'**
  String get statusInTransit;

  /// No description provided for @statusAsked.
  ///
  /// In fil, this message translates to:
  /// **'Natanong na ang {depth} sa {total} malapit na driver'**
  String statusAsked(String depth, String total);

  /// No description provided for @callDriver.
  ///
  /// In fil, this message translates to:
  /// **'Tawagan si {name}'**
  String callDriver(String name);

  /// No description provided for @cancelRide.
  ///
  /// In fil, this message translates to:
  /// **'Kanselahin ang ride'**
  String get cancelRide;

  /// No description provided for @dialerFailed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi mabuksan ang dialler. Number: {phone}'**
  String dialerFailed(String phone);

  /// No description provided for @rateTitle.
  ///
  /// In fil, this message translates to:
  /// **'Kumusta ang biyahe mo?'**
  String get rateTitle;

  /// No description provided for @ratePayCash.
  ///
  /// In fil, this message translates to:
  /// **'Bayaran ang nakasaad na TODA fare nang cash.'**
  String get ratePayCash;

  /// No description provided for @rateThanks.
  ///
  /// In fil, this message translates to:
  /// **'Salamat sa rating!'**
  String get rateThanks;

  /// No description provided for @driverTitle.
  ///
  /// In fil, this message translates to:
  /// **'Driver'**
  String get driverTitle;

  /// No description provided for @driverNoProfile.
  ///
  /// In fil, this message translates to:
  /// **'Walang nakitang driver profile.'**
  String get driverNoProfile;

  /// No description provided for @driverIdVerification.
  ///
  /// In fil, this message translates to:
  /// **'ID verification'**
  String get driverIdVerification;

  /// No description provided for @driverIdSubtitle.
  ///
  /// In fil, this message translates to:
  /// **'Ipadala ang lisensya o ID para sa chapter'**
  String get driverIdSubtitle;

  /// No description provided for @driverVerified.
  ///
  /// In fil, this message translates to:
  /// **'Verified TODA driver'**
  String get driverVerified;

  /// No description provided for @driverSuspended.
  ///
  /// In fil, this message translates to:
  /// **'Naka-suspend ang account mo. Hindi ka makakatanggap ng ride.'**
  String get driverSuspended;

  /// No description provided for @driverRejected.
  ///
  /// In fil, this message translates to:
  /// **'Hindi natanggap ang registration mo.'**
  String get driverRejected;

  /// No description provided for @driverPending.
  ///
  /// In fil, this message translates to:
  /// **'Hinihintay ang verification. Kailangan ka munang aprubahan ng admin bago ka makatanggap ng ride.'**
  String get driverPending;

  /// No description provided for @driverNamePlate.
  ///
  /// In fil, this message translates to:
  /// **'{name} • {plate}'**
  String driverNamePlate(String name, String plate);

  /// No description provided for @driverRating.
  ///
  /// In fil, this message translates to:
  /// **'★ {average} ({count})'**
  String driverRating(String average, String count);

  /// No description provided for @driverOnline.
  ///
  /// In fil, this message translates to:
  /// **'Online'**
  String get driverOnline;

  /// No description provided for @driverOffline.
  ///
  /// In fil, this message translates to:
  /// **'Offline'**
  String get driverOffline;

  /// No description provided for @driverOnlineSubtitle.
  ///
  /// In fil, this message translates to:
  /// **'Nakikita ng malapit na commuter ang location mo'**
  String get driverOnlineSubtitle;

  /// No description provided for @driverOfflineSubtitle.
  ///
  /// In fil, this message translates to:
  /// **'Mag-online para makatanggap ng ride offer'**
  String get driverOfflineSubtitle;

  /// No description provided for @driverCurrentRide.
  ///
  /// In fil, this message translates to:
  /// **'Kasalukuyang biyahe'**
  String get driverCurrentRide;

  /// No description provided for @driverCallCommuter.
  ///
  /// In fil, this message translates to:
  /// **'Tawagan si {name}'**
  String driverCallCommuter(String name);

  /// No description provided for @driverStartTrip.
  ///
  /// In fil, this message translates to:
  /// **'Simulan ang biyahe'**
  String get driverStartTrip;

  /// No description provided for @driverCompleteRide.
  ///
  /// In fil, this message translates to:
  /// **'Tapusin ang biyahe'**
  String get driverCompleteRide;

  /// No description provided for @driverCancel.
  ///
  /// In fil, this message translates to:
  /// **'Kanselahin'**
  String get driverCancel;

  /// No description provided for @driverWaiting.
  ///
  /// In fil, this message translates to:
  /// **'Naghihintay ng biyahe'**
  String get driverWaiting;

  /// No description provided for @driverYouAreOffline.
  ///
  /// In fil, this message translates to:
  /// **'Naka-offline ka'**
  String get driverYouAreOffline;

  /// No description provided for @driverWaitingBody.
  ///
  /// In fil, this message translates to:
  /// **'Ioofer sa iyo ang pinakamalapit na booking pagdating nito. Panatilihing bukas ang screen na ito.'**
  String get driverWaitingBody;

  /// No description provided for @driverOfflineBody.
  ///
  /// In fil, this message translates to:
  /// **'Mag-online sa itaas para makatanggap ng ride offer.'**
  String get driverOfflineBody;

  /// No description provided for @driverNewOffer.
  ///
  /// In fil, this message translates to:
  /// **'Bagong ride offer'**
  String get driverNewOffer;

  /// No description provided for @driverRoute.
  ///
  /// In fil, this message translates to:
  /// **'{from}  →  {to}'**
  String driverRoute(String from, String to);

  /// No description provided for @driverDecline.
  ///
  /// In fil, this message translates to:
  /// **'Tanggihan'**
  String get driverDecline;

  /// No description provided for @driverAccept.
  ///
  /// In fil, this message translates to:
  /// **'Tanggapin'**
  String get driverAccept;

  /// No description provided for @driverReportProblem.
  ///
  /// In fil, this message translates to:
  /// **'Mag-report ng problema'**
  String get driverReportProblem;

  /// No description provided for @idTitle.
  ///
  /// In fil, this message translates to:
  /// **'ID verification'**
  String get idTitle;

  /// No description provided for @idTakePhoto.
  ///
  /// In fil, this message translates to:
  /// **'Kunan ng litrato ang ID'**
  String get idTakePhoto;

  /// No description provided for @idGallery.
  ///
  /// In fil, this message translates to:
  /// **'Pumili sa gallery'**
  String get idGallery;

  /// No description provided for @idPhotoRequired.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ng litrato ng ID.'**
  String get idPhotoRequired;

  /// No description provided for @idConsentRequired.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan mong pumayag muna.'**
  String get idConsentRequired;

  /// No description provided for @idSubmitted.
  ///
  /// In fil, this message translates to:
  /// **'Naipadala na. Hihintayin ang review.'**
  String get idSubmitted;

  /// No description provided for @idWithdrawQuestion.
  ///
  /// In fil, this message translates to:
  /// **'Bawiin ang ID?'**
  String get idWithdrawQuestion;

  /// No description provided for @idWithdrawBody.
  ///
  /// In fil, this message translates to:
  /// **'Buburahin ang litrato at ang detalye ng ID mo. Puwede kang magpadala ulit anumang oras.'**
  String get idWithdrawBody;

  /// No description provided for @idWithdrawNo.
  ///
  /// In fil, this message translates to:
  /// **'Hindi'**
  String get idWithdrawNo;

  /// No description provided for @idWithdrawYes.
  ///
  /// In fil, this message translates to:
  /// **'Burahin'**
  String get idWithdrawYes;

  /// No description provided for @idDeleted.
  ///
  /// In fil, this message translates to:
  /// **'Nabura na ang ID mo.'**
  String get idDeleted;

  /// No description provided for @idApprovedTitle.
  ///
  /// In fil, this message translates to:
  /// **'Beripikado na'**
  String get idApprovedTitle;

  /// No description provided for @idApprovedBody.
  ///
  /// In fil, this message translates to:
  /// **'Nakumpirma ng chapter ang ID mo.'**
  String get idApprovedBody;

  /// No description provided for @idRejectedTitle.
  ///
  /// In fil, this message translates to:
  /// **'Hindi tinanggap'**
  String get idRejectedTitle;

  /// No description provided for @idNoReason.
  ///
  /// In fil, this message translates to:
  /// **'Walang ibinigay na dahilan.'**
  String get idNoReason;

  /// No description provided for @idPendingTitle.
  ///
  /// In fil, this message translates to:
  /// **'Hinihintay ang review'**
  String get idPendingTitle;

  /// No description provided for @idPendingBody.
  ///
  /// In fil, this message translates to:
  /// **'Ipinadala na ang ID mo. Aabisuhan ka dito pagkatapos.'**
  String get idPendingBody;

  /// No description provided for @idTypeRow.
  ///
  /// In fil, this message translates to:
  /// **'Uri ng ID'**
  String get idTypeRow;

  /// No description provided for @idNumberRow.
  ///
  /// In fil, this message translates to:
  /// **'Numero'**
  String get idNumberRow;

  /// No description provided for @idWithdrawAndDelete.
  ///
  /// In fil, this message translates to:
  /// **'Bawiin at burahin ang ID'**
  String get idWithdrawAndDelete;

  /// No description provided for @idWithdrawNote.
  ///
  /// In fil, this message translates to:
  /// **'Buburahin nito ang litrato at ang detalye, kahit na-aprubahan na.'**
  String get idWithdrawNote;

  /// No description provided for @idConfirmIdentity.
  ///
  /// In fil, this message translates to:
  /// **'Kumpirmahin ang pagkakakilanlan'**
  String get idConfirmIdentity;

  /// No description provided for @idWhyDriver.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ito ng TODA chapter bago ka makatanggap ng biyahe.'**
  String get idWhyDriver;

  /// No description provided for @idWhyRider.
  ///
  /// In fil, this message translates to:
  /// **'Nakakatulong ito para ligtas ang lahat sa biyahe.'**
  String get idWhyRider;

  /// No description provided for @idTypeLabel.
  ///
  /// In fil, this message translates to:
  /// **'Uri ng ID'**
  String get idTypeLabel;

  /// No description provided for @idNumberLabel.
  ///
  /// In fil, this message translates to:
  /// **'Numero ng ID'**
  String get idNumberLabel;

  /// No description provided for @idNumberTooShort.
  ///
  /// In fil, this message translates to:
  /// **'Masyadong maikli'**
  String get idNumberTooShort;

  /// No description provided for @idNumberTooLong.
  ///
  /// In fil, this message translates to:
  /// **'Masyadong mahaba'**
  String get idNumberTooLong;

  /// No description provided for @idSubmitForReview.
  ///
  /// In fil, this message translates to:
  /// **'Ipadala para sa review'**
  String get idSubmitForReview;

  /// No description provided for @idPhotoTitle.
  ///
  /// In fil, this message translates to:
  /// **'Litrato ng ID'**
  String get idPhotoTitle;

  /// No description provided for @idPhotoHint.
  ///
  /// In fil, this message translates to:
  /// **'Siguraduhing mabasa ang pangalan at numero'**
  String get idPhotoHint;

  /// No description provided for @idHowUsedTitle.
  ///
  /// In fil, this message translates to:
  /// **'Paano gagamitin ang ID mo'**
  String get idHowUsedTitle;

  /// No description provided for @idHowUsedBody.
  ///
  /// In fil, this message translates to:
  /// **'• Titingnan lang ito ng opisyal ng TODA chapter para kumpirmahin kung sino ka.\n• Hindi ito makikita ng ibang pasahero o ng driver mo.\n• Buburahin ito 90 araw matapos ang review, o kaagad kapag binawi mo.\n• Puwede mong burahin anumang oras dito sa screen na ito.'**
  String get idHowUsedBody;

  /// No description provided for @idConsentLabel.
  ///
  /// In fil, this message translates to:
  /// **'Pumapayag ako na iproseso ang ID ko para sa pagkumpirma.'**
  String get idConsentLabel;

  /// No description provided for @regTitle.
  ///
  /// In fil, this message translates to:
  /// **'Driver registration'**
  String get regTitle;

  /// No description provided for @regPendingNote.
  ///
  /// In fil, this message translates to:
  /// **'Ang bagong account ay Pending muna. May TODA admin na magbe-verify sa iyo bago ka makatanggap ng biyahe.'**
  String get regPendingNote;

  /// No description provided for @regYourDetails.
  ///
  /// In fil, this message translates to:
  /// **'Detalye mo'**
  String get regYourDetails;

  /// No description provided for @regFirstName.
  ///
  /// In fil, this message translates to:
  /// **'Pangalan'**
  String get regFirstName;

  /// No description provided for @regLastName.
  ///
  /// In fil, this message translates to:
  /// **'Apelyido'**
  String get regLastName;

  /// No description provided for @regMobile.
  ///
  /// In fil, this message translates to:
  /// **'Mobile number'**
  String get regMobile;

  /// No description provided for @regMobileHelper.
  ///
  /// In fil, this message translates to:
  /// **'Ito ang tatawagan ng commuter kapag tinanggap mo.'**
  String get regMobileHelper;

  /// No description provided for @regYourTricycle.
  ///
  /// In fil, this message translates to:
  /// **'Tricycle mo'**
  String get regYourTricycle;

  /// No description provided for @regPlate.
  ///
  /// In fil, this message translates to:
  /// **'Plate number'**
  String get regPlate;

  /// No description provided for @regPlateHelper.
  ///
  /// In fil, this message translates to:
  /// **'Ipapakita sa commuter para makita ka nila.'**
  String get regPlateHelper;

  /// No description provided for @regTodaChapter.
  ///
  /// In fil, this message translates to:
  /// **'TODA chapter'**
  String get regTodaChapter;

  /// No description provided for @regSignInSection.
  ///
  /// In fil, this message translates to:
  /// **'Sign-in'**
  String get regSignInSection;

  /// No description provided for @regEmail.
  ///
  /// In fil, this message translates to:
  /// **'Email'**
  String get regEmail;

  /// No description provided for @regEmailInvalid.
  ///
  /// In fil, this message translates to:
  /// **'Maglagay ng tamang email address'**
  String get regEmailInvalid;

  /// No description provided for @regPassword.
  ///
  /// In fil, this message translates to:
  /// **'Password'**
  String get regPassword;

  /// No description provided for @regPasswordHelper.
  ///
  /// In fil, this message translates to:
  /// **'Hindi bababa sa 6 na karakter.'**
  String get regPasswordHelper;

  /// No description provided for @regShowPassword.
  ///
  /// In fil, this message translates to:
  /// **'Ipakita ang password'**
  String get regShowPassword;

  /// No description provided for @regHidePassword.
  ///
  /// In fil, this message translates to:
  /// **'Itago ang password'**
  String get regHidePassword;

  /// No description provided for @regPasswordTooShort.
  ///
  /// In fil, this message translates to:
  /// **'Gumamit ng hindi bababa sa 6 na karakter'**
  String get regPasswordTooShort;

  /// No description provided for @regCreateAccount.
  ///
  /// In fil, this message translates to:
  /// **'Gumawa ng account'**
  String get regCreateAccount;

  /// No description provided for @regFieldRequired.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ang {label}'**
  String regFieldRequired(String label);

  /// No description provided for @loginTitle.
  ///
  /// In fil, this message translates to:
  /// **'Mag-sign in'**
  String get loginTitle;

  /// No description provided for @loginWelcome.
  ///
  /// In fil, this message translates to:
  /// **'Maligayang pagbabalik'**
  String get loginWelcome;

  /// No description provided for @loginBody.
  ///
  /// In fil, this message translates to:
  /// **'Dito nagsa-sign in ang mga driver at administrator. Nakadepende sa account mo kung saan ka mapupunta.'**
  String get loginBody;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In fil, this message translates to:
  /// **'Ilagay ang email na ginamit mo sa pagpaparehistro'**
  String get loginEmailInvalid;

  /// No description provided for @loginPasswordTooShort.
  ///
  /// In fil, this message translates to:
  /// **'Hindi bababa sa 6 na karakter'**
  String get loginPasswordTooShort;

  /// No description provided for @loginRegisterAsDriver.
  ///
  /// In fil, this message translates to:
  /// **'Magparehistro bilang TODA driver'**
  String get loginRegisterAsDriver;

  /// No description provided for @adminTitle.
  ///
  /// In fil, this message translates to:
  /// **'Admin'**
  String get adminTitle;

  /// No description provided for @adminFeedback.
  ///
  /// In fil, this message translates to:
  /// **'Feedback'**
  String get adminFeedback;

  /// No description provided for @adminDispatch.
  ///
  /// In fil, this message translates to:
  /// **'Dispatch'**
  String get adminDispatch;

  /// No description provided for @adminIdReview.
  ///
  /// In fil, this message translates to:
  /// **'ID review'**
  String get adminIdReview;

  /// No description provided for @adminPendingVerification.
  ///
  /// In fil, this message translates to:
  /// **'Naghihintay ng verification'**
  String get adminPendingVerification;

  /// No description provided for @adminNothingWaitingTitle.
  ///
  /// In fil, this message translates to:
  /// **'Walang naghihintay ng review'**
  String get adminNothingWaitingTitle;

  /// No description provided for @adminNothingWaitingBody.
  ///
  /// In fil, this message translates to:
  /// **'Lilitaw dito ang mga bagong driver registration.'**
  String get adminNothingWaitingBody;

  /// No description provided for @adminAllDrivers.
  ///
  /// In fil, this message translates to:
  /// **'Lahat ng driver ({count})'**
  String adminAllDrivers(String count);

  /// No description provided for @adminNoDriversTitle.
  ///
  /// In fil, this message translates to:
  /// **'Wala pang driver'**
  String get adminNoDriversTitle;

  /// No description provided for @adminNoDriversBody.
  ///
  /// In fil, this message translates to:
  /// **'Nakalista dito ang mga aprubado at naka-suspend na driver.'**
  String get adminNoDriversBody;

  /// No description provided for @adminDriverMarked.
  ///
  /// In fil, this message translates to:
  /// **'Namarkahan ang driver bilang {status}.'**
  String adminDriverMarked(String status);

  /// No description provided for @adminPlatePhone.
  ///
  /// In fil, this message translates to:
  /// **'{plate} • {phone}'**
  String adminPlatePhone(String plate, String phone);

  /// No description provided for @adminEmailChapter.
  ///
  /// In fil, this message translates to:
  /// **'{email}\n{chapter}'**
  String adminEmailChapter(String email, String chapter);

  /// No description provided for @adminRatingFrom.
  ///
  /// In fil, this message translates to:
  /// **'★ {average} mula sa {count} rating'**
  String adminRatingFrom(String average, String count);

  /// No description provided for @adminApprove.
  ///
  /// In fil, this message translates to:
  /// **'Aprubahan'**
  String get adminApprove;

  /// No description provided for @adminSuspend.
  ///
  /// In fil, this message translates to:
  /// **'I-suspend'**
  String get adminSuspend;

  /// No description provided for @reviewTitle.
  ///
  /// In fil, this message translates to:
  /// **'ID review'**
  String get reviewTitle;

  /// No description provided for @reviewQueueFailed.
  ///
  /// In fil, this message translates to:
  /// **'Hindi mabuksan ang queue'**
  String get reviewQueueFailed;

  /// No description provided for @reviewNothingTitle.
  ///
  /// In fil, this message translates to:
  /// **'Walang naghihintay'**
  String get reviewNothingTitle;

  /// No description provided for @reviewNothingBody.
  ///
  /// In fil, this message translates to:
  /// **'Lilitaw dito ang mga bagong ID na ipinadala.'**
  String get reviewNothingBody;

  /// No description provided for @reviewApproved.
  ///
  /// In fil, this message translates to:
  /// **'Naaprubahan.'**
  String get reviewApproved;

  /// No description provided for @reviewRejected.
  ///
  /// In fil, this message translates to:
  /// **'Hindi tinanggap.'**
  String get reviewRejected;

  /// No description provided for @reviewWhyRejected.
  ///
  /// In fil, this message translates to:
  /// **'Bakit hindi tinanggap?'**
  String get reviewWhyRejected;

  /// No description provided for @reviewReasonHint.
  ///
  /// In fil, this message translates to:
  /// **'Hal. Malabo ang litrato, hindi mabasa ang numero.'**
  String get reviewReasonHint;

  /// No description provided for @reviewCancel.
  ///
  /// In fil, this message translates to:
  /// **'Kanselahin'**
  String get reviewCancel;

  /// No description provided for @reviewSend.
  ///
  /// In fil, this message translates to:
  /// **'Ipadala'**
  String get reviewSend;

  /// No description provided for @reviewRoleDriver.
  ///
  /// In fil, this message translates to:
  /// **'Driver'**
  String get reviewRoleDriver;

  /// No description provided for @reviewRoleCommuter.
  ///
  /// In fil, this message translates to:
  /// **'Commuter'**
  String get reviewRoleCommuter;

  /// No description provided for @reviewOpening.
  ///
  /// In fil, this message translates to:
  /// **'Binubuksan…'**
  String get reviewOpening;

  /// No description provided for @reviewViewId.
  ///
  /// In fil, this message translates to:
  /// **'Tingnan ang ID'**
  String get reviewViewId;

  /// No description provided for @reviewReject.
  ///
  /// In fil, this message translates to:
  /// **'Hindi tanggap'**
  String get reviewReject;

  /// No description provided for @reviewApprove.
  ///
  /// In fil, this message translates to:
  /// **'Aprubahan'**
  String get reviewApprove;

  /// No description provided for @verifyEmailSent.
  ///
  /// In fil, this message translates to:
  /// **'Naipadala ang verification email.'**
  String get verifyEmailSent;

  /// No description provided for @verifyStillNot.
  ///
  /// In fil, this message translates to:
  /// **'Hindi pa rin nakumpirma. Buksan ang link sa email, tapos tingnan ulit.'**
  String get verifyStillNot;

  /// No description provided for @verifyYourAddress.
  ///
  /// In fil, this message translates to:
  /// **'ang address mo'**
  String get verifyYourAddress;

  /// No description provided for @verifyTitle.
  ///
  /// In fil, this message translates to:
  /// **'Kumpirmahin ang email mo'**
  String get verifyTitle;

  /// No description provided for @verifyHeading.
  ///
  /// In fil, this message translates to:
  /// **'Kumpirmahin ang email mo para mabuksan ang admin panel'**
  String get verifyHeading;

  /// No description provided for @verifyBody.
  ///
  /// In fil, this message translates to:
  /// **'Ang pag-sign up ay hindi patunay na sa iyo ang address, kaya hindi ka bibigyan ng admin access ng server hangga\'t hindi nakukumpirma ang {email}.'**
  String verifyBody(String email);

  /// No description provided for @verifySendAgainIn.
  ///
  /// In fil, this message translates to:
  /// **'Ipadala ulit sa {seconds}s'**
  String verifySendAgainIn(String seconds);

  /// No description provided for @verifySendAgain.
  ///
  /// In fil, this message translates to:
  /// **'Ipadala ulit'**
  String get verifySendAgain;

  /// No description provided for @verifySendEmail.
  ///
  /// In fil, this message translates to:
  /// **'Ipadala ang verification email'**
  String get verifySendEmail;

  /// No description provided for @verifyConfirmed.
  ///
  /// In fil, this message translates to:
  /// **'Nakumpirma ko na'**
  String get verifyConfirmed;

  /// No description provided for @verifyCheckSpam.
  ///
  /// In fil, this message translates to:
  /// **'Tingnan ang spam kung hindi pa dumadating. Buksan ang link, bumalik dito, tapos pindutin ang \"Nakumpirma ko na\".'**
  String get verifyCheckSpam;

  /// No description provided for @cfgTitle.
  ///
  /// In fil, this message translates to:
  /// **'Dispatch'**
  String get cfgTitle;

  /// No description provided for @cfgSaved.
  ///
  /// In fil, this message translates to:
  /// **'Na-save ang settings. Live na sa lahat ng phone.'**
  String get cfgSaved;

  /// No description provided for @cfgIntro.
  ///
  /// In fil, this message translates to:
  /// **'Nasa server ang mga halagang ito. Ang pagbabago ay tumatalab sa bawat phone sa loob ng ilang segundo — hindi kailangan ng bagong bersyon ng app.'**
  String get cfgIntro;

  /// No description provided for @cfgMatching.
  ///
  /// In fil, this message translates to:
  /// **'Matching'**
  String get cfgMatching;

  /// No description provided for @cfgRadiusLabel.
  ///
  /// In fil, this message translates to:
  /// **'Search radius (km)'**
  String get cfgRadiusLabel;

  /// No description provided for @cfgRadiusHelp.
  ///
  /// In fil, this message translates to:
  /// **'Hindi kailanman ino-offer ang biyahe sa driver na mas malayo pa rito.'**
  String get cfgRadiusHelp;

  /// No description provided for @cfgTimeoutLabel.
  ///
  /// In fil, this message translates to:
  /// **'Offer timeout (segundo)'**
  String get cfgTimeoutLabel;

  /// No description provided for @cfgTimeoutHelp.
  ///
  /// In fil, this message translates to:
  /// **'Gaano katagal sasagot ang isang driver bago lumipat ang paghahanap.'**
  String get cfgTimeoutHelp;

  /// No description provided for @cfgMaxDriversLabel.
  ///
  /// In fil, this message translates to:
  /// **'Bilang ng driver na susubukan'**
  String get cfgMaxDriversLabel;

  /// No description provided for @cfgMaxDriversHelp.
  ///
  /// In fil, this message translates to:
  /// **'Naka-cap sa 10 — tinatanggihan ng security rules ang mas malalim na paghahanap, kaya ang mas malaking numero ay magbubunga lang ng refused na write.'**
  String get cfgMaxDriversHelp;

  /// No description provided for @cfgSaveSettings.
  ///
  /// In fil, this message translates to:
  /// **'I-save ang settings'**
  String get cfgSaveSettings;

  /// No description provided for @cfgEnterNumber.
  ///
  /// In fil, this message translates to:
  /// **'Maglagay ng numero'**
  String get cfgEnterNumber;

  /// No description provided for @cfgWholeNumbers.
  ///
  /// In fil, this message translates to:
  /// **'Buong numero lang'**
  String get cfgWholeNumbers;

  /// No description provided for @cfgBetween.
  ///
  /// In fil, this message translates to:
  /// **'Dapat nasa pagitan ng {min} at {max}'**
  String cfgBetween(String min, String max);

  /// No description provided for @cfgStopQuestion.
  ///
  /// In fil, this message translates to:
  /// **'Ihinto ang bagong booking?'**
  String get cfgStopQuestion;

  /// No description provided for @cfgStopBody.
  ///
  /// In fil, this message translates to:
  /// **'Hindi makakapag-book ang mga commuter hangga\'t hindi mo ito binubuksan ulit.\n\nNatatapos nang normal ang mga biyaheng kasalukuyang tumatakbo — walang maiiwang nakasakay sa tricycle.'**
  String get cfgStopBody;

  /// No description provided for @cfgCancel.
  ///
  /// In fil, this message translates to:
  /// **'Kanselahin'**
  String get cfgCancel;

  /// No description provided for @cfgStopBookings.
  ///
  /// In fil, this message translates to:
  /// **'Ihinto ang booking'**
  String get cfgStopBookings;

  /// No description provided for @cfgResumed.
  ///
  /// In fil, this message translates to:
  /// **'Tumatanggap na ulit ng booking.'**
  String get cfgResumed;

  /// No description provided for @cfgStopped.
  ///
  /// In fil, this message translates to:
  /// **'Huminto ang booking. Matatapos ang mga biyaheng tumatakbo.'**
  String get cfgStopped;

  /// No description provided for @cfgAccepting.
  ///
  /// In fil, this message translates to:
  /// **'Tumatanggap ng booking'**
  String get cfgAccepting;

  /// No description provided for @cfgStoppedLabel.
  ///
  /// In fil, this message translates to:
  /// **'Huminto ang booking'**
  String get cfgStoppedLabel;

  /// No description provided for @cfgAcceptingHelp.
  ///
  /// In fil, this message translates to:
  /// **'I-off ito para ihinto ang pilot. Tumatalab ito sa bawat phone sa loob ng ilang segundo, at hindi kailangan ng app update.'**
  String get cfgAcceptingHelp;

  /// No description provided for @cfgStoppedHelp.
  ///
  /// In fil, this message translates to:
  /// **'Hindi makakapag-book ang mga commuter. Natatapos nang normal ang mga biyaheng tumatakbo.'**
  String get cfgStoppedHelp;

  /// No description provided for @fbTitle.
  ///
  /// In fil, this message translates to:
  /// **'Feedback'**
  String get fbTitle;

  /// No description provided for @fbNoneTitle.
  ///
  /// In fil, this message translates to:
  /// **'Wala pang report'**
  String get fbNoneTitle;

  /// No description provided for @fbNoneBody.
  ///
  /// In fil, this message translates to:
  /// **'Lilitaw dito ang mga isyu at mungkahing ipinadala mula sa app.'**
  String get fbNoneBody;

  /// No description provided for @fbNeedsAttention.
  ///
  /// In fil, this message translates to:
  /// **'Kailangan ng atensyon ({count})'**
  String fbNeedsAttention(String count);

  /// No description provided for @fbAllHandledTitle.
  ///
  /// In fil, this message translates to:
  /// **'Naasikaso na lahat'**
  String get fbAllHandledTitle;

  /// No description provided for @fbAllHandledBody.
  ///
  /// In fil, this message translates to:
  /// **'Walang bukas na report.'**
  String get fbAllHandledBody;

  /// No description provided for @fbResolved.
  ///
  /// In fil, this message translates to:
  /// **'Naresolba ({count})'**
  String fbResolved(String count);

  /// No description provided for @fbCatIssue.
  ///
  /// In fil, this message translates to:
  /// **'Isyu'**
  String get fbCatIssue;

  /// No description provided for @fbCatSuggestion.
  ///
  /// In fil, this message translates to:
  /// **'Mungkahi'**
  String get fbCatSuggestion;

  /// No description provided for @fbCatQuestion.
  ///
  /// In fil, this message translates to:
  /// **'Tanong'**
  String get fbCatQuestion;

  /// No description provided for @fbCatOther.
  ///
  /// In fil, this message translates to:
  /// **'Iba pa'**
  String get fbCatOther;

  /// No description provided for @fbMarkedResolved.
  ///
  /// In fil, this message translates to:
  /// **'Namarkahang naresolba.'**
  String get fbMarkedResolved;

  /// No description provided for @fbReopened.
  ///
  /// In fil, this message translates to:
  /// **'Binuksan ulit.'**
  String get fbReopened;

  /// No description provided for @fbFromRole.
  ///
  /// In fil, this message translates to:
  /// **'mula sa {role}'**
  String fbFromRole(String role);

  /// No description provided for @fbReopen.
  ///
  /// In fil, this message translates to:
  /// **'Buksan ulit'**
  String get fbReopen;

  /// No description provided for @fbMarkResolved.
  ///
  /// In fil, this message translates to:
  /// **'Markahang naresolba'**
  String get fbMarkResolved;

  /// No description provided for @fbJustNow.
  ///
  /// In fil, this message translates to:
  /// **'ngayon lang'**
  String get fbJustNow;

  /// No description provided for @fbMinutesAgo.
  ///
  /// In fil, this message translates to:
  /// **'{minutes}m ang nakalipas'**
  String fbMinutesAgo(String minutes);

  /// No description provided for @fbHoursAgo.
  ///
  /// In fil, this message translates to:
  /// **'{hours}h ang nakalipas'**
  String fbHoursAgo(String hours);

  /// No description provided for @fbDaysAgo.
  ///
  /// In fil, this message translates to:
  /// **'{days}d ang nakalipas'**
  String fbDaysAgo(String days);

  /// No description provided for @anRides.
  ///
  /// In fil, this message translates to:
  /// **'Biyahe'**
  String get anRides;

  /// No description provided for @anRefresh.
  ///
  /// In fil, this message translates to:
  /// **'I-refresh'**
  String get anRefresh;

  /// No description provided for @anNoRides.
  ///
  /// In fil, this message translates to:
  /// **'Walang biyahe sa window na ito.'**
  String get anNoRides;

  /// No description provided for @anTruncated.
  ///
  /// In fil, this message translates to:
  /// **'Ipinapakita lang ang pinakabagong {cap} biyahe. Bahagi lang ang mga total sa ibaba.'**
  String anTruncated(String cap);

  /// No description provided for @anCompleted.
  ///
  /// In fil, this message translates to:
  /// **'natapos'**
  String get anCompleted;

  /// No description provided for @anCompletionRate.
  ///
  /// In fil, this message translates to:
  /// **'completion rate'**
  String get anCompletionRate;

  /// No description provided for @anCancelled.
  ///
  /// In fil, this message translates to:
  /// **'kinansela'**
  String get anCancelled;

  /// No description provided for @anNoDriverFound.
  ///
  /// In fil, this message translates to:
  /// **'walang nakitang driver'**
  String get anNoDriverFound;

  /// No description provided for @anAvgRating.
  ///
  /// In fil, this message translates to:
  /// **'average na rating'**
  String get anAvgRating;

  /// No description provided for @anUnrated.
  ///
  /// In fil, this message translates to:
  /// **'{unrated} sa {completed} natapos na biyahe ang walang rating.'**
  String anUnrated(String unrated, String completed);

  /// No description provided for @anDaily.
  ///
  /// In fil, this message translates to:
  /// **'Araw-araw'**
  String get anDaily;

  /// No description provided for @anByDriver.
  ///
  /// In fil, this message translates to:
  /// **'Kada driver'**
  String get anByDriver;

  /// No description provided for @anChartLabel.
  ///
  /// In fil, this message translates to:
  /// **'Mga biyahe kada araw. Pinakaabalang araw {peak} biyahe. {days} araw ang ipinapakita.'**
  String anChartLabel(String peak, String days);

  /// No description provided for @anColDriver.
  ///
  /// In fil, this message translates to:
  /// **'Driver'**
  String get anColDriver;

  /// No description provided for @anColDone.
  ///
  /// In fil, this message translates to:
  /// **'Tapos'**
  String get anColDone;

  /// No description provided for @anColCancelled.
  ///
  /// In fil, this message translates to:
  /// **'Kinansela'**
  String get anColCancelled;

  /// No description provided for @anColRating.
  ///
  /// In fil, this message translates to:
  /// **'Rating'**
  String get anColRating;

  /// No description provided for @fsCatProblem.
  ///
  /// In fil, this message translates to:
  /// **'Problema'**
  String get fsCatProblem;

  /// No description provided for @fsCatSuggestion.
  ///
  /// In fil, this message translates to:
  /// **'Mungkahi'**
  String get fsCatSuggestion;

  /// No description provided for @fsCatQuestion.
  ///
  /// In fil, this message translates to:
  /// **'Tanong'**
  String get fsCatQuestion;

  /// No description provided for @fsCatOther.
  ///
  /// In fil, this message translates to:
  /// **'Iba pa'**
  String get fsCatOther;

  /// No description provided for @fsSent.
  ///
  /// In fil, this message translates to:
  /// **'Salamat! Nakarating sa TODA admin ang report mo.'**
  String get fsSent;

  /// No description provided for @fsTitle.
  ///
  /// In fil, this message translates to:
  /// **'Sabihin kung ano ang nangyari'**
  String get fsTitle;

  /// No description provided for @fsSubtitle.
  ///
  /// In fil, this message translates to:
  /// **'Napupunta sa TODA administrator mo ang mga report.'**
  String get fsSubtitle;

  /// No description provided for @fsWhatHappened.
  ///
  /// In fil, this message translates to:
  /// **'Ano ang nangyari?'**
  String get fsWhatHappened;

  /// No description provided for @fsDescribe.
  ///
  /// In fil, this message translates to:
  /// **'Ilarawan ang problema para may magawa ang admin'**
  String get fsDescribe;

  /// No description provided for @fsContact.
  ///
  /// In fil, this message translates to:
  /// **'Contact (opsyonal)'**
  String get fsContact;

  /// No description provided for @fsContactHelper.
  ///
  /// In fil, this message translates to:
  /// **'Kung gusto mo lang ng sagot.'**
  String get fsContactHelper;

  /// No description provided for @fsSend.
  ///
  /// In fil, this message translates to:
  /// **'Ipadala ang report'**
  String get fsSend;

  /// No description provided for @mapPickUpAt.
  ///
  /// In fil, this message translates to:
  /// **'Sunduin sa {place}'**
  String mapPickUpAt(String place);

  /// No description provided for @mapDropOffAt.
  ///
  /// In fil, this message translates to:
  /// **'Ibaba sa {place}'**
  String mapDropOffAt(String place);

  /// No description provided for @mapKm.
  ///
  /// In fil, this message translates to:
  /// **'{km} km'**
  String mapKm(String km);

  /// No description provided for @mapOpenInMaps.
  ///
  /// In fil, this message translates to:
  /// **'Buksan sa maps'**
  String get mapOpenInMaps;

  /// No description provided for @mapNoMapsApp.
  ///
  /// In fil, this message translates to:
  /// **'Walang maps app. Destinasyon: {lat}, {lng}'**
  String mapNoMapsApp(String lat, String lng);
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
