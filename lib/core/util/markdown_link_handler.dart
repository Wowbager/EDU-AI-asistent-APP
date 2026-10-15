import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../pages/course_detail_page.dart';
import '../../pages/legal/legal_page.dart';
import '../../routing/app_router.dart' show legalSlugs;
import '../providers/core_providers.dart';
import '../providers/navigation_providers.dart';
import '../services/course_enroll_service.dart';
import '../strings/app_strings.dart';
import 'silent_log.dart';
import 'shell_route.dart';

/// Hosts that serve the app itself, as opposed to the marketing site.
///
/// On web the current origin is authoritative, so prod, stage and a local dev
/// server all resolve without configuration. This constant only has to cover
/// the native builds, where `Uri.base` is a `file://` path and tells us
/// nothing. `edu-ai.eu` (the WordPress site) is deliberately absent — links to
/// it must open in the browser, and course content already contains some.
const _nativeAppHosts = <String>{'app.edu-ai.eu'};

/// Whether [uri] points at this app rather than somewhere else on the internet.
bool _isOwnHost(Uri uri) {
  if (!uri.hasAuthority) return true; // relative, e.g. /pin/uslov1
  if (kIsWeb && uri.host == Uri.base.host) return true;
  return _nativeAppHosts.contains(uri.host);
}

/// What a tapped Markdown link resolves to.
enum MarkdownLinkAction {
  /// A `/pin/:code` or `/course/:code` deep link; the value is the course code.
  courseCode,

  /// One of the legal documents; the value is its slug and [locale] the
  /// language it was requested in.
  legalPage,

  /// Anything else; the value is the href, to be handed to the OS.
  external,
}

/// The resolved target of a Markdown link.
class MarkdownLinkTarget {
  final MarkdownLinkAction action;
  final String value;

  /// Only set for [MarkdownLinkAction.legalPage]: 'cs' or 'en'.
  final String? locale;

  const MarkdownLinkTarget(this.action, this.value, {this.locale});

  @override
  String toString() =>
      'MarkdownLinkTarget(${action.name}, $value${locale == null ? '' : ', $locale'})';

  @override
  bool operator ==(Object other) =>
      other is MarkdownLinkTarget &&
      other.action == action &&
      other.value == value &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(action, value, locale);
}

/// Decide what [href] should do, without doing it.
///
/// Split out from [handleMarkdownLink] so the routing rules — which host counts
/// as ours, which paths the app can serve — are testable without a database or
/// a URL launcher.
MarkdownLinkTarget resolveMarkdownLink(String href) {
  final trimmed = href.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return MarkdownLinkTarget(MarkdownLinkAction.external, trimmed);

  if (_isOwnHost(uri)) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // /pin/:code and /course/:code — the deep links, resolved by course code.
    if (segments.length == 2 &&
        (segments.first == 'pin' || segments.first == 'course')) {
      return MarkdownLinkTarget(MarkdownLinkAction.courseCode, segments[1]);
    }

    // Legal documents: /terms, /privacy/en, ... — anything longer is not one.
    if (segments.isNotEmpty &&
        segments.length <= 2 &&
        legalSlugs.contains(segments.first) &&
        (segments.length == 1 || segments[1] == 'en')) {
      return MarkdownLinkTarget(
        MarkdownLinkAction.legalPage,
        segments.first,
        locale: segments.length == 2 ? 'en' : 'cs',
      );
    }
  }

  return MarkdownLinkTarget(MarkdownLinkAction.external, trimmed);
}

/// Handle a tap on a link inside rendered Markdown.
///
/// Links pointing at the app itself are rewritten into in-app navigation, so a
/// news item can link to `https://app.edu-ai.eu/pin/uslov1` and the course
/// opens on top of the current screen instead of reloading the whole app
/// (BR-QJJXPN). Everything else — the marketing site, `mailto:`, `tel:` — is
/// handed to the OS.
///
/// Unknown paths on our own host fall through to the browser on purpose: the
/// router's `errorBuilder` would otherwise show "Stránka nenalezena" for any
/// link the app does not have a route for.
Future<void> handleMarkdownLink(
  BuildContext context,
  WidgetRef ref,
  String href,
) async {
  final target = resolveMarkdownLink(href);
  switch (target.action) {
    case MarkdownLinkAction.courseCode:
      await openCourseByCode(context, ref, target.value);
    case MarkdownLinkAction.legalPage:
      // Pushed rather than routed with `context.go`, which would replace the
      // location and throw away whatever the link was tapped from — Back would
      // no longer return to the article.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LegalPage(
            slug: target.value,
            locale: target.locale ?? 'cs',
            inAppMode: true,
          ),
        ),
      );
    case MarkdownLinkAction.external:
      final uri = Uri.tryParse(target.value);
      if (uri != null) await _launchExternal(context, uri);
  }
}

