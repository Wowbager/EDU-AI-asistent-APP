import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a course join code/PIN captured from a `/course/:code` or `/pin/:code`
/// deep link until a screen that can act on it appears — `AuthPage` when the
/// visitor is logged out, `MainScreen` when they are not. Both URL shapes
/// resolve the same way (by course code/PIN).
///
/// `ShellEntry` is what records it: the deep links share their route with the
/// rest of the signed-in app, so the landing widget is the same one every shell
/// URL uses.
final pendingDeepLinkCodeProvider = StateProvider<String?>((ref) => null);

/// Holds the mentor slug from a `/chat/:mentor` deep link until `ChatyPage`
/// appears and can start the conversation.
///
/// Separate from [pendingDeepLinkCodeProvider] on purpose: a slug is not a
/// course code, and the login screen's PIN flow must not try to resolve one.
/// `ShellEntry` records it and points the shell at the chat tab; the page
/// itself is what creates the session, because that is where the new-chat
/// picker already does it (BR-HCF5AS).
final pendingChatMentorSlugProvider = StateProvider<String?>((ref) => null);

/// Holds the class code from a `/join/:code` link (BR-TT6TD7) until the
/// signed-in app can act on it — see `joinClassroomFromDeepLink`.
///
/// Separate from [pendingDeepLinkCodeProvider] for the same reason as the
/// mentor slug: the login screen resolves that one as a course PIN. A class
/// code needs an account instead, so a logged-out visitor just gets the login
/// screen and the code waits here until `MainScreen` is up with a real
/// account — a guest is asked to log in first, and the code survives that.
final pendingClassroomJoinCodeProvider = StateProvider<String?>((ref) => null);
