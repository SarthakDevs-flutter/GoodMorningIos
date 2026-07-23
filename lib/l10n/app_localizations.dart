import 'package:flutter/material.dart';

/// App-wide localized strings
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String _t(String key) =>
      _allStrings[locale.languageCode]?[key] ?? _allStrings['en']![key]!;
  String get appTitle => _t('appTitle');
  String get save => _t('save');
  String get cancel => _t('cancel');
  String get retry => _t('retry');
  String get settings => _t('settings');
  String get language => _t('language');
  String get selectLanguage => _t('selectLanguage');
  String get scripturePlan => _t('scripturePlan');
  String get selectScripturePlan => _t('selectScripturePlan');
  String get scripturePlanDaily => _t('scripturePlanDaily');
  String get scripturePlanDailySubtitle => _t('scripturePlanDailySubtitle');
  String get scripturePlanBeloved52 => _t('scripturePlanBeloved52');
  String get scripturePlanBeloved52Subtitle =>
      _t('scripturePlanBeloved52Subtitle');
  String get missionContent => _t('missionContent');
  String get selectMissionContent => _t('selectMissionContent');
  String get missionContentScriptureAndPrayer =>
      _t('missionContentScriptureAndPrayer');
  String get missionContentScriptureAndPrayerSubtitle =>
      _t('missionContentScriptureAndPrayerSubtitle');
  String get missionContentScriptureOnly => _t('missionContentScriptureOnly');
  String get missionContentScriptureOnlySubtitle =>
      _t('missionContentScriptureOnlySubtitle');
  String get missionContentPrayerOnly => _t('missionContentPrayerOnly');
  String get missionContentPrayerOnlySubtitle =>
      _t('missionContentPrayerOnlySubtitle');

  // ── Home ──
  String get morningPrayerEveningBlessing => _t('morningPrayerEveningBlessing');
  String get tapTimeToSetAlarm => _t('tapTimeToSetAlarm');
  String get tapToSetTimeAndSound => _t('tapToSetTimeAndSound');
  String get circleTapToOpen => _t('circleTapToOpen');
  String get webPreviewBanner => _t('webPreviewBanner');
  String get morningAlarm => _t('morningAlarm');
  String get eveningBlessing => _t('eveningBlessing');
  String get alarmOn => _t('alarmOn');
  String get alarmOff => _t('alarmOff');
  String get previewMorningAlarm => _t('previewMorningAlarm');
  String get previewEveningBlessing => _t('previewEveningBlessing');
  String get yourCircle => _t('yourCircle');
  String get localWeather => _t('localWeather');
  String get localWeatherSubtitle => _t('localWeatherSubtitle');
  String get localWeatherLoading => _t('localWeatherLoading');
  String get localWeatherSettingsBody => _t('localWeatherSettingsBody');
  String get enableLocalWeather => _t('enableLocalWeather');
  String get weatherRefresh => _t('weatherRefresh');
  String get weatherThisWeek => _t('weatherThisWeek');
  String get weatherPermissionRequired => _t('weatherPermissionRequired');
  String get weatherLocationServicesOff => _t('weatherLocationServicesOff');
  String get weatherUnavailable => _t('weatherUnavailable');
  String get weatherEnabled => _t('weatherEnabled');
  String get weatherDisabled => _t('weatherDisabled');
  String get weatherAttribution => _t('weatherAttribution');
  String get weatherTemperatureUnit => _t('weatherTemperatureUnit');
  String get weatherUnitFahrenheit => _t('weatherUnitFahrenheit');
  String get weatherUnitCelsius => _t('weatherUnitCelsius');
  String weatherFeelsLike(String temp) =>
      _t('weatherFeelsLike').replaceAll('{temp}', temp);
  String weatherWind(int speed, String unit) => _t(
    'weatherWind',
  ).replaceAll('{speed}', speed.toString()).replaceAll('{unit}', unit);
  String weatherRainChance(int chance) =>
      _t('weatherRainChance').replaceAll('{chance}', chance.toString());
  String weatherHighLow(String high, String low) =>
      _t('weatherHighLow').replaceAll('{high}', high).replaceAll('{low}', low);

  // ── Settings ──
  String get enableMorningAlarm => _t('enableMorningAlarm');
  String get morningAlarmSubtitle => _t('morningAlarmSubtitle');
  String get repeatDays => _t('repeatDays');
  String get perDayTimesTitle => _t('perDayTimesTitle');
  String get alarmsTitle => _t('alarmsTitle');
  String get addAlarm => _t('addAlarm');
  String get deleteAlarmTitle => _t('deleteAlarmTitle');
  String get everyDay => _t('everyDay');
  String get maxAlarmsReached => _t('maxAlarmsReached');
  String get cannotDeleteLastAlarm => _t('cannotDeleteLastAlarm');
  String get alarmListHint => _t('alarmListHint');
  String get streakCalendarSubtitle => _t('streakCalendarSubtitle');
  String get calendarTab => _t('calendarTab');
  String get homeTab => _t('homeTab');
  String get weatherTab => _t('weatherTab');
  String get showLocalWeather => _t('showLocalWeather');
  String get myLocation => _t('myLocation');
  String get tenDayForecast => _t('tenDayForecast');
  String get nowLabel => _t('nowLabel');
  String get todayLabel => _t('todayLabel');
  String streakTotalDays(int days) =>
      _t('streakTotalDays').replaceAll('{days}', '$days');
  String get perDayTimesSubtitle => _t('perDayTimesSubtitle');
  String setTimeForDay(String day) =>
      _t('setTimeForDay').replaceAll('{day}', day);
  String get selectAtLeastOneAlarmDay => _t('selectAtLeastOneAlarmDay');
  String get weekdayShortMonday => _t('weekdayShortMonday');
  String get weekdayShortTuesday => _t('weekdayShortTuesday');
  String get weekdayShortWednesday => _t('weekdayShortWednesday');
  String get weekdayShortThursday => _t('weekdayShortThursday');
  String get weekdayShortFriday => _t('weekdayShortFriday');
  String get weekdayShortSaturday => _t('weekdayShortSaturday');
  String get weekdayShortSunday => _t('weekdayShortSunday');
  String get setAlarmTime => _t('setAlarmTime');
  String get morningAlarmOffHint => _t('morningAlarmOffHint');
  String get eveningChildrenBlessing => _t('eveningChildrenBlessing');
  String get eveningBlessingOffHint => _t('eveningBlessingOffHint');
  String get enableEveningBlessing => _t('enableEveningBlessing');
  String get eveningBlessingSubtitle => _t('eveningBlessingSubtitle');
  String get saveAlarms => _t('saveAlarms');
  String get testMorningAlarm => _t('testMorningAlarm');
  String get testEveningAlarm => _t('testEveningAlarm');
  String get practiceMission => _t('practiceMission');
  String get practiceMissionSubtitle => _t('practiceMissionSubtitle');
  String get missionPassThreshold => _t('missionPassThreshold');
  String get missionPassThresholdSubtitle => _t('missionPassThresholdSubtitle');
  String get missionPassThresholdLow => _t('missionPassThresholdLow');
  String get missionPassThresholdHigh => _t('missionPassThresholdHigh');
  String get alarmsSaved => _t('alarmsSaved');
  String get saving => _t('saving');
  String get signOut => _t('signOut');
  String get home => _t('home');
  String get backToMain => _t('backToMain');
  String get premiumTitle => _t('premiumTitle');
  String get premiumSettingsSubtitle => _t('premiumSettingsSubtitle');
  String get premiumHeroTitle => _t('premiumHeroTitle');
  String get premiumHeroSubtitle => _t('premiumHeroSubtitle');
  String get premiumMonthlyTitle => _t('premiumMonthlyTitle');
  String get premiumMonthlyPrice => _t('premiumMonthlyPrice');
  String get premiumAnnualTitle => _t('premiumAnnualTitle');
  String get premiumAnnualPrice => _t('premiumAnnualPrice');
  String get premiumTrialLabel => _t('premiumTrialLabel');
  String get premiumMonthlyTrialTerms => _t('premiumMonthlyTrialTerms');
  String get premiumAnnualTrialTerms => _t('premiumAnnualTrialTerms');
  String get premiumFeatureAlarm => _t('premiumFeatureAlarm');
  String get premiumFeaturePlans => _t('premiumFeaturePlans');
  String get premiumFeatureLanguages => _t('premiumFeatureLanguages');
  String get premiumFeatureWeather => _t('premiumFeatureWeather');
  String get premiumStartTrial => _t('premiumStartTrial');
  String get premiumRestore => _t('premiumRestore');
  String get premiumManageSubscription => _t('premiumManageSubscription');
  String get premiumTerms => _t('premiumTerms');
  String get premiumCancelAnytime => _t('premiumCancelAnytime');
  String get premiumLoadingProducts => _t('premiumLoadingProducts');
  String get premiumProductsUnavailable => _t('premiumProductsUnavailable');
  String get premiumPurchaseSuccess => _t('premiumPurchaseSuccess');
  String get premiumPurchasePending => _t('premiumPurchasePending');
  String get premiumPurchaseCancelled => _t('premiumPurchaseCancelled');
  String get premiumPurchaseFailed => _t('premiumPurchaseFailed');
  String get premiumRestoreMissing => _t('premiumRestoreMissing');
  String get premiumPurchaseUnavailable => _t('premiumPurchaseUnavailable');
  String get premiumOpenSubscriptionFailed =>
      _t('premiumOpenSubscriptionFailed');
  String get termsOfUse => _t('termsOfUse');
  String get privacyPolicy => _t('privacyPolicy');
  String get openLinkFailed => _t('openLinkFailed');

  // ── Alarm sound ──
  String get alarmSound => _t('alarmSound');
  String get alarmSoundDescription => _t('alarmSoundDescription');
  String get alarmSoundDescriptionIos => _t('alarmSoundDescriptionIos');
  String get soundClassicAlarm => _t('soundClassicAlarm');
  String get soundGentleChime => _t('soundGentleChime');
  String get soundChurchBell => _t('soundChurchBell');
  String get moreIphoneSounds => _t('moreIphoneSounds');
  String currentAlarmSound(String name) =>
      _t('currentAlarmSound').replaceAll('{name}', name);
  String get savedAlarmSoundBadge => _t('savedAlarmSoundBadge');
  String get systemAlarmSound => _t('systemAlarmSound');
  String get systemNotificationSound => _t('systemNotificationSound');
  String get systemRingtoneSound => _t('systemRingtoneSound');
  String get chooseFromPhoneSounds => _t('chooseFromPhoneSounds');
  String get previewSound => _t('previewSound');
  String get soundSaved => _t('soundSaved');
  String get noRingtonesFound => _t('noRingtonesFound');

  // ── Onboarding ──
  String get notificationsPermissionTitle => _t('notificationsPermissionTitle');
  String get notificationsPermissionBody => _t('notificationsPermissionBody');
  String get allowNotifications => _t('allowNotifications');
  String get onboardingNext => _t('onboardingNext');
  String get onboardingEnableAndStart => _t('onboardingEnableAndStart');
  String get onboardingProductTitle => _t('onboardingProductTitle');
  String get onboardingProductBody => _t('onboardingProductBody');
  String get onboardingProductPointOneVerse =>
      _t('onboardingProductPointOneVerse');
  String get onboardingProductPointFirstMinute =>
      _t('onboardingProductPointFirstMinute');
  String get onboardingReadTitle => _t('onboardingReadTitle');
  String get onboardingReadBody => _t('onboardingReadBody');
  String get onboardingReadPointVoiceType => _t('onboardingReadPointVoiceType');
  String get onboardingReadPointAmen => _t('onboardingReadPointAmen');
  String get onboardingAlarmTitle => _t('onboardingAlarmTitle');
  String get onboardingAlarmBody => _t('onboardingAlarmBody');
  String get onboardingAlarmPointClosed => _t('onboardingAlarmPointClosed');
  String get onboardingAlarmPointReturn => _t('onboardingAlarmPointReturn');
  String get onboardingPermissionsTitle => _t('onboardingPermissionsTitle');
  String get onboardingPermissionsBody => _t('onboardingPermissionsBody');
  String get commandCopied => _t('commandCopied');

  // ── Circle ──
  String get walkTogether => _t('walkTogether');
  String get circleInviteDescription => _t('circleInviteDescription');
  String get createCircle => _t('createCircle');
  String get joinCircle => _t('joinCircle');
  String get circleNameHint => _t('circleNameHint');
  String get circleIdHint => _t('circleIdHint');
  String get membersCount => _t('membersCount');
  String get thisWeekMorning => _t('thisWeekMorning');
  String get demoCircleBanner => _t('demoCircleBanner');
  String get localCircleBanner => _t('localCircleBanner');
  String get enterCircleName => _t('enterCircleName');
  String get circleCreated => _t('circleCreated');
  String get enterCircleId => _t('enterCircleId');
  String get joinedCircle => _t('joinedCircle');
  String get sentEncouragement => _t('sentEncouragement');
  String get likeSaveFailed => _t('likeSaveFailed');
  String get morningDoneToday => _t('morningDoneToday');
  String get morningNotYetToday => _t('morningNotYetToday');
  String get sendPrayerForTomorrow => _t('sendPrayerForTomorrow');
  String get prayerAcceptHint => _t('prayerAcceptHint');
  String get unlike => _t('unlike');
  String get sendLike => _t('sendLike');
  String get doneToday => _t('doneToday');
  String get notYetToday => _t('notYetToday');
  String get morningMonSun => _t('morningMonSun');
  String get eveningMonSun => _t('eveningMonSun');
  String get notYet => _t('notYet');
  String get liked => _t('liked');
  String get like => _t('like');
  String get prayer => _t('prayer');
  String get inviteFriend => _t('inviteFriend');
  String get addMember => _t('addMember');
  String get friendName => _t('friendName');
  String get inviteByEmailOrPhone => _t('inviteByEmailOrPhone');
  String get email => _t('email');
  String get phoneNumber => _t('phoneNumber');
  String get sendInvite => _t('sendInvite');
  String get inviteSent => _t('inviteSent');
  String get inviteSentExistingUser => _t('inviteSentExistingUser');
  String get inviteFailed => _t('inviteFailed');
  String get enterEmailOrPhone => _t('enterEmailOrPhone');
  String get invalidEmail => _t('invalidEmail');
  String get invalidPhone => _t('invalidPhone');
  String get alreadyInCircle => _t('alreadyInCircle');
  String get prayerConfirmedTomorrow => _t('prayerConfirmedTomorrow');
  String get prayerRequestsForYou => _t('prayerRequestsForYou');
  String get circleLikePrayerHint => _t('circleLikePrayerHint');
  String get circleActivity => _t('circleActivity');
  String get sentPrayerRequests => _t('sentPrayerRequests');
  String get markAllRead => _t('markAllRead');
  String get friendPrayedForYou => _t('friendPrayedForYou');
  String get sendPrayerTopic => _t('sendPrayerTopic');
  String likedYouThisWeek(String name) =>
      _t('likedYouThisWeek').replaceAll('{name}', name);
  String get onePrayerPerDayWeek => _t('onePrayerPerDayWeek');
  String get schedulePrayer => _t('schedulePrayer');
  String get pickDayThisWeek => _t('pickDayThisWeek');
  String get dayBooked => _t('dayBooked');
  String get circlePrayer => _t('circlePrayer');
  String get createCirclePrayer => _t('createCirclePrayer');
  String get circlePrayersThisWeek => _t('circlePrayersThisWeek');
  String get circlePrayerTogether => _t('circlePrayerTogether');
  String get weekPrayersCircle => _t('weekPrayersCircle');
  String get importantDayLabel => _t('importantDayLabel');
  String get prayerTopic => _t('prayerTopic');
  String get pickADay => _t('pickADay');
  String get scheduled => _t('scheduled');
  String get circlePrayerCreated => _t('circlePrayerCreated');
  String get scheduleFailed => _t('scheduleFailed');
  String get fromLabel => _t('fromLabel');
  String get forYouTomorrow => _t('forYouTomorrow');
  String get decline => _t('decline');
  String get prayTomorrow => _t('prayTomorrow');
  String get tomorrowsPrayersCircle => _t('tomorrowsPrayersCircle');
  String get circlePrayerFeedSubtitle => _t('circlePrayerFeedSubtitle');
  String get pending => _t('pending');
  String get accepted => _t('accepted');
  String get declined => _t('declined');
  String get sendPrayerRequest => _t('sendPrayerRequest');
  String get toLabel => _t('toLabel');
  String get prayerRecipientChoose => _t('prayerRecipientChoose');
  String get optionalOpener => _t('optionalOpener');
  String get requiredPrayer => _t('requiredPrayer');
  String get send => _t('send');
  String get friendPrayerConfirmed => _t('friendPrayerConfirmed');
  String get prayerRequestSent => _t('prayerRequestSent');
  String get prayerAcceptedOneOnly => _t('prayerAcceptedOneOnly');
  String get acceptFailed => _t('acceptFailed');
  String get prayerDeclined => _t('prayerDeclined');
  String get declineFailed => _t('declineFailed');
  String get prayerDemoSent => _t('prayerDemoSent');
  String prayingWithYouMessage(String name) =>
      _t('prayingWithYou').replaceAll('{name}', name);

  // ── Alarm ──
  String get timeToMeetLord => _t('timeToMeetLord');
  String get stopWithPrayerAndWord => _t('stopWithPrayerAndWord');
  String get todaysPrayer => _t('todaysPrayer');
  String get todaysWord => _t('todaysWord');
  String get listening => _t('listening');
  String get completeWebDemo => _t('completeWebDemo');
  String get nextStepWebDemo => _t('nextStepWebDemo');
  String get continueToNextStep => _t('continueToNextStep');
  String get completePrayerFlow => _t('completePrayerFlow');
  String get alarmHowItWorksTitle => _t('alarmHowItWorksTitle');
  String get alarmHowItWorksBody => _t('alarmHowItWorksBody');
  String get alarmDetailedHowItWorksTitle => _t('alarmDetailedHowItWorksTitle');
  String get alarmDetailedHowItWorksBody => _t('alarmDetailedHowItWorksBody');
  String get bibleLicenseTitle => _t('bibleLicenseTitle');
  String get bibleLicenseBody => _t('bibleLicenseBody');
  String get permissionNotificationTitle => _t('permissionNotificationTitle');
  String get permissionNotificationBody => _t('permissionNotificationBody');
  String get permissionMicrophoneTitle => _t('permissionMicrophoneTitle');
  String get permissionMicrophoneBody => _t('permissionMicrophoneBody');
  String get permissionAlarmKitTitle => _t('permissionAlarmKitTitle');
  String get permissionAlarmKitBody => _t('permissionAlarmKitBody');
  String get permissionMissionTitle => _t('permissionMissionTitle');
  String get permissionMissionBody => _t('permissionMissionBody');
  String get permissionSettingsTitle => _t('permissionSettingsTitle');
  String get permissionSettingsBody => _t('permissionSettingsBody');
  String get permissionEnable => _t('permissionEnable');
  String get permissionEnabled => _t('permissionEnabled');
  String get notificationsDisabledWarning => _t('notificationsDisabledWarning');
  String get openIphoneSettings => _t('openIphoneSettings');
  String get enableNotificationsToRing => _t('enableNotificationsToRing');
  String get tomorrow => _t('tomorrow');
  String alarmScheduledNext(String time) =>
      _t('alarmScheduledNext').replaceAll('{time}', time);
  String get stepMorningPrayer => _t('stepMorningPrayer');
  String get stepCirclePrayer => _t('stepCirclePrayer');
  String get stepFriendPrayer => _t('stepFriendPrayer');
  String get stepScripture => _t('stepScripture');
  String get circlePrayingTogetherToday => _t('circlePrayingTogetherToday');
  String get successMorningCircleFriendScripture =>
      _t('successMorningCircleFriendScripture');
  String get successMorningCircleScripture =>
      _t('successMorningCircleScripture');
  String get successMeansOfGraceComplete => _t('successMeansOfGraceComplete');
  String stepOfTotal(int n, int total, String stepName) => _t('stepOfTotal')
      .replaceAll('{n}', n.toString())
      .replaceAll('{total}', total.toString())
      .replaceAll('{step}', stepName);
  String get cancelAlarmResumes => _t('cancelAlarmResumes');
  String get morningAlarmMustComplete => _t('morningAlarmMustComplete');
  String get eveningAlarmMustComplete => _t('eveningAlarmMustComplete');
  String get blessBeforeRest => _t('blessBeforeRest');
  String get stepEveningGuide => _t('stepEveningGuide');
  String get stepAaronBlessing => _t('stepAaronBlessing');
  String get goodnightTitle => _t('goodnightTitle');
  String get successEveningRest => _t('successEveningRest');
  String get readAloudToContinue => _t('readAloudToContinue');
  String get inputModeVoice => _t('inputModeVoice');
  String get inputModeKeyboard => _t('inputModeKeyboard');
  String get typePrayerHint => _t('typePrayerHint');
  String get typingProgress => _t('typingProgress');
  String get recordingInProgress => _t('recordingInProgress');
  String get liveTranscriptLabel => _t('liveTranscriptLabel');
  String get liveTranscriptHint => _t('liveTranscriptHint');
  String get typedEchoLabel => _t('typedEchoLabel');
  String get morningPrayerVoiceTypeHint => _t('morningPrayerVoiceTypeHint');
  String get typeToContinue => _t('typeToContinue');
  String get switchedToTypeMode => _t('switchedToTypeMode');

  // ── Emergency & intensity ──
  String get emergencyTitle => _t('emergencyTitle');
  String get emergencyMorningHint => _t('emergencyMorningHint');
  String get emergencyEveningHint => _t('emergencyEveningHint');
  String get emergencyMorningPhrase => _t('emergencyMorningPhrase');
  String get emergencyEveningPrefix => _t('emergencyEveningPrefix');
  String get emergencyEveningSuffix => _t('emergencyEveningSuffix');
  String get emergencyTypePhraseHint => _t('emergencyTypePhraseHint');
  String get emergencyEveningReasonHint => _t('emergencyEveningReasonHint');
  String get emergencyConfirm => _t('emergencyConfirm');
  String get emergencyNotAvailable => _t('emergencyNotAvailable');
  String get emergencyButton => _t('emergencyButton');
  String get emergencySuccessMessage => _t('emergencySuccessMessage');
  String emergencyGraceRemaining(int days) =>
      _t('emergencyGraceRemaining').replaceAll('{days}', '$days');
  String emergencyRemainingThisWeek(int count) =>
      _t('emergencyRemainingThisWeek').replaceAll('{count}', '$count');
  String get prayerIntensity => _t('prayerIntensity');
  String get prayerIntensityGentle => _t('prayerIntensityGentle');
  String get prayerIntensityNormal => _t('prayerIntensityNormal');
  String get prayerIntensityStrict => _t('prayerIntensityStrict');
  String get prayerIntensityHint => _t('prayerIntensityHint');
  String get streakTitle => _t('streakTitle');
  String streakDays(int days) => _t('streakDays').replaceAll('{days}', '$days');
  String get streakStartToday => _t('streakStartToday');
  String eveningStreakDays(int days) =>
      _t('eveningStreakDays').replaceAll('{days}', '$days');
  String get eveningStreakStart => _t('eveningStreakStart');
  String get emergencyFeatureTitle => _t('emergencyFeatureTitle');
  String get emergencyFeatureBody => _t('emergencyFeatureBody');
  String get hallelujah => _t('hallelujah');
  String get done => _t('done');
  String get amen => _t('amen');
  String get prayingWithYou => _t('prayingWithYou');
  String get blessWithPrayer => _t('blessWithPrayer');
  String get micPermissionChrome => _t('micPermissionChrome');
  String get speechNotAvailable => _t('speechNotAvailable');

  // ── Auth ──
  String get welcomeBack => _t('welcomeBack');
  String get signInToContinue => _t('signInToContinue');
  String get password => _t('password');
  String get signIn => _t('signIn');
  String get signInWithApple => _t('signInWithApple');
  String get createAccount => _t('createAccount');
  String get noAccount => _t('noAccount');
  String get haveAccount => _t('haveAccount');
  String get name => _t('name');
  String get confirmPassword => _t('confirmPassword');
  String get enterEmail => _t('enterEmail');
  String get enterPassword => _t('enterPassword');
  String get enterName => _t('enterName');
  String get passwordMinLength => _t('passwordMinLength');
  String get passwordsDoNotMatch => _t('passwordsDoNotMatch');

  // ── Auth errors ──
  String get errorInvalidEmail => _t('errorInvalidEmail');
  String get errorUserNotFound => _t('errorUserNotFound');
  String get errorWrongPassword => _t('errorWrongPassword');
  String get errorEmailInUse => _t('errorEmailInUse');
  String get errorWeakPassword => _t('errorWeakPassword');
  String get errorInvalidCredential => _t('errorInvalidCredential');
  String get errorOperationNotAllowed => _t('errorOperationNotAllowed');
  String get errorSignInFailed => _t('errorSignInFailed');

  // ── Service errors ──
  String get errorLoginRequired => _t('errorLoginRequired');
  String get errorAlreadyInCircle => _t('errorAlreadyInCircle');
  String get errorCircleNotFound => _t('errorCircleNotFound');
  String get errorPrayerTextRequired => _t('errorPrayerTextRequired');
  String get errorOpenerOneSentence => _t('errorOpenerOneSentence');
  String get errorTomorrowPrayerConfirmed => _t('errorTomorrowPrayerConfirmed');
  String get errorOnePrayerPerDay => _t('errorOnePrayerPerDay');
  String get notificationPrayerHeard => _t('notificationPrayerHeard');

  String membersLabel(int count) =>
      _t('membersCount').replaceAll('{count}', count.toString());

  String toPerson(String name) => _t('toLabel').replaceAll('{name}', name);

  String fromPerson(String name) => _t('fromLabel').replaceAll('{name}', name);

  String prayerFrom(String name) => _t('prayerFrom').replaceAll('{name}', name);

  String friendConfirmedPrayer(String name) =>
      _t('friendPrayerConfirmed').replaceAll('{name}', name);

  String personAlreadyConfirmed(String name) =>
      _t('errorTomorrowPrayerConfirmed').replaceAll('{name}', name);

  String prayerAcceptedFrom(String name) =>
      _t('prayerAcceptedOneOnly').replaceAll('{name}', name);

  String prayerDeclinedFrom(String name) =>
      _t('prayerDeclined').replaceAll('{name}', name);

  String sentEncouragementTo(String name) =>
      _t('sentEncouragement').replaceAll('{name}', name);

  String inviteSentTo(String contact) =>
      _t('inviteSent').replaceAll('{contact}', contact);
  String inviteShareCircleId(String circleId) =>
      _t('inviteShareCircleId').replaceAll('{circleId}', circleId);
  String memberAddedToCircle(String name) =>
      _t('memberAddedToCircle').replaceAll('{name}', name);

  String prayerScheduledFor(String name, String day) => _t(
    'prayerScheduledFor',
  ).replaceAll('{name}', name).replaceAll('{day}', day);

  String circlePrayerOn(String day) =>
      _t('circlePrayerOn').replaceAll('{day}', day);

  String arrowPrayer(String from, String to) =>
      _t('prayerArrow').replaceAll('{from}', from).replaceAll('{to}', to);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      _allStrings.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _allStrings = <String, Map<String, String>>{
  'en': _en,
  'ko': _ko,
  'de': _de,
  'ru': _ru,
  'es': _es,
  'fr': _fr,
  'pt': _pt,
  'zh': _zh,
  'ja': _ja,
  'hi': _hi,
  'ar': _ar,
};

