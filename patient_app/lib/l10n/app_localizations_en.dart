// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Saathi';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get demoName => 'Mr. Bora';

  @override
  String get demoLabel => 'Demo profile · Launcher preview';

  @override
  String get talk => 'Talk to Saathi';

  @override
  String get watch => 'Watch';

  @override
  String get family => 'Family';

  @override
  String get photos => 'Photos';

  @override
  String get medicine => 'Medicine';

  @override
  String get myDay => 'My Day';

  @override
  String get phone => 'Open phone';

  @override
  String get phoneApps => 'Phone apps';

  @override
  String get noApps => 'No phone apps are available.';

  @override
  String get homeEnabled => 'Saathi is your home screen.';

  @override
  String get homeNotEnabled => 'Saathi is not your default home screen yet.';

  @override
  String get chooseHome => 'Choose home screen';

  @override
  String get comingSoon =>
      'This activity is not available in this first launcher preview.';

  @override
  String get backHome => 'Back to home';

  @override
  String get actionFailed => 'Could not open this. Please try again.';

  @override
  String get passport => 'Memory Passport';

  @override
  String get caregiverEdit => 'Edit with caregiver';

  @override
  String get finishEditing => 'Done editing';

  @override
  String get profile => 'About me';

  @override
  String get places => 'Important places';

  @override
  String get memories => 'Memories';

  @override
  String get routines => 'Daily routines';

  @override
  String get medicines => 'Medicines';

  @override
  String get activities => 'Favourite activities';

  @override
  String get addEntry => 'Add';

  @override
  String get editEntry => 'Edit';

  @override
  String get save => 'Save on this phone';

  @override
  String get cancel => 'Cancel';

  @override
  String get removeEntry => 'Remove';

  @override
  String get removeQuestion => 'Remove this entry from the passport?';

  @override
  String get emptySection => 'Nothing added yet.';

  @override
  String get localOnly => 'Saved on this phone. Works offline.';

  @override
  String get medicineNotice =>
      'These are reference notes only. Reminders are not active.';

  @override
  String get nameLabel => 'Name';

  @override
  String get ageLabel => 'Age';

  @override
  String get regionLabel => 'Region';

  @override
  String get relationshipLabel => 'Relationship';

  @override
  String get visitsLabel => 'Visits';

  @override
  String get sharedActivityLabel => 'Shared activity';

  @override
  String get notesLabel => 'Details';

  @override
  String get timeLabel => 'Time (24-hour HH:MM)';

  @override
  String get doseLabel => 'Caregiver’s medicine instructions';

  @override
  String get requiredField => 'Please enter this.';

  @override
  String get invalidAge => 'Enter an age from 1 to 120.';

  @override
  String get invalidTime => 'Enter a time such as 08:00 or 20:00.';

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get noPhoto => 'No photo added';

  @override
  String get saveFailed =>
      'Could not save. Your changes are still here. Please try again.';

  @override
  String get loadFailed =>
      'Could not open the saved passport. Your existing data has been kept.';

  @override
  String get retry => 'Try again';

  @override
  String get demoProfile => 'Use demo profile label';

  @override
  String get demoPassport => 'Demo profile';

  @override
  String get savedPassport => 'Personal profile';

  @override
  String get recoveredPhoto =>
      'Your selected photo was recovered. Add its details to save it.';

  @override
  String get discardQuestion => 'Leave without saving your changes?';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Leave without saving';

  @override
  String get photoFailed => 'Could not open the photo. Please choose it again.';

  @override
  String get saving => 'Saving…';

  @override
  String get saved => 'Saved on this phone.';

  @override
  String get whoIsThis => 'Who is this?';

  @override
  String get typeYourAnswer => 'Type your answer';

  @override
  String get confirmAnswer => 'That is my answer';

  @override
  String get skipAnswer => 'I am not sure';

  @override
  String get hintLabel => 'Hint';

  @override
  String get hint1Template => 'This person is from your family.';

  @override
  String hint2Template(String relationship) {
    return 'This person is your $relationship.';
  }

  @override
  String hint3Template(String letter) {
    return 'Their name starts with $letter.';
  }

  @override
  String showHint(int number) {
    return 'Show hint $number';
  }

  @override
  String get correctAnswer => 'Correct!';

  @override
  String get incorrectAnswer => 'Not quite.';

  @override
  String get tryAnother => 'Try another';

  @override
  String get noFamilyPhotos => 'No family photos yet.';

  @override
  String get noFamilyPhotosDetail =>
      'A caregiver can add photos to family members in the Memory Passport.';

  @override
  String get addPhotoInPassport => 'Open Memory Passport';

  @override
  String get watchTitle => 'Watch';

  @override
  String get chooseVideo => 'Choose a video to watch';

  @override
  String get finishedWatching => 'Finished watching';

  @override
  String get delayedRecallPrompt => 'Earlier you watched a video.';

  @override
  String get delayedRecallQuestion => 'Do you remember what it was about?';

  @override
  String immediateRecallPrompt(String title) {
    return 'You just watched: $title';
  }

  @override
  String get dontRemember => 'I don\'t remember';

  @override
  String get watchAnother => 'Watch another';

  @override
  String get videoHint1 => 'You watched a video about a daily activity.';

  @override
  String videoHint2(String letter) {
    return 'The topic starts with the letter $letter.';
  }

  @override
  String get talkSubtitle => 'Your personal memory companion';

  @override
  String talkWelcome(String name) {
    return 'Hello $name. I am Saathi. How can I help you today?';
  }

  @override
  String get talkPlaceholder => 'Ask Saathi anything…';

  @override
  String get quickPromptFamily => 'Tell me about my family';

  @override
  String get quickPromptDay => 'What is my routine today?';

  @override
  String get quickPromptGardening => 'Let\'s talk about gardening';

  @override
  String get quickPromptMusic => 'How is the weather today?';

  @override
  String get send => 'Send';

  @override
  String get saathiThinking => 'Saathi is thinking…';
}
