import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/consent_repository.dart';
import 'resend_link_form.dart';

/// Public guardian self-service behind a magic link: see the child
/// accounts, issue a fresh login code for one of them, or revoke consent
/// entirely.
///
/// Runs standalone in the public-web context, outside `AuthWrapper` — same
/// mechanism as `/privacy`. The token lives in the URL path (decision 11 in
/// the plan): the API already answers with `Cache-Control: no-store` and
/// `Referrer-Policy: no-referrer`, and nothing on this page adds any
/// client-side caching or persistence of the token — it is only ever held
/// in this widget's state for the lifetime of the page.
class ConsentManageWebPage extends StatefulWidget {
  final String token;

  /// Load the management state for [token]. Returns a [ConsentManageResult]
  /// so this screen can tell a dead token (expired / already revoked /
  /// simply wrong — the API answers 404 for all three, per the plan) apart
  /// from a request that never reached the server at all.
  final Future<ConsentManageResult> Function() loadState;

  /// Issue a fresh plaintext code for one child. Shown once, never fetched
  /// again — losing it means generating a new one.
  final Future<ConsentCodeResult> Function(int childId) onRegenerate;

  /// Revoke the consent. Destructive and irreversible: blocks the children
  /// immediately and schedules erasure.
  final Future<ConsentActionResult> Function() onRevoke;

  /// Re-email a fresh magic link — offered when the current token is dead.
  final Future<ConsentActionResult> Function(String email) onRequestManageLink;

  const ConsentManageWebPage({
    super.key,
    required this.token,
    required this.loadState,
    required this.onRegenerate,
    required this.onRevoke,
    required this.onRequestManageLink,
  });

  @override
  State<ConsentManageWebPage> createState() => _ConsentManageWebPageState();
}

enum _LoadStatus { loading, loaded, expired, loadError }

class _ConsentManageWebPageState extends State<ConsentManageWebPage> {
  _LoadStatus _loadStatus = _LoadStatus.loading;
  ConsentManageState? _state;
  bool _revoked = false;
  String? _revokeError;

  /// Freshly issued codes, shown once and never fetched again.
  final Map<int, String> _newCodes = {};
  final Map<int, ConsentFailure> _regenerateErrors = {};

  /// Children with a regenerate request in flight — guards against a fast
  /// double-tap firing two requests for the same child, where whichever
  /// response lands last would silently win.
  final Set<int> _regenerating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadStatus = _LoadStatus.loading);

    final result = await widget.loadState();
    if (!mounted) return;

    setState(() {
      if (result.isSuccess) {
        _state = result.state;
        _loadStatus = _LoadStatus.loaded;
      } else if (result.failure == ConsentFailure.network) {
        // Honest wording matters here: this is a connectivity problem, not
        // proof the link is dead. Telling the parent to request a new link
        // when their wifi just dropped would send them on a wild goose chase.
        _loadStatus = _LoadStatus.loadError;
      } else {
        _loadStatus = _LoadStatus.expired;
      }
    });
  }

  Future<void> _regenerate(int childId) async {
    if (_regenerating.contains(childId)) return;

    setState(() {
      _regenerating.add(childId);
      _regenerateErrors.remove(childId);
    });

    final result = await widget.onRegenerate(childId);
    if (!mounted) return;

    setState(() {
      _regenerating.remove(childId);
      if (result.isSuccess) {
        _newCodes[childId] = result.code!;
      } else {
        _regenerateErrors[childId] = result.failure!;
      }
    });
  }

  Future<void> _revoke() async {
    setState(() => _revokeError = null);

    final result = await widget.onRevoke();
    if (!mounted) return;

    setState(() {
      if (result.success) {
        _revoked = true;
      } else {
        // A network failure must not be silently swallowed nor read as
        // success — the parent needs to know revocation did NOT happen and
        // that they can (and should) try again.
        _revokeError = result.failure == ConsentFailure.network
            ? AppStrings.consentNetworkError
            : AppStrings.consentGenericError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadStatus) {
      case _LoadStatus.loading:
        return Center(child: CircularProgressIndicator(color: AppColors.primary));
      case _LoadStatus.loadError:
        return _buildLoadError();
      case _LoadStatus.expired:
        return _ExpiredLink(onRequestManageLink: widget.onRequestManageLink);
      case _LoadStatus.loaded:
        return _revoked ? _buildRevoked() : _buildManage(_state!);
    }
  }

  Widget _buildLoadError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off, size: 64, color: AppColors.error),
        const SizedBox(height: 16),
        Text(
          AppStrings.consentManageLoadError,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _load,
          child: Text(AppStrings.consentManageRetry),
        ),
      ],
    );
  }

  Widget _buildRevoked() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.block, size: 64, color: AppColors.error),
        const SizedBox(height: 16),
        Text(
          AppStrings.consentManageRevoked,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge(),
        ),
        const SizedBox(height: 8),
        // The confirmation dialog already said this before the parent
        // committed to revoking; restate it here too, because the magic
        // link stays usable for 24h and a parent can land back on this
        // exact screen well after revoking, with no memory of the dialog.
        Text(
          AppStrings.consentManageRevokedDetail,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(),
        ),
      ],
    );
  }

  Widget _buildManage(ConsentManageState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.consentManageTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading3(),
        ),
        const SizedBox(height: 24),
        Text(AppStrings.consentManageChildren, style: AppTextStyles.bodyLarge()),
        const SizedBox(height: 8),
        for (final child in state.children) _buildChild(child),
        const SizedBox(height: 32),
        if (_revokeError != null) ...[
          Text(
            _revokeError!,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.error),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton(
          onPressed: _confirmRevoke,
          child: Text(AppStrings.consentManageRevoke),
        ),
      ],
    );
  }

  Widget _buildChild(ConsentChild child) {
    final code = _newCodes[child.id];
    final error = _regenerateErrors[child.id];
    final isRegenerating = _regenerating.contains(child.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(child.name, style: AppTextStyles.bodyLarge())),
                TextButton(
                  onPressed: isRegenerating ? null : () => _regenerate(child.id),
                  child: Text(AppStrings.consentManageNewCode),
                ),
              ],
            ),
            if (code != null) ...[
              const SizedBox(height: 8),
              Text(code, style: AppTextStyles.heading3(), textAlign: TextAlign.center),
              Text(AppStrings.consentManageNewCodeHint, style: AppTextStyles.bodySmall()),
            ] else if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error == ConsentFailure.network
                    ? AppStrings.consentNetworkError
                    : AppStrings.consentGenericError,
                style: AppTextStyles.bodySmall(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmRevoke() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(AppStrings.consentManageRevokeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppStrings.ageGateNo),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _revoke();
            },
            child: Text(AppStrings.consentManageRevoke),
          ),
        ],
      ),
    );
  }
}

/// Shown when the token in the URL is dead — expired, already revoked, or
/// simply wrong (all indistinguishable 404s from the API, by design: this
/// endpoint must not leak which case it is). Offers the one way out: a
/// fresh magic link, emailed to whatever address the parent types.
class _ExpiredLink extends StatelessWidget {
  final Future<ConsentActionResult> Function(String email) onRequestManageLink;

  const _ExpiredLink({required this.onRequestManageLink});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.link_off, size: 64, color: AppColors.error),
        const SizedBox(height: 16),
        Text(
          AppStrings.consentManageExpired,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge(),
        ),
        const SizedBox(height: 24),
        ResendLinkForm(onRequestManageLink: onRequestManageLink),
      ],
    );
  }
}