const _en = {
  'appTitle': 'God Morning',
  'save': 'Save',
  'cancel': 'Cancel',
  'retry': 'Retry',
  'settings': 'Settings',
  'language': 'Language',
  'selectLanguage': 'Select language',
  'scripturePlan': 'Scripture plan',
  'selectScripturePlan': 'Select Scripture plan',
  'scripturePlanDaily': '365 Psalms and Prayers',
  'scripturePlanDailySubtitle':
      'Start each morning with one Psalm verse and a short prayer.',
  'scripturePlanBeloved52': '52 Beloved Verses',
  'scripturePlanBeloved52Subtitle':
      'Read one beloved verse each week for memorization.',
  'missionContent': 'Mission content',
  'selectMissionContent': 'Select mission content',
  'missionContentScriptureAndPrayer': 'Scripture + Prayer',
  'missionContentScriptureAndPrayerSubtitle':
      'Read both the Bible verse and the morning prayer.',
  'missionContentScriptureOnly': 'Scripture only',
  'missionContentScriptureOnlySubtitle':
      'Complete the mission by reading only the Bible verse.',
  'missionContentPrayerOnly': 'Prayer only',
  'missionContentPrayerOnlySubtitle':
      'Read a dedicated 365-day topical prayer without the Scripture block.',
  'morningPrayerEveningBlessing': 'Morning prayer and evening blessing.',
  'tapTimeToSetAlarm':
      'Tap the time to set your alarm. Choose your bell sound below.',
  'tapToSetTimeAndSound': 'Tap to set time & sound',
  'circleTapToOpen': 'Small group · tap to open',
  'webPreviewBanner':
      'Chrome preview — check alarm and Circle UI. Full features on iPhone/Android.',
  'morningAlarm': 'Morning alarm',
  'eveningBlessing': 'Evening blessing',
  'alarmOn': 'Alarm is on',
  'alarmOff': 'Alarm is off',
  'previewMorningAlarm': 'Preview morning alarm',
  'previewEveningBlessing': 'Preview evening blessing',
  'yourCircle': 'Your Circle',
  'localWeather': 'Local weather',
  'localWeatherSubtitle':
      'Uses your current location to show today and this week.',
  'localWeatherLoading': 'Loading your local forecast...',
  'localWeatherSettingsBody':
      'Uses your current location only to fetch today and this week. Your location is not stored by God Morning.',
  'enableLocalWeather': 'Show local weather',
  'weatherRefresh': 'Refresh weather',
  'weatherThisWeek': 'This week',
  'weatherFeelsLike': 'Feels {temp}',
  'weatherWind': 'Wind {speed} {unit}',
  'weatherRainChance': 'Rain {chance}%',
  'weatherHighLow': 'H {high}  L {low}',
  'weatherPermissionRequired':
      'Location permission is needed for local weather.',
  'weatherLocationServicesOff':
      'Turn on Location Services to show local weather.',
  'weatherUnavailable': 'Weather is unavailable right now. Try again later.',
  'weatherEnabled': 'Local weather enabled',
  'weatherDisabled': 'Local weather disabled',
  'weatherAttribution': 'Weather data by Open-Meteo.com',
  'weatherTemperatureUnit': 'Temperature unit',
  'weatherUnitFahrenheit': 'Fahrenheit (°F)',
  'weatherUnitCelsius': 'Celsius (°C)',
  'enableMorningAlarm': 'Enable morning alarm',
  'morningAlarmSubtitle': 'Prayer and Scripture to dismiss',
  'repeatDays': 'Repeat days',
  'perDayTimesTitle': 'Different time per day',
  'alarmsTitle': 'Alarms',
  'addAlarm': 'Add alarm',
  'deleteAlarmTitle': 'Delete',
  'everyDay': 'Every day',
  'maxAlarmsReached': 'You can set up to 5 alarms.',
  'cannotDeleteLastAlarm': 'At least one alarm is needed — turn it off instead.',
  'alarmListHint': 'Each alarm has its own mission. Tap to edit, long-press to delete.',
  'streakCalendarSubtitle': 'Days you met the Lord are marked automatically.',
  'calendarTab': 'Calendar',
  'homeTab': 'Home',
  'weatherTab': 'Weather',
  'showLocalWeather': 'Show local weather — tap to turn on',
  'myLocation': 'My location',
  'tenDayForecast': '10-DAY FORECAST',
  'nowLabel': 'Now',
  'todayLabel': 'Today',
  'streakTotalDays': 'You have met the Lord {days} days in total',
  'perDayTimesSubtitle': 'Set a different alarm time for each day',
  'setTimeForDay': '{day} alarm time',
  'selectAtLeastOneAlarmDay': 'Select at least one alarm day.',
  'weekdayShortMonday': 'Mon',
  'weekdayShortTuesday': 'Tue',
  'weekdayShortWednesday': 'Wed',
  'weekdayShortThursday': 'Thu',
  'weekdayShortFriday': 'Fri',
  'weekdayShortSaturday': 'Sat',
  'weekdayShortSunday': 'Sun',
  'setAlarmTime': 'SET ALARM TIME',
  'morningAlarmOffHint': 'Alarm is off — turn on below to schedule',
  'eveningChildrenBlessing': "Children's Blessing Time",
  'eveningBlessingOffHint': 'Blessing is off — turn on below to schedule',
  'enableEveningBlessing': 'Enable evening blessing',
  'eveningBlessingSubtitle': "Aaron's blessing to dismiss",
  'saveAlarms': 'Save alarms',
  'testMorningAlarm': 'Test morning alarm (5 sec)',
  'testEveningAlarm': 'Test evening alarm (5 sec)',
  'practiceMission': 'Practice mission',
  'practiceMissionSubtitle':
      'Try the Scripture and prayer flow without changing your real alarm, retries, or streak.',
  'missionPassThreshold': 'Mission pass threshold',
  'missionPassThresholdSubtitle':
      'Choose how much of the Scripture and prayer must match before Amen unlocks. Lower is easier; higher is stricter.',
  'missionPassThresholdLow': 'Easier',
  'missionPassThresholdHigh': 'Stricter',
  'alarmsSaved': 'Alarms saved',
  'saving': 'Saving...',
  'signOut': 'Sign out',
  'home': 'Home',
  'backToMain': 'Back to main',
  'premiumTitle': 'God Morning Premium',
  'premiumSettingsSubtitle': 'Optional subscription and purchase management.',
  'premiumHeroTitle': 'Keep your morning with God first.',
  'premiumHeroSubtitle':
      'Unlock the full Scripture alarm rhythm with every plan, sound, language, and local weather.',
  'premiumMonthlyTitle': 'Monthly',
  'premiumMonthlyPrice': r'$2.99 / month',
  'premiumAnnualTitle': 'Annual',
  'premiumAnnualPrice': r'$29.99 / year',
  'premiumTrialLabel': '7-day free trial',
  'premiumMonthlyTrialTerms': '7-day free trial, then renews monthly.',
  'premiumAnnualTrialTerms': '7-day free trial, then renews yearly.',
  'premiumFeatureAlarm': 'Prayer alarm that can return until Amen',
  'premiumFeaturePlans': '365 Psalms and 52 Beloved Verses',
  'premiumFeatureLanguages':
      'English, Korean, German, Russian, Spanish, Portuguese, Chinese, and Japanese',
  'premiumFeatureWeather': 'Optional local weather after completion',
  'premiumStartTrial': 'Start 7-day free trial',
  'premiumRestore': 'Restore purchases',
  'premiumManageSubscription': 'Manage or cancel subscription',
  'premiumLoadingProducts': 'Loading subscription options...',
  'premiumProductsUnavailable':
      'Subscription options are not available yet. Please make sure the App Store or Google Play subscription products are set up for this app.',
  'premiumPurchaseSuccess': 'Premium is active.',
  'premiumPurchasePending':
      'Your purchase is pending store approval. Premium will unlock when it completes.',
  'premiumPurchaseCancelled': 'Purchase cancelled.',
  'premiumPurchaseFailed': 'Purchase could not be completed. Please try again.',
  'premiumRestoreMissing': 'No active subscription was found to restore.',
  'premiumTerms':
      'Payment is charged through Apple In-App Purchase or Google Play billing. The 7-day free trial and subscription renewal are managed by the store. Cancel anytime in your subscription settings. To avoid renewal, cancel at least 24 hours before the next billing date.',
  'premiumCancelAnytime':
      'Includes a 7-day trial. Cancel anytime in your subscription settings. To avoid renewal, cancel at least 24 hours before the next billing date.',
  'premiumPurchaseUnavailable':
      'Purchases are not available right now. Please try again later.',
  'premiumOpenSubscriptionFailed': 'Could not open subscription management.',
  'termsOfUse': 'Terms of Use',
  'privacyPolicy': 'Privacy Policy',
  'openLinkFailed': 'Could not open the link.',
  'alarmSound': 'ALARM SOUND',
  'alarmSoundDescription':
      'Choose a bundled God Morning alarm tone for your morning alarm.',
  'alarmSoundDescriptionIos':
      'Tap a sound to preview it once. Tap another to switch smoothly.',
  'soundClassicAlarm': 'Bright beeps (recommended)',
  'soundGentleChime': 'Morning chime',
  'soundChurchBell': 'Church bell toll',
  'moreIphoneSounds': 'More phone sounds…',
  'currentAlarmSound': 'Current: {name}',
  'savedAlarmSoundBadge': 'Saved',
  'systemAlarmSound': 'System alarm (default)',
  'systemNotificationSound': 'System notification',
  'systemRingtoneSound': 'System ringtone',
  'chooseFromPhoneSounds': 'Choose from phone sounds',
  'previewSound': 'Preview sound',
  'soundSaved': 'Alarm sound saved',
  'noRingtonesFound': 'No sounds found on this device.',
  'notificationsPermissionTitle': 'Allow notifications',
  'notificationsPermissionBody':
      'God Morning needs a few permissions so your morning alarm can ring and hear your prayer.',
  'allowNotifications': 'Allow & continue',
  'onboardingNext': 'Continue',
  'onboardingEnableAndStart': 'Enable and start',
  'onboardingProductTitle': 'Give God the first minute of your morning.',
  'onboardingProductBody':
      'God Morning helps you wake up with one Bible verse, one short prayer, and a simple Amen.',
  'onboardingProductPointOneVerse':
      'One verse a day, prepared for your morning',
  'onboardingProductPointFirstMinute':
      'A quiet first minute shaped by Scripture and prayer',
  'onboardingReadTitle': 'Read it aloud. Begin with attention.',
  'onboardingReadBody':
      'At alarm time, God Morning opens a focused Scripture-and-prayer mission you can complete by voice or typing.',
  'onboardingReadPointVoiceType': 'Use voice or type mode to follow the text',
  'onboardingReadPointAmen': 'Amen is the final step that completes the alarm',
  'onboardingAlarmTitle': 'A morning alarm with a purpose.',
  'onboardingAlarmBody':
      'Set your time, choose your sound, and let the alarm lead you into the mission instead of another snooze.',
  'onboardingAlarmPointClosed': 'Designed to ring even if the app is closed',
  'onboardingAlarmPointReturn':
      'If you leave before Amen, the alarm can return',
  'onboardingPermissionsTitle': 'Enable what God Morning needs.',
  'onboardingPermissionsBody':
      'We will ask for the permissions needed for alarms, notifications, microphone, and speech recognition.',
  'commandCopied': 'Command copied',
  'walkTogether': 'Walk together',
  'circleInviteDescription':
      'Encourage friends in morning prayer and Sunday worship.\nInvite unlimited members.',
  'createCircle': 'Create circle',
  'joinCircle': 'Join circle',
  'circleNameHint': 'Circle name (e.g. Grace Cell)',
  'circleIdHint': 'Circle ID from your friend',
  'membersCount': '{count} members',
  'thisWeekMorning': 'This week · Mon–Sun morning prayer',
  'demoCircleBanner': 'Demo Circle — full features on iPhone/Android app',
  'localCircleBanner':
      'Circle saved on this phone. Add friends with + — share Circle ID for them to join.',
  'enterCircleName': 'Please enter a circle name.',
  'circleCreated':
      'Circle created. Share the Circle ID or invite by email/phone.',
  'enterCircleId': 'Please enter a Circle ID.',
  'joinedCircle': 'You joined the circle!',
  'sentEncouragement': 'Sent encouragement to {name}',
  'likeSaveFailed': 'Failed to save like.',
  'morningDoneToday': 'Morning prayer done today',
  'morningNotYetToday': 'Morning prayer not yet today',
  'sendPrayerForTomorrow': 'Send prayer request',
  'prayerAcceptHint': 'They pick a day Mon–Sun this week to pray for you',
  'unlike': 'Unlike',
  'sendLike': 'Send a like',
  'doneToday': 'Done today',
  'notYetToday': 'Not yet today',
  'morningMonSun': 'Morning · Mon–Sun',
  'eveningMonSun': 'Evening · Mon–Sun',
  'notYet': 'Not yet',
  'liked': 'Liked',
  'like': 'Like',
  'prayer': 'Prayer',
  'inviteFriend': 'Invite friend',
  'addMember': 'Add member',
  'friendName': 'Friend\'s name',
  'memberAddedToCircle': '{name} was added to your Circle.',
  'inviteByEmailOrPhone': 'Invite by email or phone number',
  'email': 'Email',
  'phoneNumber': 'Phone number',
  'sendInvite': 'Send invite',
  'inviteSent':
      'Invite sent to {contact}. They will join when they sign up or open the app.',
  'inviteShareCircleId': 'Share this Circle ID with your friend: {circleId}',
  'inviteSentExistingUser':
      'Invite sent! They will receive a notification to join your circle.',
  'inviteFailed': 'Could not send invite.',
  'enterEmailOrPhone': 'Enter an email or phone number.',
  'invalidEmail': 'Please enter a valid email address.',
  'invalidPhone': 'Please enter a valid phone number.',
  'alreadyInCircle': 'This person is already in your circle.',
  'prayerConfirmedTomorrow':
      'Tomorrow\'s morning prayer is confirmed. No more requests can be accepted.',
  'prayerRequestsForYou': 'PRAYER REQUESTS FOR YOU',
  'circleLikePrayerHint':
      'Send ❤️ encouragement or share a prayer topic with Circle members. They pick a day and pray with you on the morning alarm.',
  'circleActivity': 'ACTIVITY',
  'sentPrayerRequests': 'PRAYERS YOU SENT',
  'likedYouThisWeek': '{name} sent you ❤️ this week',
  'markAllRead': 'Mark all read',
  'friendPrayedForYou': 'Prayed for you',
  'sendPrayerTopic': 'Send prayer topic',
  'onePrayerPerDayWeek':
      'One personal prayer per day · pick any day Mon–Sun this week',
  'schedulePrayer': 'Schedule',
  'pickDayThisWeek': 'Pick a day this week',
  'dayBooked': 'Booked',
  'circlePrayer': 'Circle prayer',
  'createCirclePrayer': 'Create circle prayer',
  'circlePrayersThisWeek': 'CIRCLE PRAYERS THIS WEEK',
  'circlePrayerTogether': 'Everyone prays together on important days',
  'weekPrayersCircle': 'THIS WEEK\'S PRAYERS · CIRCLE',
  'importantDayLabel': 'Important day (Mon–Sun)',
  'prayerTopic': 'Prayer topic (e.g. surgery, crisis)',
  'pickADay': 'Pick a day to pray together',
  'scheduled': 'Scheduled',
  'circlePrayerCreated': 'Circle prayer created. Everyone will pray together.',
  'scheduleFailed': 'Could not schedule prayer.',
  'prayerScheduledFor': 'Scheduled {name}\'s prayer for {day}',
  'circlePrayerOn': 'CIRCLE PRAYER · {day}',
  'onePrayerAcceptOnly': 'One personal prayer per day · pick any day Mon–Sun',
  'fromLabel': 'From {name}',
  'forYouTomorrow': 'For you · tomorrow morning',
  'decline': 'Decline',
  'prayTomorrow': 'Pray tomorrow',
  'tomorrowsPrayersCircle': 'TOMORROW\'S PRAYERS · CIRCLE',
  'circlePrayerFeedSubtitle': 'Personal prayers scheduled this week',
  'pending': 'Pending',
  'accepted': 'Accepted',
  'declined': 'Declined',
  'sendPrayerRequest': 'Send prayer request',
  'toLabel': 'To: {name}',
  'prayerRecipientChoose':
      '{name} will choose whether to pray this tomorrow morning.',
  'optionalOpener': '1. Opening sentence (optional)',
  'requiredPrayer': '2. Prayer request 1–2 sentences (required)',
  'send': 'Send',
  'friendPrayerConfirmed':
      'Scheduled {name}\'s prayer. Pick another day for other requests.',
  'prayerRequestSent':
      'Prayer request sent to {name}. They will pick a day this week.',
  'prayerAcceptedOneOnly': 'Scheduled {name}\'s prayer for the day you chose.',
  'acceptFailed': 'Could not accept request.',
  'prayerDeclined': 'Declined {name}\'s prayer request.',
  'declineFailed': 'Could not decline request.',
  'prayerDemoSent': 'Prayer request sent (demo) — shown if {name} accepts.',
  'prayerFrom': 'PRAYER FROM {name}',
  'prayerArrow': '{from} → {to}',
  'timeToMeetLord': 'It is time to meet with the Lord.',
  'stopWithPrayerAndWord': 'Stop with prayer and Word',
  'todaysPrayer': "TODAY'S PRAYER",
  'todaysWord': "TODAY'S WORD",
  'listening': 'Listening...',
  'completeWebDemo': 'Complete (web demo)',
  'nextStepWebDemo': 'Next step (web demo)',
  'continueToNextStep': 'Continue to next step',
  'completePrayerFlow': 'Amen',
  'alarmHowItWorksTitle': 'Will the alarm ring tomorrow?',
  'alarmHowItWorksBody':
      'Yes. God Morning keeps your morning alarm scheduled until you turn it off.',
  'alarmDetailedHowItWorksTitle': 'How it works',
  'alarmDetailedHowItWorksBody':
      '1. Turn on the morning alarm and tap Save.\n'
      '2. Allow Alarms and Notifications if your phone asks.\n'
      '3. At your chosen time, the alarm rings even if the app is closed.\n'
      '4. Stop the alarm to open prayer. The alarm keeps returning until Amen.\n'
      '5. During listening, the alarm sound stays off so your voice can be heard.',
  'bibleLicenseTitle': 'Bible text',
  'bibleLicenseBody':
      'Bible text sources:\n'
      'Korean: Korean Revised Version 1952/1961 (KRV / 개역한글). Source: KorRV / Zefania XML. Rights: Public Domain.\n'
      'English: World English Bible (WEB). Source: eBible.org. Rights: Public Domain.\n'
      'German: Lutherbibel 1912. Source: eBible.org. Rights: Public Domain.\n'
      'Russian: Russian Synodal Translation (1876 / Синодальный перевод). Source: eBible.org. Rights: Public Domain.\n'
      'Spanish: Reina-Valera 1909 (RV1909). Source: eBible.org. Rights: Public Domain.\n'
      'Portuguese: Bíblia Livre (BLJ). Source: eBible.org. Rights: Public Domain.\n'
      'Chinese: Chinese Union Version 1919 (和合本, Simplified). Source: getBible / CrossWire. Rights: Public Domain.\n'
      'Japanese: Kougo-yaku 1954/1955 (口語訳). Source: getBible / CrossWire. Rights: Public Domain.',
  'permissionNotificationTitle': 'Notifications',
  'permissionNotificationBody': 'Required so the alarm can alert you.',
  'permissionMicrophoneTitle': 'Microphone',
  'permissionMicrophoneBody':
      'Required so the app can hear you read Scripture and prayer.',
  'permissionAlarmKitTitle': 'Alarm permission',
  'permissionAlarmKitBody': 'Required so the morning alarm can ring reliably.',
  'permissionMissionTitle': 'Amen completes the alarm',
  'permissionMissionBody':
      'The alarm keeps returning until the Scripture and prayer mission is complete.',
  'permissionSettingsTitle': 'Permissions',
  'permissionSettingsBody':
      'Enable the permissions God Morning needs for alarms and the reading mission.',
  'permissionEnable': 'Enable',
  'permissionEnabled': 'Enabled',
  'notificationsDisabledWarning':
      'Notifications are off. Alarms will not ring until you enable them in phone settings.',
  'openIphoneSettings': 'Open phone settings',
  'enableNotificationsToRing':
      'Turn on notifications first — otherwise the alarm cannot ring.',
  'tomorrow': 'tomorrow',
  'alarmScheduledNext': 'Alarm saved. Next ring: {time}',
  'stepMorningPrayer': 'Morning prayer',
  'stepCirclePrayer': 'Circle prayer',
  'stepFriendPrayer': 'Friend prayer',
  'stepScripture': 'Scripture',
  'stepOfTotal': 'Step {n} of {total} · {step}',
  'circlePrayingTogetherToday': 'Your whole circle is praying together today.',
  'successMorningCircleFriendScripture':
      'Morning prayer, circle prayer, friend prayer, and Scripture — complete.\nWalk in peace.',
  'successMorningCircleScripture':
      'Morning prayer, circle prayer, and Scripture — complete.\nWalk in peace.',
  'successMeansOfGraceComplete':
      "Today's God Morning is complete.\nWalk in peace.",
  'cancelAlarmResumes': 'Cancel (alarm will resume)',
  'morningAlarmMustComplete':
      'Complete today\'s morning prayer to turn off the alarm.',
  'eveningAlarmMustComplete':
      'Complete today\'s evening blessing to turn off the alarm.',
  'blessBeforeRest': 'Bless your children with prayer before bed',
  'stepEveningGuide': 'Blessing guide',
  'stepAaronBlessing': "Aaron's blessing",
  'goodnightTitle': 'Goodnight.',
  'successEveningRest': 'The Lord bless you and keep you.\nRest in peace.',
  'readAloudToContinue':
      'Read or type at least 80% — the button enables, then tap when you finish reading.',
  'inputModeVoice': 'Record',
  'inputModeKeyboard': 'Type',
  'typePrayerHint': 'Type what you read…',
  'typingProgress': 'Typing',
  'recordingInProgress': 'Recording…',
  'liveTranscriptLabel': 'What we hear',
  'liveTranscriptHint':
      'Speak aloud — your words appear here so you can check as you pray.',
  'typedEchoLabel': 'What you typed',
  'morningPrayerVoiceTypeHint':
      'After you start, use Record (voice) or Type to read each prayer step.',
  'typeToContinue': 'Type what you read to continue.',
  'switchedToTypeMode':
      'Voice is unavailable — switched to Type mode. You can still complete prayer.',
  'emergencyTitle': 'Emergency — spiritual confession',
  'emergencyMorningHint':
      'Type the phrase below exactly to turn off today\'s morning alarm.',
  'emergencyEveningHint':
      'Fill in the reason (sleepover, family, travel…) to skip tonight\'s blessing.',
  'emergencyMorningPhrase':
      'I truly cannot do this today. Lord, please forgive me.',
  'emergencyEveningPrefix': 'Today because of ',
  'emergencyEveningSuffix':
      ' I could not pray the children\'s blessing. Lord, please forgive me.',
  'emergencyTypePhraseHint': 'Type the confession phrase…',
  'emergencyEveningReasonHint': 'e.g. sleepover, family trip…',
  'emergencyConfirm': 'Submit confession & dismiss alarm',
  'emergencyNotAvailable':
      'No emergency exits left this week for your intensity level.',
  'emergencyButton': 'Emergency — I need grace today',
  'emergencySuccessMessage':
      'Lord hears your confession. The alarm is off for today. Come back tomorrow.',
  'emergencyGraceRemaining':
      'First week grace — emergency open for {days} more days.',
  'emergencyRemainingThisWeek': 'Emergency exits left this week: {count}',
  'prayerIntensity': 'Prayer intensity',
  'prayerIntensityGentle': 'Gentle',
  'prayerIntensityNormal': 'Normal',
  'prayerIntensityStrict': 'Strict',
  'prayerIntensityHint':
      'Gentle 65% · Normal 80% · Strict 90%. Emergency: 3 / 1 / 0 per week after day 7.',
  'streakTitle': 'Morning streak',
  'streakDays': '{days} days in a row',
  'eveningStreakDays': "Children's blessing — {days} days in a row",
  'eveningStreakStart': "Start tonight with a children's blessing",
  'streakStartToday': 'Complete morning prayer today to start your streak.',
  'emergencyFeatureTitle': 'Emergency — spiritual confession',
  'emergencyFeatureBody':
      'On the alarm screen, tap Emergency and type the confession to dismiss. Evening: fill in your reason (sleepover, family, etc.).',
  'hallelujah': 'Hallelujah',
  'done': 'Done',
  'amen': 'Amen',
  'prayingWithYou': '{name} is praying with you this morning.',
  'blessWithPrayer': 'Bless with prayer',
  'micPermissionChrome':
      'Allow microphone access in Chrome (lock icon in address bar).',
  'speechNotAvailable': 'Speech recognition is not available on this device.',
  'welcomeBack': 'Welcome back.',
  'signInToContinue': 'Sign in to continue your journey.',
  'password': 'Password',
  'signIn': 'Sign in',
  'signInWithApple': 'Sign in with Apple',
  'createAccount': 'Create account',
  'noAccount': 'No account? Create one',
  'haveAccount': 'Already have an account? Sign in',
  'name': 'Name',
  'confirmPassword': 'Confirm password',
  'enterEmail': 'Please enter your email.',
  'enterPassword': 'Please enter your password.',
  'enterName': 'Please enter your name.',
  'passwordMinLength': 'Password must be at least 6 characters.',
  'passwordsDoNotMatch': 'Passwords do not match.',
  'errorInvalidEmail': 'Please enter a valid email address.',
  'errorUserNotFound': 'No account found with this email.',
  'errorWrongPassword': 'Incorrect password.',
  'errorEmailInUse': 'This email is already in use.',
  'errorWeakPassword': 'Password must be at least 6 characters.',
  'errorInvalidCredential': 'Please check your email and password.',
  'errorOperationNotAllowed': 'This sign-in method is not available.',
  'errorSignInFailed': 'Sign in failed. Please try again.',
  'errorLoginRequired': 'Sign in required.',
  'errorAlreadyInCircle': 'You are already in a circle.',
  'errorCircleNotFound': 'Circle not found. Check the Circle ID.',
  'errorPrayerTextRequired': 'Please enter a prayer request.',
  'errorOpenerOneSentence': 'Opening prayer must be one sentence.',
  'errorTomorrowPrayerConfirmed':
      '{name} has already confirmed tomorrow\'s morning prayer.',
  'errorOnePrayerPerDay': 'You can accept only one prayer per day.',
  'notificationPrayerHeard': 'Your friend heard your prayer.',
};

