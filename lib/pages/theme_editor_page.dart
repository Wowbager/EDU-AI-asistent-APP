import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';
import '../widgets/color_picker_dialog.dart';
import '../core/layout/breakpoints.dart';

/// Visual theme editor – shows all color keys grouped by category.
///
/// Users can tap any color to open a picker, see live preview,
/// and save the result as a custom theme.
class ThemeEditorPage extends StatefulWidget {
  final ThemeConfig? baseTheme;
  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  const ThemeEditorPage({
    super.key,
    this.baseTheme,
    this.onBack,
    this.onSaved,
  });

  @override
  State<ThemeEditorPage> createState() => _ThemeEditorPageState();
}

class _ThemeEditorPageState extends State<ThemeEditorPage> {
  late ThemeConfig _originalTheme;
  late Map<String, String> _colors;
  late TextEditingController _nameController;
  late ThemeTypography _typography;
  late ThemeRadii _radii;

  /// Which groups are expanded. First group is open by default.
  late Map<String, bool> _expanded;

  @override
  void initState() {
    super.initState();
    _originalTheme = ThemeManager.current;
    final base = widget.baseTheme ?? ThemeManager.current;
    _colors = base.colors.toJson().map((k, v) => MapEntry(k, v as String));
    _nameController = TextEditingController(
      text: base.name == 'Default' || base.name == 'Ocean' || base.name == 'Sunset'
          ? ''
          : base.name,
    );
    _typography = base.typography;
    _radii = base.radii;
    _expanded = {for (final g in _colorGroups) g.name: g == _colorGroups.first};
  }

  @override
  void dispose() {
    _nameController.dispose();
    // Revert if not saved – the caller should re-apply the saved theme.
    super.dispose();
  }

  ThemeConfig _buildConfig() {
    return ThemeConfig(
      name: _nameController.text.trim().isEmpty
          ? AppStrings.themeEditorNameHint
          : _nameController.text.trim(),
      version: 1,
      colors: ThemeColors.fromJson(
        _colors.map((k, v) => MapEntry(k, v)),
      ),
      typography: _typography,
      radii: _radii,
    );
  }

  void _applyPreview() {
    try {
      ThemeManager.apply(_buildConfig());
    } catch (_) {
      // Invalid state – ignore until all fields are valid.
    }
  }

