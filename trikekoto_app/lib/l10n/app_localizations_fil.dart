// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class LFil extends L {
  LFil([String locale = 'fil']) : super(locale);

  @override
  String get landingTagline => 'Tricycle rides sa barangay mo, kahit kailan';

  @override
  String get landingBookRide => 'Mag-book ng ride';

  @override
  String get landingStaffSignIn => 'Mag-sign in bilang driver o admin';

  @override
  String get landingNeedsNumber => 'Kailangan ng number para makapag-book.';

  @override
  String get signInTitle => 'Mag-sign in';

  @override
  String get signInCodeTitle => 'Ilagay ang code';

  @override
  String get signInAskNumber => 'Ano ang number mo?';

  @override
  String get signInWhyNumber =>
      'Padadalhan ka namin ng code para makumpirma. Hindi ito ipapakita sa driver hangga\'t hindi ka nagbo-book.';

  @override
  String get signInNumberLabel => 'Mobile number';

  @override
  String get signInNumberHelper => '09XX XXX XXXX';

  @override
  String get signInNumberInvalid =>
      'Maglagay ng 11-digit na number na nagsisimula sa 09';

  @override
  String get signInSending => 'Ipinapadala…';

  @override
  String get signInSendCode => 'Ipadala ang code';

  @override
  String signInCodeSentSnack(String number) {
    return 'Ipinadala ang code sa $number.';
  }

  @override
  String signInCodeSentTo(String number) {
    return 'Anim na numero, ipinadala sa $number.';
  }

  @override
  String get signInEnterSixDigits =>
      'Ilagay ang anim na numero mula sa message.';

  @override
  String get signInConfirm => 'Kumpirmahin';

  @override
  String get signInOtherNumber => 'Ibang number';

  @override
  String get authInvalidPhone => 'Mukhang hindi ito mobile number.';

  @override
  String get authWrongCode => 'Mali ang code. Tingnan ulit ang message.';

  @override
  String get authCodeExpired => 'Nag-expire na ang code. Humingi ng bago.';

  @override
  String get authTooManyTries =>
      'Masyadong maraming subok. Maghintay ng ilang minuto bago ulitin.';

  @override
  String get authQuotaExceeded =>
      'Hindi makapagpadala ng code ngayon. Subukan mamaya.';

  @override
  String get authNoConnection => 'Walang connection. Tingnan ang signal mo.';

  @override
  String get authPhoneSignInOff =>
      'Naka-off ang phone sign-in sa project na ito.';

  @override
  String get authCaptchaFailed =>
      'Hindi pumasa ang browser check. I-reload ang page at subukan ulit.';

  @override
  String get authAppNotRegistered =>
      'Hindi pa naka-register ang app na ito para sa phone sign-in.';

  @override
  String get authSiteNotAllowed =>
      'Wala ang site na ito sa allowed list para sa sign-in.';

  @override
  String authUnknown(String message, String code) {
    return '$message [$code]';
  }

  @override
  String get authCouldNotVerify => 'Hindi ma-verify ang number na iyon.';

  @override
  String authCouldNotSend(String detail) {
    return 'Hindi naipadala ang code. ($detail)';
  }

  @override
  String get onboardingTitle => 'Konti na lang';

  @override
  String get onboardingPhotoOptional => 'Litrato — puwedeng laktawan';

  @override
  String get onboardingAskName => 'Anong itatawag namin sa iyo?';

  @override
  String get onboardingNameWhy =>
      'Ito ang makikita ng driver kapag sinundo ka.';

  @override
  String get onboardingStart => 'Simulan';

  @override
  String get nameLabel => 'Pangalan';

  @override
  String get nameRequired => 'Ilagay ang pangalan mo';

  @override
  String get nameTooLong => 'Masyadong mahaba';

  @override
  String phoneConfirmed(String number) {
    return '$number — nakumpirma na';
  }

  @override
  String get signOut => 'Mag-sign out';

  @override
  String get photoTake => 'Kumuha ng litrato';

  @override
  String get photoGallery => 'Pumili sa gallery';

  @override
  String get photoRemove => 'Alisin ang litrato';

  @override
  String get photoChange => 'Palitan ang profile photo';

  @override
  String get photoAdd => 'Maglagay ng profile photo';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSaved => 'Na-save ang profile mo.';

  @override
  String profileNamedSavedNotPhoto(String error) {
    return 'Na-save ang pangalan, pero hindi ang litrato. $error';
  }

  @override
  String get profileNameHelper => 'Ito ang makikita ng driver';

  @override
  String get profilePhotoWillSave =>
      'Ise-save ang litrato pagpindot mo ng Save';

  @override
  String get profilePhotoTapToChange => 'Pindutin ang litrato para palitan';

  @override
  String get profileIdVerification => 'ID verification';

  @override
  String get profileSave => 'I-save';

  @override
  String get profileLoadFailedTitle => 'Hindi mabuksan ang profile';

  @override
  String get profileLoadFailedBody =>
      'Tingnan ang signal mo, tapos subukang muli.';

  @override
  String get profileRetry => 'Subukang muli';

  @override
  String get profileNoneTitle => 'Walang profile';

  @override
  String get profileNoneBody => 'Mag-sign in muli para makagawa ng account.';

  @override
  String get deleteAccount => 'Burahin ang account';

  @override
  String get deleteAccountQuestion => 'Burahin ang account mo?';

  @override
  String get deleteAccountPermanent => 'Mabubura nang tuluyan:';

  @override
  String get deleteAccountList =>
      '• Ang pangalan at litrato mo\n• Ang ID mo, kung nagpadala ka\n• Ang mga naka-save na lugar\n• Ang account mo — kakailanganin mong magparehistro ulit';

  @override
  String get deleteAccountRetained =>
      'Ang mga naunang biyahe ay mananatili bilang record ng TODA — pero tatanggalin dito ang pangalan at number mo, kaya hindi na ito maiuugnay sa iyo.';

  @override
  String get deleteAccountIrreversible => 'Hindi na ito maibabalik.';

  @override
  String get deleteAccountNo => 'Hindi';

  @override
  String get deleteAccountReauth =>
      'Para sa seguridad, mag-sign in muli bago burahin ang account.';

  @override
  String get pickerSearchHint => 'Maghanap ng lugar';

  @override
  String get pickerSearch => 'Hanapin';

  @override
  String pickerNotFound(String query) {
    return 'Walang nakitang \"$query\" malapit dito. Kung malayo ito, i-drag muna ang mapa papunta roon — o ilagay ang pin nang manu-mano.';
  }

  @override
  String get pickerPermissionOff =>
      'Naka-off ang location permission. I-on ito sa Settings para ma-center ang mapa sa iyo.';

  @override
  String get pickerNeedsName =>
      'Bigyan ng pangalan ang lugar para makilala ito ng driver mo.';

  @override
  String get pickerLocating => 'Hinahanap…';

  @override
  String get pickerMyLocation => 'Nasa akin ngayon';

  @override
  String get pickerHelp =>
      'I-drag ang mapa para ilagay ang pin — o hanapin sa itaas, o gamitin ang location mo.';

  @override
  String get pickerNameLabel => 'Pangalanan ang lugar';

  @override
  String get pickerNameHint => 'hal. Plaza, Palengke, Barangay Hall';

  @override
  String get pickerConfirm => 'Kumpirmahin ang location';

  @override
  String get bookTitle => 'Mag-book ng ride';

  @override
  String get bookWhereTo => 'Saan tayo?';

  @override
  String get bookNearestFirst =>
      'Ino-offer muna namin ang ride mo sa pinakamalapit na driver.';

  @override
  String get bookCurrentLocation => 'Kasalukuyang location';

  @override
  String get bookSetPickup => 'Itakda ang sundo';

  @override
  String get bookSetDropoff => 'Itakda ang babaan';

  @override
  String get bookSetBoth => 'Itakda sa mapa ang sundo at babaan mo.';

  @override
  String get bookPickup => 'Sundo';

  @override
  String get bookDropoff => 'Babaan';

  @override
  String get bookLocating => 'Hinahanap ang location mo…';

  @override
  String get bookSetOnMap => 'Itakda sa mapa';

  @override
  String get bookYourName => 'Pangalan mo';

  @override
  String get bookEnterName => 'Ilagay ang pangalan mo';

  @override
  String get bookNumberHelper => 'Para matawagan ka ng driver mo.';

  @override
  String get bookNumberInvalid => 'Maglagay ng number na matatawagan ng driver';

  @override
  String get bookFinding => 'Naghahanap ng driver…';

  @override
  String get bookFindDriver => 'Maghanap ng driver';

  @override
  String get bookProfile => 'Profile';

  @override
  String get bookReportProblem => 'Mag-report ng problema';

  @override
  String get bookExit => 'Lumabas';

  @override
  String get trackTitle => 'Live tracking';

  @override
  String get trackOnTheWay => 'Papunta na sa babaan mo';

  @override
  String trackKmAway(String km) {
    return '$km km ang layo';
  }

  @override
  String get trackWorkingRoute => 'Kinakalkula ang ruta…';

  @override
  String get trackTrip => 'Biyahe';

  @override
  String trackTripSummary(String km, String minutes) {
    return '$km km$minutes';
  }

  @override
  String trackAboutMinutes(String minutes) {
    return ' · mga $minutes min';
  }

  @override
  String get trackApproximate => 'Tinatantiya — hindi maabot ang route service';

  @override
  String get trackTryAgain => 'Subukang muli';

  @override
  String get statusSearching => 'Naghahanap ng driver…';

  @override
  String get statusAccepted => 'Papunta na ang driver';

  @override
  String get statusInTransit => 'Papunta na sa babaan mo';

  @override
  String statusAsked(String depth, String total) {
    return 'Natanong na ang $depth sa $total malapit na driver';
  }

  @override
  String callDriver(String name) {
    return 'Tawagan si $name';
  }

  @override
  String get cancelRide => 'Kanselahin ang ride';

  @override
  String dialerFailed(String phone) {
    return 'Hindi mabuksan ang dialler. Number: $phone';
  }

  @override
  String get rateTitle => 'Kumusta ang biyahe mo?';

  @override
  String get ratePayCash => 'Bayaran ang nakasaad na TODA fare nang cash.';

  @override
  String get rateThanks => 'Salamat sa rating!';

  @override
  String get driverTitle => 'Driver';

  @override
  String get driverNoProfile => 'Walang nakitang driver profile.';

  @override
  String get driverIdVerification => 'ID verification';

  @override
  String get driverIdSubtitle => 'Ipadala ang lisensya o ID para sa chapter';

  @override
  String get driverVerified => 'Verified TODA driver';

  @override
  String get driverSuspended =>
      'Naka-suspend ang account mo. Hindi ka makakatanggap ng ride.';

  @override
  String get driverRejected => 'Hindi natanggap ang registration mo.';

  @override
  String get driverPending =>
      'Hinihintay ang verification. Kailangan ka munang aprubahan ng admin bago ka makatanggap ng ride.';

  @override
  String driverNamePlate(String name, String plate) {
    return '$name • $plate';
  }

  @override
  String driverRating(String average, String count) {
    return '★ $average ($count)';
  }

  @override
  String get driverOnline => 'Online';

  @override
  String get driverOffline => 'Offline';

  @override
  String get driverOnlineSubtitle =>
      'Nakikita ng malapit na commuter ang location mo';

  @override
  String get driverOfflineSubtitle =>
      'Mag-online para makatanggap ng ride offer';

  @override
  String get driverCurrentRide => 'Kasalukuyang biyahe';

  @override
  String driverCallCommuter(String name) {
    return 'Tawagan si $name';
  }

  @override
  String get driverStartTrip => 'Simulan ang biyahe';

  @override
  String get driverCompleteRide => 'Tapusin ang biyahe';

  @override
  String get driverCancel => 'Kanselahin';

  @override
  String get driverWaiting => 'Naghihintay ng biyahe';

  @override
  String get driverYouAreOffline => 'Naka-offline ka';

  @override
  String get driverWaitingBody =>
      'Ioofer sa iyo ang pinakamalapit na booking pagdating nito. Panatilihing bukas ang screen na ito.';

  @override
  String get driverOfflineBody =>
      'Mag-online sa itaas para makatanggap ng ride offer.';

  @override
  String get driverNewOffer => 'Bagong ride offer';

  @override
  String driverRoute(String from, String to) {
    return '$from  →  $to';
  }

  @override
  String get driverDecline => 'Tanggihan';

  @override
  String get driverAccept => 'Tanggapin';

  @override
  String get driverReportProblem => 'Mag-report ng problema';
}