const _ko = {
  'appTitle': 'God Morning',
  'save': '저장',
  'cancel': '취소',
  'retry': '다시 시도',
  'settings': '설정',
  'language': '언어',
  'selectLanguage': '언어 선택',
  'scripturePlan': '말씀 플랜',
  'selectScripturePlan': '말씀 플랜 선택',
  'scripturePlanDaily': '365일 시편 말씀과 기도',
  'scripturePlanDailySubtitle': '매일 아침 시편 한 구절과 짧은 기도로 시작합니다.',
  'scripturePlanBeloved52': '사랑받는 52구절',
  'scripturePlanBeloved52Subtitle': '한 주에 한 구절씩 읽고 암송합니다.',
  'missionContent': '미션 내용',
  'selectMissionContent': '미션 내용 선택',
  'missionContentScriptureAndPrayer': '말씀 + 기도',
  'missionContentScriptureAndPrayerSubtitle': '성경 말씀과 아침 기도를 함께 읽습니다.',
  'missionContentScriptureOnly': '말씀만 읽기',
  'missionContentScriptureOnlySubtitle': '성경 말씀만 읽고 미션을 완료합니다.',
  'missionContentPrayerOnly': '기도만 하기',
  'missionContentPrayerOnlySubtitle': '말씀 없이 365일 주제별 기도문만 읽습니다.',
  'morningPrayerEveningBlessing': '아침 기도와 저녁 축복.',
  'tapTimeToSetAlarm': '시간을 탭해서 알람을 맞추세요. 아래에서 벨소리를 고르세요.',
  'tapToSetTimeAndSound': '탭해서 시간·소리 설정',
  'circleTapToOpen': '소그룹 Circle · 탭해서 바로 보기',
  'webPreviewBanner':
      'Chrome 미리보기 — 알람과 Circle UI를 확인하세요. 전체 기능은 iPhone/Android 앱에서.',
  'morningAlarm': '아침 알람',
  'eveningBlessing': '저녁 축복',
  'alarmOn': '알람 켜짐',
  'alarmOff': '알람 꺼짐',
  'previewMorningAlarm': '아침 알람 미리보기',
  'previewEveningBlessing': '저녁 축복 미리보기',
  'yourCircle': '내 Circle',
  'localWeather': '지역 날씨',
  'localWeatherSubtitle': '현재 위치 기준으로 오늘과 이번 주 날씨를 보여줍니다.',
  'localWeatherLoading': '지역 날씨를 불러오는 중...',
  'localWeatherSettingsBody':
      '현재 위치는 오늘과 이번 주 예보를 가져오는 데만 사용됩니다. God Morning은 위치를 저장하지 않습니다.',
  'enableLocalWeather': '지역 날씨 표시',
  'weatherRefresh': '날씨 새로고침',
  'weatherThisWeek': '이번 주',
  'weatherFeelsLike': '체감 {temp}',
  'weatherWind': '바람 {speed} {unit}',
  'weatherRainChance': '비 {chance}%',
  'weatherHighLow': '최고 {high}  최저 {low}',
  'weatherPermissionRequired': '지역 날씨를 보려면 위치 권한이 필요합니다.',
  'weatherLocationServicesOff': '지역 날씨를 보려면 위치 서비스를 켜 주세요.',
  'weatherUnavailable': '지금은 날씨를 불러올 수 없습니다. 잠시 후 다시 시도해 주세요.',
  'weatherEnabled': '지역 날씨가 켜졌습니다',
  'weatherDisabled': '지역 날씨가 꺼졌습니다',
  'weatherAttribution': '날씨 데이터: Open-Meteo.com',
  'weatherTemperatureUnit': '온도 단위',
  'weatherUnitFahrenheit': '화씨 (°F)',
  'weatherUnitCelsius': '섭씨 (°C)',
  'enableMorningAlarm': '아침 알람 사용',
  'morningAlarmSubtitle': '기도와 말씀을 읽으면 알람 해제',
  'repeatDays': '반복 요일',
  'perDayTimesTitle': '요일별 시간 설정',
  'alarmsTitle': '알람',
  'addAlarm': '알람 추가',
  'deleteAlarmTitle': '삭제',
  'everyDay': '매일',
  'maxAlarmsReached': '알람은 최대 5개까지 만들 수 있어요.',
  'cannotDeleteLastAlarm': '알람이 최소 1개는 있어야 해요 — 대신 꺼 두세요.',
  'alarmListHint': '알람마다 각자의 미션이 있어요. 탭하면 수정, 길게 누르면 삭제됩니다.',
  'streakCalendarSubtitle': '주님과 만난 날이 자동으로 표시돼요.',
  'calendarTab': '달력',
  'homeTab': '홈',
  'weatherTab': '날씨',
  'showLocalWeather': '지역 날씨 보기 — 탭해서 켜기',
  'myLocation': '나의 위치',
  'tenDayForecast': '10일간의 일기예보',
  'nowLabel': '지금',
  'todayLabel': '오늘',
  'streakTotalDays': '지금까지 총 {days}일 주님과 만났어요',
  'perDayTimesSubtitle': '요일마다 다른 시간에 알람이 울려요',
  'setTimeForDay': '{day}요일 알람 시간',
  'selectAtLeastOneAlarmDay': '알람 요일을 최소 하루 이상 선택해 주세요.',
  'weekdayShortMonday': '월',
  'weekdayShortTuesday': '화',
  'weekdayShortWednesday': '수',
  'weekdayShortThursday': '목',
  'weekdayShortFriday': '금',
  'weekdayShortSaturday': '토',
  'weekdayShortSunday': '일',
  'setAlarmTime': '알람 시간',
  'morningAlarmOffHint': '알람이 꺼져 있습니다 — 아래에서 켜 주세요',
  'eveningChildrenBlessing': '자녀 축복 시간',
  'eveningBlessingOffHint': '축복 알람이 꺼져 있습니다 — 아래에서 켜 주세요',
  'enableEveningBlessing': '저녁 축복 사용',
  'eveningBlessingSubtitle': '아론의 축복을 읽으면 알람 해제',
  'saveAlarms': '알람 저장',
  'testMorningAlarm': '아침 알람 테스트 (5초)',
  'testEveningAlarm': '저녁 알람 테스트 (5초)',
  'practiceMission': '미션 연습하기',
  'practiceMissionSubtitle': '실제 알람, 재울림, 연속 기록을 바꾸지 않고 말씀과 기도 흐름만 연습합니다.',
  'missionPassThreshold': '미션 통과 기준',
  'missionPassThresholdSubtitle':
      '아멘 버튼이 열리기 전 말씀과 기도가 얼마나 일치해야 하는지 정합니다. 낮을수록 쉽고, 높을수록 엄격합니다.',
  'missionPassThresholdLow': '쉬움',
  'missionPassThresholdHigh': '엄격',
  'alarmsSaved': '알람이 저장되었습니다',
  'saving': '저장 중...',
  'signOut': '로그아웃',
  'home': '홈',
  'backToMain': '메인으로',
  'premiumTitle': 'God Morning Premium',
  'premiumSettingsSubtitle': '선택형 구독 및 구매 관리',
  'premiumHeroTitle': '하루의 첫 시간을 하나님께 드리세요.',
  'premiumHeroSubtitle': '말씀 알람 루틴 전체를 열어 모든 플랜, 알람음, 언어, 지역 날씨를 사용할 수 있습니다.',
  'premiumMonthlyTitle': '월간',
  'premiumMonthlyPrice': r'월 $2.99',
  'premiumAnnualTitle': '연간',
  'premiumAnnualPrice': r'연 $29.99',
  'premiumTrialLabel': '7일 무료 체험',
  'premiumMonthlyTrialTerms': '7일 무료 체험 후 매월 갱신됩니다.',
  'premiumAnnualTrialTerms': '7일 무료 체험 후 매년 갱신됩니다.',
  'premiumFeatureAlarm': 'Amen 전까지 다시 울릴 수 있는 기도 알람',
  'premiumFeaturePlans': '365일 시편 말씀과 사랑받는 52구절',
  'premiumFeatureLanguages': '영어, 한국어, 독일어, 러시아어, 스페인어, 포르투갈어, 중국어, 일본어',
  'premiumFeatureWeather': '미션 완료 후 선택형 지역 날씨',
  'premiumStartTrial': '7일 무료체험 시작',
  'premiumRestore': '구매 복원',
  'premiumManageSubscription': '구독 관리 및 취소',
  'premiumLoadingProducts': '구독 옵션을 불러오는 중...',
  'premiumProductsUnavailable':
      '아직 구독 옵션을 불러올 수 없습니다. App Store Connect 또는 Google Play Console에서 이 앱의 구독 상품이 설정되어 있는지 확인해 주세요.',
  'premiumPurchaseSuccess': 'Premium이 활성화되었습니다.',
  'premiumPurchasePending': '구매가 스토어 승인 대기 중입니다. 완료되면 Premium이 열립니다.',
  'premiumPurchaseCancelled': '구매가 취소되었습니다.',
  'premiumPurchaseFailed': '구매를 완료하지 못했습니다. 다시 시도해 주세요.',
  'premiumRestoreMissing': '복원할 활성 구독을 찾지 못했습니다.',
  'premiumTerms':
      '결제는 App Store 또는 Google Play 인앱 결제를 통해 청구됩니다. 7일 무료 체험과 구독 갱신은 해당 스토어에서 관리합니다. 구독 설정에서 언제든지 취소할 수 있습니다. 갱신을 피하려면 다음 결제일 최소 24시간 전에 취소하세요.',
  'premiumCancelAnytime':
      '7일 체험이 포함됩니다. 구독 설정에서 언제든지 취소할 수 있습니다. 갱신을 피하려면 다음 결제일 최소 24시간 전에 취소하세요.',
  'premiumPurchaseUnavailable': '지금은 구매를 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
  'premiumOpenSubscriptionFailed': '구독 관리 화면을 열 수 없습니다.',
  'termsOfUse': '이용약관',
  'privacyPolicy': '개인정보 처리방침',
  'openLinkFailed': '링크를 열 수 없습니다.',
  'alarmSound': '알람 소리',
  'alarmSoundDescription': '아침 알람에 사용할 God Morning 알람 톤을 선택하세요.',
  'alarmSoundDescriptionIos': '소리를 탭하면 한 번 미리듣습니다. 다른 소리 탭 시 바로 전환.',
  'soundClassicAlarm': '밝은 비프음 (권장)',
  'soundGentleChime': '아침 차임',
  'soundChurchBell': '교회 종소리',
  'moreIphoneSounds': '휴대폰 소리 더 보기…',
  'currentAlarmSound': '현재: {name}',
  'savedAlarmSoundBadge': '저장됨',
  'systemAlarmSound': '시스템 알람 (기본)',
  'systemNotificationSound': '시스템 알림음',
  'systemRingtoneSound': '시스템 벨소리',
  'chooseFromPhoneSounds': '휴대폰 소리에서 선택',
  'previewSound': '소리 미리듣기',
  'soundSaved': '알람 소리가 저장되었습니다',
  'noRingtonesFound': '이 기기에서 소리를 찾지 못했습니다.',
  'notificationsPermissionTitle': '알림 허용',
  'notificationsPermissionBody': '아침 알람이 울리고, 기도 음성을 들을 수 있도록 몇 가지 권한이 필요합니다.',
  'allowNotifications': '허용하고 계속',
  'onboardingNext': '계속',
  'onboardingEnableAndStart': '허용하고 시작',
  'onboardingProductTitle': '아침의 첫 1분을 하나님께 드리세요.',
  'onboardingProductBody':
      'God Morning은 하루 한 구절, 짧은 기도, 그리고 Amen으로 아침을 하나님 앞에서 시작하도록 돕습니다.',
  'onboardingProductPointOneVerse': '매일 아침을 위한 하루 한 구절',
  'onboardingProductPointFirstMinute': '말씀과 기도로 정돈되는 조용한 첫 1분',
  'onboardingReadTitle': '소리 내어 읽고, 마음을 모아 시작하세요.',
  'onboardingReadBody':
      '알람이 울리면 말씀과 기도 미션이 열립니다. 음성 또는 타이핑으로 따라 읽고 완료할 수 있습니다.',
  'onboardingReadPointVoiceType': '음성 또는 타이핑 모드로 본문을 따라 읽기',
  'onboardingReadPointAmen': 'Amen을 눌러야 알람 미션이 완료됩니다',
  'onboardingAlarmTitle': '목적이 있는 아침 알람.',
  'onboardingAlarmBody': '시간과 알람음을 정해두면, 알람이 단순한 스누즈가 아니라 말씀과 기도의 자리로 이끌어 줍니다.',
  'onboardingAlarmPointClosed': '앱이 닫혀 있어도 울리도록 설계',
  'onboardingAlarmPointReturn': 'Amen 전에 나가면 알람이 다시 돌아올 수 있음',
  'onboardingPermissionsTitle': 'God Morning에 필요한 권한을 켜주세요.',
  'onboardingPermissionsBody': '알람, 알림, 마이크, 음성 인식이 안정적으로 동작하도록 필요한 권한을 요청합니다.',
  'commandCopied': '명령어가 복사되었습니다',
  'walkTogether': '함께 걸어가요',
  'circleInviteDescription': '아침 기도와 주일 예배를 함께 격려하세요.\n멤버 수 제한 없이 초대할 수 있습니다.',
  'createCircle': 'Circle 만들기',
  'joinCircle': 'Circle 참여',
  'circleNameHint': 'Circle 이름 (예: Grace Cell)',
  'circleIdHint': '친구에게 받은 Circle ID',
  'membersCount': '멤버 {count}명',
  'thisWeekMorning': '이번 주 · 월–일 아침 기도',
  'demoCircleBanner': '데모 Circle — 전체 기능은 iPhone/Android 앱에서',
  'localCircleBanner':
      '이 휴대폰에 저장됩니다. + 버튼으로 친구를 추가하세요. Circle ID를 공유하면 참여할 수 있습니다.',
  'enterCircleName': 'Circle 이름을 입력해 주세요.',
  'circleCreated': 'Circle이 생성되었습니다. Circle ID를 공유하거나 이메일/전화로 초대하세요.',
  'enterCircleId': 'Circle ID를 입력해 주세요.',
  'joinedCircle': 'Circle에 참여했습니다!',
  'sentEncouragement': '{name}에게 격려를 보냈습니다',
  'likeSaveFailed': '좋아요 저장에 실패했습니다.',
  'morningDoneToday': '오늘 아침 기도 완료',
  'morningNotYetToday': '오늘 아침 기도 아직',
  'sendPrayerForTomorrow': '기도 요청 보내기',
  'prayerAcceptHint': '이번 주 월–일 중 하루를 골라 기도해 줍니다',
  'unlike': '좋아요 취소',
  'sendLike': '좋아요 보내기',
  'doneToday': '오늘 완료',
  'notYetToday': '오늘 아직',
  'morningMonSun': '아침 · 월–일',
  'eveningMonSun': '저녁 · 월–일',
  'notYet': '아직',
  'liked': '좋아요함',
  'like': '좋아요',
  'prayer': '기도',
  'inviteFriend': '친구 초대',
  'addMember': '멤버 추가',
  'friendName': '친구 이름',
  'memberAddedToCircle': '{name}님이 Circle에 추가되었습니다.',
  'inviteByEmailOrPhone': '이메일 또는 전화번호로 초대',
  'email': '이메일',
  'phoneNumber': '전화번호',
  'sendInvite': '초대 보내기',
  'inviteSent': '{contact}에게 초대를 보냈습니다. 가입하거나 앱을 열면 참여할 수 있습니다.',
  'inviteShareCircleId': '친구에게 이 Circle ID를 공유하세요: {circleId}',
  'inviteSentExistingUser': '초대를 보냈습니다! Circle 참여 알림을 받게 됩니다.',
  'inviteFailed': '초대를 보낼 수 없습니다.',
  'enterEmailOrPhone': '이메일 또는 전화번호를 입력해 주세요.',
  'invalidEmail': '올바른 이메일 주소를 입력해 주세요.',
  'invalidPhone': '올바른 전화번호를 입력해 주세요.',
  'alreadyInCircle': '이미 Circle에 있는 사람입니다.',
  'prayerConfirmedTomorrow': '내일 아침 기도가 확정되었습니다.',
  'prayerRequestsForYou': '나에게 온 기도 요청',
  'circleLikePrayerHint':
      'Circle 멤버에게 ❤️ 격려나 기도제목을 보내세요. 상대가 요일을 고르면 아침 알람에서 함께 기도합니다.',
  'circleActivity': '활동',
  'sentPrayerRequests': '내가 보낸 기도',
  'likedYouThisWeek': '{name}님이 이번 주 ❤️를 보냈습니다',
  'markAllRead': '모두 읽음',
  'friendPrayedForYou': '기도 완료',
  'sendPrayerTopic': '기도제목 보내기',
  'onePrayerPerDayWeek': '하루 개인 기도 1개 · 이번 주 월–일 중 선택',
  'schedulePrayer': '예약',
  'pickDayThisWeek': '이번 주 하루 선택',
  'dayBooked': '예약됨',
  'circlePrayer': 'Circle 공동 기도',
  'createCirclePrayer': 'Circle 공동 기도 만들기',
  'circlePrayersThisWeek': '이번 주 CIRCLE 공동 기도',
  'circlePrayerTogether': '중요한 날, 모두가 함께 기도합니다',
  'weekPrayersCircle': '이번 주 기도 · CIRCLE',
  'importantDayLabel': '중요한 날 (월–일)',
  'prayerTopic': '기도 제목 (예: 수술, 위기)',
  'pickADay': '함께 기도할 날 선택',
  'scheduled': '예약됨',
  'circlePrayerCreated': 'Circle 공동 기도가 생성되었습니다. 모두가 함께 기도합니다.',
  'scheduleFailed': '기도 예약에 실패했습니다.',
  'prayerScheduledFor': '{name}의 기도를 {day}에 예약했습니다',
  'circlePrayerOn': 'CIRCLE 기도 · {day}',
  'onePrayerAcceptOnly': '하루 개인 기도 1개 · 월–일 중 선택',
  'fromLabel': '{name}에게서',
  'forYouTomorrow': '나를 위해 · 내일 아침',
  'decline': '거절',
  'prayTomorrow': '내일 기도',
  'tomorrowsPrayersCircle': '내일의 기도 · CIRCLE',
  'circlePrayerFeedSubtitle': '이번 주 예약된 개인 기도',
  'pending': '대기',
  'accepted': '수락',
  'declined': '거절됨',
  'sendPrayerRequest': '기도 요청 보내기',
  'toLabel': '받는 사람: {name}',
  'prayerRecipientChoose': '{name}이(가) 내일 아침 기도할지 선택합니다.',
  'optionalOpener': '1. 시작 한 문장 (선택)',
  'requiredPrayer': '2. 기도 요청 1–2문장 (필수)',
  'send': '보내기',
  'friendPrayerConfirmed': '{name}의 기도를 예약했습니다. 다른 요청은 다른 날에 예약하세요.',
  'prayerRequestSent': '{name}에게 기도 요청을 보냈습니다. 이번 주 하루를 고를 거예요.',
  'prayerAcceptedOneOnly': '{name}의 기도를 선택한 날에 예약했습니다.',
  'acceptFailed': '요청을 수락할 수 없습니다.',
  'prayerDeclined': '{name}의 기도 요청을 거절했습니다.',
  'declineFailed': '거절할 수 없습니다.',
  'prayerDemoSent': '기도 요청 전송 (데모) — {name}이(가) 수락하면 표시됩니다.',
  'prayerFrom': '{name}의 기도',
  'prayerArrow': '{from} → {to}',
  'timeToMeetLord': '주님을 만날 시간입니다.',
  'stopWithPrayerAndWord': '기도와 말씀으로 알람 끄기',
  'todaysPrayer': '오늘의 기도',
  'todaysWord': '오늘의 말씀',
  'listening': '듣는 중...',
  'completeWebDemo': '완료 (웹 데모)',
  'nextStepWebDemo': '다음 단계 (웹 데모)',
  'continueToNextStep': '다음 단계로',
  'completePrayerFlow': 'Amen',
  'alarmHowItWorksTitle': '내일도 알람이 울리나요?',
  'alarmHowItWorksBody': '네. 알람을 끄기 전까지 아침 알람은 계속 예약됩니다.',
  'alarmDetailedHowItWorksTitle': '알람은 이렇게 작동합니다',
  'alarmDetailedHowItWorksBody':
      '1. 아침 알람을 켜고 저장을 누르세요.\n'
      '2. 휴대폰이 알람과 알림 권한을 물으면 허용하세요.\n'
      '3. 정한 시간에 앱이 닫혀 있어도 알람이 울립니다.\n'
      '4. 알람을 멈추면 기도 화면이 열립니다. Amen 전까지 알람은 다시 울립니다.\n'
      '5. 음성 인식 중에는 목소리를 들을 수 있도록 알람 소리가 꺼집니다.',
  'bibleLicenseTitle': '성경 본문',
  'bibleLicenseBody':
      '성경 본문 출처:\n'
      '한국어: Korean Revised Version 1952/1961 (KRV / 개역한글). 출처: KorRV / Zefania XML. 권리: Public Domain.\n'
      '영어: World English Bible (WEB). 출처: eBible.org. 권리: Public Domain.\n'
      '독일어: Lutherbibel 1912. 출처: eBible.org. 권리: Public Domain.\n'
      '러시아어: Russian Synodal Translation (1876 / Синодальный перевод). 출처: eBible.org. 권리: Public Domain.\n'
      '스페인어: Reina-Valera 1909 (RV1909). 출처: eBible.org. 권리: Public Domain.\n'
      '포르투갈어: Bíblia Livre (BLJ). 출처: eBible.org. 권리: Public Domain.\n'
      '중국어: 和合本 1919 (Chinese Union Version, 간체). 출처: getBible / CrossWire. 권리: Public Domain.\n'
      '일본어: 口語訳 1954/1955 (Kougo-yaku). 출처: getBible / CrossWire. 권리: Public Domain.',
  'permissionNotificationTitle': '알림 허용',
  'permissionNotificationBody': '알람이 실제로 울리기 위해 필요합니다.',
  'permissionMicrophoneTitle': '마이크 허용',
  'permissionMicrophoneBody': '말씀과 기도를 읽는 목소리를 듣기 위해 필요합니다.',
  'permissionAlarmKitTitle': '알람 권한 허용',
  'permissionAlarmKitBody': '아침 알람이 안정적으로 울리기 위해 필요합니다.',
  'permissionMissionTitle': 'Amen 전까지 계속 울림',
  'permissionMissionBody': '말씀과 기도 미션을 완료해야 알람이 멈춥니다.',
  'permissionSettingsTitle': '권한',
  'permissionSettingsBody': '알람과 말씀 읽기 미션에 필요한 권한을 여기서 허용할 수 있습니다.',
  'permissionEnable': '허용',
  'permissionEnabled': '허용됨',
  'notificationsDisabledWarning': '알림이 꺼져 있습니다. 휴대폰 설정에서 알림을 켜야 알람이 울립니다.',
  'openIphoneSettings': '휴대폰 설정 열기',
  'enableNotificationsToRing': '알림을 먼저 허용해야 알람이 울립니다.',
  'tomorrow': '내일',
  'alarmScheduledNext': '알람 저장됨. 다음 울림: {time}',
  'stepMorningPrayer': '아침 기도',
  'stepCirclePrayer': 'Circle 공동 기도',
  'stepFriendPrayer': '친구 기도',
  'stepScripture': '성경 구절',
  'stepOfTotal': '{total}단계 중 {n} · {step}',
  'circlePrayingTogetherToday': '오늘 Circle 전체가 함께 기도합니다.',
  'successMorningCircleFriendScripture':
      '아침 기도, Circle 기도, 친구 기도, 성경 구절 — 완료.\n평안히 걸어가세요.',
  'successMorningCircleScripture': '아침 기도, Circle 기도, 성경 구절 — 완료.\n평안히 걸어가세요.',
  'successMeansOfGraceComplete': '오늘의 God Morning을 마쳤습니다.\n평안히 걸어가세요.',
  'cancelAlarmResumes': '취소 (알람이 다시 울립니다)',
  'morningAlarmMustComplete': '오늘 아침 기도를 완료해야 알람이 꺼집니다.',
  'eveningAlarmMustComplete': '오늘 저녁 축복을 완료해야 알람이 꺼집니다.',
  'blessBeforeRest': '자기 전 자녀들을 기도로 축복해주세요',
  'stepEveningGuide': '축복 안내',
  'stepAaronBlessing': '아론의 축복',
  'goodnightTitle': '안녕히 주무세요.',
  'successEveningRest': '주님이 너를 축복하시고 지키시기를.\n평안히 쉬세요.',
  'readAloudToContinue':
      '소리 내어 읽거나 입력하세요 — 80% 이상이면 버튼이 활성화됩니다. 끝까지 읽은 뒤 직접 눌러 주세요.',
  'inputModeVoice': '녹음',
  'inputModeKeyboard': '타이핑',
  'typePrayerHint': '읽은 내용을 입력하세요…',
  'typingProgress': '입력 중',
  'recordingInProgress': '녹음 중…',
  'liveTranscriptLabel': '인식된 말',
  'liveTranscriptHint': '소리 내어 읽으면 여기에 글자가 자동으로 써집니다.',
  'typedEchoLabel': '입력한 내용',
  'morningPrayerVoiceTypeHint': '시작하면 녹음(음성) 또는 타이핑으로 기도를 진행할 수 있습니다.',
  'typeToContinue': '읽은 내용을 입력하면 다음 단계로 넘어갑니다.',
  'switchedToTypeMode': '음성을 사용할 수 없어 타이핑 모드로 전환했습니다. 기도는 계속할 수 있습니다.',
  'emergencyTitle': 'Emergency — 영적 고백',
  'emergencyMorningHint': '아래 문장을 그대로 입력해야 오늘 아침 알람을 끌 수 있습니다.',
  'emergencyEveningHint': '외박·가족 사정 등 이유를 적어 오늘 저녁 축복을 건너뜁니다.',
  'emergencyMorningPhrase': '오늘은 도저히 못 하겠습니다. 주님 용서해주세요',
  'emergencyEveningPrefix': '오늘은 ',
  'emergencyEveningSuffix': ' 때문에 자녀 축복 기도를 드리지 못합니다. 주님 용서해주세요',
  'emergencyTypePhraseHint': '고백 문장을 입력하세요…',
  'emergencyEveningReasonHint': '예: 외박, 가족 여행, 할머니 댁…',
  'emergencyConfirm': '고백하고 알람 끄기',
  'emergencyNotAvailable': '이번 주 Emergency 사용 횟수를 모두 썼습니다.',
  'emergencyButton': 'Emergency — 오늘은 정말 못 하겠어요',
  'emergencySuccessMessage': '주님이 고백을 들으십니다. 오늘 알람은 꺼졌습니다. 내일 다시 만나요.',
  'emergencyGraceRemaining': '첫 7일 — Emergency 무제한 ({days}일 남음)',
  'emergencyRemainingThisWeek': '이번 주 Emergency 남은 횟수: {count}',
  'prayerIntensity': '기도 강도',
  'prayerIntensityGentle': '부드러운',
  'prayerIntensityNormal': '일반',
  'prayerIntensityStrict': '엄격',
  'prayerIntensityHint':
      '부드러운 65% · 일반 80% · 엄격 90%. 7일 후 Emergency: 주 3 / 1 / 0회',
  'streakTitle': '연속 기록',
  'streakDays': '{days}일 연속',
  'eveningStreakDays': '자녀 축복 {days}일 연속',
  'eveningStreakStart': '오늘 저녁, 자녀 축복으로 시작해요',
  'streakStartToday': '오늘 아침 기도를 마치면 연속 기록이 시작됩니다.',
  'emergencyFeatureTitle': 'Emergency — 영적 고백',
  'emergencyFeatureBody':
      '알람 화면에서 Emergency → 고백 문장 입력으로 해제. 저녁은 외박·가족 사정 등 이유를 적으세요. 미리보기에서도 테스트 가능.',
  'hallelujah': '할렐루야!',
  'done': '완료',
  'amen': 'Amen',
  'prayingWithYou': '오늘 아침 {name}이(가) 함께 기도합니다.',
  'blessWithPrayer': '기도로 축복하기',
  'micPermissionChrome': 'Chrome 주소창 자물쇠에서 마이크 권한을 허용해 주세요.',
  'speechNotAvailable': '이 기기에서는 음성 인식을 사용할 수 없습니다.',
  'welcomeBack': '다시 오신 것을 환영합니다.',
  'signInToContinue': '계속하려면 로그인하세요.',
  'password': '비밀번호',
  'signIn': '로그인',
  'signInWithApple': 'Apple로 로그인',
  'createAccount': '계정 만들기',
  'noAccount': '계정이 없으신가요? 만들기',
  'haveAccount': '이미 계정이 있으신가요? 로그인',
  'name': '이름',
  'confirmPassword': '비밀번호 확인',
  'enterEmail': '이메일을 입력해 주세요.',
  'enterPassword': '비밀번호를 입력해 주세요.',
  'enterName': '이름을 입력해 주세요.',
  'passwordMinLength': '비밀번호는 6자 이상이어야 합니다.',
  'passwordsDoNotMatch': '비밀번호가 일치하지 않습니다.',
  'errorInvalidEmail': '올바른 이메일 주소를 입력해 주세요.',
  'errorUserNotFound': '이 이메일로 등록된 계정이 없습니다.',
  'errorWrongPassword': '비밀번호가 올바르지 않습니다.',
  'errorEmailInUse': '이미 사용 중인 이메일입니다.',
  'errorWeakPassword': '비밀번호는 6자 이상이어야 합니다.',
  'errorInvalidCredential': '이메일과 비밀번호를 확인해 주세요.',
  'errorOperationNotAllowed': '이 로그인 방식은 사용할 수 없습니다.',
  'errorSignInFailed': '로그인에 실패했습니다. 다시 시도해 주세요.',
  'errorLoginRequired': '로그인이 필요합니다.',
  'errorAlreadyInCircle': '이미 Circle에 속해 있습니다.',
  'errorCircleNotFound': 'Circle을 찾을 수 없습니다. Circle ID를 확인하세요.',
  'errorPrayerTextRequired': '기도 요청을 입력해 주세요.',
  'errorOpenerOneSentence': '시작 기도는 한 문장이어야 합니다.',
  'errorTomorrowPrayerConfirmed': '{name}은(는) 이미 내일 아침 기도를 확정했습니다.',
  'errorOnePrayerPerDay': '하루에 기도는 하나만 수락할 수 있습니다.',
  'notificationPrayerHeard': '친구가 당신의 기도를 들었습니다.',
};

