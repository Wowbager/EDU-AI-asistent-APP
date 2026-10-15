import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the selected main tab.
///
/// Held in a provider rather than `MainScreen` state because on wide layouts
/// pushed pages (course detail, for one) draw their own copy of the sidebar.
/// Tapping a destination there has to change the tab that `MainScreen` — still
/// mounted underneath — will show once the pushed route pops.
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

/// Index of the Kurzy tab in `MainScreen.pages` / `navDestinations`.
///
/// Named because code that opens a course from outside the tab strip (deep
/// links, PIN login) has to point the shell at it — see [mainTabIndexProvider].
const int kKurzyTabIndex = 3;

/// Index of the Chat tab, for the same reason as [kKurzyTabIndex]: the
/// `/chat/:mentor` deep link has to land on the page that starts the
/// conversation (BR-HCF5AS).
const int kChatTabIndex = 1;

/// Something a pushed page's sidebar wants `MainScreen` to do after the page
/// pops back.
///
/// The sidebar's footer needs callbacks that only `MainScreen` has — they
/// close over its navigator and the app-level logout handler. A pushed page
/// cannot reach those, so it records the intent here and `MainScreen`
/// performs it.
///
/// [openGuestLogin] is the sidebar's "Registrovat se" card. It used to bump
/// `requestGuestLoginProvider` instead (BR-QJJXPN), but that provider is a
/// counter nobody can pop back to the shell first — and a course opened
/// straight from a PIN login has no `MainScreen` underneath to hear it at all,
/// so the tap did nothing (BR-CMP2PX). `requestGuestLoginProvider` still
/// serves callers that are already sitting above a mounted shell.
///
/// [openDoplnky] is here for the same reason as the footer actions: the
/// sidebar's push destination opens a page that `MainScreen` knows how to set
/// up (the games list has to be re-fetched first), and stacking it on top of
/// whatever detail page is showing would bury the user two routes deep.
/// Recording the intent pops back to the shell first.
enum ShellIntent { openProfile, openGuestLogin, logout, openDoplnky }

/// One-shot slot for [ShellIntent]. `MainScreen` acts on it and clears it.
final pendingShellIntentProvider = StateProvider<ShellIntent?>((ref) => null);

/// Read the pending intent and empty the slot.
///
/// A slot rather than an event, and read-and-clear rather than a plain
/// `ref.listen`: the intent can be recorded while `MainScreen` is not mounted
/// at all — `AuthPage` pushes the course a PIN resolved to, so popping that
/// page is what completes the login and mounts the shell. A listener
/// registered at that moment has already missed the change (BR-CMP2PX).
ShellIntent? takePendingShellIntent(WidgetRef ref) {
  final intent = ref.read(pendingShellIntentProvider);
  if (intent != null) {
    ref.read(pendingShellIntentProvider.notifier).state = null;
  }
  return intent;
}
