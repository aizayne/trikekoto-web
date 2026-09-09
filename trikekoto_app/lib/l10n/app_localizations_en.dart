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
}