const _ru = {
  'repeatDays': 'Дни повтора',
  'perDayTimesTitle': 'Разное время по дням',
  'alarmsTitle': 'Будильники',
  'addAlarm': 'Добавить будильник',
  'deleteAlarmTitle': 'Удалить',
  'everyDay': 'Каждый день',
  'maxAlarmsReached': 'Можно задать до 5 будильников.',
  'cannotDeleteLastAlarm': 'Нужен хотя бы один будильник — вместо удаления выключите его.',
  'alarmListHint': 'У каждого будильника своя миссия. Нажмите, чтобы изменить, удерживайте, чтобы удалить.',
  'streakCalendarSubtitle': 'Дни встречи с Господом отмечаются автоматически.',
  'calendarTab': 'Календарь',
  'homeTab': 'Главная',
  'weatherTab': 'Погода',
  'showLocalWeather': 'Показать местную погоду — нажмите, чтобы включить',
  'myLocation': 'Моё местоположение',
  'tenDayForecast': 'ПРОГНОЗ НА 10 ДНЕЙ',
  'nowLabel': 'Сейчас',
  'todayLabel': 'Сегодня',
  'streakTotalDays': 'Всего вы встречали Господа {days} дней',
  'perDayTimesSubtitle': 'Задайте своё время будильника для каждого дня',
  'setTimeForDay': 'Время будильника на {day}',
  'selectAtLeastOneAlarmDay': 'Выберите хотя бы один день будильника.',
  'weekdayShortMonday': 'Пн',
  'weekdayShortTuesday': 'Вт',
  'weekdayShortWednesday': 'Ср',
  'weekdayShortThursday': 'Чт',
  'weekdayShortFriday': 'Пт',
  'weekdayShortSaturday': 'Сб',
  'weekdayShortSunday': 'Вс',
  'setAlarmTime': 'ЗАДАТЬ ВРЕМЯ БУДИЛЬНИКА',
  'morningAlarmOffHint': 'Будильник выключен — включите ниже, чтобы запланировать',
  'eveningBlessingOffHint': 'Благословение выключено — включите ниже, чтобы запланировать',
  'backToMain': 'На главную',
  'premiumTitle': 'God Morning Премиум',
  'premiumSettingsSubtitle': 'Управление подпиской и покупками (по желанию).',
  'premiumHeroTitle': 'Начните утро с Богом на первом месте.',
  'premiumHeroSubtitle': 'Откройте полный ритм будильника с Писанием: все планы, звуки, языки и местная погода.',
  'premiumMonthlyTitle': 'Месячная',
  'premiumMonthlyPrice': '\$2.99 / месяц',
  'premiumAnnualTitle': 'Годовая',
  'premiumAnnualPrice': '\$29.99 / год',
  'premiumTrialLabel': '7 дней бесплатно',
  'premiumMonthlyTrialTerms': '7 дней бесплатно, затем ежемесячное продление.',
  'premiumAnnualTrialTerms': '7 дней бесплатно, затем ежегодное продление.',
  'premiumFeatureAlarm': 'Молитвенный будильник, повторяющийся до «Аминь»',
  'premiumFeaturePlans': '365 псалмов и 52 любимых стиха',
  'premiumFeatureWeather': 'Местная погода после завершения (по желанию)',
  'premiumStartTrial': 'Начать 7-дневный бесплатный период',
  'premiumRestore': 'Восстановить покупки',
  'premiumManageSubscription': 'Управление или отмена подписки',
  'premiumLoadingProducts': 'Загрузка вариантов подписки...',
  'premiumProductsUnavailable': 'Варианты подписки пока недоступны. Убедитесь, что продукты подписки в App Store или Google Play настроены для этого приложения.',
  'premiumPurchaseSuccess': 'Премиум активен.',
  'premiumPurchasePending': 'Ваша покупка ожидает подтверждения магазина. Премиум откроется после её завершения.',
  'premiumPurchaseCancelled': 'Покупка отменена.',
  'premiumPurchaseFailed': 'Не удалось завершить покупку. Попробуйте ещё раз.',
  'premiumRestoreMissing': 'Активная подписка для восстановления не найдена.',
  'premiumTerms': 'Оплата производится через Apple In-App Purchase или биллинг Google Play. 7-дневный бесплатный период и продление подписки управляются магазином. Отменить можно в любое время в настройках подписки. Чтобы избежать продления, отмените подписку не позднее чем за 24 часа до следующей даты списания.',
  'premiumCancelAnytime': 'Включает 7-дневный пробный период. Отменить можно в любое время в настройках подписки. Чтобы избежать продления, отмените подписку не позднее чем за 24 часа до следующей даты списания.',
  'premiumPurchaseUnavailable': 'Покупки сейчас недоступны. Попробуйте позже.',
  'premiumOpenSubscriptionFailed': 'Не удалось открыть управление подпиской.',
  'termsOfUse': 'Условия использования',
  'privacyPolicy': 'Политика конфиденциальности',
  'openLinkFailed': 'Не удалось открыть ссылку.',
  'circleLikePrayerHint': 'Отправьте ❤️ в поддержку или поделитесь темой молитвы с участниками Круга. Они выберут день и помолятся с вами на утреннем будильнике.',
  'circleActivity': 'АКТИВНОСТЬ',
  'sentPrayerRequests': 'ОТПРАВЛЕННЫЕ МОЛИТВЫ',
  'likedYouThisWeek': '{name} отправил(а) вам ❤️ на этой неделе',
  'markAllRead': 'Отметить всё прочитанным',
  'friendPrayedForYou': 'Помолился за вас',
  'sendPrayerTopic': 'Отправить тему молитвы',
  'recordingInProgress': 'Запись…',
  'liveTranscriptLabel': 'Что мы слышим',
  'liveTranscriptHint': 'Говорите вслух — ваши слова появятся здесь, чтобы вы могли следить во время молитвы.',
  'typedEchoLabel': 'Что вы напечатали',
  'morningPrayerVoiceTypeHint': 'После начала используйте Запись (голос) или Печать, чтобы прочитать каждый шаг молитвы.',
  'typeToContinue': 'Напечатайте прочитанное, чтобы продолжить.',
  'switchedToTypeMode': 'Голос недоступен — включён режим Печать. Вы всё равно можете завершить молитву.',
  'appTitle': 'God Morning',
  'save': 'Сохранить',
  'cancel': 'Отмена',
  'retry': 'Повторить',
  'settings': 'Настройки',
  'language': 'Язык',
  'selectLanguage': 'Выберите язык',
  'scripturePlan': 'План Писания',
  'selectScripturePlan': 'Выберите план Писания',
  'scripturePlanDaily': '365 псалмов и молитв',
  'scripturePlanDailySubtitle':
      'Каждое утро один стих из Псалмов и короткая молитва.',
  'scripturePlanBeloved52': '52 любимых стиха',
  'scripturePlanBeloved52Subtitle':
      'Читайте один любимый стих каждую неделю для запоминания.',
  'missionContent': 'Содержание миссии',
  'selectMissionContent': 'Выберите содержание миссии',
  'missionContentScriptureAndPrayer': 'Писание + молитва',
  'missionContentScriptureAndPrayerSubtitle':
      'Читайте и библейский стих, и утреннюю молитву.',
  'missionContentScriptureOnly': 'Только Писание',
  'missionContentScriptureOnlySubtitle':
      'Завершайте миссию, читая только библейский стих.',
  'missionContentPrayerOnly': 'Только молитва',
  'missionContentPrayerOnlySubtitle':
      'Читайте отдельный 365-дневный план тематических молитв без блока Писания.',
  'morningPrayerEveningBlessing': 'Утренняя молитва и вечернее благословение.',
  'tapTimeToSetAlarm':
      'Нажмите на время, чтобы настроить будильник. Выберите звук ниже.',
  'tapToSetTimeAndSound': 'Нажмите, чтобы настроить время и звук',
  'circleTapToOpen': 'Малая группа · нажмите, чтобы открыть',
  'webPreviewBanner':
      'Предпросмотр в Chrome — проверьте будильник и Circle. Полный функционал на iPhone/Android.',
  'morningAlarm': 'Утренний будильник',
  'eveningBlessing': 'Вечернее благословение',
  'alarmOn': 'Будильник включён',
  'alarmOff': 'Будильник выключен',
  'previewMorningAlarm': 'Предпросмотр утреннего будильника',
  'previewEveningBlessing': 'Предпросмотр вечернего благословения',
  'yourCircle': 'Ваш Circle',
  'localWeather': 'Местная погода',
  'localWeatherSubtitle':
      'Показывает сегодня и неделю по текущему местоположению.',
  'localWeatherLoading': 'Загрузка прогноза...',
  'localWeatherSettingsBody':
      'Текущее местоположение используется только для прогноза на сегодня и неделю. God Morning не сохраняет местоположение.',
  'enableLocalWeather': 'Показывать местную погоду',
  'weatherRefresh': 'Обновить погоду',
  'weatherThisWeek': 'Эта неделя',
  'weatherFeelsLike': 'Ощущается как {temp}',
  'weatherWind': 'Ветер {speed} {unit}',
  'weatherRainChance': 'Дождь {chance}%',
  'weatherHighLow': 'Макс {high}  Мин {low}',
  'weatherPermissionRequired':
      'Для местной погоды нужно разрешение геолокации.',
  'weatherLocationServicesOff':
      'Включите службы геолокации, чтобы показать погоду.',
  'weatherUnavailable': 'Погода сейчас недоступна. Попробуйте позже.',
  'weatherEnabled': 'Местная погода включена',
  'weatherDisabled': 'Местная погода выключена',
  'weatherAttribution': 'Данные погоды: Open-Meteo.com',
  'weatherTemperatureUnit': 'Единицы температуры',
  'weatherUnitFahrenheit': 'Фаренгейт (°F)',
  'weatherUnitCelsius': 'Цельсий (°C)',
  'enableMorningAlarm': 'Включить утренний будильник',
  'morningAlarmSubtitle': 'Прочитайте молитву и Писание, чтобы отключить',
  'enableEveningBlessing': 'Включить вечернее благословение',
  'eveningBlessingSubtitle': 'Прочитайте благословение Аарона, чтобы отключить',
  'saveAlarms': 'Сохранить будильники',
  'testMorningAlarm': 'Тест утреннего будильника (5 сек)',
  'testEveningAlarm': 'Тест вечернего будильника (5 сек)',
  'practiceMission': 'Практика миссии',
  'practiceMissionSubtitle':
      'Попробуйте чтение Писания и молитвы без изменения настоящего будильника, повторов или серии.',
  'missionPassThreshold': 'Порог прохождения миссии',
  'missionPassThresholdSubtitle':
      'Выберите, какая часть Писания и молитвы должна совпасть, прежде чем откроется Amen. Ниже проще; выше строже.',
  'missionPassThresholdLow': 'Проще',
  'missionPassThresholdHigh': 'Строже',
  'alarmsSaved': 'Будильники сохранены',
  'saving': 'Сохранение...',
  'signOut': 'Выйти',
  'home': 'Главная',
  'alarmSound': 'ЗВУК БУДИЛЬНИКА',
  'alarmSoundDescription':
      'Выберите встроенный сигнал God Morning для утреннего будильника.',
  'alarmSoundDescriptionIos':
      'Нажмите, чтобы прослушать один раз. Другой звук переключается плавно.',
  'soundClassicAlarm': 'Классический будильник (рекомендуется)',
  'soundGentleChime': 'Мягкий перезвон',
  'soundChurchBell': 'Церковный колокол',
  'moreIphoneSounds': 'Ещё звуки телефона…',
  'currentAlarmSound': 'Сейчас: {name}',
  'savedAlarmSoundBadge': 'Сохранено',
  'systemAlarmSound': 'Системный будильник (по умолчанию)',
  'systemNotificationSound': 'Системное уведомление',
  'systemRingtoneSound': 'Системная мелодия',
  'chooseFromPhoneSounds': 'Выбрать звук с телефона',
  'previewSound': 'Прослушать',
  'soundSaved': 'Звук будильника сохранён',
  'noRingtonesFound': 'На этом устройстве звуки не найдены.',
  'notificationsPermissionTitle': 'Разрешить уведомления',
  'notificationsPermissionBody':
      'God Morning нужны разрешения, чтобы утренний будильник звонил и слышал вашу молитву.',
  'allowNotifications': 'Разрешить и продолжить',
  'onboardingNext': 'Продолжить',
  'onboardingEnableAndStart': 'Разрешить и начать',
  'onboardingProductTitle': 'Отдайте Богу первую минуту утра.',
  'onboardingProductBody':
      'God Morning помогает начать день с одного библейского стиха, короткой молитвы и простого Amen.',
  'onboardingProductPointOneVerse': 'Один стих в день для вашего утра',
  'onboardingProductPointFirstMinute':
      'Тихая первая минута со Словом и молитвой',
  'onboardingReadTitle': 'Читайте вслух. Начинайте внимательно.',
  'onboardingReadBody':
      'Когда прозвучит будильник, откроется миссия со стихом и молитвой. Ее можно выполнить голосом или набором текста.',
  'onboardingReadPointVoiceType': 'Следуйте тексту голосом или в режиме набора',
  'onboardingReadPointAmen': 'Amen завершает миссию будильника',
  'onboardingAlarmTitle': 'Будильник с целью.',
  'onboardingAlarmBody':
      'Выберите время и звук, чтобы будильник вел вас не к очередному сну, а к Слову и молитве.',
  'onboardingAlarmPointClosed':
      'Создан, чтобы звонить даже когда приложение закрыто',
  'onboardingAlarmPointReturn': 'Если выйти до Amen, будильник может вернуться',
  'onboardingPermissionsTitle': 'Включите то, что нужно God Morning.',
  'onboardingPermissionsBody':
      'Мы запросим разрешения для будильника, уведомлений, микрофона и распознавания речи.',
  'commandCopied': 'Команда скопирована',
  'walkTogether': 'Идём вместе',
  'circleInviteDescription':
      'Поддерживайте друзей в утренней молитве и воскресном богослужении.\nБез ограничения числа участников.',
  'createCircle': 'Создать Circle',
  'joinCircle': 'Присоединиться к Circle',
  'circleNameHint': 'Название Circle (напр. Grace Cell)',
  'circleIdHint': 'Circle ID от друга',
  'membersCount': '{count} участников',
  'thisWeekMorning': 'На этой неделе · утренняя молитва пн–вс',
  'demoCircleBanner':
      'Демо Circle — полный функционал в приложении iPhone/Android',
  'localCircleBanner':
      'Сохранено на этом телефоне. Поделитесь Circle ID, чтобы друзья могли присоединиться.',
  'enterCircleName': 'Введите название Circle.',
  'circleCreated':
      'Circle создан. Поделитесь ID или пригласите по email/телефону.',
  'enterCircleId': 'Введите Circle ID.',
  'joinedCircle': 'Вы присоединились к Circle!',
  'sentEncouragement': 'Отправлено ободрение для {name}',
  'likeSaveFailed': 'Не удалось сохранить лайк.',
  'morningDoneToday': 'Утренняя молитва сегодня выполнена',
  'morningNotYetToday': 'Утренняя молитва сегодня ещё не выполнена',
  'sendPrayerForTomorrow': 'Отправить просьбу о молитве',
  'prayerAcceptHint': 'Они выберут день пн–вс на этой неделе для молитвы',
  'unlike': 'Убрать лайк',
  'sendLike': 'Отправить лайк',
  'doneToday': 'Сегодня выполнено',
  'notYetToday': 'Сегодня ещё нет',
  'morningMonSun': 'Утро · пн–вс',
  'eveningMonSun': 'Вечер · пн–вс',
  'notYet': 'Ещё нет',
  'liked': 'Лайкнуто',
  'like': 'Лайк',
  'prayer': 'Молитва',
  'inviteFriend': 'Пригласить друга',
  'addMember': 'Добавить участника',
  'friendName': 'Имя друга',
  'memberAddedToCircle': '{name} добавлен(а) в ваш Circle.',
  'inviteByEmailOrPhone': 'Пригласить по email или телефону',
  'email': 'Email',
  'phoneNumber': 'Телефон',
  'sendInvite': 'Отправить приглашение',
  'inviteSent':
      'Приглашение отправлено {contact}. Они присоединятся после регистрации.',
  'inviteShareCircleId': 'Поделитесь Circle ID с другом: {circleId}',
  'inviteSentExistingUser': 'Приглашение отправлено! Они получат уведомление.',
  'inviteFailed': 'Не удалось отправить приглашение.',
  'enterEmailOrPhone': 'Введите email или номер телефона.',
  'invalidEmail': 'Введите корректный email.',
  'invalidPhone': 'Введите корректный номер телефона.',
  'alreadyInCircle': 'Этот человек уже в вашем Circle.',
  'prayerConfirmedTomorrow': 'Утренняя молитва на завтра подтверждена.',
  'prayerRequestsForYou': 'ПРОСЬБЫ О МОЛИТВЕ ДЛЯ ВАС',
  'onePrayerPerDayWeek': 'Одна личная молитва в день · выберите день пн–вс',
  'schedulePrayer': 'Запланировать',
  'pickDayThisWeek': 'Выберите день на этой неделе',
  'dayBooked': 'Занято',
  'circlePrayer': 'Молитва Circle',
  'createCirclePrayer': 'Создать общую молитву Circle',
  'circlePrayersThisWeek': 'ОБЩИЕ МОЛИТВЫ CIRCLE НА ЭТОЙ НЕДЕЛЕ',
  'circlePrayerTogether': 'В важные дни все молятся вместе',
  'weekPrayersCircle': 'МОЛИТВЫ НА ЭТОЙ НЕДЕЛЕ · CIRCLE',
  'importantDayLabel': 'Важный день (пн–вс)',
  'prayerTopic': 'Тема молитвы (напр. операция, кризис)',
  'pickADay': 'Выберите день для совместной молитвы',
  'scheduled': 'Запланировано',
  'circlePrayerCreated': 'Общая молитва создана. Все будут молиться вместе.',
  'scheduleFailed': 'Не удалось запланировать молитву.',
  'prayerScheduledFor': 'Молитва для {name} запланирована на {day}',
  'circlePrayerOn': 'МОЛИТВА CIRCLE · {day}',
  'onePrayerAcceptOnly': 'Одна личная молитва в день · пн–вс',
  'fromLabel': 'От {name}',
  'forYouTomorrow': 'Для вас · завтра утром',
  'decline': 'Отклонить',
  'prayTomorrow': 'Молиться завтра',
  'tomorrowsPrayersCircle': 'МОЛИТВЫ НА ЗАВТРА · CIRCLE',
  'circlePrayerFeedSubtitle': 'Личные молитвы, запланированные на неделю',
  'pending': 'Ожидание',
  'accepted': 'Принято',
  'declined': 'Отклонено',
  'sendPrayerRequest': 'Отправить просьбу о молитве',
  'toLabel': 'Кому: {name}',
  'prayerRecipientChoose': '{name} решит, молиться ли завтра утром.',
  'optionalOpener': '1. Вступительное предложение (необяз.)',
  'requiredPrayer': '2. Просьба о молитве 1–2 предложения (обяз.)',
  'send': 'Отправить',
  'friendPrayerConfirmed':
      'Молитва для {name} запланирована. Другие — на другие дни.',
  'prayerRequestSent':
      'Просьба отправлена {name}. Они выберут день на этой неделе.',
  'prayerAcceptedOneOnly':
      'Молитва для {name} запланирована на выбранный день.',
  'acceptFailed': 'Не удалось принять запрос.',
  'prayerDeclined': 'Просьба от {name} отклонена.',
  'declineFailed': 'Не удалось отклонить.',
  'prayerDemoSent': 'Просьба отправлена (демо) — появится, если {name} примет.',
  'prayerFrom': 'МОЛИТВА ОТ {name}',
  'prayerArrow': '{from} → {to}',
  'timeToMeetLord': 'Пришло время встретиться с Господом.',
  'stopWithPrayerAndWord': 'Остановить молитвой и Словом',
  'todaysPrayer': 'СЕГОДНЯШНЯЯ МОЛИТВА',
  'todaysWord': 'СЕГОДНЯШНЕЕ СЛОВО',
  'listening': 'Слушаю...',
  'completeWebDemo': 'Готово (веб-демо)',
  'nextStepWebDemo': 'Следующий шаг (веб-демо)',
  'continueToNextStep': 'Следующий шаг',
  'completePrayerFlow': 'Amen',
  'alarmHowItWorksTitle': 'Зазвонит ли будильник завтра?',
  'alarmHowItWorksBody':
      'Да. God Morning будет держать утренний будильник включённым, пока вы его не выключите.',
  'alarmDetailedHowItWorksTitle': 'Как это работает',
  'alarmDetailedHowItWorksBody':
      '1. Включите утренний будильник и нажмите «Сохранить».\n'
      '2. Разрешите будильники и уведомления, если телефон спросит.\n'
      '3. В выбранное время будильник зазвонит, даже если приложение закрыто.\n'
      '4. Остановите будильник, чтобы открыть молитву. До Amen он будет возвращаться.\n'
      '5. Во время распознавания речи звук будильника выключен, чтобы приложение слышало голос.',
  'bibleLicenseTitle': 'Текст Библии',
  'bibleLicenseBody':
      'Источники библейского текста:\n'
      'Корейский: Korean Revised Version 1952/1961 (KRV / 개역한글). Источник: KorRV / Zefania XML. Права: Public Domain.\n'
      'Английский: World English Bible (WEB). Источник: eBible.org. Права: Public Domain.\n'
      'Немецкий: Lutherbibel 1912. Источник: eBible.org. Права: Public Domain.\n'
      'Русский: Russian Synodal Translation (1876 / Синодальный перевод). Источник: eBible.org. Права: Public Domain.\n'
      'Испанский: Reina-Valera 1909 (RV1909). Источник: eBible.org. Права: Public Domain.\n'
      'Португальский: Bíblia Livre (BLJ). Источник: eBible.org. Права: Public Domain.\n'
      'Китайский: Chinese Union Version 1919 (和合本, упрощённый). Источник: getBible / CrossWire. Права: Public Domain.\n'
      'Японский: Kougo-yaku 1954/1955 (口語訳). Источник: getBible / CrossWire. Права: Public Domain.',
  'permissionNotificationTitle': 'Уведомления',
  'permissionNotificationBody': 'Нужны, чтобы будильник мог вас разбудить.',
  'permissionMicrophoneTitle': 'Микрофон',
  'permissionMicrophoneBody':
      'Нужен, чтобы приложение слышало чтение Писания и молитвы.',
  'permissionAlarmKitTitle': 'Разрешение будильника',
  'permissionAlarmKitBody': 'Нужно, чтобы утренний будильник звонил надёжно.',
  'permissionMissionTitle': 'Amen завершает будильник',
  'permissionMissionBody':
      'Будильник возвращается, пока миссия Писания и молитвы не завершена.',
  'permissionSettingsTitle': 'Разрешения',
  'permissionSettingsBody':
      'Включите разрешения, нужные для будильника и миссии чтения.',
  'permissionEnable': 'Включить',
  'permissionEnabled': 'Включено',
  'notificationsDisabledWarning':
      'Уведомления выключены. Включите их в настройках телефона.',
  'openIphoneSettings': 'Открыть настройки телефона',
  'enableNotificationsToRing':
      'Сначала включите уведомления — иначе будильник не зазвонит.',
  'tomorrow': 'завтра',
  'alarmScheduledNext': 'Будильник сохранён. Следующий звонок: {time}',
  'stepMorningPrayer': 'Утренняя молитва',
  'stepCirclePrayer': 'Молитва Circle',
  'stepFriendPrayer': 'Молитва друга',
  'stepScripture': 'Писание',
  'stepOfTotal': 'Шаг {n} из {total} · {step}',
  'circlePrayingTogetherToday': 'Сегодня весь Circle молится вместе.',
  'successMorningCircleFriendScripture':
      'Утренняя молитва, молитва Circle, молитва друга и Писание — готово.\nИдите с миром.',
  'successMorningCircleScripture':
      'Утренняя молитва, молитва Circle и Писание — готово.\nИдите с миром.',
  'successMeansOfGraceComplete':
      'God Morning на сегодня завершен.\nИдите с миром.',
  'cancelAlarmResumes': 'Отмена (будильник снова зазвонит)',
  'morningAlarmMustComplete':
      'Завершите утреннюю молитву, чтобы выключить будильник.',
  'eveningAlarmMustComplete':
      'Завершите вечернее благословение, чтобы выключить будильник.',
  'blessBeforeRest': 'Благословите детей молитвой перед сном',
  'stepEveningGuide': 'Напутствие',
  'stepAaronBlessing': 'Благословение Аарона',
  'goodnightTitle': 'Спокойной ночи.',
  'successEveningRest':
      'Господь благословит тебя и сохранит тебя.\nОтдыхай с миром.',
  'readAloudToContinue':
      'Читайте вслух или вводите текст — при 80% кнопка активна. Нажмите, когда дочитаете.',
  'inputModeVoice': 'Голос',
  'inputModeKeyboard': 'Текст',
  'typePrayerHint': 'Введите прочитанное…',
  'typingProgress': 'Ввод',
  'emergencyTitle': 'Emergency — духовное покаяние',
  'emergencyMorningHint':
      'Введите фразу ниже дословно, чтобы отключить утренний будильник.',
  'emergencyEveningHint':
      'Укажите причину (ночёвка, семья…) чтобы пропустить вечернее благословение.',
  'emergencyMorningPhrase': 'Сегодня я правда не могу. Господи, прости меня.',
  'emergencyEveningPrefix': 'Сегодня из-за ',
  'emergencyEveningSuffix':
      ' я не смог помолиться благословением для детей. Господи, прости меня.',
  'emergencyTypePhraseHint': 'Введите фразу покаяния…',
  'emergencyEveningReasonHint': 'напр. ночёвка, поездка…',
  'emergencyConfirm': 'Отправить покаяние и выключить',
  'emergencyNotAvailable': 'Emergency на этой неделе уже использованы.',
  'emergencyButton': 'Emergency — сегодня не могу',
  'emergencySuccessMessage':
      'Господь слышит ваше покаяние. Будильник на сегодня выключен.',
  'emergencyGraceRemaining':
      'Первые 7 дней — Emergency без лимита ({days} дн. осталось).',
  'emergencyRemainingThisWeek': 'Emergency осталось на неделе: {count}',
  'prayerIntensity': 'Интенсивность молитвы',
  'prayerIntensityGentle': 'Мягкая',
  'prayerIntensityNormal': 'Обычная',
  'prayerIntensityStrict': 'Строгая',
  'prayerIntensityHint':
      'Мягкая 65% · Обычная 80% · Строгая 90%. Emergency: 3 / 1 / 0 в неделю после 7 дней.',
  'streakTitle': 'Серия дней',
  'streakDays': '{days} дней подряд',
  'eveningStreakDays': 'Благословение детей — {days} дней подряд',
  'eveningStreakStart': 'Начните сегодня вечером с благословения детей',
  'streakStartToday': 'Завершите утреннюю молитву сегодня, чтобы начать серию.',
  'emergencyFeatureTitle': 'Emergency — духовное покаяние',
  'emergencyFeatureBody':
      'На экране будильника нажмите Emergency и введите покаяние. Вечером — укажите причину.',
  'hallelujah': 'Аллилуия!',
  'done': 'Готово',
  'amen': 'Amen',
  'prayingWithYou': 'Сегодня утром {name} молится с вами.',
  'blessWithPrayer': 'Благословить молитвой',
  'micPermissionChrome':
      'Разрешите микрофон в Chrome (значок замка в адресной строке).',
  'speechNotAvailable': 'Распознавание речи недоступно на этом устройстве.',
  'welcomeBack': 'С возвращением.',
  'signInToContinue': 'Войдите, чтобы продолжить.',
  'password': 'Пароль',
  'signIn': 'Войти',
  'signInWithApple': 'Войти через Apple',
  'createAccount': 'Создать аккаунт',
  'noAccount': 'Нет аккаунта? Создать',
  'haveAccount': 'Уже есть аккаунт? Войти',
  'name': 'Имя',
  'confirmPassword': 'Подтвердите пароль',
  'enterEmail': 'Введите email.',
  'enterPassword': 'Введите пароль.',
  'enterName': 'Введите имя.',
  'passwordMinLength': 'Пароль должен быть не менее 6 символов.',
  'passwordsDoNotMatch': 'Пароли не совпадают.',
  'errorInvalidEmail': 'Введите корректный email.',
  'errorUserNotFound': 'Аккаунт с этим email не найден.',
  'errorWrongPassword': 'Неверный пароль.',
  'errorEmailInUse': 'Этот email уже используется.',
  'errorWeakPassword': 'Пароль должен быть не менее 6 символов.',
  'errorInvalidCredential': 'Проверьте email и пароль.',
  'errorOperationNotAllowed': 'Этот способ входа недоступен.',
  'errorSignInFailed': 'Не удалось войти. Попробуйте снова.',
  'errorLoginRequired': 'Требуется вход.',
  'errorAlreadyInCircle': 'Вы уже в Circle.',
  'errorCircleNotFound': 'Circle не найден. Проверьте Circle ID.',
  'errorPrayerTextRequired': 'Введите просьбу о молитве.',
  'errorOpenerOneSentence': 'Вступительная молитва — одно предложение.',
  'errorTomorrowPrayerConfirmed':
      '{name} уже подтвердил(а) утреннюю молитву на завтра.',
  'errorOnePrayerPerDay': 'Можно принять только одну молитву в день.',
  'notificationPrayerHeard': 'Ваш друг услышал вашу молитву.',
  'premiumFeatureLanguages':
      'Английский, корейский, немецкий, русский, испанский, португальский, китайский и японский',
  'eveningChildrenBlessing': 'Время благословения детей',
};

// Spanish — complete app UI map.
const _es = {
  'repeatDays': 'Días de repetición',
  'perDayTimesTitle': 'Hora distinta por día',
  'alarmsTitle': 'Alarmas',
  'addAlarm': 'Añadir alarma',
  'deleteAlarmTitle': 'Eliminar',
  'everyDay': 'Todos los días',
  'maxAlarmsReached': 'Puedes configurar hasta 5 alarmas.',
  'cannotDeleteLastAlarm': 'Necesitas al menos una alarma; desactívala en su lugar.',
  'alarmListHint': 'Cada alarma tiene su propia misión. Toca para editar, mantén pulsado para eliminar.',
  'streakCalendarSubtitle': 'Los días que te encontraste con el Señor se marcan automáticamente.',
  'calendarTab': 'Calendario',
  'homeTab': 'Inicio',
  'weatherTab': 'Clima',
  'showLocalWeather': 'Mostrar el clima local; toca para activar',
  'myLocation': 'Mi ubicación',
  'tenDayForecast': 'PRONÓSTICO DE 10 DÍAS',
  'nowLabel': 'Ahora',
  'todayLabel': 'Hoy',
  'streakTotalDays': 'Te has encontrado con el Señor {days} días en total',
  'perDayTimesSubtitle': 'Establece una hora de alarma distinta para cada día',
  'setTimeForDay': 'Hora de alarma del {day}',
  'selectAtLeastOneAlarmDay': 'Selecciona al menos un día de alarma.',
  'weekdayShortMonday': 'Lun',
  'weekdayShortTuesday': 'Mar',
  'weekdayShortWednesday': 'Mié',
  'weekdayShortThursday': 'Jue',
  'weekdayShortFriday': 'Vie',
  'weekdayShortSaturday': 'Sáb',
  'weekdayShortSunday': 'Dom',
  'premiumTitle': 'God Morning Premium',
  'premiumSettingsSubtitle': 'Gestión opcional de suscripción y compras.',
  'premiumHeroTitle': 'Mantén tu mañana con Dios en primer lugar.',
  'premiumHeroSubtitle': 'Desbloquea el ritmo completo de la alarma con la Escritura: todos los planes, sonidos, idiomas y el clima local.',
  'premiumMonthlyTitle': 'Mensual',
  'premiumMonthlyPrice': '\$2.99 / mes',
  'premiumAnnualTitle': 'Anual',
  'premiumAnnualPrice': '\$29.99 / año',
  'premiumTrialLabel': 'Prueba gratuita de 7 días',
  'premiumMonthlyTrialTerms': 'Prueba gratuita de 7 días; luego se renueva mensualmente.',
  'premiumAnnualTrialTerms': 'Prueba gratuita de 7 días; luego se renueva anualmente.',
  'premiumFeatureAlarm': 'Alarma de oración que puede volver hasta el Amén',
  'premiumFeaturePlans': '365 Salmos y 52 Versículos Amados',
  'premiumFeatureWeather': 'Clima local opcional al finalizar',
  'premiumStartTrial': 'Comenzar prueba gratuita de 7 días',
  'premiumRestore': 'Restaurar compras',
  'premiumManageSubscription': 'Gestionar o cancelar la suscripción',
  'premiumLoadingProducts': 'Cargando opciones de suscripción...',
  'premiumProductsUnavailable': 'Las opciones de suscripción aún no están disponibles. Asegúrate de que los productos de suscripción de App Store o Google Play estén configurados para esta app.',
  'premiumPurchaseSuccess': 'Premium está activo.',
  'premiumPurchasePending': 'Tu compra está pendiente de aprobación de la tienda. Premium se desbloqueará cuando se complete.',
  'premiumPurchaseCancelled': 'Compra cancelada.',
  'premiumPurchaseFailed': 'No se pudo completar la compra. Inténtalo de nuevo.',
  'premiumRestoreMissing': 'No se encontró ninguna suscripción activa para restaurar.',
  'premiumTerms': 'El pago se cobra a través de la compra dentro de la app de Apple o la facturación de Google Play. La prueba gratuita de 7 días y la renovación de la suscripción las gestiona la tienda. Cancela cuando quieras en los ajustes de tu suscripción. Para evitar la renovación, cancela al menos 24 horas antes de la próxima fecha de facturación.',
  'premiumCancelAnytime': 'Incluye una prueba de 7 días. Cancela cuando quieras en los ajustes de tu suscripción. Para evitar la renovación, cancela al menos 24 horas antes de la próxima fecha de facturación.',
  'premiumPurchaseUnavailable': 'Las compras no están disponibles en este momento. Inténtalo de nuevo más tarde.',
  'premiumOpenSubscriptionFailed': 'No se pudo abrir la gestión de la suscripción.',
  'termsOfUse': 'Términos de uso',
  'privacyPolicy': 'Política de privacidad',
  'openLinkFailed': 'No se pudo abrir el enlace.',
  'appTitle': 'God Morning',
  'save': 'Guardar',
  'cancel': 'Cancelar',
  'retry': 'Intentar de nuevo',
  'settings': 'Ajustes',
  'language': 'Idioma',
  'selectLanguage': 'Seleccionar idioma',
  'scripturePlan': 'Plan bíblico',
  'selectScripturePlan': 'Seleccionar plan bíblico',
  'scripturePlanDaily': '365 salmos y oraciones',
  'scripturePlanDailySubtitle':
      'Comienza cada mañana con un versículo de los Salmos y una breve oración.',
  'scripturePlanBeloved52': '52 versículos amados',
  'scripturePlanBeloved52Subtitle':
      'Lee un versículo amado cada semana para memorizar.',
  'missionContent': 'Contenido de la misión',
  'selectMissionContent': 'Seleccionar contenido de la misión',
  'missionContentScriptureAndPrayer': 'Escritura + oración',
  'missionContentScriptureAndPrayerSubtitle':
      'Lee el versículo bíblico y la oración de la mañana.',
  'missionContentScriptureOnly': 'Solo Escritura',
  'missionContentScriptureOnlySubtitle':
      'Completa la misión leyendo solo el versículo bíblico.',
  'missionContentPrayerOnly': 'Solo oración',
  'missionContentPrayerOnlySubtitle':
      'Lee un plan dedicado de 365 oraciones temáticas sin el bloque bíblico.',
  'morningPrayerEveningBlessing': 'Oración matutina y bendición nocturna.',
  'tapTimeToSetAlarm':
      'Toca la hora para configurar tu alarma. Elige el sonido abajo.',
  'tapToSetTimeAndSound': 'Toca para configurar hora y sonido',
  'circleTapToOpen': 'Grupo pequeño · toca para abrir',
  'webPreviewBanner':
      'Vista previa en Chrome — revisa la alarma y Circle. Funciones completas en iPhone/Android.',
  'morningAlarm': 'Alarma matutina',
  'eveningBlessing': 'Bendición nocturna',
  'alarmOn': 'Alarma activada',
  'alarmOff': 'Alarma desactivada',
  'previewMorningAlarm': 'Vista previa de la alarma matutina',
  'previewEveningBlessing': 'Vista previa de la bendición nocturna',
  'yourCircle': 'Tu Circle',
  'localWeather': 'Clima local',
  'localWeatherSubtitle':
      'Usa tu ubicación actual para mostrar el clima de hoy y de esta semana.',
  'localWeatherLoading': 'Cargando tu pronóstico local...',
  'localWeatherSettingsBody':
      'Usa tu ubicación actual solo para obtener el pronóstico de hoy y de esta semana. God Morning no guarda tu ubicación.',
  'enableLocalWeather': 'Mostrar clima local',
  'weatherRefresh': 'Actualizar clima',
  'weatherThisWeek': 'Esta semana',
  'weatherFeelsLike': 'Sensación {temp}',
  'weatherWind': 'Viento {speed} {unit}',
  'weatherRainChance': 'Lluvia {chance}%',
  'weatherHighLow': 'Máx {high}  Mín {low}',
  'weatherPermissionRequired':
      'Se necesita permiso de ubicación para el clima local.',
  'weatherLocationServicesOff':
      'Activa los servicios de ubicación para mostrar el clima local.',
  'weatherUnavailable':
      'El clima no está disponible ahora. Inténtalo más tarde.',
  'weatherEnabled': 'Clima local activado',
  'weatherDisabled': 'Clima local desactivado',
  'weatherAttribution': 'Datos del clima por Open-Meteo.com',
  'weatherTemperatureUnit': 'Unidad de temperatura',
  'weatherUnitFahrenheit': 'Fahrenheit (°F)',
  'weatherUnitCelsius': 'Celsius (°C)',
  'enableMorningAlarm': 'Activar alarma matutina',
  'morningAlarmSubtitle': 'Oración y Escritura para apagarla',
  'setAlarmTime': 'HORA DE LA ALARMA',
  'morningAlarmOffHint':
      'La alarma está apagada — actívala abajo para programarla',
  'eveningChildrenBlessing': 'Hora de bendecir a los hijos',
  'eveningBlessingOffHint':
      'La bendición está apagada — actívala abajo para programarla',
  'enableEveningBlessing': 'Activar bendición nocturna',
  'eveningBlessingSubtitle': 'Bendición de Aarón para apagarla',
  'saveAlarms': 'Guardar alarmas',
  'testMorningAlarm': 'Probar alarma matutina (5 s)',
  'testEveningAlarm': 'Probar alarma nocturna (5 s)',
  'practiceMission': 'Practicar misión',
  'practiceMissionSubtitle':
      'Prueba el flujo de Escritura y oración sin cambiar tu alarma real, repeticiones ni racha.',
  'missionPassThreshold': 'Criterio para completar la misión',
  'missionPassThresholdSubtitle':
      'Elige cuánto de la Escritura y la oración debe coincidir antes de desbloquear Amen. Más bajo es más fácil; más alto es más estricto.',
  'missionPassThresholdLow': 'Más fácil',
  'missionPassThresholdHigh': 'Más estricto',
  'alarmsSaved': 'Alarmas guardadas',
  'saving': 'Guardando...',
  'signOut': 'Cerrar sesión',
  'home': 'Inicio',
  'backToMain': 'Volver al inicio',
  'alarmSound': 'SONIDO DE ALARMA',
  'alarmSoundDescription':
      'Elige un tono de alarma integrado de God Morning para tu alarma matutina.',
  'alarmSoundDescriptionIos':
      'Toca un sonido para escucharlo una vez. Toca otro para cambiar suavemente.',
  'soundClassicAlarm': 'Pitidos claros (recomendado)',
  'soundGentleChime': 'Campanilla matutina',
  'soundChurchBell': 'Campana de iglesia',
  'moreIphoneSounds': 'Más sonidos del teléfono…',
  'currentAlarmSound': 'Actual: {name}',
  'savedAlarmSoundBadge': 'Guardado',
  'systemAlarmSound': 'Alarma del sistema (predeterminada)',
  'systemNotificationSound': 'Notificación del sistema',
  'systemRingtoneSound': 'Tono del sistema',
  'chooseFromPhoneSounds': 'Elegir sonidos del teléfono',
  'previewSound': 'Escuchar sonido',
  'soundSaved': 'Sonido de alarma guardado',
  'noRingtonesFound': 'No se encontraron sonidos en este dispositivo.',
  'notificationsPermissionTitle': 'Permitir notificaciones',
  'notificationsPermissionBody':
      'God Morning necesita algunos permisos para que la alarma matutina pueda sonar y escuchar tu oración.',
  'allowNotifications': 'Permitir y continuar',
  'onboardingNext': 'Continuar',
  'onboardingEnableAndStart': 'Permitir y empezar',
  'onboardingProductTitle': 'Dale a Dios el primer minuto de tu mañana.',
  'onboardingProductBody':
      'God Morning te ayuda a despertar con un versículo bíblico, una oración breve y un Amen sencillo.',
  'onboardingProductPointOneVerse':
      'Un versículo cada día, preparado para tu mañana',
  'onboardingProductPointFirstMinute':
      'Un primer minuto tranquilo con Escritura y oración',
  'onboardingReadTitle': 'Léelo en voz alta. Comienza con atención.',
  'onboardingReadBody':
      'Cuando suene la alarma, God Morning abre una misión enfocada de Escritura y oración que puedes completar con voz o escritura.',
  'onboardingReadPointVoiceType':
      'Usa voz o modo de escritura para seguir el texto',
  'onboardingReadPointAmen': 'Amen es el paso final que completa la alarma',
  'onboardingAlarmTitle': 'Una alarma matutina con propósito.',
  'onboardingAlarmBody':
      'Elige la hora y el sonido para que la alarma te lleve a la misión, no a otro snooze.',
  'onboardingAlarmPointClosed':
      'Diseñada para sonar aunque la app esté cerrada',
  'onboardingAlarmPointReturn':
      'Si sales antes de Amen, la alarma puede volver',
  'onboardingPermissionsTitle': 'Activa lo que God Morning necesita.',
  'onboardingPermissionsBody':
      'Pediremos los permisos necesarios para alarmas, notificaciones, micrófono y reconocimiento de voz.',
  'commandCopied': 'Comando copiado',
  'walkTogether': 'Caminar juntos',
  'circleInviteDescription':
      'Anima a tus amigos en la oración matutina y la adoración dominical.\nInvita miembros sin límite.',
  'createCircle': 'Crear Circle',
  'joinCircle': 'Unirse a Circle',
  'circleNameHint': 'Nombre del Circle (ej. Grace Cell)',
  'circleIdHint': 'Circle ID de tu amigo',
  'membersCount': '{count} miembros',
  'thisWeekMorning': 'Esta semana · oración matutina lun–dom',
  'demoCircleBanner':
      'Circle de demo — funciones completas en la app de iPhone/Android',
  'localCircleBanner':
      'Circle guardado en este teléfono. Agrega amigos con + — comparte el Circle ID para que se unan.',
  'enterCircleName': 'Ingresa un nombre para el Circle.',
  'circleCreated':
      'Circle creado. Comparte el Circle ID o invita por email/teléfono.',
  'enterCircleId': 'Ingresa un Circle ID.',
  'joinedCircle': '¡Te uniste al Circle!',
  'sentEncouragement': 'Enviaste ánimo a {name}',
  'likeSaveFailed': 'No se pudo guardar el like.',
  'morningDoneToday': 'Oración matutina completada hoy',
  'morningNotYetToday': 'Oración matutina aún no completada hoy',
  'sendPrayerForTomorrow': 'Enviar petición de oración',
  'prayerAcceptHint':
      'Ellos eligen un día de lun–dom esta semana para orar por ti',
  'unlike': 'Quitar like',
  'sendLike': 'Enviar like',
  'doneToday': 'Completado hoy',
  'notYetToday': 'Aún no hoy',
  'morningMonSun': 'Mañana · lun–dom',
  'eveningMonSun': 'Noche · lun–dom',
  'notYet': 'Aún no',
  'liked': 'Con like',
  'like': 'Like',
  'prayer': 'Oración',
  'inviteFriend': 'Invitar amigo',
  'addMember': 'Agregar miembro',
  'friendName': 'Nombre del amigo',
  'memberAddedToCircle': '{name} fue agregado a tu Circle.',
  'inviteByEmailOrPhone': 'Invitar por email o teléfono',
  'email': 'Email',
  'phoneNumber': 'Número de teléfono',
  'sendInvite': 'Enviar invitación',
  'inviteSent':
      'Invitación enviada a {contact}. Se unirá cuando se registre o abra la app.',
  'inviteShareCircleId': 'Comparte este Circle ID con tu amigo: {circleId}',
  'inviteSentExistingUser':
      '¡Invitación enviada! Recibirá una notificación para unirse a tu Circle.',
  'inviteFailed': 'No se pudo enviar la invitación.',
  'enterEmailOrPhone': 'Ingresa un email o número de teléfono.',
  'invalidEmail': 'Ingresa un email válido.',
  'invalidPhone': 'Ingresa un número de teléfono válido.',
  'alreadyInCircle': 'Esta persona ya está en tu Circle.',
  'prayerConfirmedTomorrow':
      'La oración matutina de mañana está confirmada. No se pueden aceptar más peticiones.',
  'prayerRequestsForYou': 'PETICIONES DE ORACIÓN PARA TI',
  'circleLikePrayerHint':
      'Envía ánimo ❤️ o comparte una petición con miembros de Circle. Ellos eligen un día y oran contigo durante la alarma matutina.',
  'circleActivity': 'ACTIVIDAD',
  'sentPrayerRequests': 'ORACIONES QUE ENVIASTE',
  'likedYouThisWeek': '{name} te envió ❤️ esta semana',
  'markAllRead': 'Marcar todo como leído',
  'friendPrayedForYou': 'Oró por ti',
  'sendPrayerTopic': 'Enviar petición',
  'onePrayerPerDayWeek':
      'Una oración personal por día · elige cualquier día lun–dom esta semana',
  'schedulePrayer': 'Programar',
  'pickDayThisWeek': 'Elige un día esta semana',
  'dayBooked': 'Reservado',
  'circlePrayer': 'Oración de Circle',
  'createCirclePrayer': 'Crear oración de Circle',
  'circlePrayersThisWeek': 'ORACIONES DE CIRCLE ESTA SEMANA',
  'circlePrayerTogether': 'Todos oran juntos en días importantes',
  'weekPrayersCircle': 'ORACIONES DE ESTA SEMANA · CIRCLE',
  'importantDayLabel': 'Día importante (lun–dom)',
  'prayerTopic': 'Petición de oración (ej. cirugía, crisis)',
  'pickADay': 'Elige un día para orar juntos',
  'scheduled': 'Programado',
  'circlePrayerCreated': 'Oración de Circle creada. Todos orarán juntos.',
  'scheduleFailed': 'No se pudo programar la oración.',
  'prayerScheduledFor': 'Oración de {name} programada para {day}',
  'circlePrayerOn': 'ORACIÓN DE CIRCLE · {day}',
  'onePrayerAcceptOnly':
      'Una oración personal por día · elige cualquier día lun–dom',
  'fromLabel': 'De {name}',
  'forYouTomorrow': 'Para ti · mañana por la mañana',
  'decline': 'Rechazar',
  'prayTomorrow': 'Orar mañana',
  'tomorrowsPrayersCircle': 'ORACIONES DE MAÑANA · CIRCLE',
  'circlePrayerFeedSubtitle': 'Oraciones personales programadas esta semana',
  'pending': 'Pendiente',
  'accepted': 'Aceptado',
  'declined': 'Rechazado',
  'sendPrayerRequest': 'Enviar petición de oración',
  'toLabel': 'Para: {name}',
  'prayerRecipientChoose':
      '{name} elegirá si ora por esto mañana por la mañana.',
  'optionalOpener': '1. Frase inicial (opcional)',
  'requiredPrayer': '2. Petición de oración 1–2 frases (obligatoria)',
  'send': 'Enviar',
  'friendPrayerConfirmed':
      'Oración de {name} programada. Elige otro día para otras peticiones.',
  'prayerRequestSent': 'Petición enviada a {name}. Elegirá un día esta semana.',
  'prayerAcceptedOneOnly':
      'Oración de {name} programada para el día que elegiste.',
  'acceptFailed': 'No se pudo aceptar la petición.',
  'prayerDeclined': 'Petición de oración de {name} rechazada.',
  'declineFailed': 'No se pudo rechazar.',
  'prayerDemoSent': 'Petición enviada (demo) — se mostrará si {name} acepta.',
  'prayerFrom': 'ORACIÓN DE {name}',
  'prayerArrow': '{from} → {to}',
  'timeToMeetLord': 'Es hora de encontrarte con el Señor.',
  'stopWithPrayerAndWord': 'Apagar con oración y Palabra',
  'todaysPrayer': 'ORACIÓN DE HOY',
  'todaysWord': 'PALABRA DE HOY',
  'listening': 'Escuchando...',
  'completeWebDemo': 'Completar (demo web)',
  'nextStepWebDemo': 'Siguiente paso (demo web)',
  'continueToNextStep': 'Continuar al siguiente paso',
  'completePrayerFlow': 'Amen',
  'alarmHowItWorksTitle': '¿Sonará la alarma mañana?',
  'alarmHowItWorksBody':
      'Sí. God Morning mantiene programada tu alarma matutina hasta que la apagues.',
  'alarmDetailedHowItWorksTitle': 'Cómo funciona',
  'alarmDetailedHowItWorksBody':
      '1. Activa la alarma matutina y toca Guardar.\n'
      '2. Permite Alarmas y Notificaciones si tu teléfono lo pide.\n'
      '3. A la hora elegida, la alarma suena aunque la app esté cerrada.\n'
      '4. Detén la alarma para abrir la oración. La alarma vuelve hasta que toques Amen.\n'
      '5. Mientras escucha, el sonido de la alarma permanece apagado para que se oiga tu voz.',
  'bibleLicenseTitle': 'Texto bíblico',
  'bibleLicenseBody':
      'Fuentes del texto bíblico:\n'
      'Coreano: Korean Revised Version 1952/1961 (KRV / 개역한글). Fuente: KorRV / Zefania XML. Derechos: Public Domain.\n'
      'Inglés: World English Bible (WEB). Fuente: eBible.org. Derechos: Public Domain.\n'
      'Alemán: Lutherbibel 1912. Fuente: eBible.org. Derechos: Public Domain.\n'
      'Ruso: Russian Synodal Translation (1876 / Синодальный перевод). Fuente: eBible.org. Derechos: Public Domain.\n'
      'Español: Reina-Valera 1909 (RV1909). Fuente: eBible.org. Derechos: Public Domain.\n'
      'Portugués: Bíblia Livre (BLJ). Fuente: eBible.org. Derechos: Public Domain.\n'
      'Chino: Chinese Union Version 1919 (和合本, simplificado). Fuente: getBible / CrossWire. Derechos: Public Domain.\n'
      'Japonés: Kougo-yaku 1954/1955 (口語訳). Fuente: getBible / CrossWire. Derechos: Public Domain.',
  'permissionNotificationTitle': 'Notificaciones',
  'permissionNotificationBody': 'Necesarias para que la alarma pueda avisarte.',
  'permissionMicrophoneTitle': 'Micrófono',
  'permissionMicrophoneBody':
      'Necesario para que la app escuche cuando lees la Escritura y la oración.',
  'permissionAlarmKitTitle': 'Permiso de alarma',
  'permissionAlarmKitBody':
      'Necesario para que la alarma matutina suene de forma confiable.',
  'permissionMissionTitle': 'Amen completa la alarma',
  'permissionMissionBody':
      'La alarma vuelve hasta que completes la misión de Escritura y oración.',
  'permissionSettingsTitle': 'Permisos',
  'permissionSettingsBody':
      'Activa los permisos que God Morning necesita para la alarma y la misión de lectura.',
  'permissionEnable': 'Activar',
  'permissionEnabled': 'Activado',
  'notificationsDisabledWarning':
      'Las notificaciones están apagadas. Las alarmas no sonarán hasta que las actives en los ajustes del teléfono.',
  'openIphoneSettings': 'Abrir ajustes del teléfono',
  'enableNotificationsToRing':
      'Activa primero las notificaciones; de lo contrario la alarma no puede sonar.',
  'tomorrow': 'mañana',
  'alarmScheduledNext': 'Alarma guardada. Próxima vez: {time}',
  'stepMorningPrayer': 'Oración matutina',
  'stepCirclePrayer': 'Oración de Circle',
  'stepFriendPrayer': 'Oración de amigo',
  'stepScripture': 'Escritura',
  'stepOfTotal': 'Paso {n} de {total} · {step}',
  'circlePrayingTogetherToday': 'Todo tu Circle está orando junto hoy.',
  'successMorningCircleFriendScripture':
      'Oración matutina, oración de Circle, oración de amigo y Escritura — completas.\nCamina en paz.',
  'successMorningCircleScripture':
      'Oración matutina, oración de Circle y Escritura — completas.\nCamina en paz.',
  'successMeansOfGraceComplete':
      'El God Morning de hoy está completo.\nCamina en paz.',
  'cancelAlarmResumes': 'Cancelar (la alarma volverá)',
  'morningAlarmMustComplete':
      'Completa la oración matutina de hoy para apagar la alarma.',
  'eveningAlarmMustComplete':
      'Completa la bendición nocturna de hoy para apagar la alarma.',
  'blessBeforeRest': 'Bendice a tus hijos con una oración antes de dormir',
  'stepEveningGuide': 'Guía de bendición',
  'stepAaronBlessing': 'Bendición de Aarón',
  'goodnightTitle': 'Buenas noches.',
  'successEveningRest': 'Jehová te bendiga y te guarde.\nDescansa en paz.',
  'readAloudToContinue':
      'Lee o escribe al menos el 80% — el botón se activa; luego tócalo cuando termines de leer.',
  'inputModeVoice': 'Grabar',
  'inputModeKeyboard': 'Escribir',
  'typePrayerHint': 'Escribe lo que lees…',
  'typingProgress': 'Escribiendo',
  'recordingInProgress': 'Grabando…',
  'liveTranscriptLabel': 'Lo que escuchamos',
  'liveTranscriptHint':
      'Habla en voz alta — tus palabras aparecen aquí para que puedas revisar mientras oras.',
  'typedEchoLabel': 'Lo que escribiste',
  'morningPrayerVoiceTypeHint':
      'Después de empezar, usa Grabar (voz) o Escribir para leer cada paso de oración.',
  'typeToContinue': 'Escribe lo que lees para continuar.',
  'switchedToTypeMode':
      'La voz no está disponible — cambiamos a Escribir. Aún puedes completar la oración.',
  'emergencyTitle': 'Emergencia — confesión espiritual',
  'emergencyMorningHint':
      'Escribe exactamente la frase de abajo para apagar la alarma matutina de hoy.',
  'emergencyEveningHint':
      'Completa la razón (viaje, familia, dormir fuera…) para saltar la bendición de esta noche.',
  'emergencyMorningPhrase':
      'Hoy realmente no puedo hacerlo. Señor, por favor perdóname.',
  'emergencyEveningPrefix': 'Hoy por ',
  'emergencyEveningSuffix':
      ' no pude orar la bendición de los hijos. Señor, por favor perdóname.',
  'emergencyTypePhraseHint': 'Escribe la frase de confesión…',
  'emergencyEveningReasonHint': 'ej. viaje, familia, dormir fuera…',
  'emergencyConfirm': 'Enviar confesión y apagar alarma',
  'emergencyNotAvailable':
      'No quedan salidas de emergencia esta semana para tu nivel de intensidad.',
  'emergencyButton': 'Emergencia — hoy necesito gracia',
  'emergencySuccessMessage':
      'El Señor escucha tu confesión. La alarma está apagada por hoy. Vuelve mañana.',
  'emergencyGraceRemaining':
      'Gracia de la primera semana — emergencia disponible por {days} días más.',
  'emergencyRemainingThisWeek': 'Emergencias restantes esta semana: {count}',
  'prayerIntensity': 'Intensidad de oración',
  'prayerIntensityGentle': 'Suave',
  'prayerIntensityNormal': 'Normal',
  'prayerIntensityStrict': 'Estricto',
  'prayerIntensityHint':
      'Suave 65% · Normal 80% · Estricto 90%. Emergencia: 3 / 1 / 0 por semana después del día 7.',
  'streakTitle': 'Racha matutina',
  'streakDays': '{days} días seguidos',
  'eveningStreakDays': 'Bendición de los hijos — {days} días seguidos',
  'eveningStreakStart': 'Empieza esta noche con la bendición de tus hijos',
  'streakStartToday': 'Completa la oración matutina hoy para iniciar tu racha.',
  'emergencyFeatureTitle': 'Emergencia — confesión espiritual',
  'emergencyFeatureBody':
      'En la pantalla de alarma, toca Emergencia y escribe la confesión para apagarla. Noche: escribe tu razón (viaje, familia, etc.).',
  'hallelujah': '¡Aleluya!',
  'done': 'Hecho',
  'amen': 'Amen',
  'prayingWithYou': '{name} está orando contigo esta mañana.',
  'blessWithPrayer': 'Bendecir con oración',
  'micPermissionChrome':
      'Permite el acceso al micrófono en Chrome (icono de candado en la barra de direcciones).',
  'speechNotAvailable':
      'El reconocimiento de voz no está disponible en este dispositivo.',
  'welcomeBack': 'Bienvenido de nuevo.',
  'signInToContinue': 'Inicia sesión para continuar tu camino.',
  'password': 'Contraseña',
  'signIn': 'Iniciar sesión',
  'signInWithApple': 'Iniciar sesión con Apple',
  'createAccount': 'Crear cuenta',
  'noAccount': '¿No tienes cuenta? Crea una',
  'haveAccount': '¿Ya tienes cuenta? Inicia sesión',
  'name': 'Nombre',
  'confirmPassword': 'Confirmar contraseña',
  'enterEmail': 'Ingresa tu email.',
  'enterPassword': 'Ingresa tu contraseña.',
  'enterName': 'Ingresa tu nombre.',
  'passwordMinLength': 'La contraseña debe tener al menos 6 caracteres.',
  'passwordsDoNotMatch': 'Las contraseñas no coinciden.',
  'errorInvalidEmail': 'Ingresa un email válido.',
  'errorUserNotFound': 'No se encontró una cuenta con este email.',
  'errorWrongPassword': 'Contraseña incorrecta.',
  'errorEmailInUse': 'Este email ya está en uso.',
  'errorWeakPassword': 'La contraseña debe tener al menos 6 caracteres.',
  'errorInvalidCredential': 'Revisa tu email y contraseña.',
  'errorOperationNotAllowed':
      'Este método de inicio de sesión no está disponible.',
  'errorSignInFailed': 'No se pudo iniciar sesión. Inténtalo de nuevo.',
  'errorLoginRequired': 'Debes iniciar sesión.',
  'errorAlreadyInCircle': 'Ya estás en un Circle.',
  'errorCircleNotFound': 'Circle no encontrado. Revisa el Circle ID.',
  'errorPrayerTextRequired': 'Ingresa una petición de oración.',
  'errorOpenerOneSentence': 'La oración inicial debe ser una sola frase.',
  'errorTomorrowPrayerConfirmed':
      '{name} ya confirmó la oración matutina de mañana.',
  'errorOnePrayerPerDay': 'Solo puedes aceptar una oración por día.',
  'notificationPrayerHeard': 'Tu amigo escuchó tu oración.',
  'premiumFeatureLanguages':
      'Inglés, coreano, alemán, ruso, español, portugués, chino y japonés',
};

