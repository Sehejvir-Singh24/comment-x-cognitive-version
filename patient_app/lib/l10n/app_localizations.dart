import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Saathi'**
  String get appTitle;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @demoName.
  ///
  /// In en, this message translates to:
  /// **'Mr. Bora'**
  String get demoName;

  /// No description provided for @demoLabel.
  ///
  /// In en, this message translates to:
  /// **'Demo profile · Launcher preview'**
  String get demoLabel;

  /// No description provided for @talk.
  ///
  /// In en, this message translates to:
  /// **'Talk to Saathi'**
  String get talk;

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// No description provided for @family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get family;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @medicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get medicine;

  /// No description provided for @myDay.
  ///
  /// In en, this message translates to:
  /// **'My Day'**
  String get myDay;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Open phone'**
  String get phone;

  /// No description provided for @phoneApps.
  ///
  /// In en, this message translates to:
  /// **'Phone apps'**
  String get phoneApps;

  /// No description provided for @noApps.
  ///
  /// In en, this message translates to:
  /// **'No phone apps are available.'**
  String get noApps;

  /// No description provided for @homeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Saathi is your home screen.'**
  String get homeEnabled;

  /// No description provided for @homeNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Saathi is not your default home screen yet.'**
  String get homeNotEnabled;

  /// No description provided for @chooseHome.
  ///
  /// In en, this message translates to:
  /// **'Choose home screen'**
  String get chooseHome;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'This activity is not available in this first launcher preview.'**
  String get comingSoon;

  /// No description provided for @backHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backHome;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this. Please try again.'**
  String get actionFailed;

  /// No description provided for @passport.
  ///
  /// In en, this message translates to:
  /// **'Memory Passport'**
  String get passport;

  /// No description provided for @caregiverEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit with caregiver'**
  String get caregiverEdit;

  /// No description provided for @finishEditing.
  ///
  /// In en, this message translates to:
  /// **'Done editing'**
  String get finishEditing;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get profile;

  /// No description provided for @places.
  ///
  /// In en, this message translates to:
  /// **'Important places'**
  String get places;

  /// No description provided for @memories.
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get memories;

  /// No description provided for @routines.
  ///
  /// In en, this message translates to:
  /// **'Daily routines'**
  String get routines;

  /// No description provided for @medicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicines;

  /// No description provided for @activities.
  ///
  /// In en, this message translates to:
  /// **'Favourite activities'**
  String get activities;

  /// No description provided for @addEntry.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addEntry;

  /// No description provided for @editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editEntry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save on this phone'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @removeEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeEntry;

  /// No description provided for @removeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove this entry from the passport?'**
  String get removeQuestion;

  /// No description provided for @emptySection.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet.'**
  String get emptySection;

  /// No description provided for @localOnly.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. Works offline.'**
  String get localOnly;

  /// No description provided for @medicineNotice.
  ///
  /// In en, this message translates to:
  /// **'These are reference notes only. Reminders are not active.'**
  String get medicineNotice;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @regionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get regionLabel;

  /// No description provided for @relationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationshipLabel;

  /// No description provided for @visitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsLabel;

  /// No description provided for @sharedActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared activity'**
  String get sharedActivityLabel;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get notesLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time (24-hour HH:MM)'**
  String get timeLabel;

  /// No description provided for @doseLabel.
  ///
  /// In en, this message translates to:
  /// **'Caregiver’s medicine instructions'**
  String get doseLabel;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Please enter this.'**
  String get requiredField;

  /// No description provided for @invalidAge.
  ///
  /// In en, this message translates to:
  /// **'Enter an age from 1 to 120.'**
  String get invalidAge;

  /// No description provided for @invalidTime.
  ///
  /// In en, this message translates to:
  /// **'Enter a time such as 08:00 or 20:00.'**
  String get invalidTime;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @noPhoto.
  ///
  /// In en, this message translates to:
  /// **'No photo added'**
  String get noPhoto;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Your changes are still here. Please try again.'**
  String get saveFailed;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the saved passport. Your existing data has been kept.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @demoProfile.
  ///
  /// In en, this message translates to:
  /// **'Use demo profile label'**
  String get demoProfile;

  /// No description provided for @demoPassport.
  ///
  /// In en, this message translates to:
  /// **'Demo profile'**
  String get demoPassport;

  /// No description provided for @savedPassport.
  ///
  /// In en, this message translates to:
  /// **'Personal profile'**
  String get savedPassport;

  /// No description provided for @recoveredPhoto.
  ///
  /// In en, this message translates to:
  /// **'Your selected photo was recovered. Add its details to save it.'**
  String get recoveredPhoto;

  /// No description provided for @discardQuestion.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving your changes?'**
  String get discardQuestion;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get discard;

  /// No description provided for @photoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the photo. Please choose it again.'**
  String get photoFailed;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone.'**
  String get saved;

  /// No description provided for @whoIsThis.
  ///
  /// In en, this message translates to:
  /// **'Who is this?'**
  String get whoIsThis;

  /// No description provided for @typeYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get typeYourAnswer;

  /// No description provided for @confirmAnswer.
  ///
  /// In en, this message translates to:
  /// **'That is my answer'**
  String get confirmAnswer;

  /// No description provided for @skipAnswer.
  ///
  /// In en, this message translates to:
  /// **'I am not sure'**
  String get skipAnswer;

  /// No description provided for @hintLabel.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hintLabel;

  /// No description provided for @hint1Template.
  ///
  /// In en, this message translates to:
  /// **'This person is from your family.'**
  String get hint1Template;

  /// No description provided for @hint2Template.
  ///
  /// In en, this message translates to:
  /// **'This person is your {relationship}.'**
  String hint2Template(String relationship);

  /// No description provided for @hint3Template.
  ///
  /// In en, this message translates to:
  /// **'Their name starts with {letter}.'**
  String hint3Template(String letter);

  /// No description provided for @showHint.
  ///
  /// In en, this message translates to:
  /// **'Show hint {number}'**
  String showHint(int number);

  /// No description provided for @correctAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correctAnswer;

  /// No description provided for @incorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Not quite.'**
  String get incorrectAnswer;

  /// No description provided for @tryAnother.
  ///
  /// In en, this message translates to:
  /// **'Try another'**
  String get tryAnother;

  /// No description provided for @noFamilyPhotos.
  ///
  /// In en, this message translates to:
  /// **'No family photos yet.'**
  String get noFamilyPhotos;

  /// No description provided for @noFamilyPhotosDetail.
  ///
  /// In en, this message translates to:
  /// **'A caregiver can add photos to family members in the Memory Passport.'**
  String get noFamilyPhotosDetail;

  /// No description provided for @addPhotoInPassport.
  ///
  /// In en, this message translates to:
  /// **'Open Memory Passport'**
  String get addPhotoInPassport;

  /// No description provided for @watchTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watchTitle;

  /// No description provided for @chooseVideo.
  ///
  /// In en, this message translates to:
  /// **'Choose a video to watch'**
  String get chooseVideo;

  /// No description provided for @finishedWatching.
  ///
  /// In en, this message translates to:
  /// **'Finished watching'**
  String get finishedWatching;

  /// No description provided for @delayedRecallPrompt.
  ///
  /// In en, this message translates to:
  /// **'Earlier you watched a video.'**
  String get delayedRecallPrompt;

  /// No description provided for @delayedRecallQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you remember what it was about?'**
  String get delayedRecallQuestion;

  /// No description provided for @immediateRecallPrompt.
  ///
  /// In en, this message translates to:
  /// **'You just watched: {title}'**
  String immediateRecallPrompt(String title);

  /// No description provided for @dontRemember.
  ///
  /// In en, this message translates to:
  /// **'I don\'t remember'**
  String get dontRemember;

  /// No description provided for @watchAnother.
  ///
  /// In en, this message translates to:
  /// **'Watch another'**
  String get watchAnother;

  /// No description provided for @videoHint1.
  ///
  /// In en, this message translates to:
  /// **'You watched a video about a daily activity.'**
  String get videoHint1;

  /// No description provided for @videoHint2.
  ///
  /// In en, this message translates to:
  /// **'The topic starts with the letter {letter}.'**
  String videoHint2(String letter);

  /// No description provided for @talkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal memory companion'**
  String get talkSubtitle;

  /// No description provided for @talkWelcome.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}. I am Saathi. How can I help you today?'**
  String talkWelcome(String name);

  /// No description provided for @talkPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask Saathi anything…'**
  String get talkPlaceholder;

  /// No description provided for @quickPromptFamily.
  ///
  /// In en, this message translates to:
  /// **'Tell me about my family'**
  String get quickPromptFamily;

  /// No description provided for @quickPromptDay.
  ///
  /// In en, this message translates to:
  /// **'What is my routine today?'**
  String get quickPromptDay;

  /// No description provided for @quickPromptGardening.
  ///
  /// In en, this message translates to:
  /// **'Let\'s talk about gardening'**
  String get quickPromptGardening;

  /// No description provided for @quickPromptMusic.
  ///
  /// In en, this message translates to:
  /// **'How is the weather today?'**
  String get quickPromptMusic;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @saathiThinking.
  ///
  /// In en, this message translates to:
  /// **'Saathi is thinking…'**
  String get saathiThinking;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