  void _revert() {
    ThemeManager.apply(_originalTheme);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.themeEditorNameEmpty),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final config = _buildConfig();
    ThemeManager.apply(config);
    await ThemeManager.saveCustomTheme(config);
    await ThemeManager.saveSelectedTheme(config.name);
    // Push to API in background (fire-and-forget).
    ThemeManager.pushThemeToApi(config, isActive: true);
    widget.onSaved?.call();
    if (mounted) Navigator.pop(context);
  }

  void _exportJson() {
    final json = const JsonEncoder.withIndent('  ').convert(_buildConfig().toJson());
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.themeEditorExportCopied),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // ── Color group definitions ───────────────────────────────────────

  static final _colorGroups = [
    _ColorGroup(
      name: AppStrings.themeEditorGroupCoreBrand,
      keys: ['primary', 'primaryDark', 'background', 'gradientPurple', 'surface'],
    ),
    _ColorGroup(
      name: AppStrings.themeEditorGroupStatus,
      keys: ['success', 'orange', 'warning', 'error', 'errorLight'],
    ),
    _ColorGroup(
      name: AppStrings.themeEditorGroupUi,
      keys: [
        'surfaceLight', 'progressTrack', 'progressFill', 'quizPurple',
        'inputBg', 'infoBg', 'disabled', 'disabledButton', 'progressBorder',
      ],
    ),
    _ColorGroup(
      name: AppStrings.themeEditorGroupCards,
      keys: [
        'cardBlue', 'cardLavender', 'cardPeach', 'cardPeachDark', 'cardYellow',
        'successBg', 'errorBg', 'hintBg', 'hintBorder', 'hintIconColor',
        'orangeBg', 'successBgLight', 'videoDark', 'hintIcon',
        'bannerOrange', 'bannerOrangeDark',
      ],
    ),
    _ColorGroup(
      name: AppStrings.themeEditorGroupAvatars,
      keys: ['avatarFox', 'avatarPanda', 'avatarLion', 'avatarFrog', 'avatarOwl', 'avatarCat'],
    ),
    _ColorGroup(
      name: AppStrings.themeEditorGroupSubjects,
      keys: [
        'subjectGrammar', 'subjectLiterature', 'subjectMath',
        'subjectChemistry', 'subjectBiology',
      ],
    ),
    _ColorGroup(
      name: AppStrings.themeEditorGroupOther,
      keys: ['skillRed', 'skillBlue', 'gradientGold'],
    ),
  ];

  static const _colorLabels = <String, String>{
    'primary': 'Primary color',
    'primaryDark': 'Primary dark',
    'background': 'Background',
    'gradientPurple': 'Gradient',
    'surface': 'Surface',
    'success': 'Success',
    'orange': 'Orange',
    'warning': 'Warning',
    'error': 'Error',
    'errorLight': 'Error light',
    'surfaceLight': 'Surface light',
    'progressTrack': 'Progress – track',
    'progressFill': 'Progress – fill',
    'quizPurple': 'Quiz',
    'inputBg': 'Input field',
    'infoBg': 'Info background',
    'disabled': 'Disabled',
    'disabledButton': 'Disabled button',
    'progressBorder': 'Progress – border',
    'cardBlue': 'Card blue',
    'cardLavender': 'Card lavender',
    'cardPeach': 'Card peach',
    'cardPeachDark': 'Card peach dark',
    'cardYellow': 'Card yellow',
    'successBg': 'Success background',
    'errorBg': 'Error background',
    'hintBg': 'Hint background',
    'hintBorder': 'Hint border',
    'hintIconColor': 'Hint icon',
    'orangeBg': 'Orange background',
    'successBgLight': 'Success background light',
    'videoDark': 'Video dark',
    'hintIcon': 'Hint icon alt',
    'bannerOrange': 'Banner orange',
    'bannerOrangeDark': 'Banner dark',
    'avatarFox': 'Fox',
    'avatarPanda': 'Panda',
    'avatarLion': 'Lion',
    'avatarFrog': 'Frog',
    'avatarOwl': 'Owl',
    'avatarCat': 'Cat',
    'subjectGrammar': 'Grammar',
    'subjectLiterature': 'Literature',
    'subjectMath': 'Mathematics',
    'subjectChemistry': 'Chemistry',
    'subjectBiology': 'Biology',
    'skillRed': 'Skill red',
    'skillBlue': 'Skill blue',
    'gradientGold': 'Gradient gold',
  };

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _revert();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 16),
                    ..._colorGroups.map(_buildGroup),
                    const SizedBox(height: 24),
                    _buildExportButton(),
                    const SizedBox(height: 12),
                    _buildSaveButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
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
            onTap: () {
              _revert();
              (widget.onBack ?? () => Navigator.of(context).pop())();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppDecorations.radiusS,
                boxShadow: AppDecorations.shadowLight,
              ),
              child: Icon(Icons.arrow_back, size: 22, color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: 16),
          Text(AppStrings.themeEditorTitle, style: AppTextStyles.heading2Bold()),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusL,
        boxShadow: AppDecorations.shadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.themeEditorName, style: AppTextStyles.labelMedium()),
          const SizedBox(height: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: AppDecorations.radiusS,
            ),
            child: TextField(
              controller: _nameController,
              style: AppTextStyles.bodySmall(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: AppStrings.themeEditorNameHint,
                hintStyle: AppTextStyles.bodySmall(color: AppColors.primaryDark32),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(_ColorGroup group) {
    final isExpanded = _expanded[group.name] ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusL,
          boxShadow: AppDecorations.shadowLight,
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded[group.name] = !isExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Mini preview dots
                    ...group.keys.take(5).map((k) {
                      final hex = _colors[k] ?? '#CCCCCC';
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _hexToColor(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryDark16,
                              width: 1,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.name,
                        style: AppTextStyles.cardTitleSmall(),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        color: AppColors.primaryDark48,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              ...group.keys.map((key) => _buildColorRow(key)),
            if (isExpanded) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow(String key) {
    final hex = _colors[key] ?? '#CCCCCC';
    final color = _hexToColor(hex);
    final label = _colorLabels[key] ?? key;

    return GestureDetector(
      onTap: () async {
        final result = await ColorPickerDialog.show(
          context,
          initialColor: color,
          label: label,
        );
        if (result != null) {
          setState(() {
            _colors[key] = _colorToHex(result);
          });
          _applyPreview();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryDark16, width: 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.labelMedium()),
                  Text(
                    hex,
                    style: AppTextStyles.caption(color: AppColors.primaryDark48),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 18, color: AppColors.primaryDark32),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return GestureDetector(
      onTap: _exportJson,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusM,
          border: Border.all(color: AppColors.primaryDark16, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.copy, size: 20, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Text(
              AppStrings.themeEditorExport,
              style: AppTextStyles.buttonLarge(color: AppColors.primaryDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _save,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppDecorations.radiusM,
          boxShadow: AppDecorations.shadowMedium,
        ),
        child: Center(
          child: Text(
            AppStrings.themeEditorSave,
            style: AppTextStyles.buttonLarge(color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).substring(2).toUpperCase()}';
  }
}

// ── Helpers ─────────────────────────────────────────────────────────

class _ColorGroup {
  final String name;
  final List<String> keys;
  const _ColorGroup({required this.name, required this.keys});
}