const _fr = {
  'appTitle': 'Moyens de Grâce',
  'yourCircle': 'Votre Cercle',
  'settings': 'Paramètres',
  'language': 'Langue',
  'inviteFriend': 'Inviter un ami',
  'signIn': 'Se connecter',
  'save': 'Enregistrer',
  'cancel': 'Annuler',
};

const _pt = {
  'appTitle': 'God Morning',
  'save': 'Salvar',
  'cancel': 'Cancelar',
  'retry': 'Tentar novamente',
  'settings': 'Configurações',
  'language': 'Idioma',
  'selectLanguage': 'Selecionar idioma',
  'scripturePlan': 'Plano de leitura bíblica',
  'selectScripturePlan': 'Selecionar plano de leitura',
  'scripturePlanDaily': '365 Salmos e Orações',
  'scripturePlanDailySubtitle': 'Comece cada manhã com um versículo dos Salmos e uma breve oração.',
  'scripturePlanBeloved52': '52 Versículos Amados',
  'scripturePlanBeloved52Subtitle': 'Leia um versículo amado por semana para memorizar.',
  'missionContent': 'Conteúdo da missão',
  'selectMissionContent': 'Selecionar conteúdo da missão',
  'missionContentScriptureAndPrayer': 'Escritura + Oração',
  'missionContentScriptureAndPrayerSubtitle': 'Leia o versículo bíblico e a oração da manhã.',
  'missionContentScriptureOnly': 'Somente Escritura',
  'missionContentScriptureOnlySubtitle': 'Complete a missão lendo apenas o versículo bíblico.',
  'missionContentPrayerOnly': 'Somente oração',
  'missionContentPrayerOnlySubtitle': 'Leia uma oração temática dedicada de 365 dias, sem o bloco da Escritura.',
  'morningPrayerEveningBlessing': 'Oração da manhã e bênção da noite.',
  'tapTimeToSetAlarm': 'Toque no horário para definir seu alarme. Escolha o som do sino abaixo.',
  'tapToSetTimeAndSound': 'Toque para definir horário e som',
  'circleTapToOpen': 'Pequeno grupo · toque para abrir',
  'webPreviewBanner': 'Prévia no Chrome — confira o alarme e a interface do Círculo. Recursos completos no iPhone/Android.',
  'morningAlarm': 'Alarme da manhã',
  'eveningBlessing': 'Bênção da noite',
  'alarmOn': 'Alarme ligado',
  'alarmOff': 'Alarme desligado',
  'previewMorningAlarm': 'Prévia do alarme da manhã',
  'previewEveningBlessing': 'Prévia da bênção da noite',
  'yourCircle': 'Seu Círculo',
  'localWeather': 'Clima local',
  'localWeatherSubtitle': 'Usa sua localização atual para mostrar hoje e esta semana.',
  'localWeatherLoading': 'Carregando a previsão local...',
  'localWeatherSettingsBody': 'Usa sua localização atual apenas para buscar a previsão de hoje e desta semana. Sua localização não é armazenada pelo God Morning.',
  'enableLocalWeather': 'Mostrar clima local',
  'weatherRefresh': 'Atualizar clima',
  'weatherThisWeek': 'Esta semana',
  'weatherFeelsLike': 'Sensação {temp}',
  'weatherWind': 'Vento {speed} {unit}',
  'weatherRainChance': 'Chuva {chance}%',
  'weatherHighLow': 'Máx {high}  Mín {low}',
  'weatherPermissionRequired': 'É necessária a permissão de localização para o clima local.',
  'weatherLocationServicesOff': 'Ative os Serviços de Localização para mostrar o clima local.',
  'weatherUnavailable': 'O clima não está disponível no momento. Tente novamente mais tarde.',
  'weatherEnabled': 'Clima local ativado',
  'weatherDisabled': 'Clima local desativado',
  'weatherAttribution': 'Dados do clima por Open-Meteo.com',
  'weatherTemperatureUnit': 'Unidade de temperatura',
  'weatherUnitFahrenheit': 'Fahrenheit (°F)',
  'weatherUnitCelsius': 'Celsius (°C)',
  'enableMorningAlarm': 'Ativar alarme da manhã',
  'morningAlarmSubtitle': 'Oração e Escritura para desligar',
  'repeatDays': 'Dias de repetição',
  'perDayTimesTitle': 'Horário diferente por dia',
  'alarmsTitle': 'Alarmes',
  'addAlarm': 'Adicionar alarme',
  'deleteAlarmTitle': 'Excluir',
  'everyDay': 'Todos os dias',
  'maxAlarmsReached': 'Você pode criar até 5 alarmes.',
  'cannotDeleteLastAlarm': 'É preciso ter pelo menos um alarme — desligue-o em vez de excluir.',
  'alarmListHint': 'Cada alarme tem sua própria missão. Toque para editar, segure para excluir.',
  'streakCalendarSubtitle': 'Os dias em que você se encontrou com o Senhor são marcados automaticamente.',
  'calendarTab': 'Calendário',
  'homeTab': 'Início',
  'weatherTab': 'Clima',
  'showLocalWeather': 'Mostrar clima local — toque para ativar',
  'myLocation': 'Minha localização',
  'tenDayForecast': 'PREVISÃO DE 10 DIAS',
  'nowLabel': 'Agora',
  'todayLabel': 'Hoje',
  'streakTotalDays': 'Você já se encontrou com o Senhor {days} dias no total',
  'perDayTimesSubtitle': 'Defina um horário de alarme diferente para cada dia',
  'setTimeForDay': 'Horário do alarme de {day}',
  'selectAtLeastOneAlarmDay': 'Selecione pelo menos um dia de alarme.',
  'weekdayShortMonday': 'Seg',
  'weekdayShortTuesday': 'Ter',
  'weekdayShortWednesday': 'Qua',
  'weekdayShortThursday': 'Qui',
  'weekdayShortFriday': 'Sex',
  'weekdayShortSaturday': 'Sáb',
  'weekdayShortSunday': 'Dom',
  'setAlarmTime': 'DEFINIR HORÁRIO DO ALARME',
  'morningAlarmOffHint': 'O alarme está desativado — ative abaixo para agendar',
  'eveningBlessingOffHint': 'A bênção está desativada — ative abaixo para agendar',
  'enableEveningBlessing': 'Ativar bênção da noite',
  'saveAlarms': 'Salvar alarmes',
  'testMorningAlarm': 'Testar alarme da manhã (5 s)',
  'testEveningAlarm': 'Testar alarme da noite (5 s)',
  'practiceMission': 'Praticar missão',
  'practiceMissionSubtitle': 'Experimente o fluxo de Escritura e oração sem alterar seu alarme real, suas tentativas ou sua sequência.',
  'missionPassThreshold': 'Nível de exigência da missão',
  'missionPassThresholdSubtitle': 'Escolha quanto da Escritura e da oração deve corresponder para desbloquear o Amém. Menor é mais fácil; maior é mais rigoroso.',
  'missionPassThresholdLow': 'Mais fácil',
  'missionPassThresholdHigh': 'Mais rigoroso',
  'alarmsSaved': 'Alarmes salvos',
  'saving': 'Salvando...',
  'signOut': 'Sair',
  'home': 'Início',
  'backToMain': 'Voltar ao início',
  'premiumTitle': 'God Morning Premium',
  'premiumSettingsSubtitle': 'Assinatura opcional e gerenciamento de compras.',
  'premiumHeroTitle': 'Mantenha Deus em primeiro lugar na sua manhã.',
  'premiumHeroSubtitle': 'Desbloqueie o ritmo completo do alarme com a Escritura, com todos os planos, sons, idiomas e o clima local.',
  'premiumMonthlyTitle': 'Mensal',
  'premiumAnnualTitle': 'Anual',
  'premiumTrialLabel': 'Teste grátis de 7 dias',
  'premiumMonthlyTrialTerms': 'Teste grátis de 7 dias, depois renova mensalmente.',
  'premiumAnnualTrialTerms': 'Teste grátis de 7 dias, depois renova anualmente.',
  'premiumFeatureAlarm': 'Alarme de oração que pode voltar até o Amém',
  'premiumFeaturePlans': '365 Salmos e 52 Versículos Amados',
  'premiumFeatureLanguages':
      'Inglês, coreano, alemão, russo, espanhol, português, chinês e japonês',
  'premiumFeatureWeather': 'Clima local opcional após a conclusão',
  'premiumStartTrial': 'Começar teste grátis de 7 dias',
  'premiumRestore': 'Restaurar compras',
  'premiumManageSubscription': 'Gerenciar ou cancelar assinatura',
  'premiumLoadingProducts': 'Carregando opções de assinatura...',
  'premiumProductsUnavailable': 'As opções de assinatura ainda não estão disponíveis. Verifique se os produtos de assinatura da App Store ou do Google Play estão configurados para este app.',
  'premiumPurchaseSuccess': 'O Premium está ativo.',
  'premiumPurchasePending': 'Sua compra está aguardando a aprovação da loja. O Premium será liberado quando ela for concluída.',
  'premiumPurchaseCancelled': 'Compra cancelada.',
  'premiumPurchaseFailed': 'Não foi possível concluir a compra. Tente novamente.',
  'premiumRestoreMissing': 'Nenhuma assinatura ativa foi encontrada para restaurar.',
  'premiumTerms': 'O pagamento é cobrado por meio da compra no app da Apple ou do faturamento do Google Play. O teste grátis de 7 dias e a renovação da assinatura são gerenciados pela loja. Cancele quando quiser nos ajustes da sua assinatura. Para evitar a renovação, cancele pelo menos 24 horas antes da próxima data de cobrança.',
  'premiumCancelAnytime': 'Inclui 7 dias de teste. Cancele quando quiser nos ajustes da sua assinatura. Para evitar a renovação, cancele pelo menos 24 horas antes da próxima data de cobrança.',
  'premiumPurchaseUnavailable': 'As compras não estão disponíveis no momento. Tente novamente mais tarde.',
  'premiumOpenSubscriptionFailed': 'Não foi possível abrir o gerenciamento da assinatura.',
  'termsOfUse': 'Termos de Uso',
  'privacyPolicy': 'Política de Privacidade',
  'openLinkFailed': 'Não foi possível abrir o link.',
  'alarmSound': 'SOM DO ALARME',
  'alarmSoundDescription': 'Escolha um dos toques inclusos do God Morning para o seu alarme da manhã.',
  'alarmSoundDescriptionIos': 'Toque em um som para ouvi-lo uma vez. Toque em outro para trocar suavemente.',
  'soundClassicAlarm': 'Bipes claros (recomendado)',
  'soundGentleChime': 'Carrilhão da manhã',
  'soundChurchBell': 'Sino de igreja',
  'moreIphoneSounds': 'Mais sons do telefone…',
  'currentAlarmSound': 'Atual: {name}',
  'savedAlarmSoundBadge': 'Salvo',
  'systemAlarmSound': 'Alarme do sistema (padrão)',
  'systemNotificationSound': 'Notificação do sistema',
  'systemRingtoneSound': 'Toque do sistema',
  'chooseFromPhoneSounds': 'Escolher entre os sons do celular',
  'previewSound': 'Prévia do som',
  'soundSaved': 'Som do alarme salvo',
  'noRingtonesFound': 'Nenhum som encontrado neste dispositivo.',
  'notificationsPermissionTitle': 'Permitir notificações',
  'notificationsPermissionBody': 'O God Morning precisa de algumas permissões para que o alarme da manhã possa tocar e ouvir sua oração.',
  'allowNotifications': 'Permitir e continuar',
  'onboardingNext': 'Continuar',
  'onboardingEnableAndStart': 'Ativar e começar',
  'onboardingProductTitle': 'Dê a Deus o primeiro minuto da sua manhã.',
  'onboardingProductBody': 'O God Morning ajuda você a acordar com um versículo bíblico, uma oração curta e um simples Amém.',
  'onboardingProductPointOneVerse': 'Um versículo por dia, preparado para a sua manhã',
  'onboardingProductPointFirstMinute': 'Um primeiro minuto tranquilo moldado pela Escritura e pela oração',
  'onboardingReadTitle': 'Leia em voz alta. Comece com atenção.',
  'onboardingReadBody': 'Na hora do alarme, o God Morning abre uma missão focada de Escritura e oração que você pode completar por voz ou digitando.',
  'onboardingReadPointVoiceType': 'Use o modo de voz ou de digitação para acompanhar o texto',
  'onboardingReadPointAmen': 'O Amém é o passo final que conclui o alarme',
  'onboardingAlarmTitle': 'Um alarme matinal com propósito.',
  'onboardingAlarmBody': 'Defina o horário, escolha o som e deixe o alarme conduzir você à missão em vez de mais uma soneca.',
  'onboardingAlarmPointClosed': 'Feito para tocar mesmo com o app fechado',
  'onboardingAlarmPointReturn': 'Se você sair antes do Amém, o alarme pode voltar',
  'onboardingPermissionsTitle': 'Ative o que o God Morning precisa.',
  'onboardingPermissionsBody': 'Vamos pedir as permissões necessárias para alarmes, notificações, microfone e reconhecimento de voz.',
  'commandCopied': 'Comando copiado',
  'walkTogether': 'Caminhar juntos',
  'circleInviteDescription': 'Incentive amigos na oração da manhã e no culto de domingo.\\nConvide quantos membros quiser.',
  'createCircle': 'Criar círculo',
  'joinCircle': 'Entrar no círculo',
  'circleNameHint': 'Nome do círculo (ex.: Célula Graça)',
  'circleIdHint': 'ID do Círculo do seu amigo',
  'membersCount': '{count} membros',
  'thisWeekMorning': 'Esta semana · Oração da manhã de seg–dom',
  'demoCircleBanner': 'Círculo demo — recursos completos no app para iPhone/Android',
  'localCircleBanner': 'Círculo salvo neste telefone. Adicione amigos com + — compartilhe o ID do Círculo para eles entrarem.',
  'enterCircleName': 'Digite o nome do círculo.',
  'circleCreated': 'Círculo criado. Compartilhe o ID do Círculo ou convide por e-mail/telefone.',
  'enterCircleId': 'Digite o ID do Círculo.',
  'joinedCircle': 'Você entrou no círculo!',
  'sentEncouragement': 'Incentivo enviado a {name}',
  'likeSaveFailed': 'Não foi possível salvar a curtida.',
  'morningDoneToday': 'Oração da manhã concluída hoje',
  'morningNotYetToday': 'Oração da manhã ainda pendente hoje',
  'sendPrayerForTomorrow': 'Enviar pedido de oração',
  'prayerAcceptHint': 'A pessoa escolhe um dia de seg a dom desta semana para orar por você',
  'unlike': 'Descurtir',
  'sendLike': 'Enviar curtida',
  'doneToday': 'Concluído hoje',
  'notYetToday': 'Ainda não hoje',
  'morningMonSun': 'Manhã · Seg–Dom',
  'eveningMonSun': 'Noite · Seg–Dom',
  'notYet': 'Ainda não',
  'liked': 'Curtido',
  'like': 'Curtir',
  'prayer': 'Oração',
  'inviteFriend': 'Convidar amigo',
  'addMember': 'Adicionar membro',
  'friendName': 'Nome do amigo',
  'memberAddedToCircle': '{name} agora faz parte do seu Círculo.',
  'inviteByEmailOrPhone': 'Convidar por e-mail ou telefone',
  'email': 'E-mail',
  'phoneNumber': 'Número de telefone',
  'sendInvite': 'Enviar convite',
  'inviteSent': 'Convite enviado para {contact}. A pessoa entrará quando se cadastrar ou abrir o app.',
  'inviteShareCircleId': 'Compartilhe este ID do Círculo com seu amigo: {circleId}',
  'inviteSentExistingUser': 'Convite enviado! A pessoa receberá uma notificação para entrar no seu círculo.',
  'inviteFailed': 'Não foi possível enviar o convite.',
  'enterEmailOrPhone': 'Digite um e-mail ou número de telefone.',
  'invalidEmail': 'Digite um endereço de e-mail válido.',
  'invalidPhone': 'Digite um número de telefone válido.',
  'alreadyInCircle': 'Esta pessoa já está no seu círculo.',
  'prayerConfirmedTomorrow': 'A oração da manhã de amanhã está confirmada. Não é possível aceitar mais pedidos.',
  'prayerRequestsForYou': 'PEDIDOS DE ORAÇÃO PARA VOCÊ',
  'circleLikePrayerHint': 'Envie ❤️ de incentivo ou compartilhe um pedido de oração com os membros do Círculo. Eles escolhem um dia e oram com você no alarme da manhã.',
  'circleActivity': 'ATIVIDADE',
  'sentPrayerRequests': 'ORAÇÕES QUE VOCÊ ENVIOU',
  'likedYouThisWeek': '{name} enviou ❤️ para você esta semana',
  'markAllRead': 'Marcar tudo como lido',
  'friendPrayedForYou': 'Orou por você',
  'sendPrayerTopic': 'Enviar motivo de oração',
  'onePrayerPerDayWeek': 'Uma oração pessoal por dia · escolha qualquer dia de seg a dom desta semana',
  'schedulePrayer': 'Agendar',
  'pickDayThisWeek': 'Escolha um dia desta semana',
  'dayBooked': 'Reservado',
  'circlePrayer': 'Oração do círculo',
  'createCirclePrayer': 'Criar oração do círculo',
  'circlePrayersThisWeek': 'ORAÇÕES DO CÍRCULO NESTA SEMANA',
  'circlePrayerTogether': 'Todos oram juntos nos dias importantes',
  'weekPrayersCircle': 'ORAÇÕES DESTA SEMANA · CÍRCULO',
  'importantDayLabel': 'Dia importante (Seg–Dom)',
  'prayerTopic': 'Motivo de oração (ex.: cirurgia, crise)',
  'pickADay': 'Escolha um dia para orarem juntos',
  'scheduled': 'Agendado',
  'circlePrayerCreated': 'Oração do círculo criada. Todos vão orar juntos.',
  'scheduleFailed': 'Não foi possível agendar a oração.',
  'prayerScheduledFor': 'Oração de {name} agendada para {day}',
  'circlePrayerOn': 'ORAÇÃO DO CÍRCULO · {day}',
  'onePrayerAcceptOnly': 'Uma oração pessoal por dia · escolha qualquer dia de seg a dom',
  'fromLabel': 'De {name}',
  'forYouTomorrow': 'Para você · amanhã de manhã',
  'decline': 'Recusar',
  'prayTomorrow': 'Orar amanhã',
  'tomorrowsPrayersCircle': 'ORAÇÕES DE AMANHÃ · CÍRCULO',
  'circlePrayerFeedSubtitle': 'Orações pessoais agendadas para esta semana',
  'pending': 'Pendente',
  'accepted': 'Aceito',
  'declined': 'Recusado',
  'sendPrayerRequest': 'Enviar pedido de oração',
  'toLabel': 'Para: {name}',
  'prayerRecipientChoose': '{name} vai decidir se ora por isso amanhã de manhã.',
  'optionalOpener': '1. Frase de abertura (opcional)',
  'requiredPrayer': '2. Pedido de oração em 1–2 frases (obrigatório)',
  'send': 'Enviar',
  'friendPrayerConfirmed': 'Oração de {name} agendada. Escolha outro dia para outros pedidos.',
  'prayerRequestSent': 'Pedido de oração enviado para {name}. A pessoa escolherá um dia desta semana.',
  'prayerAcceptedOneOnly': 'A oração de {name} foi agendada para o dia que você escolheu.',
  'acceptFailed': 'Não foi possível aceitar a solicitação.',
  'prayerDeclined': 'Pedido de oração de {name} recusado.',
  'declineFailed': 'Não foi possível recusar a solicitação.',
  'prayerDemoSent': 'Pedido de oração enviado (demo) — exibido se {name} aceitar.',
  'prayerFrom': 'ORAÇÃO DE {name}',
  'prayerArrow': '{from} → {to}',
  'timeToMeetLord': 'É hora de se encontrar com o Senhor.',
  'stopWithPrayerAndWord': 'Desligue com oração e a Palavra',
  'listening': 'Ouvindo...',
  'completeWebDemo': 'Concluir (demo web)',
  'nextStepWebDemo': 'Próxima etapa (demo web)',
  'continueToNextStep': 'Continuar para o próximo passo',
  'completePrayerFlow': 'Amém',
  'alarmHowItWorksTitle': 'O alarme vai tocar amanhã?',
  'alarmHowItWorksBody': 'Sim. O God Morning mantém seu alarme da manhã agendado até você desligá-lo.',
  'alarmDetailedHowItWorksTitle': 'Como funciona',
  'alarmDetailedHowItWorksBody': '1. Ative o alarme da manhã e toque em Salvar.\\n2. Permita Alarmes e Notificações se o celular pedir.\\n3. No horário escolhido, o alarme toca mesmo com o app fechado.\\n4. Pare o alarme para abrir a oração. O alarme continua voltando até o Amém.\\n5. Durante a escuta, o som do alarme fica desligado para que sua voz seja ouvida.',
  'bibleLicenseTitle': 'Texto bíblico',
  'bibleLicenseBody': 'Fontes do texto bíblico:\n'
      'Coreano: Korean Revised Version 1952/1961 (KRV / 개역한글). Fonte: KorRV / Zefania XML. Direitos: Public Domain.\n'
      'Inglês: World English Bible (WEB). Fonte: eBible.org. Direitos: Public Domain.\n'
      'Alemão: Lutherbibel 1912. Fonte: eBible.org. Direitos: Public Domain.\n'
      'Russo: Russian Synodal Translation (1876 / Синодальный перевод). Fonte: eBible.org. Direitos: Public Domain.\n'
      'Espanhol: Reina-Valera 1909 (RV1909). Fonte: eBible.org. Direitos: Public Domain.\n'
      'Português: Bíblia Livre (BLJ). Fonte: eBible.org. Direitos: Public Domain.\n'
      'Chinês: Chinese Union Version 1919 (和合本, simplificado). Fonte: getBible / CrossWire. Direitos: Public Domain.\n'
      'Japonês: 口語訳 1954/1955 (Kougo-yaku). Fonte: getBible / CrossWire. Direitos: Public Domain.',
  'permissionNotificationTitle': 'Notificações',
  'permissionNotificationBody': 'Necessária para que o alarme possa avisar você.',
  'permissionMicrophoneTitle': 'Microfone',
  'permissionMicrophoneBody': 'Necessária para que o app ouça você ler a Escritura e a oração.',
  'permissionAlarmKitTitle': 'Permissão de alarme',
  'permissionAlarmKitBody': 'Necessária para que o alarme da manhã toque de forma confiável.',
  'permissionMissionTitle': 'O Amém conclui o alarme',
  'permissionMissionBody': 'O alarme continua voltando até que a missão de Escritura e oração seja concluída.',
  'permissionSettingsTitle': 'Permissões',
  'permissionSettingsBody': 'Ative as permissões que o God Morning precisa para os alarmes e a missão de leitura.',
  'permissionEnable': 'Ativar',
  'permissionEnabled': 'Ativada',
  'notificationsDisabledWarning': 'As notificações estão desativadas. Os alarmes não tocarão até que você as ative nas configurações do telefone.',
  'openIphoneSettings': 'Abrir ajustes do celular',
  'enableNotificationsToRing': 'Ative as notificações primeiro — sem elas, o alarme não pode tocar.',
  'tomorrow': 'amanhã',
  'alarmScheduledNext': 'Alarme salvo. Próximo toque: {time}',
  'stepMorningPrayer': 'Oração da manhã',
  'stepCirclePrayer': 'Oração do Círculo',
  'stepFriendPrayer': 'Oração pelo amigo',
  'stepScripture': 'Escritura',
  'stepOfTotal': 'Passo {n} de {total} · {step}',
  'circlePrayingTogetherToday': 'Todo o seu círculo está orando junto hoje.',
  'successMorningCircleFriendScripture': 'Oração da manhã, oração do Círculo, oração pelo amigo e Escritura — concluído.\\nVá em paz.',
  'successMorningCircleScripture': 'Oração da manhã, oração do Círculo e Escritura — concluído.\\nVá em paz.',
  'cancelAlarmResumes': 'Cancelar (o alarme voltará a tocar)',
  'morningAlarmMustComplete': 'Complete a oração da manhã de hoje para desligar o alarme.',
  'eveningAlarmMustComplete': 'Complete a bênção da noite de hoje para desligar o alarme.',
  'blessBeforeRest': 'Abençoe seus filhos com uma oração antes de dormir',
  'stepEveningGuide': 'Guia de bênção',
  'goodnightTitle': 'Boa noite.',
  'successEveningRest': 'O Senhor te abençoe e te guarde.\\nDurma em paz.',
  'readAloudToContinue': 'Leia ou digite pelo menos 80% — o botão será ativado; toque nele quando terminar de ler.',
  'inputModeVoice': 'Gravar',
  'inputModeKeyboard': 'Digitar',
  'typePrayerHint': 'Digite o que você leu…',
  'typingProgress': 'Digitando',
  'recordingInProgress': 'Gravando…',
  'liveTranscriptLabel': 'O que estamos ouvindo',
  'liveTranscriptHint': 'Fale em voz alta — suas palavras aparecem aqui para você acompanhar enquanto ora.',
  'typedEchoLabel': 'O que você digitou',
  'morningPrayerVoiceTypeHint': 'Depois de começar, use Gravar (voz) ou Digitar para ler cada etapa da oração.',
  'typeToContinue': 'Digite o que você leu para continuar.',
  'switchedToTypeMode': 'Voz indisponível — mudamos para o modo Digitar. Você ainda pode completar a oração.',
  'emergencyTitle': 'Emergência — confissão espiritual',
  'emergencyMorningHint': 'Digite a frase abaixo exatamente como está para desligar o alarme da manhã de hoje.',
  'emergencyEveningHint': 'Preencha o motivo (dormir fora, família, viagem…) para pular a bênção desta noite.',
  'emergencyMorningPhrase': 'Hoje eu realmente não consigo. Senhor, perdoa-me, por favor.',
  'emergencyEveningPrefix': 'Hoje, por causa de ',
  'emergencyEveningSuffix': ', não pude orar a bênção das crianças. Senhor, perdoa-me, por favor.',
  'emergencyTypePhraseHint': 'Digite a frase de confissão…',
  'emergencyEveningReasonHint': 'ex.: dormir na casa de um amigo, viagem em família…',
  'emergencyConfirm': 'Enviar confissão e desligar o alarme',
  'emergencyNotAvailable': 'Não restam saídas de emergência nesta semana para o seu nível de intensidade.',
  'emergencyButton': 'Emergência — preciso de graça hoje',
  'emergencySuccessMessage': 'O Senhor ouve a sua confissão. O alarme está desligado por hoje. Volte amanhã.',
  'emergencyGraceRemaining': 'Graça da primeira semana — emergência disponível por mais {days} dias.',
  'emergencyRemainingThisWeek': 'Saídas de emergência restantes nesta semana: {count}',
  'prayerIntensity': 'Intensidade da oração',
  'prayerIntensityGentle': 'Suave',
  'prayerIntensityNormal': 'Normal',
  'prayerIntensityStrict': 'Rigoroso',
  'prayerIntensityHint': 'Suave 65% · Normal 80% · Rigoroso 90%. Emergência: 3 / 1 / 0 por semana após o dia 7.',
  'streakTitle': 'Sequência matinal',
  'streakDays': '{days} dias seguidos',
  'eveningStreakDays': 'Bênção dos filhos — {days} dias seguidos',
  'eveningStreakStart': 'Comece esta noite com a bênção dos filhos',
  'streakStartToday': 'Complete a oração da manhã hoje para começar sua sequência.',
  'emergencyFeatureTitle': 'Emergência — confissão espiritual',
  'emergencyFeatureBody': 'Na tela do alarme, toque em Emergência e digite a confissão para desligar. À noite: preencha seu motivo (dormir fora, família etc.).',
  'hallelujah': 'Aleluia',
  'done': 'Concluído',
  'amen': 'Amém',
  'prayingWithYou': '{name} está orando com você esta manhã.',
  'blessWithPrayer': 'Abençoar com oração',
  'micPermissionChrome': 'Permita o acesso ao microfone no Chrome (ícone de cadeado na barra de endereço).',
  'speechNotAvailable': 'O reconhecimento de voz não está disponível neste dispositivo.',
  'welcomeBack': 'Bem-vindo de volta.',
  'signInToContinue': 'Entre para continuar sua jornada.',
  'password': 'Senha',
  'signIn': 'Entrar',
  'signInWithApple': 'Entrar com a Apple',
  'createAccount': 'Criar conta',
  'noAccount': 'Não tem conta? Crie uma',
  'haveAccount': 'Já tem uma conta? Entrar',
  'name': 'Nome',
  'confirmPassword': 'Confirmar senha',
  'enterEmail': 'Digite seu e-mail.',
  'enterPassword': 'Digite sua senha.',
  'enterName': 'Digite seu nome.',
  'passwordMinLength': 'A senha deve ter pelo menos 6 caracteres.',
  'passwordsDoNotMatch': 'As senhas não coincidem.',
  'errorInvalidEmail': 'Digite um endereço de e-mail válido.',
  'errorUserNotFound': 'Nenhuma conta encontrada com este e-mail.',
  'errorWrongPassword': 'Senha incorreta.',
  'errorEmailInUse': 'Este e-mail já está em uso.',
  'errorWeakPassword': 'A senha deve ter pelo menos 6 caracteres.',
  'errorInvalidCredential': 'Verifique seu e-mail e sua senha.',
  'errorOperationNotAllowed': 'Este método de login não está disponível.',
  'errorSignInFailed': 'Falha ao entrar. Tente novamente.',
  'errorLoginRequired': 'É preciso fazer login.',
  'errorAlreadyInCircle': 'Você já está em um círculo.',
  'errorCircleNotFound': 'Círculo não encontrado. Verifique o ID do Círculo.',
  'errorPrayerTextRequired': 'Digite um pedido de oração.',
  'errorOpenerOneSentence': 'A oração de abertura deve ter apenas uma frase.',
  'errorTomorrowPrayerConfirmed': '{name} já confirmou a oração da manhã de amanhã.',
  'errorOnePrayerPerDay': 'Você pode aceitar apenas uma oração por dia.',
  'notificationPrayerHeard': 'Seu amigo ouviu sua oração.',
  'eveningChildrenBlessing': 'Hora da bênção dos filhos',
  'eveningBlessingSubtitle': 'Leia a bênção de Arão para encerrar',
  'premiumMonthlyPrice': '\$2.99 / mês',
  'premiumAnnualPrice': '\$29.99 / ano',
  'todaysPrayer': 'ORAÇÃO DE HOJE',
  'todaysWord': 'PALAVRA DE HOJE',
  'successMeansOfGraceComplete': 'O God Morning de hoje está completo.\nAnde em paz.',
  'stepAaronBlessing': 'Bênção de Arão',
};

