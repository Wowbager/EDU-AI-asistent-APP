import 'package:flutter/material.dart';

import '../../core/consent/age_threshold.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/auth_buttons.dart';
import '../../widgets/auth_hero_scaffold.dart';

/// Gate shown before the auth stack — a route in front of login/sign-up,
/// never a field inside the login form (a guard belongs above the thing it
/// guards). The answer is never persisted anywhere: no date of birth is
/// collected, and a child who answers "no" and abandons the flow gets asked
/// again next time, exactly like a child who never answered at all.
///
/// Two mandatory steps:
///  1. **Confirm the country.** [AgeThreshold.detectCountry] is only a guess
///     derived from the device locale — a Czech-locale phone used in
///     Slovakia resolves to CZ (threshold 15) when Slovakia's threshold is
///     16. That is a *wrong* answer, not an *unknown* one: the OS reports a
///     locale with high confidence, so the conservative "unknown country"
///     fallback never has a chance to fire. Failing in the direction of a
///     lower age threshold is the legally relevant failure. The guess is
///     therefore surfaced as large, explicit country choices the user must
///     actively continue past — not a compact dropdown sitting next to
///     unrelated buttons, which is easy to miss entirely. The choices come
///     from [AgeThreshold.knownCountries], not a hardcoded CZ/SK pair, so a
///     new market added via `/api/consent/config` appears here without an
///     app release.
///  2. **Answer the age question** for the confirmed country's threshold.
class AgeGatePage extends StatefulWidget {
  /// Pre-selected country (e.g. for tests, or a caller that already knows
  /// it). Falls back to [AgeThreshold.detectCountry] when null. This is only
  /// ever the *starting guess* for step 1 — the user can still change it
  /// there before continuing.
  final String? initialCountry;

  /// The user confirmed they are old enough for the confirmed country's
  /// threshold — proceed to the normal login/sign-up flow.
  final VoidCallback onOldEnough;

  /// The user said they are under the threshold. Carries the *confirmed*
  /// country (never the raw, unconfirmed guess) so the guardian consent
  /// request that follows uses the right one. Task 14 builds what this leads
  /// to; here it is only invoked.
  final ValueChanged<String?> onNeedsConsent;

  /// Leaves the gate entirely (e.g. back to the PIN screen). Only offered on
  /// the country step. On the age step, "back" instead returns to the
  /// country step — once a country is confirmed, going back means changing
  /// that answer, not abandoning the gate.
  final VoidCallback? onBack;

  const AgeGatePage({
    super.key,
    required this.onOldEnough,
    required this.onNeedsConsent,
    this.initialCountry,
    this.onBack,
  });

  @override
  State<AgeGatePage> createState() => _AgeGatePageState();
}

class _AgeGatePageState extends State<AgeGatePage> {
  late String? _country = widget.initialCountry ?? AgeThreshold.detectCountry();
  bool _countryConfirmed = false;

  bool get _hasValidSelection => AgeThreshold.knownCountries.contains(_country);

  void _confirmCountry() {
    if (!_hasValidSelection) return;
    setState(() => _countryConfirmed = true);
  }

  void _changeCountry() {
    setState(() => _countryConfirmed = false);
  }

