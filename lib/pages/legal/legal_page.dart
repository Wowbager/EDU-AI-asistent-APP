import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/util/markdown_table_column_width.dart';

/// Slugs of all legal documents. Each has a markdown file per locale under
/// `assets/legal/{locale}/`, and a pair of routes (`/slug`, `/slug/en`).
const legalSlugs = <String>[
  'terms',
  'privacy',
  'about',
  'cookies',
  'accessibility',
  'ai',
];

/// Universal legal page renderer. Loads markdown from
/// `assets/legal/{locale}/{slug}.md` and renders with brand styling.
///
/// Used both for public web routes (/terms, /terms/en, …) and for
/// in-app navigation (Profile → Podmínky etc.).
class LegalPage extends StatelessWidget {
  /// Slug of the document: terms, privacy, about, cookies, accessibility, ai.
  final String slug;

  /// Locale: 'cs' or 'en'. If null, derived from current URL or defaults to 'cs'.
  final String locale;

  /// If true, shows a back button (in-app context). If false, shows a "Home"
  /// link and language switcher (public-web context).
  final bool inAppMode;

  const LegalPage({
    super.key,
    required this.slug,
    this.locale = 'cs',
    this.inAppMode = false,
  });

  /// Language the *document* is served in. Legal texts exist in Czech and
  /// English only, so Slovak readers get the Czech wording — legal copy is
  /// not machine-translated. Everything below (asset path, header chrome,
  /// footer links, the language pill) keys off this rather than off the
  /// UI locale, so the page never ends up half in a language it has no
  /// document for.
  String get _docLocale => locale == 'en' ? 'en' : 'cs';

  String get _assetPath => 'assets/legal/$_docLocale/$slug.md';