const _de = {
  'retry': 'Erneut versuchen',
  'morningPrayerEveningBlessing': 'Morgengebet und Abendsegen.',
  'tapTimeToSetAlarm': 'Tippe auf die Uhrzeit, um deinen Wecker zu stellen. Wähle unten deinen Klingelton.',
  'tapToSetTimeAndSound': 'Tippen für Zeit & Ton',
  'circleTapToOpen': 'Kleingruppe · zum Öffnen tippen',
  'webPreviewBanner': 'Chrome-Vorschau — prüfe Wecker- und Circle-Oberfläche. Alle Funktionen auf iPhone/Android.',
  'morningAlarm': 'Morgenwecker',
  'eveningBlessing': 'Abendsegen',
  'alarmOn': 'Wecker ist an',
  'alarmOff': 'Wecker ist aus',
  'previewMorningAlarm': 'Morgenwecker anhören',
  'previewEveningBlessing': 'Abendsegen anhören',
  'enableMorningAlarm': 'Morgenwecker aktivieren',
  'morningAlarmSubtitle': 'Mit Gebet und Bibelvers ausschalten',
  'repeatDays': 'Wiederholungstage',
  'perDayTimesTitle': 'Andere Zeit pro Tag',
  'alarmsTitle': 'Wecker',
  'addAlarm': 'Wecker hinzufügen',
  'deleteAlarmTitle': 'Löschen',
  'everyDay': 'Täglich',
  'maxAlarmsReached': 'Du kannst bis zu 5 Wecker stellen.',
  'cannotDeleteLastAlarm': 'Mindestens ein Wecker wird benötigt — schalte ihn stattdessen aus.',
  'alarmListHint': 'Jeder Wecker hat seine eigene Mission. Zum Bearbeiten tippen, zum Löschen gedrückt halten.',
  'streakCalendarSubtitle': 'Tage, an denen du dem Herrn begegnet bist, werden automatisch markiert.',
  'calendarTab': 'Kalender',
  'homeTab': 'Start',
  'weatherTab': 'Wetter',
  'showLocalWeather': 'Lokales Wetter anzeigen — zum Einschalten tippen',
  'myLocation': 'Mein Standort',
  'tenDayForecast': '10-TAGE-VORHERSAGE',
  'nowLabel': 'Jetzt',
  'todayLabel': 'Heute',
  'streakTotalDays': 'Du bist dem Herrn insgesamt {days} Tage begegnet',
  'perDayTimesSubtitle': 'Stelle für jeden Tag eine andere Weckzeit ein',
  'setTimeForDay': 'Weckzeit {day}',
  'selectAtLeastOneAlarmDay': 'Wähle mindestens einen Wecktag aus.',
  'weekdayShortMonday': 'Mo',
  'weekdayShortTuesday': 'Di',
  'weekdayShortWednesday': 'Mi',
  'weekdayShortThursday': 'Do',
  'weekdayShortFriday': 'Fr',
  'weekdayShortSaturday': 'Sa',
  'weekdayShortSunday': 'So',
  'setAlarmTime': 'WECKZEIT EINSTELLEN',
  'morningAlarmOffHint': 'Wecker ist aus — unten einschalten, um zu planen',
  'eveningBlessingOffHint': 'Segen ist aus — unten einschalten, um zu planen',
  'enableEveningBlessing': 'Abendsegen aktivieren',
  'eveningBlessingSubtitle': 'Mit dem aaronitischen Segen ausschalten',
  'saveAlarms': 'Wecker speichern',
  'testMorningAlarm': 'Morgenwecker testen (5 Sek.)',
  'testEveningAlarm': 'Abendwecker testen (5 Sek.)',
  'alarmsSaved': 'Wecker gespeichert',
  'saving': 'Wird gespeichert…',
  'signOut': 'Abmelden',
  'home': 'Start',
  'backToMain': 'Zurück zur Startseite',
  'premiumTitle': 'God Morning Premium',
  'premiumSettingsSubtitle': 'Optionales Abo und Kaufverwaltung.',
  'premiumHeroTitle': 'Halte deinen Morgen mit Gott an erster Stelle.',
  'premiumHeroSubtitle': 'Schalte den vollen Rhythmus des Bibelvers-Weckers frei — mit jedem Plan, Ton, jeder Sprache und lokalem Wetter.',
  'premiumMonthlyTitle': 'Monatlich',
  'premiumMonthlyPrice': '2,99 \$ / Monat',
  'premiumAnnualTitle': 'Jährlich',
  'premiumAnnualPrice': '29,99 \$ / Jahr',
  'premiumTrialLabel': '7 Tage kostenlos testen',
  'premiumMonthlyTrialTerms': '7 Tage kostenlos, danach monatliche Verlängerung.',
  'premiumAnnualTrialTerms': '7 Tage kostenlos, danach jährliche Verlängerung.',
  'premiumFeatureAlarm': 'Gebetswecker, der bis zum Amen zurückkehren kann',
  'premiumFeaturePlans': '365 Psalmen und 52 geliebte Verse',
  'premiumFeatureWeather': 'Optionales lokales Wetter nach Abschluss',
  'premiumStartTrial': '7-tägige kostenlose Testphase starten',
  'premiumRestore': 'Käufe wiederherstellen',
  'premiumManageSubscription': 'Abo verwalten oder kündigen',
  'premiumLoadingProducts': 'Abo-Optionen werden geladen…',
  'premiumProductsUnavailable': 'Abo-Optionen sind noch nicht verfügbar. Bitte stelle sicher, dass die Abo-Produkte im App Store oder bei Google Play für diese App eingerichtet sind.',
  'premiumPurchaseSuccess': 'Premium ist aktiv.',
  'premiumPurchasePending': 'Dein Kauf wartet auf die Freigabe durch den Store. Premium wird nach Abschluss freigeschaltet.',
  'premiumPurchaseCancelled': 'Kauf abgebrochen.',
  'premiumPurchaseFailed': 'Der Kauf konnte nicht abgeschlossen werden. Bitte versuche es erneut.',
  'premiumRestoreMissing': 'Es wurde kein aktives Abo zum Wiederherstellen gefunden.',
  'premiumTerms': 'Die Zahlung erfolgt über Apple In-App-Kauf oder Google Play. Die 7-tägige kostenlose Testphase und die Abo-Verlängerung werden vom Store verwaltet. Du kannst jederzeit in deinen Abo-Einstellungen kündigen. Um eine Verlängerung zu vermeiden, kündige mindestens 24 Stunden vor dem nächsten Abrechnungstermin.',
  'premiumCancelAnytime': 'Enthält eine 7-tägige Testphase. Du kannst jederzeit in deinen Abo-Einstellungen kündigen. Um eine Verlängerung zu vermeiden, kündige mindestens 24 Stunden vor dem nächsten Abrechnungstermin.',
  'premiumPurchaseUnavailable': 'Käufe sind derzeit nicht verfügbar. Bitte versuche es später erneut.',
  'premiumOpenSubscriptionFailed': 'Die Abo-Verwaltung konnte nicht geöffnet werden.',
  'termsOfUse': 'Nutzungsbedingungen',
  'privacyPolicy': 'Datenschutzerklärung',
  'openLinkFailed': 'Der Link konnte nicht geöffnet werden.',
  'alarmSound': 'WECKTON',
  'alarmSoundDescription': 'Wähle einen mitgelieferten God-Morning-Weckton für deinen Morgenwecker.',
  'alarmSoundDescriptionIos': 'Tippe auf einen Ton, um ihn einmal anzuhören. Tippe auf einen anderen, um sanft zu wechseln.',
  'soundClassicAlarm': 'Helle Pieptöne (empfohlen)',
  'soundGentleChime': 'Morgenglöckchen',
  'soundChurchBell': 'Kirchenglockengeläut',
  'moreIphoneSounds': 'Weitere Handytöne…',
  'currentAlarmSound': 'Aktuell: {name}',
  'savedAlarmSoundBadge': 'Gespeichert',
  'systemAlarmSound': 'Systemwecker (Standard)',
  'systemNotificationSound': 'Systembenachrichtigung',
  'systemRingtoneSound': 'System-Klingelton',
  'chooseFromPhoneSounds': 'Aus Handytönen auswählen',
  'previewSound': 'Ton anhören',
  'soundSaved': 'Weckton gespeichert',
  'noRingtonesFound': 'Auf diesem Gerät wurden keine Töne gefunden.',
  'commandCopied': 'Befehl kopiert',
  'walkTogether': 'Gemeinsam gehen',
  'circleInviteDescription': 'Ermutige Freunde zum Morgengebet und Sonntagsgottesdienst.\\nLade unbegrenzt Mitglieder ein.',
  'createCircle': 'Circle erstellen',
  'joinCircle': 'Circle beitreten',
  'circleNameHint': 'Circle-Name (z. B. Gnadenzelle)',
  'circleIdHint': 'Circle-ID von deinem Freund',
  'membersCount': '{count} Mitglieder',
  'thisWeekMorning': 'Diese Woche · Mo–So Morgengebet',
  'demoCircleBanner': 'Demo-Circle — alle Funktionen in der iPhone-/Android-App',
  'localCircleBanner': 'Circle auf diesem Handy gespeichert. Füge Freunde mit + hinzu — teile die Circle-ID, damit sie beitreten können.',
  'enterCircleName': 'Bitte gib einen Circle-Namen ein.',
  'circleCreated': 'Circle erstellt. Teile die Circle-ID oder lade per E-Mail/Telefon ein.',
  'enterCircleId': 'Bitte gib eine Circle-ID ein.',
  'joinedCircle': 'Du bist dem Circle beigetreten!',
  'sentEncouragement': 'Ermutigung an {name} gesendet',
  'likeSaveFailed': 'Like konnte nicht gespeichert werden.',
  'morningDoneToday': 'Morgengebet heute erledigt',
  'morningNotYetToday': 'Morgengebet heute noch offen',
  'sendPrayerForTomorrow': 'Gebetsanliegen senden',
  'prayerAcceptHint': 'Sie wählen einen Tag Mo–So diese Woche, um für dich zu beten',
  'unlike': 'Like entfernen',
  'sendLike': 'Like senden',
  'doneToday': 'Heute erledigt',
  'notYetToday': 'Heute noch offen',
  'morningMonSun': 'Morgens · Mo–So',
  'eveningMonSun': 'Abends · Mo–So',
  'notYet': 'Noch nicht',
  'liked': 'Gefällt mir',
  'like': 'Like',
  'prayer': 'Gebet',
  'addMember': 'Mitglied hinzufügen',
  'friendName': 'Name des Freundes',
  'memberAddedToCircle': '{name} wurde deinem Circle hinzugefügt.',
  'inviteByEmailOrPhone': 'Per E-Mail oder Telefonnummer einladen',
  'email': 'E-Mail',
  'phoneNumber': 'Telefonnummer',
  'sendInvite': 'Einladung senden',
  'inviteSent': 'Einladung an {contact} gesendet. Sie treten bei, sobald sie sich anmelden oder die App öffnen.',
  'inviteShareCircleId': 'Teile diese Circle-ID mit deinem Freund: {circleId}',
  'inviteSentExistingUser': 'Einladung gesendet! Sie erhalten eine Benachrichtigung, um deinem Circle beizutreten.',
  'inviteFailed': 'Einladung konnte nicht gesendet werden.',
  'enterEmailOrPhone': 'Gib eine E-Mail-Adresse oder Telefonnummer ein.',
  'invalidEmail': 'Bitte gib eine gültige E-Mail-Adresse ein.',
  'invalidPhone': 'Bitte gib eine gültige Telefonnummer ein.',
  'alreadyInCircle': 'Diese Person ist bereits in deinem Circle.',
  'prayerConfirmedTomorrow': 'Das Morgengebet für morgen ist bestätigt. Es können keine weiteren Anfragen angenommen werden.',
  'prayerRequestsForYou': 'GEBETSANLIEGEN FÜR DICH',
  'circleLikePrayerHint': 'Sende ❤️ als Ermutigung oder teile ein Gebetsanliegen mit Circle-Mitgliedern. Sie wählen einen Tag und beten mit dir beim Morgenwecker.',
  'circleActivity': 'AKTIVITÄT',
  'sentPrayerRequests': 'GEBETE, DIE DU GESENDET HAST',
  'likedYouThisWeek': '{name} hat dir diese Woche ein ❤️ gesendet',
  'markAllRead': 'Alle als gelesen markieren',
  'friendPrayedForYou': 'Hat für dich gebetet',
  'sendPrayerTopic': 'Gebetsanliegen senden',
  'onePrayerPerDayWeek': 'Ein persönliches Gebet pro Tag · wähle einen beliebigen Tag Mo–So diese Woche',
  'schedulePrayer': 'Planen',
  'pickDayThisWeek': 'Wähle einen Tag diese Woche',
  'dayBooked': 'Gebucht',
  'circlePrayer': 'Circle-Gebet',
  'createCirclePrayer': 'Circle-Gebet erstellen',
  'circlePrayersThisWeek': 'CIRCLE-GEBETE DIESE WOCHE',
  'circlePrayerTogether': 'An wichtigen Tagen betet ihr alle gemeinsam',
  'weekPrayersCircle': 'GEBETE DIESER WOCHE · CIRCLE',
  'importantDayLabel': 'Wichtiger Tag (Mo–So)',
  'prayerTopic': 'Gebetsanliegen (z. B. Operation, Krise)',
  'pickADay': 'Wähle einen Tag zum gemeinsamen Beten',
  'scheduled': 'Geplant',
  'circlePrayerCreated': 'Circle-Gebet erstellt. Alle beten gemeinsam.',
  'scheduleFailed': 'Gebet konnte nicht geplant werden.',
  'prayerScheduledFor': 'Gebet von {name} für {day} geplant',
  'circlePrayerOn': 'CIRCLE-GEBET · {day}',
  'onePrayerAcceptOnly': 'Ein persönliches Gebet pro Tag · wähle einen beliebigen Tag Mo–So',
  'fromLabel': 'Von {name}',
  'forYouTomorrow': 'Für dich · morgen früh',
  'decline': 'Ablehnen',
  'prayTomorrow': 'Morgen beten',
  'tomorrowsPrayersCircle': 'GEBETE FÜR MORGEN · CIRCLE',
  'circlePrayerFeedSubtitle': 'Persönliche Gebete, die für diese Woche geplant sind',
  'pending': 'Ausstehend',
  'accepted': 'Angenommen',
  'declined': 'Abgelehnt',
  'sendPrayerRequest': 'Gebetsanliegen senden',
  'toLabel': 'An: {name}',
  'prayerRecipientChoose': '{name} entscheidet, ob morgen früh dafür gebetet wird.',
  'optionalOpener': '1. Eröffnungssatz (optional)',
  'requiredPrayer': '2. Gebetsanliegen in 1–2 Sätzen (erforderlich)',
  'send': 'Senden',
  'friendPrayerConfirmed': 'Gebet von {name} geplant. Wähle für weitere Anliegen einen anderen Tag.',
  'prayerRequestSent': 'Gebetsanliegen an {name} gesendet. Sie wählen einen Tag diese Woche.',
  'prayerAcceptedOneOnly': 'Gebet von {name} für den von dir gewählten Tag geplant.',
  'acceptFailed': 'Anfrage konnte nicht angenommen werden.',
  'prayerDeclined': 'Gebetsanliegen von {name} abgelehnt.',
  'declineFailed': 'Anfrage konnte nicht abgelehnt werden.',
  'prayerDemoSent': 'Gebetsanliegen gesendet (Demo) — wird angezeigt, wenn {name} annimmt.',
  'prayerFrom': 'GEBET VON {name}',
  'prayerArrow': '{from} → {to}',
  'timeToMeetLord': 'Es ist Zeit, dem Herrn zu begegnen.',
  'stopWithPrayerAndWord': 'Mit Gebet und Wort ausschalten',
  'todaysPrayer': 'GEBET DES TAGES',
  'todaysWord': 'WORT DES TAGES',
  'listening': 'Höre zu…',
  'completeWebDemo': 'Abschließen (Web-Demo)',
  'nextStepWebDemo': 'Nächster Schritt (Web-Demo)',
  'continueToNextStep': 'Weiter zum nächsten Schritt',
  'completePrayerFlow': 'Amen',
  'alarmHowItWorksTitle': 'Klingelt der Wecker morgen?',
  'alarmHowItWorksBody': 'Ja. God Morning hält deinen Morgenwecker geplant, bis du ihn ausschaltest.',
  'alarmDetailedHowItWorksTitle': 'So funktioniert es',
  'alarmDetailedHowItWorksBody': '1. Schalte den Morgenwecker ein und tippe auf Speichern.\\n2. Erlaube Wecker und Benachrichtigungen, wenn dein Handy danach fragt.\\n3. Zur gewählten Zeit klingelt der Wecker, auch wenn die App geschlossen ist.\\n4. Stoppe den Wecker, um das Gebet zu öffnen. Der Wecker kehrt zurück, bis du Amen sagst.\\n5. Während des Zuhörens bleibt der Weckton stumm, damit deine Stimme gehört werden kann.',
  'tomorrow': 'morgen',
  'alarmScheduledNext': 'Wecker gespeichert. Nächstes Klingeln: {time}',
  'stepMorningPrayer': 'Morgengebet',
  'stepCirclePrayer': 'Circle-Gebet',
  'stepFriendPrayer': 'Freundesgebet',
  'stepScripture': 'Bibelvers',
  'stepOfTotal': 'Schritt {n} von {total} · {step}',
  'circlePrayingTogetherToday': 'Dein ganzer Circle betet heute gemeinsam.',
  'successMorningCircleFriendScripture': 'Morgengebet, Circle-Gebet, Freundesgebet und Bibelvers — abgeschlossen.\\nGeh in Frieden.',
  'successMorningCircleScripture': 'Morgengebet, Circle-Gebet und Bibelvers — abgeschlossen.\\nGeh in Frieden.',
  'successMeansOfGraceComplete': 'Dein heutiges God Morning ist abgeschlossen.\\nGeh in Frieden.',
  'cancelAlarmResumes': 'Abbrechen (Wecker klingelt weiter)',
  'morningAlarmMustComplete': 'Schließe das heutige Morgengebet ab, um den Wecker auszuschalten.',
  'eveningAlarmMustComplete': 'Schließe den heutigen Abendsegen ab, um den Wecker auszuschalten.',
  'stepEveningGuide': 'Segensanleitung',
  'stepAaronBlessing': 'Aaronitischer Segen',
  'goodnightTitle': 'Gute Nacht.',
  'successEveningRest': 'Der Herr segne dich und behüte dich.\\nRuhe in Frieden.',
  'readAloudToContinue': 'Lies oder tippe mindestens 80 % — dann wird die Schaltfläche aktiv, tippe darauf, wenn du fertig gelesen hast.',
  'inputModeVoice': 'Aufnehmen',
  'inputModeKeyboard': 'Tippen',
  'typePrayerHint': 'Tippe, was du liest…',
  'typingProgress': 'Tippen',
  'recordingInProgress': 'Aufnahme läuft…',
  'liveTranscriptLabel': 'Was wir hören',
  'liveTranscriptHint': 'Sprich laut — deine Worte erscheinen hier, damit du beim Beten mitlesen kannst.',
  'typedEchoLabel': 'Was du getippt hast',
  'morningPrayerVoiceTypeHint': 'Nach dem Start nutze Aufnehmen (Stimme) oder Tippen, um jeden Gebetsschritt zu lesen.',
  'typeToContinue': 'Tippe, was du liest, um fortzufahren.',
  'switchedToTypeMode': 'Sprache ist nicht verfügbar — auf Tippmodus umgeschaltet. Du kannst das Gebet trotzdem abschließen.',
  'emergencyTitle': 'Notfall — geistliches Bekenntnis',
  'emergencyMorningHint': 'Tippe den folgenden Satz genau ein, um den heutigen Morgenwecker auszuschalten.',
  'emergencyEveningHint': 'Gib den Grund an (Übernachtung, Familie, Reise…), um den heutigen Segen zu überspringen.',
  'emergencyMorningPhrase': 'Ich kann das heute wirklich nicht. Herr, bitte vergib mir.',
  'emergencyEveningPrefix': 'Heute konnte ich wegen ',
  'emergencyEveningSuffix': ' den Kindersegen nicht beten. Herr, bitte vergib mir.',
  'emergencyTypePhraseHint': 'Tippe den Bekenntnissatz…',
  'emergencyEveningReasonHint': 'z. B. Übernachtung, Familienausflug…',
  'emergencyConfirm': 'Bekenntnis absenden & Wecker ausschalten',
  'emergencyNotAvailable': 'Diese Woche sind für deine Intensitätsstufe keine Notausstiege mehr übrig.',
  'emergencyButton': 'Notfall — ich brauche heute Gnade',
  'emergencySuccessMessage': 'Der Herr hört dein Bekenntnis. Der Wecker ist für heute aus. Komm morgen wieder.',
  'emergencyGraceRemaining': 'Gnade der ersten Woche — Notfall noch {days} Tage lang geöffnet.',
  'emergencyRemainingThisWeek': 'Notausstiege diese Woche übrig: {count}',
  'prayerIntensity': 'Gebetsintensität',
  'prayerIntensityGentle': 'Sanft',
  'prayerIntensityNormal': 'Normal',
  'prayerIntensityStrict': 'Streng',
  'prayerIntensityHint': 'Sanft 65 % · Normal 80 % · Streng 90 %. Notfall: 3 / 1 / 0 pro Woche ab Tag 7.',
  'streakTitle': 'Morgen-Serie',
  'streakDays': '{days} Tage in Folge',
  'eveningStreakDays': 'Kindersegen — {days} Tage in Folge',
  'eveningStreakStart': 'Beginne heute Abend mit dem Kindersegen',
  'streakStartToday': 'Schließe heute das Morgengebet ab, um deine Serie zu starten.',
  'emergencyFeatureTitle': 'Notfall — geistliches Bekenntnis',
  'emergencyFeatureBody': 'Tippe auf dem Weckerbildschirm auf Notfall und gib das Bekenntnis ein, um auszuschalten. Abends: Gib deinen Grund an (Übernachtung, Familie usw.).',
  'hallelujah': 'Halleluja',
  'done': 'Fertig',
  'amen': 'Amen',
  'prayingWithYou': '{name} betet heute Morgen mit dir.',
  'blessWithPrayer': 'Mit Gebet segnen',
  'micPermissionChrome': 'Erlaube den Mikrofonzugriff in Chrome (Schloss-Symbol in der Adressleiste).',
  'speechNotAvailable': 'Spracherkennung ist auf diesem Gerät nicht verfügbar.',
  'welcomeBack': 'Willkommen zurück.',
  'signInToContinue': 'Melde dich an, um deinen Weg fortzusetzen.',
  'password': 'Passwort',
  'signInWithApple': 'Mit Apple anmelden',
  'createAccount': 'Konto erstellen',
  'noAccount': 'Kein Konto? Erstelle eines',
  'haveAccount': 'Hast du schon ein Konto? Anmelden',
  'name': 'Name',
  'confirmPassword': 'Passwort bestätigen',
  'enterEmail': 'Bitte gib deine E-Mail-Adresse ein.',
  'enterPassword': 'Bitte gib dein Passwort ein.',
  'enterName': 'Bitte gib deinen Namen ein.',
  'passwordMinLength': 'Das Passwort muss mindestens 6 Zeichen lang sein.',
  'passwordsDoNotMatch': 'Die Passwörter stimmen nicht überein.',
  'errorInvalidEmail': 'Bitte gib eine gültige E-Mail-Adresse ein.',
  'errorUserNotFound': 'Mit dieser E-Mail-Adresse wurde kein Konto gefunden.',
  'errorWrongPassword': 'Falsches Passwort.',
  'errorEmailInUse': 'Diese E-Mail-Adresse wird bereits verwendet.',
  'errorWeakPassword': 'Das Passwort muss mindestens 6 Zeichen lang sein.',
  'errorInvalidCredential': 'Bitte überprüfe deine E-Mail-Adresse und dein Passwort.',
  'errorOperationNotAllowed': 'Diese Anmeldemethode ist nicht verfügbar.',
  'errorSignInFailed': 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.',
  'errorLoginRequired': 'Anmeldung erforderlich.',
  'errorAlreadyInCircle': 'Du bist bereits in einem Circle.',
  'errorCircleNotFound': 'Circle nicht gefunden. Überprüfe die Circle-ID.',
  'errorPrayerTextRequired': 'Bitte gib ein Gebetsanliegen ein.',
  'errorOpenerOneSentence': 'Das Eröffnungsgebet muss ein Satz sein.',
  'errorTomorrowPrayerConfirmed': '{name} hat das Morgengebet für morgen bereits bestätigt.',
  'errorOnePrayerPerDay': 'Du kannst nur ein Gebet pro Tag annehmen.',
  'notificationPrayerHeard': 'Dein Freund hat dein Gebet gehört.',
  'appTitle': 'God Morning',
  'yourCircle': 'Dein Kreis',
  'localWeather': 'Lokales Wetter',
  'localWeatherSubtitle':
      'Zeigt heute und diese Woche anhand deines aktuellen Standorts.',
  'localWeatherLoading': 'Lokale Vorhersage wird geladen...',
  'localWeatherSettingsBody':
      'Der aktuelle Standort wird nur für die Vorhersage für heute und diese Woche verwendet. God Morning speichert deinen Standort nicht.',
  'enableLocalWeather': 'Lokales Wetter anzeigen',
  'weatherRefresh': 'Wetter aktualisieren',
  'weatherThisWeek': 'Diese Woche',
  'weatherFeelsLike': 'Gefühlt {temp}',
  'weatherWind': 'Wind {speed} {unit}',
  'weatherRainChance': 'Regen {chance}%',
  'weatherHighLow': 'H {high}  T {low}',
  'weatherPermissionRequired':
      'Für lokales Wetter ist Standortzugriff erforderlich.',
  'weatherLocationServicesOff':
      'Aktiviere die Ortungsdienste, um lokales Wetter zu zeigen.',
  'weatherUnavailable':
      'Wetter ist gerade nicht verfügbar. Bitte später erneut versuchen.',
  'weatherEnabled': 'Lokales Wetter aktiviert',
  'weatherDisabled': 'Lokales Wetter deaktiviert',
  'weatherAttribution': 'Wetterdaten von Open-Meteo.com',
  'weatherTemperatureUnit': 'Temperatureinheit',
  'weatherUnitFahrenheit': 'Fahrenheit (°F)',
  'weatherUnitCelsius': 'Celsius (°C)',
  'settings': 'Einstellungen',
  'language': 'Sprache',
  'selectLanguage': 'Sprache auswählen',
  'scripturePlan': 'Bibelplan',
  'selectScripturePlan': 'Bibelplan auswählen',
  'scripturePlanDaily': '365 Psalmen und Gebete',
  'scripturePlanDailySubtitle':
      'Beginne jeden Morgen mit einem Psalmvers und einem kurzen Gebet.',
  'scripturePlanBeloved52': '52 geliebte Bibelverse',
  'scripturePlanBeloved52Subtitle':
      'Lies jede Woche einen geliebten Vers zum Auswendiglernen.',
  'missionContent': 'Missionsinhalt',
  'selectMissionContent': 'Missionsinhalt auswählen',
  'missionContentScriptureAndPrayer': 'Bibeltext + Gebet',
  'missionContentScriptureAndPrayerSubtitle':
      'Lies den Bibelvers und das Morgengebet.',
  'missionContentScriptureOnly': 'Nur Bibeltext',
  'missionContentScriptureOnlySubtitle':
      'Schließe die Mission nur mit dem Bibelvers ab.',
  'missionContentPrayerOnly': 'Nur Gebet',
  'missionContentPrayerOnlySubtitle':
      'Lies einen eigenen 365-Tage-Themengebetsplan ohne Bibeltextblock.',
  'inviteFriend': 'Freund einladen',
  'signIn': 'Anmelden',
  'save': 'Speichern',
  'cancel': 'Abbrechen',
  'practiceMission': 'Mission üben',
  'practiceMissionSubtitle':
      'Übe den Ablauf mit Bibeltext und Gebet, ohne den echten Wecker, Wiederholungen oder die Serie zu ändern.',
  'missionPassThreshold': 'Bestehensgrenze der Mission',
  'missionPassThresholdSubtitle':
      'Wähle, wie viel von Bibeltext und Gebet übereinstimmen muss, bevor Amen aktiv wird. Niedriger ist leichter; höher ist strenger.',
  'missionPassThresholdLow': 'Leichter',
  'missionPassThresholdHigh': 'Strenger',
  'bibleLicenseTitle': 'Bibeltext',
  'bibleLicenseBody':
      'Quellen der Bibeltexte:\n'
      'Koreanisch: Korean Revised Version 1952/1961 (KRV / 개역한글). Quelle: KorRV / Zefania XML. Rechte: Public Domain.\n'
      'Englisch: World English Bible (WEB). Quelle: eBible.org. Rechte: Public Domain.\n'
      'Deutsch: Lutherbibel 1912. Quelle: eBible.org. Rechte: Public Domain.\n'
      'Russisch: Russian Synodal Translation (1876 / Синодальный перевод). Quelle: eBible.org. Rechte: Public Domain.\n'
      'Spanisch: Reina-Valera 1909 (RV1909). Quelle: eBible.org. Rechte: Public Domain.\n'
      'Portugiesisch: Bíblia Livre (BLJ). Quelle: eBible.org. Rechte: Public Domain.\n'
      'Chinesisch: Chinese Union Version 1919 (和合本, vereinfacht). Quelle: getBible / CrossWire. Rechte: Public Domain.\n'
      'Japanisch: Kougo-yaku 1954/1955 (口語訳). Quelle: getBible / CrossWire. Rechte: Public Domain.',
  'permissionNotificationTitle': 'Benachrichtigungen',
  'permissionNotificationBody': 'Nötig, damit der Wecker dich alarmieren kann.',
  'permissionMicrophoneTitle': 'Mikrofon',
  'permissionMicrophoneBody':
      'Nötig, damit die App hört, wenn du Bibeltext und Gebet liest.',
  'permissionAlarmKitTitle': 'Weckerberechtigung',
  'permissionAlarmKitBody':
      'Nötig, damit der Morgenwecker zuverlässig klingeln kann.',
  'permissionMissionTitle': 'Amen beendet den Wecker',
  'permissionMissionBody':
      'Der Wecker kehrt zurück, bis die Bibeltext- und Gebetsmission abgeschlossen ist.',
  'notificationsPermissionTitle': 'Benachrichtigungen erlauben',
  'notificationsPermissionBody':
      'God Morning braucht einige Berechtigungen, damit der Morgenwecker klingeln und dein Gebet hören kann.',
  'allowNotifications': 'Erlauben und fortfahren',
  'onboardingNext': 'Weiter',
  'onboardingEnableAndStart': 'Erlauben und starten',
  'onboardingProductTitle': 'Gib Gott die erste Minute deines Morgens.',
  'onboardingProductBody':
      'God Morning hilft dir, mit einem Bibelvers, einem kurzen Gebet und einem einfachen Amen aufzuwachen.',
  'onboardingProductPointOneVerse':
      'Ein Vers pro Tag, vorbereitet für deinen Morgen',
  'onboardingProductPointFirstMinute':
      'Eine stille erste Minute mit Schrift und Gebet',
  'onboardingReadTitle': 'Lies laut. Beginne aufmerksam.',
  'onboardingReadBody':
      'Wenn der Wecker klingelt, öffnet God Morning eine fokussierte Schrift-und-Gebet-Mission, die du per Stimme oder Tippen abschließen kannst.',
  'onboardingReadPointVoiceType': 'Folge dem Text per Stimme oder Tippmodus',
  'onboardingReadPointAmen':
      'Amen ist der letzte Schritt, der den Wecker abschließt',
  'onboardingAlarmTitle': 'Ein Morgenwecker mit Ziel.',
  'onboardingAlarmBody':
      'Wähle Zeit und Ton, damit der Wecker dich nicht zum Snooze, sondern zu Schrift und Gebet führt.',
  'onboardingAlarmPointClosed':
      'Entwickelt, um auch bei geschlossener App zu klingeln',
  'onboardingAlarmPointReturn':
      'Wenn du vor Amen gehst, kann der Wecker zurückkehren',
  'onboardingPermissionsTitle': 'Aktiviere, was God Morning braucht.',
  'onboardingPermissionsBody':
      'Wir fragen nach den Berechtigungen für Wecker, Benachrichtigungen, Mikrofon und Spracherkennung.',
  'permissionSettingsTitle': 'Berechtigungen',
  'permissionSettingsBody':
      'Aktiviere die Berechtigungen, die God Morning für Wecker und Lesemission braucht.',
  'permissionEnable': 'Aktivieren',
  'permissionEnabled': 'Aktiviert',
  'notificationsDisabledWarning':
      'Benachrichtigungen sind aus. Wecker klingeln erst, wenn du sie in den Telefoneinstellungen aktivierst.',
  'openIphoneSettings': 'Telefoneinstellungen öffnen',
  'enableNotificationsToRing':
      'Aktiviere zuerst Benachrichtigungen, sonst kann der Wecker nicht klingeln.',
  'premiumFeatureLanguages':
      'Englisch, Koreanisch, Deutsch, Russisch, Spanisch, Portugiesisch, Chinesisch und Japanisch',
  'eveningChildrenBlessing': 'Segenszeit für die Kinder',
  'blessBeforeRest': 'Segne deine Kinder mit einem Gebet vor dem Schlafengehen',
};