  @override
  Widget build(BuildContext context) {
    // Back button lives outside the scrollable, centered content so it stays
    // pinned to the top-left corner no matter how tall that content gets —
    // see the layout note on _CountryOption's parent Wrap for why the
    // content itself must be allowed to grow past one screen.
    final VoidCallback? back = _countryConfirmed ? _changeCountry : widget.onBack;
    final Widget step = _countryConfirmed ? _buildAgeStep() : _buildCountryStep();

    return PopScope(
      // The software arrow above already steps age→country before leaving
      // the gate, but Android's hardware/gesture back bypasses that IconButton
      // entirely and pops whatever Route this page sits in — e.g.
      // main_screen.dart pushes AuthPage (and this gate inside it) as a
      // MaterialPageRoute. Without this, hardware back on the age step would
      // pop the gate straight out to whatever is behind that route instead of
      // returning to country selection, letting the flow be proven wrong
      // ("hop back in with a different, unconfirmed country") or simply
      // abandoning it in a state the user never explicitly chose to leave
      // from. Only once back is on the country step (nothing left to step
      // back through inside the gate) does a system back actually leave it.
      canPop: !_countryConfirmed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _changeCountry();
      },
      // Wide windows keep the illustrated hero scene on screen and put the
      // gate's steps in the right-hand panel, exactly where the login form
      // sits — the gate is a stop on the same journey, not a context switch.
      child: context.isExpanded
          ? AuthHeroScaffold(onBack: back, panel: step)
          : Scaffold(
              backgroundColor: AppColors.background,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 72,
                            ),
                            child: Center(child: step),
                          ),
                        ),
                      ),
                    ),
                    if (back != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: back,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCountryStep() {
    final countries = AgeThreshold.knownCountries;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.ageGateCountryQuestion,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading3(),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.ageGateCountryLabel,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(color: AppColors.primaryDark48),
        ),
        const SizedBox(height: 24),
        // Wrap, not a fixed Row: AgeThreshold.knownCountries can grow past
        // the two bundled markets once the server config adds more, and a
        // Row would either overflow horizontally or need per-count layout
        // logic. Wrap flows extra options onto new lines instead, and the
        // whole thing sits in the scrollable content built in [build] so a
        // long list scrolls rather than overflowing the screen vertically.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final country in countries)
              _CountryOption(
                code: country,
                selected: _country == country,
                onTap: () => setState(() => _country = country),
              ),
          ],
        ),
        const SizedBox(height: 32),
        AuthPrimaryButton(
          label: AppStrings.authContinue,
          arrow: true,
          onPressed: _hasValidSelection ? _confirmCountry : null,
        ),
      ],
    );
  }

  Widget _buildAgeStep() {
    final threshold = AgeThreshold.forCountry(_country);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.ageGateTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading3(),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.ageGateQuestion(threshold),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge(),
        ),
        const SizedBox(height: 32),
        // Side by side — the labels are one word in every locale, so the two
        // halves of the form column fit them comfortably. Affirmative on the
        // right, per dialog convention; prominence unchanged (yes stays the
        // filled one, no the quiet outline).
        Row(
          children: [
            Expanded(
              child: AuthSecondaryButton(
                label: AppStrings.ageGateNo,
                onPressed: () => widget.onNeedsConsent(_country),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AuthPrimaryButton(
                label: AppStrings.ageGateYes,
                onPressed: widget.onOldEnough,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One large, tappable country choice. Deliberately not a dropdown: the
/// country reads as a real, visible question on screen, not a detail tucked
/// away next to unrelated buttons.
class _CountryOption extends StatelessWidget {
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _CountryOption({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  /// Converts a 2-letter ISO 3166-1 alpha-2 code into its flag emoji via
  /// Unicode regional indicator symbols. This works for any code the server
  /// sends — no per-market lookup table to keep in sync with
  /// [AgeThreshold.knownCountries].
  static String _flagFor(String isoCode) {
    if (isoCode.length != 2) return '🏳️';
    const regionalIndicatorBase = 0x1F1E6; // Regional Indicator Symbol A
    const asciiUpperA = 0x41;
    return String.fromCharCodes(
      isoCode.toUpperCase().codeUnits.map(
            (unit) => regionalIndicatorBase + (unit - asciiUpperA),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppDecorations.radiusM,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: AppDecorations.radiusM,
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.primaryDark16,
            width: selected ? 2 : 1,
          ),
          color: selected ? AppColors.primaryDark08 : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(_flagFor(code), style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(code, style: AppTextStyles.statValue()),
          ],
        ),
      ),
    );
  }
}
