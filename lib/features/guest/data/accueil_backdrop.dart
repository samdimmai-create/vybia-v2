import '../model/moment.dart';
import 'assets.dart';

/// A time-/mood-fitting Accueil backdrop (S19E): a real image plus a gentle
/// invitation line, chosen for the current moment.
class AccueilBackdrop {
  const AccueilBackdrop({required this.image, required this.invite});

  /// A real, bundled image that fits the time of day / season / usual mood.
  final String image;

  /// A calm, time-aware invitation to let oneself be guided to an activity.
  final String invite;
}

/// Choose the Accueil backdrop for [moment].
///
/// If we know the guest's USUAL MOOD at this time (from the persisted history,
/// S19B), the image leads with that feeling; otherwise it falls back to the
/// time-of-day (and a light winter tweak). Pure + deterministic so it's testable
/// and never reaches for the clock itself.
AccueilBackdrop accueilBackdropFor({
  required MomentContext moment,
  MoodBucket? usualMood,
  bool winter = false,
}) {
  return AccueilBackdrop(
    image: _imageFor(moment, usualMood, winter),
    invite: _inviteFor(moment.slot),
  );
}

String _imageFor(MomentContext moment, MoodBucket? usualMood, bool winter) {
  // Lead with the usual mood at this time when we've learned it.
  if (usualMood != null) {
    switch (usualMood) {
      case MoodBucket.calm:
        return Img.calm;
      case MoodBucket.open:
        return Img.curious;
      case MoodBucket.lively:
        return moment.slot == DaySlot.evening || moment.slot == DaySlot.night
            ? Img.social
            : Img.energetic;
    }
  }
  // Otherwise, fit the time of day (and season).
  switch (moment.slot) {
    case DaySlot.morning:
      return winter ? Img.cafe : Img.garden;
    case DaySlot.afternoon:
      return moment.isWeekend ? Img.market : Img.park;
    case DaySlot.evening:
      return Img.restaurant;
    case DaySlot.night:
      return Img.bar;
  }
}

String _inviteFor(DaySlot slot) {
  switch (slot) {
    case DaySlot.morning:
      return 'Belle matinée — laisse-toi guider vers ton moment.';
    case DaySlot.afternoon:
      return 'L’après-midi est à toi — vers quoi te laisser porter ?';
    case DaySlot.evening:
      return 'La soirée s’ouvre — laisse Vybia te trouver une belle idée.';
    case DaySlot.night:
      return 'Tard, mais l’envie est là — laisse-toi guider.';
  }
}