const _zh = {
  'appTitle': 'God Morning',
  'save': '保存',
  'cancel': '取消',
  'retry': '重试',
  'settings': '设置',
  'language': '语言',
  'selectLanguage': '选择语言',
  'scripturePlan': '经文计划',
  'selectScripturePlan': '选择经文计划',
  'scripturePlanDaily': '365天诗篇与祷告',
  'scripturePlanDailySubtitle': '每天清晨以一节诗篇和简短祷告开始。',
  'scripturePlanBeloved52': '52节挚爱经文',
  'scripturePlanBeloved52Subtitle': '每周诵读一节挚爱经文，用心背诵。',
  'missionContent': '任务内容',
  'selectMissionContent': '选择任务内容',
  'missionContentScriptureAndPrayer': '经文 + 祷告',
  'missionContentScriptureAndPrayerSubtitle': '诵读圣经经文和晨间祷告。',
  'missionContentScriptureOnly': '仅经文',
  'missionContentScriptureOnlySubtitle': '只需诵读圣经经文即可完成任务。',
  'missionContentPrayerOnly': '仅祷告',
  'missionContentPrayerOnlySubtitle': '诵读专属的 365 天主题祷告，不含经文部分。',
  'morningPrayerEveningBlessing': '晨间祷告与晚间祝福。',
  'tapTimeToSetAlarm': '点按时间设置闹钟，并在下方选择铃声。',
  'tapToSetTimeAndSound': '点按设置时间与铃声',
  'circleTapToOpen': '小组 · 点按打开',
  'webPreviewBanner': 'Chrome 预览——可查看闹钟与圈子界面。完整功能请在 iPhone/Android 上体验。',
  'morningAlarm': '晨间闹钟',
  'eveningBlessing': '晚间祝福',
  'alarmOn': '闹钟已开启',
  'alarmOff': '闹钟已关闭',
  'previewMorningAlarm': '试听晨间闹钟',
  'previewEveningBlessing': '试听晚间祝福',
  'yourCircle': '你的圈子',
  'localWeather': '本地天气',
  'localWeatherSubtitle': '使用你的当前位置显示今天和本周的天气。',
  'localWeatherLoading': '正在加载本地天气预报…',
  'localWeatherSettingsBody': '仅使用你的当前位置获取今天和本周的天气。God Morning 不会存储你的位置信息。',
  'enableLocalWeather': '显示本地天气',
  'weatherRefresh': '刷新天气',
  'weatherThisWeek': '本周',
  'weatherFeelsLike': '体感 {temp}',
  'weatherWind': '风速 {speed} {unit}',
  'weatherRainChance': '降雨 {chance}%',
  'weatherHighLow': '最高 {high}  最低 {low}',
  'weatherPermissionRequired': '显示本地天气需要位置权限。',
  'weatherLocationServicesOff': '请开启定位服务以显示本地天气。',
  'weatherUnavailable': '暂时无法获取天气，请稍后再试。',
  'weatherEnabled': '已开启本地天气',
  'weatherDisabled': '已关闭本地天气',
  'weatherAttribution': '天气数据来自 Open-Meteo.com',
  'weatherTemperatureUnit': '温度单位',
  'weatherUnitFahrenheit': '华氏度（°F）',
  'weatherUnitCelsius': '摄氏度（°C）',
  'enableMorningAlarm': '开启晨间闹钟',
  'morningAlarmSubtitle': '以祷告与经文来关闭闹钟',
  'repeatDays': '重复日',
  'perDayTimesTitle': '每天不同时间',
  'alarmsTitle': '闹钟',
  'addAlarm': '添加闹钟',
  'deleteAlarmTitle': '删除',
  'everyDay': '每天',
  'maxAlarmsReached': '最多可设置 5 个闹钟。',
  'cannotDeleteLastAlarm': '至少需要保留一个闹钟，请改为将其关闭。',
  'alarmListHint': '每个闹钟都有自己的使命。点按可编辑，长按可删除。',
  'streakCalendarSubtitle': '与主相遇的日子会自动标记。',
  'calendarTab': '日历',
  'homeTab': '首页',
  'weatherTab': '天气',
  'showLocalWeather': '显示本地天气——点按开启',
  'myLocation': '我的位置',
  'tenDayForecast': '10日预报',
  'nowLabel': '现在',
  'todayLabel': '今天',
  'streakTotalDays': '你已与主相遇 {days} 天',
  'perDayTimesSubtitle': '为每一天设置不同的闹钟时间',
  'setTimeForDay': '{day}闹钟时间',
  'selectAtLeastOneAlarmDay': '请至少选择一天设置闹钟。',
  'weekdayShortMonday': '周一',
  'weekdayShortTuesday': '周二',
  'weekdayShortWednesday': '周三',
  'weekdayShortThursday': '周四',
  'weekdayShortFriday': '周五',
  'weekdayShortSaturday': '周六',
  'weekdayShortSunday': '周日',
  'setAlarmTime': '设置闹钟时间',
  'morningAlarmOffHint': '闹钟已关闭，在下方开启即可安排',
  'eveningBlessingOffHint': '祝福已关闭，在下方开启即可安排',
  'enableEveningBlessing': '开启晚间祝福',
  'saveAlarms': '保存闹钟',
  'testMorningAlarm': '测试晨间闹钟（5秒）',
  'testEveningAlarm': '测试晚间闹钟（5秒）',
  'practiceMission': '练习任务',
  'practiceMissionSubtitle': '体验读经与祷告流程，不会影响您的真实闹钟、重试次数或连续记录。',
  'missionPassThreshold': '任务通过标准',
  'missionPassThresholdSubtitle': '选择经文与祷告需匹配的程度，达到后才能解锁“阿们”。数值越低越宽松，越高越严格。',
  'missionPassThresholdLow': '更宽松',
  'missionPassThresholdHigh': '更严格',
  'alarmsSaved': '闹钟已保存',
  'saving': '保存中…',
  'signOut': '退出登录',
  'home': '首页',
  'backToMain': '返回主页',
  'premiumTitle': 'God Morning 高级版',
  'premiumSettingsSubtitle': '可选的订阅与购买管理。',
  'premiumHeroTitle': '让每个清晨以神为先。',
  'premiumHeroSubtitle': '解锁完整的经文闹钟节奏，包含全部计划、铃声、语言和当地天气。',
  'premiumMonthlyTitle': '月度',
  'premiumAnnualTitle': '年度',
  'premiumTrialLabel': '7 天免费试用',
  'premiumMonthlyTrialTerms': '7 天免费试用，之后按月续订。',
  'premiumAnnualTrialTerms': '7 天免费试用，之后按年续订。',
  'premiumFeatureAlarm': '可反复响起直到阿们的祷告闹钟',
  'premiumFeaturePlans': '365 篇诗篇与 52 节挚爱经文',
  'premiumFeatureLanguages': '英语、韩语、德语、俄语、西班牙语、葡萄牙语、中文和日语',
  'premiumFeatureWeather': '完成后可选显示当地天气',
  'premiumStartTrial': '开始 7 天免费试用',
  'premiumRestore': '恢复购买',
  'premiumManageSubscription': '管理或取消订阅',
  'premiumLoadingProducts': '正在加载订阅选项…',
  'premiumProductsUnavailable': '订阅选项暂不可用。请确认已为本应用配置 App Store 或 Google Play 的订阅商品。',
  'premiumPurchaseSuccess': '高级版已激活。',
  'premiumPurchasePending': '您的购买正在等待商店批准，完成后将解锁高级版。',
  'premiumPurchaseCancelled': '购买已取消。',
  'premiumPurchaseFailed': '购买未能完成，请重试。',
  'premiumRestoreMissing': '未找到可恢复的有效订阅。',
  'premiumTerms': '费用将通过 Apple 应用内购买或 Google Play 结算收取。7 天免费试用和订阅续订由商店管理。可随时在订阅设置中取消。如需避免续订，请至少在下一个扣费日前 24 小时取消。',
  'premiumCancelAnytime': '包含 7 天试用。可随时在订阅设置中取消。如需避免续订，请至少在下一个扣费日前 24 小时取消。',
  'premiumPurchaseUnavailable': '目前无法进行购买，请稍后重试。',
  'premiumOpenSubscriptionFailed': '无法打开订阅管理。',
  'termsOfUse': '使用条款',
  'privacyPolicy': '隐私政策',
  'openLinkFailed': '无法打开链接。',
  'alarmSound': '闹钟铃声',
  'alarmSoundDescription': '为您的晨间闹钟选择一款 God Morning 内置铃声。',
  'alarmSoundDescriptionIos': '点按铃声即可试听一次，点按其他铃声可流畅切换。',
  'soundClassicAlarm': '明快提示音（推荐）',
  'soundGentleChime': '晨间风铃',
  'soundChurchBell': '教堂钟声',
  'moreIphoneSounds': '更多手机铃声…',
  'currentAlarmSound': '当前：{name}',
  'savedAlarmSoundBadge': '已保存',
  'systemAlarmSound': '系统闹钟（默认）',
  'systemNotificationSound': '系统通知音',
  'systemRingtoneSound': '系统铃声',
  'chooseFromPhoneSounds': '从手机铃声中选择',
  'previewSound': '试听铃声',
  'soundSaved': '闹钟铃声已保存',
  'noRingtonesFound': '此设备上未找到铃声。',
  'notificationsPermissionTitle': '允许通知',
  'notificationsPermissionBody': 'God Morning 需要一些权限，才能让晨间闹钟响铃并听到你的祷告。',
  'allowNotifications': '允许并继续',
  'onboardingNext': '继续',
  'onboardingEnableAndStart': '启用并开始',
  'onboardingProductTitle': '把清晨的第一分钟献给神。',
  'onboardingProductBody': 'God Morning 以一节圣经经文、一段简短祷告和一声“阿们”，帮助你开始每个清晨。',
  'onboardingProductPointOneVerse': '每天一节经文，为你的清晨预备',
  'onboardingProductPointFirstMinute': '以经文与祷告塑造安静的清晨第一分钟',
  'onboardingReadTitle': '大声诵读，以专注开始。',
  'onboardingReadBody': '闹钟响起时，God Morning 会打开一个专注的读经与祷告任务，您可以通过语音或打字完成。',
  'onboardingReadPointVoiceType': '使用语音或打字模式跟读经文',
  'onboardingReadPointAmen': '阿们是完成闹钟的最后一步',
  'onboardingAlarmTitle': '一个有使命的晨间闹钟。',
  'onboardingAlarmBody': '设定时间，选择铃声，让闹钟引导你进入任务，而不是再一次贪睡。',
  'onboardingAlarmPointClosed': '即使应用已关闭也能响铃',
  'onboardingAlarmPointReturn': '若在说“阿们”之前离开，闹钟会再次响起',
  'onboardingPermissionsTitle': '开启 God Morning 所需的权限。',
  'onboardingPermissionsBody': '我们将请求闹钟、通知、麦克风和语音识别所需的权限。',
  'commandCopied': '命令已复制',
  'walkTogether': '一同前行',
  'circleInviteDescription': '鼓励朋友一同晨祷、参加主日敬拜。\\n可邀请的成员人数不限。',
  'createCircle': '创建圈子',
  'joinCircle': '加入圈子',
  'circleNameHint': '圈子名称（例如：恩典小组）',
  'circleIdHint': '朋友提供的圈子 ID',
  'membersCount': '{count} 位成员',
  'thisWeekMorning': '本周 · 周一至周日晨祷',
  'demoCircleBanner': '演示圈子——完整功能请使用 iPhone／Android 应用',
  'localCircleBanner': '圈子已保存在这部手机上。点按 + 添加朋友，分享圈子 ID 邀请他们加入。',
  'enterCircleName': '请输入圈子名称。',
  'circleCreated': '圈子已创建。分享圈子 ID，或通过邮箱／手机号邀请。',
  'enterCircleId': '请输入圈子 ID。',
  'joinedCircle': '你已加入圈子！',
  'sentEncouragement': '已向 {name} 送出鼓励',
  'likeSaveFailed': '点赞保存失败。',
  'morningDoneToday': '今日晨祷已完成',
  'morningNotYetToday': '今日晨祷尚未完成',
  'sendPrayerForTomorrow': '发送代祷请求',
  'prayerAcceptHint': '对方将在本周周一至周日中选择一天为您祷告',
  'unlike': '取消点赞',
  'sendLike': '点赞',
  'doneToday': '今日已完成',
  'notYetToday': '今天尚未完成',
  'morningMonSun': '晨间 · 周一至周日',
  'eveningMonSun': '晚间 · 周一至周日',
  'notYet': '尚未',
  'liked': '已点赞',
  'like': '点赞',
  'prayer': '祷告',
  'inviteFriend': '邀请朋友',
  'addMember': '添加成员',
  'friendName': '朋友的名字',
  'memberAddedToCircle': '已将{name}添加到你的圈子。',
  'inviteByEmailOrPhone': '通过邮箱或电话号码邀请',
  'email': '邮箱',
  'phoneNumber': '电话号码',
  'sendInvite': '发送邀请',
  'inviteSent': '已向{contact}发送邀请。对方注册或打开应用后即可加入。',
  'inviteShareCircleId': '将此圈子 ID 分享给你的朋友：{circleId}',
  'inviteSentExistingUser': '邀请已发送！对方将收到加入你圈子的通知。',
  'inviteFailed': '无法发送邀请。',
  'enterEmailOrPhone': '请输入邮箱或手机号。',
  'invalidEmail': '请输入有效的电子邮箱地址。',
  'invalidPhone': '请输入有效的电话号码。',
  'alreadyInCircle': '此人已在您的圈子中。',
  'prayerConfirmedTomorrow': '明天的晨间祷告已确认，无法再接受其他请求。',
  'prayerRequestsForYou': '给您的祷告请求',
  'circleLikePrayerHint': '向圈子成员发送 ❤️ 鼓励，或分享代祷事项。他们会选定一天，在晨间闹钟时与您一同祷告。',
  'circleActivity': '动态',
  'sentPrayerRequests': '你发送的代祷',
  'likedYouThisWeek': '本周{name}向你发送了 ❤️',
  'markAllRead': '全部标为已读',
  'friendPrayedForYou': '为你祷告了',
  'sendPrayerTopic': '发送祷告事项',
  'onePrayerPerDayWeek': '每天一次个人祷告 · 本周周一至周日任选一天',
  'schedulePrayer': '安排',
  'pickDayThisWeek': '选择本周的一天',
  'dayBooked': '已预约',
  'circlePrayer': '圈子祷告',
  'createCirclePrayer': '创建圈子祷告',
  'circlePrayersThisWeek': '本周圈子祷告',
  'circlePrayerTogether': '在重要的日子里大家一同祷告',
  'weekPrayersCircle': '本周祷告 · 圈子',
  'importantDayLabel': '重要的日子（周一至周日）',
  'prayerTopic': '祷告事项（如手术、危机）',
  'pickADay': '选择一天一同祷告',
  'scheduled': '已安排',
  'circlePrayerCreated': '圈子祷告已创建。大家将一同祷告。',
  'scheduleFailed': '无法安排祷告。',
  'prayerScheduledFor': '已将{name}的祷告安排在{day}',
  'circlePrayerOn': '圈子祷告 · {day}',
  'onePrayerAcceptOnly': '每天一次个人祷告 · 周一至周日任选一天',
  'fromLabel': '来自{name}',
  'forYouTomorrow': '为你预备 · 明天早晨',
  'decline': '拒绝',
  'prayTomorrow': '明天祷告',
  'tomorrowsPrayersCircle': '明日祷告 · 圈子',
  'circlePrayerFeedSubtitle': '本周已安排的个人祷告',
  'pending': '待处理',
  'accepted': '已接受',
  'declined': '已拒绝',
  'sendPrayerRequest': '发送代祷请求',
  'toLabel': '致：{name}',
  'prayerRecipientChoose': '{name}将选择是否在明天早晨为此祷告。',
  'optionalOpener': '1. 开头语（可选）',
  'requiredPrayer': '2. 祷告请求 1–2 句（必填）',
  'send': '发送',
  'friendPrayerConfirmed': '已安排{name}的祷告。其他代祷事项请另选一天。',
  'prayerRequestSent': '祷告请求已发送给{name}。对方将在本周选择一天。',
  'prayerAcceptedOneOnly': '已将{name}的祷告安排在您选择的日子。',
  'acceptFailed': '无法接受请求。',
  'prayerDeclined': '已拒绝{name}的祷告请求。',
  'declineFailed': '无法拒绝请求。',
  'prayerDemoSent': '祷告请求已发送（演示）——{name}接受后即会显示。',
  'prayerFrom': '来自{name}的祷告',
  'prayerArrow': '{from} → {to}',
  'timeToMeetLord': '与主相会的时候到了。',
  'stopWithPrayerAndWord': '以祷告与话语停止闹钟',
  'listening': '正在聆听…',
  'completeWebDemo': '完成（网页演示）',
  'nextStepWebDemo': '下一步（网页演示）',
  'continueToNextStep': '继续下一步',
  'completePrayerFlow': '阿们',
  'alarmHowItWorksTitle': '闹钟明天会响吗？',
  'alarmHowItWorksBody': '会的。God Morning 会一直为您安排晨间闹钟，直到您将其关闭。',
  'alarmDetailedHowItWorksTitle': '运作方式',
  'alarmDetailedHowItWorksBody': '1. 打开晨间闹钟并点按“保存”。\\n2. 若手机询问，请允许闹钟和通知权限。\\n3. 到了设定时间，即使应用已关闭，闹钟也会响起。\\n4. 停止闹钟即进入祷告。在说出阿们之前，闹钟会不断重响。\\n5. 聆听期间闹钟声保持静音，以便听清您的声音。',
  'bibleLicenseTitle': '圣经文本',
  'bibleLicenseBody': '圣经文本来源：\n'
      '韩文：Korean Revised Version 1952/1961 (KRV / 개역한글)。来源：KorRV / Zefania XML。权利：Public Domain。\n'
      '英文：World English Bible (WEB)。来源：eBible.org。权利：Public Domain。\n'
      '德文：Lutherbibel 1912。来源：eBible.org。权利：Public Domain。\n'
      '俄文：Russian Synodal Translation (1876 / Синодальный перевод)。来源：eBible.org。权利：Public Domain。\n'
      '西班牙文：Reina-Valera 1909 (RV1909)。来源：eBible.org。权利：Public Domain。\n'
      '葡萄牙文：Bíblia Livre (BLJ)。来源：eBible.org。权利：Public Domain。\n'
      '中文：和合本 1919（简体，Chinese Union Version）。来源：getBible / CrossWire。权利：Public Domain。\n'
      '日文：口語訳 1954/1955 (Kougo-yaku)。来源：getBible / CrossWire。权利：Public Domain。',
  'permissionNotificationTitle': '通知',
  'permissionNotificationBody': '需要此权限，闹钟才能提醒您。',
  'permissionMicrophoneTitle': '麦克风',
  'permissionMicrophoneBody': '需要此权限，应用才能听到您诵读经文和祷告。',
  'permissionAlarmKitTitle': '闹钟权限',
  'permissionAlarmKitBody': '需要此权限，晨间闹钟才能可靠地响起。',
  'permissionMissionTitle': '阿们完成闹钟',
  'permissionMissionBody': '在完成读经与祷告任务之前，闹钟会不断再次响起。',
  'permissionSettingsTitle': '权限',
  'permissionSettingsBody': '启用 God Morning 的闹钟和诵读任务所需的权限。',
  'permissionEnable': '启用',
  'permissionEnabled': '已启用',
  'notificationsDisabledWarning': '通知已关闭。在手机设置中开启通知之前，闹钟不会响铃。',
  'openIphoneSettings': '打开手机设置',
  'enableNotificationsToRing': '请先开启通知，否则闹钟无法响铃。',
  'tomorrow': '明天',
  'alarmScheduledNext': '闹钟已保存。下次响铃：{time}',
  'stepMorningPrayer': '晨祷',
  'stepCirclePrayer': '圈子祷告',
  'stepFriendPrayer': '好友祷告',
  'stepScripture': '经文',
  'stepOfTotal': '第 {n}/{total} 步 · {step}',
  'circlePrayingTogetherToday': '今天您的整个圈子正在一同祷告。',
  'successMorningCircleFriendScripture': '晨祷、圈子祷告、好友祷告与经文——全部完成。\\n平安前行。',
  'successMorningCircleScripture': '晨祷、圈子祷告与经文——全部完成。\\n平安前行。',
  'cancelAlarmResumes': '取消（闹钟将恢复响铃）',
  'morningAlarmMustComplete': '完成今天的晨祷后才能关闭闹钟。',
  'eveningAlarmMustComplete': '完成今天的晚间祝福后才能关闭闹钟。',
  'blessBeforeRest': '睡前用祷告祝福你的孩子',
  'stepEveningGuide': '祝福指引',
  'goodnightTitle': '晚安。',
  'successEveningRest': '愿主赐福给你，保护你。\\n安然歇息。',
  'readAloudToContinue': '诵读或输入至少 80% 后按钮将启用，读完后点按即可。',
  'inputModeVoice': '录音',
  'inputModeKeyboard': '打字',
  'typePrayerHint': '输入你所读的内容……',
  'typingProgress': '输入中',
  'recordingInProgress': '录音中…',
  'liveTranscriptLabel': '我们听到的',
  'liveTranscriptHint': '请开口朗读，你的话语会显示在这里，方便你边祷告边确认。',
  'typedEchoLabel': '你输入的内容',
  'morningPrayerVoiceTypeHint': '开始后，使用录音（语音）或打字来诵读每一步祷告。',
  'typeToContinue': '输入你所读的内容以继续。',
  'switchedToTypeMode': '语音不可用——已切换为输入模式。你仍可完成祷告。',
  'emergencyTitle': '紧急——属灵认罪',
  'emergencyMorningHint': '请一字不差地输入下方语句，以关闭今天的晨间闹钟。',
  'emergencyEveningHint': '填写原因（外宿、家庭、旅行等），即可跳过今晚的祝福。',
  'emergencyMorningPhrase': '今天我实在做不到。主啊，求你赦免我。',
  'emergencyEveningPrefix': '今天因为',
  'emergencyEveningSuffix': '，我未能为孩子们献上祝福祷告。主啊，求你赦免我。',
  'emergencyTypePhraseHint': '输入认罪语句……',
  'emergencyEveningReasonHint': '例如：外宿、家庭旅行……',
  'emergencyConfirm': '提交认罪并解除闹钟',
  'emergencyNotAvailable': '按您的强度等级，本周的紧急豁免次数已用完。',
  'emergencyButton': '紧急——今天我需要恩典',
  'emergencySuccessMessage': '主垂听了你的认罪。今天的闹钟已关闭，明天再回来吧。',
  'emergencyGraceRemaining': '首周恩典期——紧急通道还可使用 {days} 天。',
  'emergencyRemainingThisWeek': '本周剩余紧急豁免次数：{count}',
  'prayerIntensity': '祷告强度',
  'prayerIntensityGentle': '温和',
  'prayerIntensityNormal': '普通',
  'prayerIntensityStrict': '严格',
  'prayerIntensityHint': '温和 65% · 普通 80% · 严格 90%。紧急：第 7 天后每周 3 / 1 / 0 次。',
  'streakTitle': '晨祷连续记录',
  'streakDays': '连续 {days} 天',
  'eveningStreakDays': '孩子祝福 — 连续 {days} 天',
  'eveningStreakStart': '今晚从孩子祝福开始吧',
  'streakStartToday': '今天完成晨祷，开始你的连续记录。',
  'emergencyFeatureTitle': '紧急——属灵认罪',
  'emergencyFeatureBody': '在闹钟界面点按“紧急”，输入认罪语句即可解除闹钟。晚间：填写您的原因（外宿、家庭事务等）。',
  'hallelujah': '哈利路亚',
  'done': '完成',
  'amen': '阿们',
  'prayingWithYou': '{name}今天早晨正与您一同祷告。',
  'blessWithPrayer': '以祷告祝福',
  'micPermissionChrome': '请在 Chrome 中允许麦克风访问（地址栏中的锁形图标）。',
  'speechNotAvailable': '此设备不支持语音识别。',
  'welcomeBack': '欢迎回来。',
  'signInToContinue': '登录以继续你的旅程。',
  'password': '密码',
  'signIn': '登录',
  'signInWithApple': '通过 Apple 登录',
  'createAccount': '创建账号',
  'noAccount': '没有账户？立即注册',
  'haveAccount': '已有账户？登录',
  'name': '姓名',
  'confirmPassword': '确认密码',
  'enterEmail': '请输入您的邮箱。',
  'enterPassword': '请输入您的密码。',
  'enterName': '请输入您的姓名。',
  'passwordMinLength': '密码至少需要 6 个字符。',
  'passwordsDoNotMatch': '两次输入的密码不一致。',
  'errorInvalidEmail': '请输入有效的邮箱地址。',
  'errorUserNotFound': '未找到使用此邮箱的账户。',
  'errorWrongPassword': '密码错误。',
  'errorEmailInUse': '该邮箱已被使用。',
  'errorWeakPassword': '密码至少需要 6 个字符。',
  'errorInvalidCredential': '请检查您的邮箱和密码。',
  'errorOperationNotAllowed': '此登录方式不可用。',
  'errorSignInFailed': '登录失败，请重试。',
  'errorLoginRequired': '需要登录。',
  'errorAlreadyInCircle': '您已在一个圈子中。',
  'errorCircleNotFound': '未找到圈子，请核对圈子 ID。',
  'errorPrayerTextRequired': '请输入代祷事项。',
  'errorOpenerOneSentence': '开场祷告必须为一句话。',
  'errorTomorrowPrayerConfirmed': '{name}已确认明天的晨祷。',
  'errorOnePrayerPerDay': '每天只能接受一个祷告。',
  'notificationPrayerHeard': '你的朋友听到了你的祷告。',
  'eveningChildrenBlessing': '为儿女祝福时间',
  'eveningBlessingSubtitle': '读亚伦的祝福即可解除',
  'premiumMonthlyPrice': '\$2.99 / 月',
  'premiumAnnualPrice': '\$29.99 / 年',
  'todaysPrayer': '今日祷告',
  'todaysWord': '今日经文',
  'successMeansOfGraceComplete': '今天的 God Morning 已完成。\n愿你平安前行。',
  'stepAaronBlessing': '亚伦的祝福',
};

