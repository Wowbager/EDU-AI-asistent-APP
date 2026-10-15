import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';
import 'theme_editor_page.dart';
import '../core/layout/breakpoints.dart';

/// Available theme definition — loaded from assets or custom storage.
class _ThemeOption {
  final String? assetPath;
  final ThemeConfig config;
  final bool isCustom;

  _ThemeOption({
    this.assetPath,
    required this.config,
    this.isCustom = false,
  });
}

/// Page for selecting the app's visual theme.
///
/// Shows built-in themes, custom themes, and options to create/import.
class ThemeSelectorPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onThemeChanged;

  const ThemeSelectorPage({
    super.key,
    this.onBack,
    this.onThemeChanged,
  });

  @override
  State<ThemeSelectorPage> createState() => _ThemeSelectorPageState();
}

class _ThemeSelectorPageState extends State<ThemeSelectorPage> {
  List<_ThemeOption> _builtInThemes = [];
  List<_ThemeOption> _customThemes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    final themeFiles = [
      'assets/themes/default.json',
      'assets/themes/ocean.json',
      'assets/themes/sunset.json',
      'assets/themes/fire.json',
      'assets/themes/light.json',
      'assets/themes/neutral.json',
    ];

    final builtIn = <_ThemeOption>[];
    for (final path in themeFiles) {
      try {
        final raw = await rootBundle.loadString(path);
        final config =
            ThemeConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        builtIn.add(_ThemeOption(assetPath: path, config: config));
      } catch (_) {}
    }

    final custom = (await ThemeManager.loadCustomThemes())
        .map((c) => _ThemeOption(config: c, isCustom: true))
        .toList();

    if (mounted) {
      setState(() {
        _builtInThemes = builtIn;
        _customThemes = custom;
        _isLoading = false;
      });
    }
  }

  void _selectTheme(_ThemeOption option) {
    ThemeManager.apply(option.config);
    ThemeManager.saveSelectedTheme(option.config.name);
    setState(() {});
    widget.onThemeChanged?.call();
  }

  void _openEditor({ThemeConfig? base}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThemeEditorPage(
          baseTheme: base,
          onBack: () => Navigator.of(context).pop(),
          onSaved: () {
            _loadThemes();
            widget.onThemeChanged?.call();
          },
        ),
      ),
    );
  }

  Future<void> _deleteCustomTheme(_ThemeOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.themeEditorDelete),
        content: Text(AppStrings.themeEditorDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.themeEditorCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.themeEditorDeleteYes,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ThemeManager.deleteCustomTheme(option.config.name);
    // Remove from API in background.
    ThemeManager.deleteThemeFromApi(option.config.name);

    // If we deleted the active theme, revert to default.
    if (ThemeManager.current.name == option.config.name) {
      if (_builtInThemes.isNotEmpty) {
        ThemeManager.apply(_builtInThemes.first.config);
        ThemeManager.saveSelectedTheme(_builtInThemes.first.config.name);
        widget.onThemeChanged?.call();
      }
    }
    _loadThemes();
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<ThemeConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark16,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(AppStrings.themeImportTitle,
                      style: AppTextStyles.heading3()),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: AppDecorations.radiusM,
                    ),
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      expands: true,
                      style: AppTextStyles.caption(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: AppStrings.themeImportHint,
                        hintStyle:
                            AppTextStyles.caption(color: AppColors.primaryDark32),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!,
                        style: AppTextStyles.caption(color: AppColors.error)),
                  ],
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      try {
                        final json = jsonDecode(controller.text)
                            as Map<String, dynamic>;
                        final config = ThemeConfig.fromJson(json);
                        Navigator.pop(ctx, config);
                      } catch (e) {
                        setSheetState(() =>
                            errorText = '${AppStrings.themeImportError}: $e');
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppDecorations.radiusM,
                      ),
                      child: Center(
                        child: Text(
                          AppStrings.themeImportButton,
                          style: AppTextStyles.buttonLarge(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      ThemeManager.apply(result);
      await ThemeManager.saveCustomTheme(result);
      await ThemeManager.saveSelectedTheme(result.name);
      // Push to API in background.
      ThemeManager.pushThemeToApi(result, isActive: true);
      widget.onThemeChanged?.call();
      _loadThemes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.themeImportSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildThemeList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack ?? () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppDecorations.radiusS,
                boxShadow: AppDecorations.shadowLight,
              ),
              child: Icon(
                Icons.arrow_back,
                size: 22,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(AppStrings.themeTitle, style: AppTextStyles.heading2Bold()),
        ],
      ),
    );
  }

  Widget _buildThemeList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Built-in themes
        ..._builtInThemes.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildThemeCard(t),
            )),

        // Custom themes
        ..._customThemes.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildThemeCard(t),
            )),

        const SizedBox(height: 8),

        // Action buttons: Create + Import
        _buildActionButton(
          icon: Icons.add_circle_outline,
          label: AppStrings.themeCreateNew,
          onTap: () => _openEditor(),
        ),
        const SizedBox(height: 10),
        _buildActionButton(
          icon: Icons.file_download_outlined,
          label: AppStrings.themeImportJson,
          onTap: _showImportDialog,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildThemeCard(_ThemeOption option, ) {
    final c = option.config.colors;
    final isActive = option.config.name == ThemeManager.current.name;
    return GestureDetector(
      onTap: () => _selectTheme(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusL,
          boxShadow: isActive
              ? AppDecorations.shadowStrong
              : AppDecorations.shadowLight,
          border: isActive ? Border.all(color: c.primary, width: 2) : null,
        ),
        child: Row(
          children: [
            // Color preview circles
            _buildColorPreview(c),
            const SizedBox(width: 16),
            // Theme name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.config.name,
                    style: AppTextStyles.cardTitleSmall(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _themeDescription(option.config.name, option.isCustom),
                    style: AppTextStyles.meta(color: AppColors.primaryDark48),
                  ),
                ],
              ),
            ),
            // Custom theme actions
            if (option.isCustom) ...[
              GestureDetector(
                onTap: () => _openEditor(base: option.config),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.edit, size: 20, color: AppColors.primaryDark48),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _deleteCustomTheme(option),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                ),
              ),
            ],
            // Check indicator
            if (isActive) ...[
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 18, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorPreview(ThemeColors colors) {
    final previewColors = [
      colors.primary,
      colors.primaryDark,
      colors.background,
      colors.success,
    ];
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: List.generate(previewColors.length, (i) {
          final offset = i * 12.0;
          return Positioned(
            left: offset,
            top: offset * 0.3,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: previewColors[i],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusL,
          border: Border.all(
            color: AppColors.primaryDark16,
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primaryDark),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.statSuffix()),
            const Spacer(),
            Icon(Icons.chevron_right, size: 22, color: AppColors.primaryDark32),
          ],
        ),
      ),
    );
  }

  String _themeDescription(String name, bool isCustom) {
    if (isCustom) return AppStrings.themeCustom;
    switch (name) {
      case 'Default':
        return AppStrings.themeDefault;
      case 'Ocean':
        return AppStrings.themeOcean;
      case 'Sunset':
        return AppStrings.themeSunset;
      case 'Fire':
        return AppStrings.themeFire;
      case 'Light':
        return AppStrings.themeLight;
      case 'Neutral':
        return AppStrings.themeNeutral;
      default:
        return AppStrings.themeCustom;
    }
  }
}