  String get _otherLocale => _docLocale == 'cs' ? 'en' : 'cs';

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(_assetPath),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _docLocale == 'en'
                        ? 'The document could not be loaded.\n${snap.error}'
                        : 'Dokument se nepodařilo načíst.\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.error),
                  ),
                ),
              );
            }
            return _LegalContent(
              markdown: snap.data ?? '',
              slug: slug,
              locale: _docLocale,
              inAppMode: inAppMode,
              otherLocaleLabel: _otherLocale.toUpperCase(),
            );
          },
        ),
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  final String markdown;
  final String slug;
  final String locale;
  final bool inAppMode;
  final String otherLocaleLabel;

  const _LegalContent({
    required this.markdown,
    required this.slug,
    required this.locale,
    required this.inAppMode,
    required this.otherLocaleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          locale: locale,
          otherLocaleLabel: otherLocaleLabel,
          onSwitchLocale: () =>
              _goToLegal(context, slug, locale == 'cs' ? 'en' : 'cs'),
          onBack: inAppMode ? () => Navigator.of(context).maybePop() : null,
          onHome: inAppMode ? null : () => context.go('/'),
        ),
        Expanded(
          child: Markdown(
            data: markdown,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            selectable: true,
            styleSheet: _buildMarkdownStyle(),
            onTapLink: (text, href, title) {
              if (href == null) return;
              _handleLinkTap(context, href);
            },
          ),
        ),
        _Footer(
          locale: locale,
          onTap: (targetSlug) => _goToLegal(context, targetSlug, locale),
        ),
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle() {
    return MarkdownStyleSheet(
      h1: AppTextStyles.heading1(color: AppColors.primaryDark)
          .copyWith(height: 1.2),
      h2: AppTextStyles.heading2(color: AppColors.primaryDark)
          .copyWith(height: 1.3),
      h3: AppTextStyles.heading3(color: AppColors.primaryDark),
      h4: AppTextStyles.cardTitle(color: AppColors.primaryDark),
      p: AppTextStyles.body(color: AppColors.primaryDark, height: 1.55),
      listBullet: AppTextStyles.body(color: AppColors.primaryDark),
      strong: AppTextStyles.bodyBold(color: AppColors.primaryDark),
      em: AppTextStyles.bodyItalic(color: AppColors.primaryDark),
      a: AppTextStyles.body(color: AppColors.quizPurple).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: AppColors.quizPurple,
      ),
      code: AppTextStyles.codeInline(color: AppColors.primaryDark).copyWith(
        backgroundColor: AppColors.surfaceLight,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquote: AppTextStyles.body(color: AppColors.primaryDark72),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      tableHead: AppTextStyles.bodySmall(color: AppColors.primaryDark)
          .copyWith(fontWeight: FontWeight.w600),
      tableBody: AppTextStyles.bodySmall(color: AppColors.primaryDark),
      tableHeadAlign: TextAlign.left,
      tableBorder: TableBorder.all(color: AppColors.progressBorder, width: 1),
      // Wide tables scroll sideways instead of being squeezed into the
      // viewport (BR-9AHW8R) — see markdown_table_column_width.dart.
      tableColumnWidth: kMarkdownTableColumnWidth,
      tableScrollbarThumbVisibility: true,
      tableCellsPadding: const EdgeInsets.all(8),
      h2Padding: const EdgeInsets.only(top: 20, bottom: 4),
      h3Padding: const EdgeInsets.only(top: 14, bottom: 2),
      pPadding: const EdgeInsets.only(bottom: 2),
    );
  }

  /// Moves to another legal document using whichever navigation model owns the
  /// current page. Getting this wrong is BR-QVMBDN: an in-app page lives on an
  /// imperatively pushed route, so `context.go` would swap the go_router stack
  /// *underneath* it — the URL changes while the old document stays on screen.
  ///
  /// Deliberately keyed on [inAppMode], not on `kIsWeb`: the in-app pages are
  /// reachable on web too (Profile → Podmínky, auth screen → Podmínky).
  void _goToLegal(BuildContext context, String targetSlug, String targetLocale) {
    if (inAppMode) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LegalPage(
            slug: targetSlug,
            locale: targetLocale,
            inAppMode: true,
          ),
        ),
      );
    } else {
      context.go(targetLocale == 'en' ? '/$targetSlug/en' : '/$targetSlug');
    }
  }

  Future<void> _handleLinkTap(BuildContext context, String href) async {
    // Internal legal route (relative, starts with /).
    if (href.startsWith('/')) {
      final parts = href.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty && legalSlugs.contains(parts.first)) {
        // An explicit `/slug/en` suffix wins; otherwise stay in this locale.
        final targetLocale = parts.length > 1 && parts[1] == 'en' ? 'en' : locale;
        _goToLegal(context, parts.first, targetLocale);
        return;
      }
    }
    // mailto: / tel: / external — open via OS.
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale == 'en' ? "Can't open: $href" : 'Nelze otevřít: $href',
            ),
          ),
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  final String locale;
  final String otherLocaleLabel;
  final VoidCallback onSwitchLocale;

  /// Exactly one of [onBack] (in-app) / [onHome] (public web) is non-null.
  final VoidCallback? onBack;
  final VoidCallback? onHome;

  const _Header({
    required this.locale,
    required this.otherLocaleLabel,
    required this.onSwitchLocale,
    this.onBack,
    this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
              tooltip: locale == 'cs' ? 'Zpět' : 'Back',
            )
          else
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: onHome,
              tooltip: locale == 'cs' ? 'Domů' : 'Home',
            ),
          Expanded(
            child: Center(
              child: Text(
                'EDU AI asistent',
                style: AppTextStyles.cardTitle(color: Colors.white)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          _LangPill(
            currentLabel: locale.toUpperCase(),
            otherLabel: otherLocaleLabel,
            onSwitch: onSwitchLocale,
          ),
        ],
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final String currentLabel;
  final String otherLabel;
  final VoidCallback onSwitch;

  const _LangPill({
    required this.currentLabel,
    required this.otherLabel,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSwitch,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: AppTextStyles.bodySmall(color: Colors.white)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Text(
              '→ $otherLabel',
              style: AppTextStyles.bodySmall(color: Colors.white)
                  .copyWith(fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final String locale;

  /// Called with the target slug. Navigation strategy lives in [LegalPage] so
  /// the footer stays agnostic of go_router vs. imperative routes.
  final void Function(String slug) onTap;

  const _Footer({required this.locale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCs = locale == 'cs';
    final items = <(String, String)>[
      (isCs ? 'Podmínky' : 'Terms', 'terms'),
      (isCs ? 'Soukromí' : 'Privacy', 'privacy'),
      ('Cookies', 'cookies'),
      (isCs ? 'O aplikaci' : 'About', 'about'),
      (isCs ? 'Přístupnost' : 'Accessibility', 'accessibility'),
      ('AI', 'ai'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.progressBorder)),
        color: AppColors.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final (label, slug) in items)
            InkWell(
              onTap: () => onTap(slug),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall(color: AppColors.primaryDark72)
                      .copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