const _ja = {
  'appTitle': 'God Morning',
  'save': '保存',
  'cancel': 'キャンセル',
  'retry': '再試行',
  'settings': '設定',
  'language': '言語',
  'selectLanguage': '言語を選択',
  'scripturePlan': 'みことばプラン',
  'selectScripturePlan': 'みことばプランを選択',
  'scripturePlanDaily': '365日の詩篇と祈り',
  'scripturePlanDailySubtitle': '毎朝、詩篇のひと節と短い祈りで一日を始めましょう。',
  'scripturePlanBeloved52': '52の愛唱聖句',
  'scripturePlanBeloved52Subtitle': '毎週1つの愛唱聖句を読んで暗唱しましょう。',
  'missionContent': 'ミッションの内容',
  'selectMissionContent': 'ミッション内容を選択',
  'missionContentScriptureAndPrayer': 'みことば＋祈り',
  'missionContentScriptureAndPrayerSubtitle': '聖書の一節と朝の祈りの両方を読みます。',
  'missionContentScriptureOnly': 'みことばのみ',
  'missionContentScriptureOnlySubtitle': '聖書の一節を読むだけでミッション完了です。',
  'missionContentPrayerOnly': '祈りのみ',
  'missionContentPrayerOnlySubtitle': '聖書箇所なしで、365日のテーマ別の祈りを読みます。',
  'morningPrayerEveningBlessing': '朝の祈りと夜の祝福。',
  'tapTimeToSetAlarm': '時刻をタップしてアラームを設定します。下からベルの音を選んでください。',
  'tapToSetTimeAndSound': 'タップして時刻と音を設定',
  'circleTapToOpen': 'スモールグループ · タップして開く',
  'webPreviewBanner': 'Chromeプレビュー — アラームとサークルのUIを確認できます。全機能はiPhone/Androidでご利用ください。',
  'morningAlarm': '朝のアラーム',
  'eveningBlessing': '夜の祝福',
  'alarmOn': 'アラームはオンです',
  'alarmOff': 'アラームはオフです',
  'previewMorningAlarm': '朝のアラームをプレビュー',
  'previewEveningBlessing': '夕べの祝福をプレビュー',
  'yourCircle': 'あなたのサークル',
  'localWeather': '現在地の天気',
  'localWeatherSubtitle': '現在地を使って、今日と今週の天気を表示します。',
  'localWeatherLoading': '現在地の天気予報を読み込んでいます...',
  'localWeatherSettingsBody': '現在地は、今日と今週の天気の取得のみに使用されます。位置情報がGod Morningに保存されることはありません。',
  'enableLocalWeather': '現在地の天気を表示',
  'weatherRefresh': '天気を更新',
  'weatherThisWeek': '今週',
  'weatherFeelsLike': '体感 {temp}',
  'weatherWind': '風速 {speed} {unit}',
  'weatherRainChance': '降水確率 {chance}%',
  'weatherHighLow': '最高 {high}  最低 {low}',
  'weatherPermissionRequired': '現在地の天気には位置情報の許可が必要です。',
  'weatherLocationServicesOff': '現在地の天気を表示するには、位置情報サービスをオンにしてください。',
  'weatherUnavailable': '現在、天気情報を取得できません。しばらくしてからお試しください。',
  'weatherEnabled': '現在地の天気をオンにしました',
  'weatherDisabled': '現在地の天気をオフにしました',
  'weatherAttribution': '天気データ提供: Open-Meteo.com',
  'weatherTemperatureUnit': '気温の単位',
  'weatherUnitFahrenheit': '華氏（°F）',
  'weatherUnitCelsius': '摂氏（°C）',
  'enableMorningAlarm': '朝のアラームをオンにする',
  'morningAlarmSubtitle': '祈りとみことばで解除',
  'repeatDays': '繰り返す曜日',
  'perDayTimesTitle': '曜日別の時刻',
  'alarmsTitle': 'アラーム',
  'addAlarm': 'アラームを追加',
  'deleteAlarmTitle': '削除',
  'everyDay': '毎日',
  'maxAlarmsReached': 'アラームは最大5件まで設定できます。',
  'cannotDeleteLastAlarm': 'アラームは最低1つ必要です。削除せずオフにしてください。',
  'alarmListHint': 'アラームごとにミッションがあります。タップで編集、長押しで削除できます。',
  'streakCalendarSubtitle': '主にお会いした日が自動で記録されます。',
  'calendarTab': 'カレンダー',
  'homeTab': 'ホーム',
  'weatherTab': '天気',
  'showLocalWeather': '現在地の天気を表示 — タップしてオン',
  'myLocation': '現在地',
  'tenDayForecast': '10日間予報',
  'nowLabel': '現在',
  'todayLabel': '今日',
  'streakTotalDays': 'これまでに合計{days}日、主にお会いしました',
  'perDayTimesSubtitle': '曜日ごとに異なるアラーム時刻を設定',
  'setTimeForDay': '{day}のアラーム時刻',
  'selectAtLeastOneAlarmDay': 'アラームの曜日を1つ以上選択してください。',
  'weekdayShortMonday': '月',
  'weekdayShortTuesday': '火',
  'weekdayShortWednesday': '水',
  'weekdayShortThursday': '木',
  'weekdayShortFriday': '金',
  'weekdayShortSaturday': '土',
  'weekdayShortSunday': '日',
  'setAlarmTime': 'アラーム時刻を設定',
  'morningAlarmOffHint': 'アラームはオフです — 下でオンにして設定してください',
  'eveningBlessingOffHint': '祝福はオフです — 下でオンにして設定してください',
  'enableEveningBlessing': '夜の祝福をオンにする',
  'saveAlarms': 'アラームを保存',
  'testMorningAlarm': '朝のアラームをテスト（5秒）',
  'testEveningAlarm': '夜のアラームをテスト（5秒）',
  'practiceMission': '練習ミッション',
  'practiceMissionSubtitle': '実際のアラームや再試行、連続記録に影響を与えずに、聖書と祈りの流れを試せます。',
  'missionPassThreshold': 'ミッション合格基準',
  'missionPassThresholdSubtitle': 'アーメンが有効になるまでに、みことばと祈りをどの程度一致させるかを選びます。低いほどやさしく、高いほど厳しくなります。',
  'missionPassThresholdLow': 'やさしめ',
  'missionPassThresholdHigh': '厳しめ',
  'alarmsSaved': 'アラームを保存しました',
  'saving': '保存中...',
  'signOut': 'サインアウト',
  'home': 'ホーム',
  'backToMain': 'メインに戻る',
  'premiumTitle': 'God Morning プレミアム',
  'premiumSettingsSubtitle': 'サブスクリプションと購入の管理（任意）。',
  'premiumHeroTitle': '朝はいつも、神さまを第一に。',
  'premiumHeroSubtitle': 'すべてのプラン、サウンド、言語、地域の天気で、聖書アラームのリズムを余すことなく味わえます。',
  'premiumMonthlyTitle': '月額',
  'premiumAnnualTitle': '年額',
  'premiumTrialLabel': '7日間無料トライアル',
  'premiumMonthlyTrialTerms': '7日間の無料トライアル後、毎月自動更新されます。',
  'premiumAnnualTrialTerms': '7日間の無料トライアル後、毎年自動更新されます。',
  'premiumFeatureAlarm': 'アーメンまで繰り返し鳴る祈りのアラーム',
  'premiumFeaturePlans': '365の詩篇と52の愛唱聖句',
  'premiumFeatureLanguages': '英語・韓国語・ドイツ語・ロシア語・スペイン語・ポルトガル語・中国語・日本語',
  'premiumFeatureWeather': '完了後に地域の天気を表示（オプション）',
  'premiumStartTrial': '7日間の無料トライアルを開始',
  'premiumRestore': '購入を復元',
  'premiumManageSubscription': 'サブスクリプションの管理・解約',
  'premiumLoadingProducts': 'サブスクリプションのオプションを読み込み中...',
  'premiumProductsUnavailable': 'サブスクリプションのオプションはまだ利用できません。このアプリのApp StoreまたはGoogle Playのサブスクリプション商品が設定されているかご確認ください。',
  'premiumPurchaseSuccess': 'プレミアムが有効になりました。',
  'premiumPurchasePending': '購入はストアの承認待ちです。完了するとプレミアムが有効になります。',
  'premiumPurchaseCancelled': '購入がキャンセルされました。',
  'premiumPurchaseFailed': '購入を完了できませんでした。もう一度お試しください。',
  'premiumRestoreMissing': '復元できる有効なサブスクリプションが見つかりませんでした。',
  'premiumTerms': 'お支払いはAppleのアプリ内課金またはGoogle Playの決済を通じて請求されます。7日間の無料トライアルとサブスクリプションの更新はストアが管理します。サブスクリプション設定からいつでも解約できます。更新を避けるには、次回請求日の24時間以上前に解約してください。',
  'premiumCancelAnytime': '7日間のトライアル付き。サブスクリプション設定からいつでも解約できます。更新を避けるには、次回請求日の24時間以上前に解約してください。',
  'premiumPurchaseUnavailable': '現在、購入をご利用いただけません。しばらくしてからもう一度お試しください。',
  'premiumOpenSubscriptionFailed': 'サブスクリプション管理を開けませんでした。',
  'termsOfUse': '利用規約',
  'privacyPolicy': 'プライバシーポリシー',
  'openLinkFailed': 'リンクを開けませんでした。',
  'alarmSound': 'アラーム音',
  'alarmSoundDescription': '朝のアラームに使う God Morning 内蔵のアラーム音を選べます。',
  'alarmSoundDescriptionIos': 'サウンドをタップすると一度試聴できます。別のサウンドをタップするとスムーズに切り替わります。',
  'soundClassicAlarm': '明るいビープ音（推奨）',
  'soundGentleChime': '朝のチャイム',
  'soundChurchBell': '教会の鐘',
  'moreIphoneSounds': 'その他の端末サウンド…',
  'currentAlarmSound': '現在：{name}',
  'savedAlarmSoundBadge': '保存済み',
  'systemAlarmSound': 'システムアラーム（デフォルト）',
  'systemNotificationSound': 'システム通知音',
  'systemRingtoneSound': 'システム着信音',
  'chooseFromPhoneSounds': '端末のサウンドから選ぶ',
  'previewSound': 'サウンドをプレビュー',
  'soundSaved': 'アラーム音を保存しました',
  'noRingtonesFound': 'この端末にサウンドが見つかりません。',
  'notificationsPermissionTitle': '通知を許可',
  'notificationsPermissionBody': '朝のアラームを鳴らし、祈りを聞き取るために、God Morningはいくつかの権限を必要とします。',
  'allowNotifications': '許可して続ける',
  'onboardingNext': '続ける',
  'onboardingEnableAndStart': '有効にして開始',
  'onboardingProductTitle': '朝の最初の1分を、神さまに。',
  'onboardingProductBody': 'God Morningは、一つの聖句と短い祈り、そしてシンプルなアーメンとともに目覚めるお手伝いをします。',
  'onboardingProductPointOneVerse': 'あなたの朝のために用意された、1日1つの聖句',
  'onboardingProductPointFirstMinute': 'みことばと祈りで整える、静かな最初の1分',
  'onboardingReadTitle': '声に出して読む。心を向けて始める。',
  'onboardingReadBody': 'アラームの時刻になると、God Morningが聖書と祈りのミッションを開きます。音声または入力で完了できます。',
  'onboardingReadPointVoiceType': '音声モードまたは入力モードで本文をたどれます',
  'onboardingReadPointAmen': 'アーメンがアラームを完了する最後のステップです',
  'onboardingAlarmTitle': '目的のある朝のアラーム。',
  'onboardingAlarmBody': '時刻とサウンドを設定して、スヌーズの代わりにアラームがミッションへと導くようにしましょう。',
  'onboardingAlarmPointClosed': 'アプリを閉じていても鳴るように設計',
  'onboardingAlarmPointReturn': 'アーメンの前に離れると、アラームが再び鳴ることがあります',
  'onboardingPermissionsTitle': 'God Morningに必要な設定を有効にしましょう。',
  'onboardingPermissionsBody': 'アラーム、通知、マイク、音声認識に必要な権限の許可をお願いします。',
  'commandCopied': 'コマンドをコピーしました',
  'walkTogether': 'ともに歩む',
  'circleInviteDescription': '朝の祈りと日曜礼拝で友だちを励まし合いましょう。\\nメンバーは何人でも招待できます。',
  'createCircle': 'サークルを作成',
  'joinCircle': 'サークルに参加',
  'circleNameHint': 'サークル名（例：恵みセル）',
  'circleIdHint': '友だちから受け取ったサークルID',
  'membersCount': 'メンバー{count}人',
  'thisWeekMorning': '今週 · 月〜日の朝の祈り',
  'demoCircleBanner': 'デモサークル — すべての機能は iPhone/Android アプリで',
  'localCircleBanner': 'サークルはこのスマートフォンに保存されています。＋で友達を追加し、サークルIDを共有して参加してもらいましょう。',
  'enterCircleName': 'サークル名を入力してください。',
  'circleCreated': 'サークルを作成しました。サークルIDを共有するか、メール・電話番号で招待しましょう。',
  'enterCircleId': 'サークルIDを入力してください。',
  'joinedCircle': 'サークルに参加しました！',
  'sentEncouragement': '{name}さんに励ましを送りました',
  'likeSaveFailed': 'いいねを保存できませんでした。',
  'morningDoneToday': '今日の朝の祈りは完了',
  'morningNotYetToday': '今日の朝の祈りはまだです',
  'sendPrayerForTomorrow': '祈りの課題を送る',
  'prayerAcceptHint': '相手が今週の月〜日から、あなたのために祈る日を選びます',
  'unlike': 'いいねを取り消す',
  'sendLike': 'いいねを送る',
  'doneToday': '今日は完了',
  'notYetToday': '今日はまだ',
  'morningMonSun': '朝 · 月〜日',
  'eveningMonSun': '夜 · 月〜日',
  'notYet': 'まだ',
  'liked': 'いいね済み',
  'like': 'いいね',
  'prayer': '祈り',
  'inviteFriend': '友達を招待',
  'addMember': 'メンバーを追加',
  'friendName': '友達の名前',
  'memberAddedToCircle': '{name}さんがサークルに追加されました。',
  'inviteByEmailOrPhone': 'メールまたは電話番号で招待',
  'email': 'メールアドレス',
  'phoneNumber': '電話番号',
  'sendInvite': '招待を送る',
  'inviteSent': '{contact}に招待を送信しました。相手が登録するか、アプリを開くと参加します。',
  'inviteShareCircleId': 'このサークルIDを友達に共有してください：{circleId}',
  'inviteSentExistingUser': '招待を送信しました！相手にサークル参加の通知が届きます。',
  'inviteFailed': '招待を送信できませんでした。',
  'enterEmailOrPhone': 'メールアドレスまたは電話番号を入力してください。',
  'invalidEmail': '有効なメールアドレスを入力してください。',
  'invalidPhone': '有効な電話番号を入力してください。',
  'alreadyInCircle': 'この方はすでにサークルのメンバーです。',
  'prayerConfirmedTomorrow': '明日の朝の祈りが確定しました。これ以上のリクエストは受け付けられません。',
  'prayerRequestsForYou': 'あなたへの祈りのリクエスト',
  'circleLikePrayerHint': 'サークルのメンバーに❤️で励ましを送ったり、祈りの課題を分かち合ったりできます。メンバーは日を選んで、朝のアラームであなたと一緒に祈ります。',
  'circleActivity': 'アクティビティ',
  'sentPrayerRequests': 'あなたが送った祈り',
  'likedYouThisWeek': '今週、{name}さんから❤️が届きました',
  'markAllRead': 'すべて既読にする',
  'friendPrayedForYou': 'あなたのために祈りました',
  'sendPrayerTopic': '祈りのテーマを送る',
  'onePrayerPerDayWeek': '個人の祈りは1日1件 · 今週の月〜日から選択',
  'schedulePrayer': '予定する',
  'pickDayThisWeek': '今週の日を選ぶ',
  'dayBooked': '予約済み',
  'circlePrayer': 'サークルの祈り',
  'createCirclePrayer': 'サークルの祈りを作成',
  'circlePrayersThisWeek': '今週のサークルの祈り',
  'circlePrayerTogether': '大切な日にはみんなで一緒に祈ります',
  'weekPrayersCircle': '今週の祈り · サークル',
  'importantDayLabel': '大切な日（月〜日）',
  'prayerTopic': '祈りの課題（例：手術、危機）',
  'pickADay': '一緒に祈る日を選ぶ',
  'scheduled': '予定済み',
  'circlePrayerCreated': 'サークルの祈りを作成しました。みんなで一緒に祈ります。',
  'scheduleFailed': '祈りを予定できませんでした。',
  'prayerScheduledFor': '{name}さんの祈りを{day}に予定しました',
  'circlePrayerOn': 'サークルの祈り · {day}',
  'onePrayerAcceptOnly': '個人の祈りは1日1件 · 月〜日から選択',
  'fromLabel': '{name}さんから',
  'forYouTomorrow': 'あなたへ · 明日の朝',
  'decline': '拒否',
  'prayTomorrow': '明日祈る',
  'tomorrowsPrayersCircle': '明日の祈り · サークル',
  'circlePrayerFeedSubtitle': '今週予定されている個人の祈り',
  'pending': '保留中',
  'accepted': '承認済み',
  'declined': '拒否しました',
  'sendPrayerRequest': '祈りの課題を送る',
  'toLabel': '宛先: {name}',
  'prayerRecipientChoose': '{name}さんが明日の朝この祈りをささげるかどうかを選びます。',
  'optionalOpener': '1. 書き出しの一文（任意）',
  'requiredPrayer': '2. 祈りの課題 1〜2文（必須）',
  'send': '送信',
  'friendPrayerConfirmed': '{name}さんの祈りを予約しました。他の課題には別の日を選んでください。',
  'prayerRequestSent': '{name}さんに祈りのリクエストを送信しました。相手が今週の中から日を選びます。',
  'prayerAcceptedOneOnly': '選んだ日に{name}さんの祈りを予定しました。',
  'acceptFailed': 'リクエストを承認できませんでした。',
  'prayerDeclined': '{name}さんの祈りのリクエストをお断りしました。',
  'declineFailed': 'リクエストを拒否できませんでした。',
  'prayerDemoSent': '祈りのリクエストを送信しました（デモ）— {name}さんが承諾すると表示されます。',
  'prayerFrom': '{name}さんからの祈り',
  'prayerArrow': '{from} → {to}',
  'timeToMeetLord': '主にお会いする時間です。',
  'stopWithPrayerAndWord': '祈りとみことばで止める',
  'listening': '聞き取り中...',
  'completeWebDemo': '完了（Webデモ）',
  'nextStepWebDemo': '次のステップ（Webデモ）',
  'continueToNextStep': '次のステップへ',
  'completePrayerFlow': 'アーメン',
  'alarmHowItWorksTitle': '明日もアラームは鳴りますか？',
  'alarmHowItWorksBody': 'はい。God Morning は、アラームをオフにするまで朝のアラームを予約し続けます。',
  'alarmDetailedHowItWorksTitle': '仕組み',
  'alarmDetailedHowItWorksBody': '1. 朝のアラームをオンにして「保存」をタップします。\\n2. 端末から求められたら、アラームと通知を許可します。\\n3. 設定した時刻になると、アプリを閉じていてもアラームが鳴ります。\\n4. アラームを止めると祈りの画面が開きます。アーメンまでアラームは繰り返し鳴ります。\\n5. 音声を聞き取っている間はアラーム音が止まり、あなたの声が届くようになります。',
  'bibleLicenseTitle': '聖書本文',
  'bibleLicenseBody': '聖書本文の出典:\n'
      '韓国語: Korean Revised Version 1952/1961 (KRV / 개역한글)。出典: KorRV / Zefania XML。権利: Public Domain。\n'
      '英語: World English Bible (WEB)。出典: eBible.org。権利: Public Domain。\n'
      'ドイツ語: Lutherbibel 1912。出典: eBible.org。権利: Public Domain。\n'
      'ロシア語: Russian Synodal Translation (1876 / Синодальный перевод)。出典: eBible.org。権利: Public Domain。\n'
      'スペイン語: Reina-Valera 1909 (RV1909)。出典: eBible.org。権利: Public Domain。\n'
      'ポルトガル語: Bíblia Livre (BLJ)。出典: eBible.org。権利: Public Domain。\n'
      '中国語: 和合本 1919（簡体字、Chinese Union Version）。出典: getBible / CrossWire。権利: Public Domain。\n'
      '日本語: 口語訳 1954/1955（Kougo-yaku）。出典: getBible / CrossWire。権利: Public Domain。',
  'permissionNotificationTitle': '通知',
  'permissionNotificationBody': 'アラームでお知らせするために必要です。',
  'permissionMicrophoneTitle': 'マイク',
  'permissionMicrophoneBody': '聖書と祈りの朗読を聞き取るために必要です。',
  'permissionAlarmKitTitle': 'アラームの許可',
  'permissionAlarmKitBody': '朝のアラームを確実に鳴らすために必要です。',
  'permissionMissionTitle': 'アーメンでアラームが完了',
  'permissionMissionBody': '聖書と祈りのミッションが完了するまで、アラームは繰り返し鳴ります。',
  'permissionSettingsTitle': '許可設定',
  'permissionSettingsBody': 'アラームと朗読ミッションのためにGod Morningが必要とする許可を有効にしてください。',
  'permissionEnable': '有効にする',
  'permissionEnabled': '有効',
  'notificationsDisabledWarning': '通知がオフです。端末の設定で有効にするまでアラームは鳴りません。',
  'openIphoneSettings': '端末の設定を開く',
  'enableNotificationsToRing': '先に通知をオンにしてください。オフのままではアラームが鳴りません。',
  'tomorrow': '明日',
  'alarmScheduledNext': 'アラームを保存しました。次回：{time}',
  'stepMorningPrayer': '朝の祈り',
  'stepCirclePrayer': 'サークルの祈り',
  'stepFriendPrayer': '友のための祈り',
  'stepScripture': 'みことば',
  'stepOfTotal': 'ステップ {n}/{total} · {step}',
  'circlePrayingTogetherToday': '今日はサークル全員が一緒に祈っています。',
  'successMorningCircleFriendScripture': '朝の祈り、サークルの祈り、友のための祈り、みことば — 完了です。\\n平安のうちに歩みましょう。',
  'successMorningCircleScripture': '朝の祈り、サークルの祈り、みことば — 完了です。\\n平安のうちに歩みましょう。',
  'cancelAlarmResumes': 'キャンセル（アラームは再開します）',
  'morningAlarmMustComplete': 'アラームを止めるには、今日の朝の祈りを完了してください。',
  'eveningAlarmMustComplete': 'アラームを止めるには、今日の夜の祝福を完了してください。',
  'blessBeforeRest': '寝る前に祈りで子どもたちを祝福しましょう',
  'stepEveningGuide': '祝福のガイド',
  'goodnightTitle': 'おやすみなさい。',
  'successEveningRest': '主があなたを祝福し、あなたを守られますように。\\n安らかにお休みください。',
  'readAloudToContinue': '80%以上を朗読または入力するとボタンが有効になります。読み終えたらタップしてください。',
  'inputModeVoice': '録音',
  'inputModeKeyboard': '入力',
  'typePrayerHint': '読んだことばを入力…',
  'typingProgress': '入力中',
  'recordingInProgress': '録音中…',
  'liveTranscriptLabel': '聞き取った内容',
  'liveTranscriptHint': '声に出して祈ってください。言葉がここに表示され、祈りながら確認できます。',
  'typedEchoLabel': '入力した内容',
  'morningPrayerVoiceTypeHint': '開始後は「録音」（音声）または「入力」で、祈りの各ステップを読み進めます。',
  'typeToContinue': '続けるには、読んだことばを入力してください。',
  'switchedToTypeMode': '音声が利用できないため、入力モードに切り替えました。祈りはそのまま完了できます。',
  'emergencyTitle': '緊急 — 主への告白',
  'emergencyMorningHint': '今日の朝のアラームをオフにするには、下の言葉をそのまま入力してください。',
  'emergencyEveningHint': '理由（お泊まり、家族の予定、旅行など）を入力すると、今夜の祝福をお休みできます。',
  'emergencyMorningPhrase': '今日は本当にできません。主よ、お赦しください。',
  'emergencyEveningPrefix': '今日は',
  'emergencyEveningSuffix': 'のため、子どもたちへの祝福の祈りができませんでした。主よ、お赦しください。',
  'emergencyTypePhraseHint': '告白の言葉を入力…',
  'emergencyEveningReasonHint': '例：お泊まり、家族旅行など',
  'emergencyConfirm': '告白を送信してアラームを解除',
  'emergencyNotAvailable': '今週の緊急解除は、現在の強度レベルではもう残っていません。',
  'emergencyButton': '緊急 — 今日は恵みが必要です',
  'emergencySuccessMessage': '主はあなたの告白を聞いてくださいます。今日のアラームはオフになりました。また明日お会いしましょう。',
  'emergencyGraceRemaining': '最初の1週間は恵みの期間です。緊急解除はあと{days}日利用できます。',
  'emergencyRemainingThisWeek': '今週残りの緊急解除：{count}回',
  'prayerIntensity': '祈りの強度',
  'prayerIntensityGentle': 'やさしい',
  'prayerIntensityNormal': 'ふつう',
  'prayerIntensityStrict': 'きびしい',
  'prayerIntensityHint': 'やさしい65% · ふつう80% · きびしい90%。緊急用：7日目を過ぎると週3 / 1 / 0回。',
  'streakTitle': '朝の連続記録',
  'streakDays': '{days}日連続',
  'eveningStreakDays': '子どもの祝福 — {days}日連続',
  'eveningStreakStart': '今夜、子どもの祝福から始めましょう',
  'streakStartToday': '今日の朝の祈りを完了して、連続記録を始めましょう。',
  'emergencyFeatureTitle': '緊急 — 主への告白',
  'emergencyFeatureBody': 'アラーム画面で「緊急」をタップし、告白の言葉を入力すると解除できます。夜は理由（お泊まり、家族の予定など）を入力します。',
  'hallelujah': 'ハレルヤ',
  'done': '完了',
  'amen': 'アーメン',
  'prayingWithYou': '今朝、{name}さんがあなたと一緒に祈っています。',
  'blessWithPrayer': '祈りで祝福する',
  'micPermissionChrome': 'Chromeでマイクへのアクセスを許可してください（アドレスバーの鍵アイコン）。',
  'speechNotAvailable': 'この端末では音声認識を利用できません。',
  'welcomeBack': 'おかえりなさい。',
  'signInToContinue': 'サインインして歩みを続けましょう。',
  'password': 'パスワード',
  'signIn': 'サインイン',
  'signInWithApple': 'Appleでサインイン',
  'createAccount': 'アカウントを作成',
  'noAccount': 'アカウントをお持ちでない方は作成',
  'haveAccount': 'アカウントをお持ちの方はサインイン',
  'name': '名前',
  'confirmPassword': 'パスワード（確認）',
  'enterEmail': 'メールアドレスを入力してください。',
  'enterPassword': 'パスワードを入力してください。',
  'enterName': 'お名前を入力してください。',
  'passwordMinLength': 'パスワードは6文字以上で入力してください。',
  'passwordsDoNotMatch': 'パスワードが一致しません。',
  'errorInvalidEmail': '有効なメールアドレスを入力してください。',
  'errorUserNotFound': 'このメールアドレスのアカウントが見つかりません。',
  'errorWrongPassword': 'パスワードが正しくありません。',
  'errorEmailInUse': 'このメールアドレスはすでに使用されています。',
  'errorWeakPassword': 'パスワードは6文字以上で入力してください。',
  'errorInvalidCredential': 'メールアドレスとパスワードをご確認ください。',
  'errorOperationNotAllowed': 'このログイン方法は利用できません。',
  'errorSignInFailed': 'サインインに失敗しました。もう一度お試しください。',
  'errorLoginRequired': 'ログインが必要です。',
  'errorAlreadyInCircle': 'すでにサークルに参加しています。',
  'errorCircleNotFound': 'サークルが見つかりません。サークルIDをご確認ください。',
  'errorPrayerTextRequired': '祈りの課題を入力してください。',
  'errorOpenerOneSentence': '始めの祈りは1文で入力してください。',
  'errorTomorrowPrayerConfirmed': '{name}さんは明日の朝の祈りをすでに確定しています。',
  'errorOnePrayerPerDay': '祈りは1日1件まで受け付けられます。',
  'notificationPrayerHeard': '友達があなたの祈りを聞きました。',
  'eveningChildrenBlessing': '子どもを祝福する時間',
  'eveningBlessingSubtitle': 'アロンの祝福を読むと解除されます',
  'premiumMonthlyPrice': '\$2.99 / 月',
  'premiumAnnualPrice': '\$29.99 / 年',
  'todaysPrayer': '今日の祈り',
  'todaysWord': '今日のみことば',
  'successMeansOfGraceComplete': '今日のGod Morningが完了しました。\n安らかに歩んでください。',
  'stepAaronBlessing': 'アロンの祝福',
};

const _hi = {
  'appTitle': 'अनुग्रह के साधन',
  'yourCircle': 'आपका सर्कल',
  'settings': 'सेटिंग्स',
  'language': 'भाषा',
  'inviteFriend': 'मित्र को आमंत्रित करें',
  'signIn': 'साइन इन',
  'save': 'सहेजें',
  'cancel': 'रद्द करें',
};

const _ar = {
  'appTitle': 'وسائل النعمة',
  'yourCircle': 'دائرتك',
  'settings': 'الإعدادات',
  'language': 'اللغة',
  'inviteFriend': 'دعوة صديق',
  'signIn': 'تسجيل الدخول',
  'save': 'حفظ',
  'cancel': 'إلغاء',
};
