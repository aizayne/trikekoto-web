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

  @override
  String get idTitle => 'ID verification';

  @override
  String get idTakePhoto => 'Kunan ng litrato ang ID';

  @override
  String get idGallery => 'Pumili sa gallery';

  @override
  String get idPhotoRequired => 'Kailangan ng litrato ng ID.';

  @override
  String get idConsentRequired => 'Kailangan mong pumayag muna.';

  @override
  String get idSubmitted => 'Naipadala na. Hihintayin ang review.';

  @override
  String get idWithdrawQuestion => 'Bawiin ang ID?';

  @override
  String get idWithdrawBody =>
      'Buburahin ang litrato at ang detalye ng ID mo. Puwede kang magpadala ulit anumang oras.';

  @override
  String get idWithdrawNo => 'Hindi';

  @override
  String get idWithdrawYes => 'Burahin';

  @override
  String get idDeleted => 'Nabura na ang ID mo.';

  @override
  String get idApprovedTitle => 'Beripikado na';

  @override
  String get idApprovedBody => 'Nakumpirma ng chapter ang ID mo.';

  @override
  String get idRejectedTitle => 'Hindi tinanggap';

  @override
  String get idNoReason => 'Walang ibinigay na dahilan.';

  @override
  String get idPendingTitle => 'Hinihintay ang review';

  @override
  String get idPendingBody =>
      'Ipinadala na ang ID mo. Aabisuhan ka dito pagkatapos.';

  @override
  String get idTypeRow => 'Uri ng ID';

  @override
  String get idNumberRow => 'Numero';

  @override
  String get idWithdrawAndDelete => 'Bawiin at burahin ang ID';

  @override
  String get idWithdrawNote =>
      'Buburahin nito ang litrato at ang detalye, kahit na-aprubahan na.';

  @override
  String get idConfirmIdentity => 'Kumpirmahin ang pagkakakilanlan';

  @override
  String get idWhyDriver =>
      'Kailangan ito ng TODA chapter bago ka makatanggap ng biyahe.';

  @override
  String get idWhyRider => 'Nakakatulong ito para ligtas ang lahat sa biyahe.';

  @override
  String get idTypeLabel => 'Uri ng ID';

  @override
  String get idNumberLabel => 'Numero ng ID';

  @override
  String get idNumberTooShort => 'Masyadong maikli';

  @override
  String get idNumberTooLong => 'Masyadong mahaba';

  @override
  String get idSubmitForReview => 'Ipadala para sa review';

  @override
  String get idPhotoTitle => 'Litrato ng ID';

  @override
  String get idPhotoHint => 'Siguraduhing mabasa ang pangalan at numero';

  @override
  String get idHowUsedTitle => 'Paano gagamitin ang ID mo';

  @override
  String get idHowUsedBody =>
      '• Titingnan lang ito ng opisyal ng TODA chapter para kumpirmahin kung sino ka.\n• Hindi ito makikita ng ibang pasahero o ng driver mo.\n• Buburahin ito 90 araw matapos ang review, o kaagad kapag binawi mo.\n• Puwede mong burahin anumang oras dito sa screen na ito.';

  @override
  String get idConsentLabel =>
      'Pumapayag ako na iproseso ang ID ko para sa pagkumpirma.';

  @override
  String get regTitle => 'Driver registration';

  @override
  String get regPendingNote =>
      'Ang bagong account ay Pending muna. May TODA admin na magbe-verify sa iyo bago ka makatanggap ng biyahe.';

  @override
  String get regYourDetails => 'Detalye mo';

  @override
  String get regFirstName => 'Pangalan';

  @override
  String get regLastName => 'Apelyido';

  @override
  String get regMobile => 'Mobile number';

  @override
  String get regMobileHelper =>
      'Ito ang tatawagan ng commuter kapag tinanggap mo.';

  @override
  String get regYourTricycle => 'Tricycle mo';

  @override
  String get regPlate => 'Plate number';

  @override
  String get regPlateHelper => 'Ipapakita sa commuter para makita ka nila.';

  @override
  String get regTodaChapter => 'TODA chapter';

  @override
  String get regSignInSection => 'Sign-in';

  @override
  String get regEmail => 'Email';

  @override
  String get regEmailInvalid => 'Maglagay ng tamang email address';

  @override
  String get regPassword => 'Password';

  @override
  String get regPasswordHelper => 'Hindi bababa sa 6 na karakter.';

  @override
  String get regShowPassword => 'Ipakita ang password';

  @override
  String get regHidePassword => 'Itago ang password';

  @override
  String get regPasswordTooShort => 'Gumamit ng hindi bababa sa 6 na karakter';

  @override
  String get regCreateAccount => 'Gumawa ng account';

  @override
  String regFieldRequired(String label) {
    return 'Ilagay ang $label';
  }

  @override
  String get loginTitle => 'Mag-sign in';

  @override
  String get loginWelcome => 'Maligayang pagbabalik';

  @override
  String get loginBody =>
      'Dito nagsa-sign in ang mga driver at administrator. Nakadepende sa account mo kung saan ka mapupunta.';

  @override
  String get loginEmailInvalid =>
      'Ilagay ang email na ginamit mo sa pagpaparehistro';

  @override
  String get loginPasswordTooShort => 'Hindi bababa sa 6 na karakter';

  @override
  String get loginRegisterAsDriver => 'Magparehistro bilang TODA driver';

  @override
  String get adminTitle => 'Admin';

  @override
  String get adminFeedback => 'Feedback';

  @override
  String get adminDispatch => 'Dispatch';

  @override
  String get adminIdReview => 'ID review';

  @override
  String get adminPendingVerification => 'Naghihintay ng verification';

  @override
  String get adminNothingWaitingTitle => 'Walang naghihintay ng review';

  @override
  String get adminNothingWaitingBody =>
      'Lilitaw dito ang mga bagong driver registration.';

  @override
  String adminAllDrivers(String count) {
    return 'Lahat ng driver ($count)';
  }

  @override
  String get adminNoDriversTitle => 'Wala pang driver';

  @override
  String get adminNoDriversBody =>
      'Nakalista dito ang mga aprubado at naka-suspend na driver.';

  @override
  String adminDriverMarked(String status) {
    return 'Namarkahan ang driver bilang $status.';
  }

  @override
  String adminPlatePhone(String plate, String phone) {
    return '$plate • $phone';
  }

  @override
  String adminEmailChapter(String email, String chapter) {
    return '$email\n$chapter';
  }

  @override
  String adminRatingFrom(String average, String count) {
    return '★ $average mula sa $count rating';
  }

  @override
  String get adminApprove => 'Aprubahan';

  @override
  String get adminSuspend => 'I-suspend';

  @override
  String get reviewTitle => 'ID review';

  @override
  String get reviewQueueFailed => 'Hindi mabuksan ang queue';

  @override
  String get reviewNothingTitle => 'Walang naghihintay';

  @override
  String get reviewNothingBody =>
      'Lilitaw dito ang mga bagong ID na ipinadala.';

  @override
  String get reviewApproved => 'Naaprubahan.';

  @override
  String get reviewRejected => 'Hindi tinanggap.';

  @override
  String get reviewWhyRejected => 'Bakit hindi tinanggap?';

  @override
  String get reviewReasonHint =>
      'Hal. Malabo ang litrato, hindi mabasa ang numero.';

  @override
  String get reviewCancel => 'Kanselahin';

  @override
  String get reviewSend => 'Ipadala';

  @override
  String get reviewRoleDriver => 'Driver';

  @override
  String get reviewRoleCommuter => 'Commuter';

  @override
  String get reviewOpening => 'Binubuksan…';

  @override
  String get reviewViewId => 'Tingnan ang ID';

  @override
  String get reviewReject => 'Hindi tanggap';

  @override
  String get reviewApprove => 'Aprubahan';

  @override
  String get verifyEmailSent => 'Naipadala ang verification email.';

  @override
  String get verifyStillNot =>
      'Hindi pa rin nakumpirma. Buksan ang link sa email, tapos tingnan ulit.';

  @override
  String get verifyYourAddress => 'ang address mo';

  @override
  String get verifyTitle => 'Kumpirmahin ang email mo';

  @override
  String get verifyHeading =>
      'Kumpirmahin ang email mo para mabuksan ang admin panel';

  @override
  String verifyBody(String email) {
    return 'Ang pag-sign up ay hindi patunay na sa iyo ang address, kaya hindi ka bibigyan ng admin access ng server hangga\'t hindi nakukumpirma ang $email.';
  }

  @override
  String verifySendAgainIn(String seconds) {
    return 'Ipadala ulit sa ${seconds}s';
  }

  @override
  String get verifySendAgain => 'Ipadala ulit';

  @override
  String get verifySendEmail => 'Ipadala ang verification email';

  @override
  String get verifyConfirmed => 'Nakumpirma ko na';

  @override
  String get verifyCheckSpam =>
      'Tingnan ang spam kung hindi pa dumadating. Buksan ang link, bumalik dito, tapos pindutin ang \"Nakumpirma ko na\".';

  @override
  String get cfgTitle => 'Dispatch';

  @override
  String get cfgSaved => 'Na-save ang settings. Live na sa lahat ng phone.';

  @override
  String get cfgIntro =>
      'Nasa server ang mga halagang ito. Ang pagbabago ay tumatalab sa bawat phone sa loob ng ilang segundo — hindi kailangan ng bagong bersyon ng app.';

  @override
  String get cfgMatching => 'Matching';

  @override
  String get cfgRadiusLabel => 'Search radius (km)';

  @override
  String get cfgRadiusHelp =>
      'Hindi kailanman ino-offer ang biyahe sa driver na mas malayo pa rito.';

  @override
  String get cfgTimeoutLabel => 'Offer timeout (segundo)';

  @override
  String get cfgTimeoutHelp =>
      'Gaano katagal sasagot ang isang driver bago lumipat ang paghahanap.';

  @override
  String get cfgMaxDriversLabel => 'Bilang ng driver na susubukan';

  @override
  String get cfgMaxDriversHelp =>
      'Naka-cap sa 10 — tinatanggihan ng security rules ang mas malalim na paghahanap, kaya ang mas malaking numero ay magbubunga lang ng refused na write.';

  @override
  String get cfgSaveSettings => 'I-save ang settings';

  @override
  String get cfgEnterNumber => 'Maglagay ng numero';

  @override
  String get cfgWholeNumbers => 'Buong numero lang';

  @override
  String cfgBetween(String min, String max) {
    return 'Dapat nasa pagitan ng $min at $max';
  }

  @override
  String get cfgStopQuestion => 'Ihinto ang bagong booking?';

  @override
  String get cfgStopBody =>
      'Hindi makakapag-book ang mga commuter hangga\'t hindi mo ito binubuksan ulit.\n\nNatatapos nang normal ang mga biyaheng kasalukuyang tumatakbo — walang maiiwang nakasakay sa tricycle.';

  @override
  String get cfgCancel => 'Kanselahin';

  @override
  String get cfgStopBookings => 'Ihinto ang booking';

  @override
  String get cfgResumed => 'Tumatanggap na ulit ng booking.';

  @override
  String get cfgStopped =>
      'Huminto ang booking. Matatapos ang mga biyaheng tumatakbo.';

  @override
  String get cfgAccepting => 'Tumatanggap ng booking';

  @override
  String get cfgStoppedLabel => 'Huminto ang booking';

  @override
  String get cfgAcceptingHelp =>
      'I-off ito para ihinto ang pilot. Tumatalab ito sa bawat phone sa loob ng ilang segundo, at hindi kailangan ng app update.';

  @override
  String get cfgStoppedHelp =>
      'Hindi makakapag-book ang mga commuter. Natatapos nang normal ang mga biyaheng tumatakbo.';

  @override
  String get fbTitle => 'Feedback';

  @override
  String get fbNoneTitle => 'Wala pang report';

  @override
  String get fbNoneBody =>
      'Lilitaw dito ang mga isyu at mungkahing ipinadala mula sa app.';

  @override
  String fbNeedsAttention(String count) {
    return 'Kailangan ng atensyon ($count)';
  }

  @override
  String get fbAllHandledTitle => 'Naasikaso na lahat';

  @override
  String get fbAllHandledBody => 'Walang bukas na report.';

  @override
  String fbResolved(String count) {
    return 'Naresolba ($count)';
  }

  @override
  String get fbCatIssue => 'Isyu';

  @override
  String get fbCatSuggestion => 'Mungkahi';

  @override
  String get fbCatQuestion => 'Tanong';

  @override
  String get fbCatOther => 'Iba pa';

  @override
  String get fbMarkedResolved => 'Namarkahang naresolba.';

  @override
  String get fbReopened => 'Binuksan ulit.';

  @override
  String fbFromRole(String role) {
    return 'mula sa $role';
  }

  @override
  String get fbReopen => 'Buksan ulit';

  @override
  String get fbMarkResolved => 'Markahang naresolba';

  @override
  String get fbJustNow => 'ngayon lang';

  @override
  String fbMinutesAgo(String minutes) {
    return '${minutes}m ang nakalipas';
  }

  @override
  String fbHoursAgo(String hours) {
    return '${hours}h ang nakalipas';
  }

  @override
  String fbDaysAgo(String days) {
    return '${days}d ang nakalipas';
  }

  @override
  String get anRides => 'Biyahe';

  @override
  String get anRefresh => 'I-refresh';

  @override
  String get anNoRides => 'Walang biyahe sa window na ito.';

  @override
  String anTruncated(String cap) {
    return 'Ipinapakita lang ang pinakabagong $cap biyahe. Bahagi lang ang mga total sa ibaba.';
  }

  @override
  String get anCompleted => 'natapos';

  @override
  String get anCompletionRate => 'completion rate';

  @override
  String get anCancelled => 'kinansela';

  @override
  String get anNoDriverFound => 'walang nakitang driver';

  @override
  String get anAvgRating => 'average na rating';

  @override
  String anUnrated(String unrated, String completed) {
    return '$unrated sa $completed natapos na biyahe ang walang rating.';
  }

  @override
  String get anDaily => 'Araw-araw';

  @override
  String get anByDriver => 'Kada driver';

  @override
  String anChartLabel(String peak, String days) {
    return 'Mga biyahe kada araw. Pinakaabalang araw $peak biyahe. $days araw ang ipinapakita.';
  }

  @override
  String get anColDriver => 'Driver';

  @override
  String get anColDone => 'Tapos';

  @override
  String get anColCancelled => 'Kinansela';

  @override
  String get anColRating => 'Rating';

  @override
  String get fsCatProblem => 'Problema';

  @override
  String get fsCatSuggestion => 'Mungkahi';

  @override
  String get fsCatQuestion => 'Tanong';

  @override
  String get fsCatOther => 'Iba pa';

  @override
  String get fsSent => 'Salamat! Nakarating sa TODA admin ang report mo.';

  @override
  String get fsTitle => 'Sabihin kung ano ang nangyari';

  @override
  String get fsSubtitle => 'Napupunta sa TODA administrator mo ang mga report.';

  @override
  String get fsWhatHappened => 'Ano ang nangyari?';

  @override
  String get fsDescribe => 'Ilarawan ang problema para may magawa ang admin';

  @override
  String get fsContact => 'Contact (opsyonal)';

  @override
  String get fsContactHelper => 'Kung gusto mo lang ng sagot.';

  @override
  String get fsSend => 'Ipadala ang report';

  @override
  String mapPickUpAt(String place) {
    return 'Sunduin sa $place';
  }

  @override
  String mapDropOffAt(String place) {
    return 'Ibaba sa $place';
  }

  @override
  String mapKm(String km) {
    return '$km km';
  }

  @override
  String get mapOpenInMaps => 'Buksan sa maps';

  @override
  String mapNoMapsApp(String lat, String lng) {
    return 'Walang maps app. Destinasyon: $lat, $lng';
  }

  @override
  String get idGateTitle => 'Kailangan ng verified na ID';

  @override
  String get idGateBody =>
      'Para protektahan ang mga pasahero at driver laban sa scam at troll, kinukumpirma ng TODA chapter ang ID mo bago magamit ang TrikeKoTo. Kapag naaprubahan, may lalabas na Magpatuloy dito.';

  @override
  String get idContinue => 'Magpatuloy';
}
