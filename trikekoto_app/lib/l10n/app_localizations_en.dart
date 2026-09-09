// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get landingTagline => 'On-demand tricycle rides for your barangay';

  @override
  String get landingBookRide => 'Book a ride';

  @override
  String get landingStaffSignIn => 'Driver / Admin sign in';

  @override
  String get landingNeedsNumber => 'You need a mobile number to book.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInCodeTitle => 'Enter the code';

  @override
  String get signInAskNumber => 'What is your number?';

  @override
  String get signInWhyNumber =>
      'We will send you a code to confirm it. Your number is not shown to a driver until you book.';

  @override
  String get signInNumberLabel => 'Mobile number';

  @override
  String get signInNumberHelper => '09XX XXX XXXX';

  @override
  String get signInNumberInvalid =>
      'Enter an 11-digit mobile number starting 09';

  @override
  String get signInSending => 'Sending…';

  @override
  String get signInSendCode => 'Send code';

  @override
  String signInCodeSentSnack(String number) {
    return 'Code sent to $number.';
  }

  @override
  String signInCodeSentTo(String number) {
    return 'Six digits, sent to $number.';
  }

  @override
  String get signInEnterSixDigits => 'Enter the six digits from the message.';

  @override
  String get signInConfirm => 'Confirm';

  @override
  String get signInOtherNumber => 'Use a different number';

  @override
  String get authInvalidPhone => 'That does not look like a mobile number.';

  @override
  String get authWrongCode => 'Wrong code. Check the message again.';

  @override
  String get authCodeExpired => 'That code expired. Ask for a new one.';

  @override
  String get authTooManyTries =>
      'Too many tries. Wait a few minutes before asking again.';

  @override
  String get authQuotaExceeded =>
      'Cannot send codes right now. Try again later.';

  @override
  String get authNoConnection => 'No connection. Check your signal.';

  @override
  String get authPhoneSignInOff =>
      'Phone sign-in is switched off for this project.';

  @override
  String get authCaptchaFailed =>
      'The browser check failed. Reload the page and try again.';

  @override
  String get authAppNotRegistered =>
      'This app is not registered for phone sign-in yet.';

  @override
  String get authSiteNotAllowed =>
      'This site is not on the allowed list for sign-in.';

  @override
  String authUnknown(String message, String code) {
    return '$message [$code]';
  }

  @override
  String get authCouldNotVerify => 'Could not verify that number.';

  @override
  String authCouldNotSend(String detail) {
    return 'Could not send the code. ($detail)';
  }

  @override
  String get onboardingTitle => 'Almost done';

  @override
  String get onboardingPhotoOptional => 'Photo — you can skip this';

  @override
  String get onboardingAskName => 'What should we call you?';

  @override
  String get onboardingNameWhy =>
      'This is what the driver sees when they collect you.';

  @override
  String get onboardingStart => 'Start';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameRequired => 'Enter your name';

  @override
  String get nameTooLong => 'Too long';

  @override
  String phoneConfirmed(String number) {
    return '$number — confirmed';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get photoTake => 'Take a photo';

  @override
  String get photoGallery => 'Choose from gallery';

  @override
  String get photoRemove => 'Remove photo';

  @override
  String get photoChange => 'Change profile photo';

  @override
  String get photoAdd => 'Add a profile photo';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSaved => 'Your profile is saved.';

  @override
  String profileNamedSavedNotPhoto(String error) {
    return 'Name saved, but not the photo. $error';
  }

  @override
  String get profileNameHelper => 'This is what the driver sees';

  @override
  String get profilePhotoWillSave => 'The photo saves when you press Save';

  @override
  String get profilePhotoTapToChange => 'Tap the photo to change it';

  @override
  String get profileIdVerification => 'ID verification';

  @override
  String get profileSave => 'Save';

  @override
  String get profileLoadFailedTitle => 'Cannot open your profile';

  @override
  String get profileLoadFailedBody => 'Check your signal, then try again.';

  @override
  String get profileRetry => 'Try again';

  @override
  String get profileNoneTitle => 'No profile';

  @override
  String get profileNoneBody => 'Sign in again to create an account.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountQuestion => 'Delete your account?';

  @override
  String get deleteAccountPermanent => 'Permanently deleted:';

  @override
  String get deleteAccountList =>
      '• Your name and photo\n• Your ID, if you sent one\n• Your saved places\n• Your account — you would need to register again';

  @override
  String get deleteAccountRetained =>
      'Past rides stay as a TODA record — but your name and number are removed from them, so they can no longer be traced to you.';

  @override
  String get deleteAccountIrreversible => 'This cannot be undone.';

  @override
  String get deleteAccountNo => 'No';

  @override
  String get deleteAccountReauth =>
      'For security, sign in again before deleting the account.';

  @override
  String get pickerSearchHint => 'Search a place';

  @override
  String get pickerSearch => 'Search';

  @override
  String pickerNotFound(String query) {
    return 'Nothing called \"$query\" found near here. If it is far away, drag the map there first — or place the pin by hand.';
  }

  @override
  String get pickerPermissionOff =>
      'Location permission is off. Enable it in Settings to centre the map on you.';

  @override
  String get pickerNeedsName =>
      'Give this place a name so your driver recognises it.';

  @override
  String get pickerLocating => 'Locating…';

  @override
  String get pickerMyLocation => 'Where I am now';

  @override
  String get pickerHelp =>
      'Drag the map to place the pin — or search above, or use your location.';

  @override
  String get pickerNameLabel => 'Name this place';

  @override
  String get pickerNameHint => 'e.g. Plaza, Palengke, Barangay Hall';

  @override
  String get pickerConfirm => 'Confirm location';

  @override
  String get bookTitle => 'Book a ride';

  @override
  String get bookWhereTo => 'Where to?';

  @override
  String get bookNearestFirst =>
      'We offer your ride to the nearest available driver first.';

  @override
  String get bookCurrentLocation => 'Current location';

  @override
  String get bookSetPickup => 'Set pickup';

  @override
  String get bookSetDropoff => 'Set drop-off';

  @override
  String get bookSetBoth => 'Set both your pickup and drop-off on the map.';

  @override
  String get bookPickup => 'Pickup';

  @override
  String get bookDropoff => 'Drop-off';

  @override
  String get bookLocating => 'Finding your location…';

  @override
  String get bookSetOnMap => 'Set on map';

  @override
  String get bookYourName => 'Your name';

  @override
  String get bookEnterName => 'Enter your name';

  @override
  String get bookNumberHelper => 'So your driver can reach you.';

  @override
  String get bookNumberInvalid => 'Enter a mobile number the driver can call';

  @override
  String get bookFinding => 'Finding a driver…';

  @override
  String get bookFindDriver => 'Find a driver';

  @override
  String get bookProfile => 'Profile';

  @override
  String get bookReportProblem => 'Report a problem';

  @override
  String get bookExit => 'Exit';

  @override
  String get trackTitle => 'Live tracking';

  @override
  String get trackOnTheWay => 'On the way to your drop-off';

  @override
  String trackKmAway(String km) {
    return '$km km away';
  }

  @override
  String get trackWorkingRoute => 'Working out the route…';

  @override
  String get trackTrip => 'Trip';

  @override
  String trackTripSummary(String km, String minutes) {
    return '$km km$minutes';
  }

  @override
  String trackAboutMinutes(String minutes) {
    return ' · about $minutes min';
  }

  @override
  String get trackApproximate =>
      'Approximate — could not reach the route service';

  @override
  String get trackTryAgain => 'Try again';

  @override
  String get statusSearching => 'Looking for a driver…';

  @override
  String get statusAccepted => 'Driver is on the way';

  @override
  String get statusInTransit => 'On the way to your drop-off';

  @override
  String statusAsked(String depth, String total) {
    return 'Asked $depth of $total nearby drivers';
  }

  @override
  String callDriver(String name) {
    return 'Call $name';
  }

  @override
  String get cancelRide => 'Cancel ride';

  @override
  String dialerFailed(String phone) {
    return 'Could not open the dialler. Number: $phone';
  }

  @override
  String get rateTitle => 'How was your ride?';

  @override
  String get ratePayCash => 'Pay the posted TODA fare in cash.';

  @override
  String get rateThanks => 'Thanks for the rating!';

  @override
  String get driverTitle => 'Driver';

  @override
  String get driverNoProfile => 'No driver profile found.';

  @override
  String get driverIdVerification => 'ID verification';

  @override
  String get driverIdSubtitle => 'Send your licence or ID to the chapter';

  @override
  String get driverVerified => 'Verified TODA driver';

  @override
  String get driverSuspended =>
      'Your account is suspended. You cannot accept rides.';

  @override
  String get driverRejected => 'Your registration was rejected.';

  @override
  String get driverPending =>
      'Pending verification. An admin must approve you before you can accept rides.';

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
      'Your location is visible to nearby commuters';

  @override
  String get driverOfflineSubtitle => 'Go online to receive ride offers';

  @override
  String get driverCurrentRide => 'Current ride';

  @override
  String driverCallCommuter(String name) {
    return 'Call $name';
  }

  @override
  String get driverStartTrip => 'Start trip';

  @override
  String get driverCompleteRide => 'Complete ride';

  @override
  String get driverCancel => 'Cancel';

  @override
  String get driverWaiting => 'Waiting for a ride';

  @override
  String get driverYouAreOffline => 'You are offline';

  @override
  String get driverWaitingBody =>
      'You will be offered the nearest booking as soon as one comes in. Keep this screen open.';

  @override
  String get driverOfflineBody =>
      'Go online above to start receiving ride offers.';

  @override
  String get driverNewOffer => 'New ride offer';

  @override
  String driverRoute(String from, String to) {
    return '$from  →  $to';
  }

  @override
  String get driverDecline => 'Decline';

  @override
  String get driverAccept => 'Accept';

  @override
  String get driverReportProblem => 'Report a problem';
}