Future<void> _launchExternal(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) return;
  } catch (e, st) {
    silentLog('markdown_link:launch', e, st);
    if (!context.mounted) return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppStrings.libraryLinkOpenFailed)),
  );
}

/// Resolve a course by [code], enroll the user and push the course detail.
///
/// Shares [enrollCourseByCode] with the Knihovna code input and the deep-link
/// entry so all three behave identically, and renders the outcome the same way
/// they do.
///
/// [selectCoursesTab] points the shell at the Kurzy tab. Callers that arrive
/// with no tab context — a `/pin` or `/course` deep link — pass true: the
/// sidebar a pushed page draws reads [mainTabIndexProvider], so without it the
/// course opens with "Přehled" highlighted and "Zpět na všechny kurzy" lands
/// there too (BR-48B7DY). Off by default so a `/pin` link tapped inside a news
/// article still returns to Novinky.
Future<void> openCourseByCode(
  BuildContext context,
  WidgetRef ref,
  String code, {
  bool selectCoursesTab = false,
}) async {
  final outcome = await enrollCourseByCode(ref, code);
  if (!context.mounted) return;

  if (!outcome.isSuccess) {
    await showEnrollFailure(context, ref, outcome);
    return;
  }

  // After the failure paths: a code that never resolved must not move the tab.
  if (selectCoursesTab) {
    ref.read(mainTabIndexProvider.notifier).state = kKurzyTabIndex;
  }

  await Navigator.of(context).push(
    shellPageRoute(
      context,
      builder: (_) => CourseDetailPage(
        course: outcome.course!,
        userCourseId: outcome.userCourseId,
      ),
    ),
  );
}

/// Render a failed enroll attempt.
///
/// A guest blocked from a `logged_only` course gets an actionable dialog; every
/// other failure is a snackbar, since there is nothing for the user to do about
/// it. [EnrollErrorKind.loginRequired] shows nothing at all — the session is
/// already being torn down and the app is returning to the login screen, so a
/// dialog would flash over a screen that is about to disappear.
Future<void> showEnrollFailure(
  BuildContext context,
  WidgetRef ref,
  EnrollOutcome outcome,
) async {
  if (outcome.error == EnrollErrorKind.loginRequiredForCourse) {
    await showLoginRequiredForCourseDialog(context, ref);
    return;
  }
  if (outcome.error == EnrollErrorKind.loginRequired) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(enrollErrorText(outcome))),
  );
}

/// Tell a guest the course needs an account and offer to log in.
///
/// Confirming bumps [requestGuestLoginProvider], which MainScreen turns into
/// the same guest-upgrade login page its profile screen pushes — no local data
/// is wiped, so the guest's progress survives and is merged server-side.
Future<void> showLoginRequiredForCourseDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppStrings.libraryLoggedOnlyTitle),
      content: Text(AppStrings.libraryLoggedOnlyBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(AppStrings.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(AppStrings.libraryLoggedOnlyAction),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    ref.read(requestGuestLoginProvider.notifier).state++;
  }
}

/// Localized copy for a failed enroll attempt. Shared by every caller of
/// [enrollCourseByCode] so the deep link, the Knihovna code input and a link in
/// a news item all word the same failure identically.
String enrollErrorText(EnrollOutcome outcome) {
  switch (outcome.error) {
    case EnrollErrorKind.codeShort:
      return AppStrings.libraryCodeShort;
    case EnrollErrorKind.notFound:
      return AppStrings.libraryCodeNotFound(outcome.code);
    case EnrollErrorKind.loginRequired:
    case EnrollErrorKind.loginRequiredForCourse:
      return AppStrings.libraryLoginRequired;
    case EnrollErrorKind.alreadyCompleted:
      return AppStrings.libraryCourseAlreadyCompleted;
    case EnrollErrorKind.loadError:
      return AppStrings.libraryLoadError;
    case EnrollErrorKind.generic:
    case null:
      return AppStrings.genericError(outcome.message ?? '');
  }
}
