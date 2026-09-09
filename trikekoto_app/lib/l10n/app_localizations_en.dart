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

  @override
  String get idTitle => 'ID verification';

  @override
  String get idTakePhoto => 'Photograph the ID';

  @override
  String get idGallery => 'Choose from gallery';

  @override
  String get idPhotoRequired => 'A photo of the ID is required.';

  @override
  String get idConsentRequired => 'You need to agree first.';

  @override
  String get idSubmitted => 'Sent. It will be reviewed.';

  @override
  String get idWithdrawQuestion => 'Withdraw the ID?';

  @override
  String get idWithdrawBody =>
      'Your ID photo and details will be deleted. You can send it again at any time.';

  @override
  String get idWithdrawNo => 'No';

  @override
  String get idWithdrawYes => 'Delete';

  @override
  String get idDeleted => 'Your ID has been deleted.';

  @override
  String get idApprovedTitle => 'Verified';

  @override
  String get idApprovedBody => 'The chapter has confirmed your ID.';

  @override
  String get idRejectedTitle => 'Not accepted';

  @override
  String get idNoReason => 'No reason was given.';

  @override
  String get idPendingTitle => 'Waiting for review';

  @override
  String get idPendingBody =>
      'Your ID has been sent. You will be told here once it is reviewed.';

  @override
  String get idTypeRow => 'ID type';

  @override
  String get idNumberRow => 'Number';

  @override
  String get idWithdrawAndDelete => 'Withdraw and delete the ID';

  @override
  String get idWithdrawNote =>
      'This deletes the photo and the details, even if it was already approved.';

  @override
  String get idConfirmIdentity => 'Confirm your identity';

  @override
  String get idWhyDriver =>
      'The TODA chapter needs this before you can take rides.';

  @override
  String get idWhyRider => 'This helps keep everyone safe on a ride.';

  @override
  String get idTypeLabel => 'ID type';

  @override
  String get idNumberLabel => 'ID number';

  @override
  String get idNumberTooShort => 'Too short';

  @override
  String get idNumberTooLong => 'Too long';

  @override
  String get idSubmitForReview => 'Send for review';

  @override
  String get idPhotoTitle => 'Photo of the ID';

  @override
  String get idPhotoHint => 'Make sure the name and number can be read';

  @override
  String get idHowUsedTitle => 'How your ID is used';

  @override
  String get idHowUsedBody =>
      '• Only a TODA chapter officer looks at it, to confirm who you are.\n• No other passenger and no driver of yours can see it.\n• It is deleted 90 days after review, or immediately if you withdraw it.\n• You can delete it at any time from this screen.';

  @override
  String get idConsentLabel =>
      'I agree to my ID being processed for verification.';

  @override
  String get regTitle => 'Driver registration';

  @override
  String get regPendingNote =>
      'New accounts start as Pending. A TODA admin verifies you before you can accept rides.';

  @override
  String get regYourDetails => 'Your details';

  @override
  String get regFirstName => 'First name';

  @override
  String get regLastName => 'Last name';

  @override
  String get regMobile => 'Mobile number';

  @override
  String get regMobileHelper => 'Commuters call this number when you accept.';

  @override
  String get regYourTricycle => 'Your tricycle';

  @override
  String get regPlate => 'Plate number';

  @override
  String get regPlateHelper => 'Shown to the commuter so they find you.';

  @override
  String get regTodaChapter => 'TODA chapter';

  @override
  String get regSignInSection => 'Sign-in';

  @override
  String get regEmail => 'Email';

  @override
  String get regEmailInvalid => 'Enter a valid email address';

  @override
  String get regPassword => 'Password';

  @override
  String get regPasswordHelper => 'At least 6 characters.';

  @override
  String get regShowPassword => 'Show password';

  @override
  String get regHidePassword => 'Hide password';

  @override
  String get regPasswordTooShort => 'Use at least 6 characters';

  @override
  String get regCreateAccount => 'Create account';

  @override
  String regFieldRequired(String label) {
    return 'Enter your $label';
  }

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginWelcome => 'Welcome back';

  @override
  String get loginBody =>
      'Drivers and administrators sign in here. Where you land depends on your account.';

  @override
  String get loginEmailInvalid => 'Enter the email you registered with';

  @override
  String get loginPasswordTooShort => 'At least 6 characters';

  @override
  String get loginRegisterAsDriver => 'Register as a TODA driver';

  @override
  String get adminTitle => 'Admin';

  @override
  String get adminFeedback => 'Feedback';

  @override
  String get adminDispatch => 'Dispatch';

  @override
  String get adminIdReview => 'ID review';

  @override
  String get adminPendingVerification => 'Pending verification';

  @override
  String get adminNothingWaitingTitle => 'Nothing waiting for review';

  @override
  String get adminNothingWaitingBody => 'New driver registrations appear here.';

  @override
  String adminAllDrivers(String count) {
    return 'All drivers ($count)';
  }

  @override
  String get adminNoDriversTitle => 'No drivers yet';

  @override
  String get adminNoDriversBody =>
      'Approved and suspended drivers are listed here.';

  @override
  String adminDriverMarked(String status) {
    return 'Driver marked $status.';
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
    return '★ $average from $count ratings';
  }

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminSuspend => 'Suspend';

  @override
  String get reviewTitle => 'ID review';

  @override
  String get reviewQueueFailed => 'Cannot open the queue';

  @override
  String get reviewNothingTitle => 'Nothing waiting';

  @override
  String get reviewNothingBody => 'Newly submitted IDs appear here.';

  @override
  String get reviewApproved => 'Approved.';

  @override
  String get reviewRejected => 'Not accepted.';

  @override
  String get reviewWhyRejected => 'Why was it not accepted?';

  @override
  String get reviewReasonHint =>
      'e.g. Photo is blurry, the number cannot be read.';

  @override
  String get reviewCancel => 'Cancel';

  @override
  String get reviewSend => 'Send';

  @override
  String get reviewRoleDriver => 'Driver';

  @override
  String get reviewRoleCommuter => 'Commuter';

  @override
  String get reviewOpening => 'Opening…';

  @override
  String get reviewViewId => 'View the ID';

  @override
  String get reviewReject => 'Not accepted';

  @override
  String get reviewApprove => 'Approve';

  @override
  String get verifyEmailSent => 'Verification email sent.';

  @override
  String get verifyStillNot =>
      'Still not confirmed. Open the link in the email, then check again.';

  @override
  String get verifyYourAddress => 'your address';

  @override
  String get verifyTitle => 'Confirm your email';

  @override
  String get verifyHeading => 'Confirm your email to open the admin panel';

  @override
  String verifyBody(String email) {
    return 'Signing up does not prove you own an address, so the server will not grant admin access until $email is confirmed.';
  }

  @override
  String verifySendAgainIn(String seconds) {
    return 'Send again in ${seconds}s';
  }

  @override
  String get verifySendAgain => 'Send again';

  @override
  String get verifySendEmail => 'Send verification email';

  @override
  String get verifyConfirmed => 'I have confirmed it';

  @override
  String get verifyCheckSpam =>
      'Check spam if it has not arrived. Open the link, come back here, then tap \"I have confirmed it\".';

  @override
  String get cfgTitle => 'Dispatch';

  @override
  String get cfgSaved => 'Settings saved. Clients update live.';

  @override
  String get cfgIntro =>
      'These values live on the server. Changing them takes effect on every phone within seconds — no new app version needed.';

  @override
  String get cfgMatching => 'Matching';

  @override
  String get cfgRadiusLabel => 'Search radius (km)';

  @override
  String get cfgRadiusHelp =>
      'Drivers further than this are never offered the ride.';

  @override
  String get cfgTimeoutLabel => 'Offer timeout (seconds)';

  @override
  String get cfgTimeoutHelp =>
      'How long one driver has to answer before the search moves on.';

  @override
  String get cfgMaxDriversLabel => 'Drivers to try';

  @override
  String get cfgMaxDriversHelp =>
      'Capped at 10 — the security rules reject a deeper search, so a larger number here would only produce refused writes.';

  @override
  String get cfgSaveSettings => 'Save settings';

  @override
  String get cfgEnterNumber => 'Enter a number';

  @override
  String get cfgWholeNumbers => 'Whole numbers only';

  @override
  String cfgBetween(String min, String max) {
    return 'Must be between $min and $max';
  }

  @override
  String get cfgStopQuestion => 'Stop new bookings?';

  @override
  String get cfgStopBody =>
      'Commuters will not be able to book until you turn this back on.\n\nRides already in progress finish normally — nobody sitting in a tricycle is stranded.';

  @override
  String get cfgCancel => 'Cancel';

  @override
  String get cfgStopBookings => 'Stop bookings';

  @override
  String get cfgResumed => 'Bookings resumed.';

  @override
  String get cfgStopped => 'Bookings stopped. Rides in progress will finish.';

  @override
  String get cfgAccepting => 'Accepting bookings';

  @override
  String get cfgStoppedLabel => 'Bookings stopped';

  @override
  String get cfgAcceptingHelp =>
      'Turn this off to halt the pilot. It takes effect on every phone within seconds, and needs no app update.';

  @override
  String get cfgStoppedHelp =>
      'Commuters cannot book. Rides already in progress finish normally.';

  @override
  String get fbTitle => 'Feedback';

  @override
  String get fbNoneTitle => 'No reports yet';

  @override
  String get fbNoneBody =>
      'Issues and suggestions sent from the app appear here.';

  @override
  String fbNeedsAttention(String count) {
    return 'Needs attention ($count)';
  }

  @override
  String get fbAllHandledTitle => 'Everything handled';

  @override
  String get fbAllHandledBody => 'No open reports.';

  @override
  String fbResolved(String count) {
    return 'Resolved ($count)';
  }

  @override
  String get fbCatIssue => 'Issue';

  @override
  String get fbCatSuggestion => 'Suggestion';

  @override
  String get fbCatQuestion => 'Question';

  @override
  String get fbCatOther => 'Other';

  @override
  String get fbMarkedResolved => 'Marked resolved.';

  @override
  String get fbReopened => 'Reopened.';

  @override
  String fbFromRole(String role) {
    return 'from a $role';
  }

  @override
  String get fbReopen => 'Reopen';

  @override
  String get fbMarkResolved => 'Mark resolved';

  @override
  String get fbJustNow => 'just now';

  @override
  String fbMinutesAgo(String minutes) {
    return '${minutes}m ago';
  }

  @override
  String fbHoursAgo(String hours) {
    return '${hours}h ago';
  }

  @override
  String fbDaysAgo(String days) {
    return '${days}d ago';
  }

  @override
  String get anRides => 'Rides';

  @override
  String get anRefresh => 'Refresh';

  @override
  String get anNoRides => 'No rides in this window.';

  @override
  String anTruncated(String cap) {
    return 'Showing the most recent $cap rides only. Totals below are partial.';
  }

  @override
  String get anCompleted => 'completed';

  @override
  String get anCompletionRate => 'completion rate';

  @override
  String get anCancelled => 'cancelled';

  @override
  String get anNoDriverFound => 'no driver found';

  @override
  String get anAvgRating => 'avg rating';

  @override
  String anUnrated(String unrated, String completed) {
    return '$unrated of $completed completed rides went unrated.';
  }

  @override
  String get anDaily => 'Daily';

  @override
  String get anByDriver => 'By driver';

  @override
  String anChartLabel(String peak, String days) {
    return 'Daily rides. Busiest day $peak rides. $days days shown.';
  }

  @override
  String get anColDriver => 'Driver';

  @override
  String get anColDone => 'Done';

  @override
  String get anColCancelled => 'Cancelled';

  @override
  String get anColRating => 'Rating';

  @override
  String get fsCatProblem => 'Problem';

  @override
  String get fsCatSuggestion => 'Suggestion';

  @override
  String get fsCatQuestion => 'Question';

  @override
  String get fsCatOther => 'Other';

  @override
  String get fsSent => 'Thanks! Your report reached the TODA admin.';

  @override
  String get fsTitle => 'Tell us what happened';

  @override
  String get fsSubtitle => 'Reports go to your TODA administrator.';

  @override
  String get fsWhatHappened => 'What happened?';

  @override
  String get fsDescribe => 'Describe the problem so an admin can act on it';

  @override
  String get fsContact => 'Contact (optional)';

  @override
  String get fsContactHelper => 'Only if you want a reply.';

  @override
  String get fsSend => 'Send report';

  @override
  String mapPickUpAt(String place) {
    return 'Pick up at $place';
  }

  @override
  String mapDropOffAt(String place) {
    return 'Drop off at $place';
  }

  @override
  String mapKm(String km) {
    return '$km km';
  }

  @override
  String get mapOpenInMaps => 'Open in maps';

  @override
  String mapNoMapsApp(String lat, String lng) {
    return 'No maps app available. Destination: $lat, $lng';
  }
}
