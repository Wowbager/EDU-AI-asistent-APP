import '../core/strings/app_strings.dart';
import 'chat_models.dart';

/// What the "Nový chat" cards draw on top of a [ChatMentor].
///
/// Deliberately an extension rather than a second model: the mentors are
/// admin-managed and arrive parsed from `GET /api/chat/mentors` (BR-N7FC2B),
/// so a parallel view model would only be a second parser to keep in step.
/// Everything here is derived from server fields — `engine` decides the kind
/// tag, `visibility` the availability chip — so a mentor created in the admin
/// gets the right labels without an app release.
extension MentorPresentation on ChatMentor {
  /// Answers out of the document store rather than from a prompt.
  bool get isLibrarian => engine == 'rag';

  /// Kept out of the general list and reached from its course instead.
  bool get isCourseOnly => visibility == ChatMentor.visibilityHidden;

  /// "AI" or "knihovna" — the tag at the top right of the card.
  String get kindLabel =>
      isLibrarian ? AppStrings.mentorKindLibrary : AppStrings.mentorKindAi;

  /// "online" or "jen v kurzu" — the clock chip beside the tag.
  String get availabilityLabel => isCourseOnly
      ? AppStrings.mentorAvailabilityCourseOnly
      : AppStrings.mentorAvailabilityOnline;

  /// Falls back to the subtitle: an admin may fill in one or the other, and a
  /// card with a blank second line looks broken.
  String get cardDescription {
    final text = description?.trim();
    if (text != null && text.isNotEmpty) return text;

    return subtitle?.trim() ?? '';
  }
}
