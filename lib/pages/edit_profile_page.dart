import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/consent/minor_mode.dart';
import '../core/providers/core_providers.dart';
import '../core/services/classroom_join_service.dart';
import '../core/sync/sync_queue.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';
import '../core/util/classroom_join_flow.dart';
import '../widgets/page_header.dart';
import '../widgets/user_avatar.dart';
import '../core/layout/breakpoints.dart';

/// Edit Profile page - update name, email is read-only.
class EditProfilePage extends ConsumerStatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback? onBack;

  const EditProfilePage({
    super.key,
    required this.userName,
    required this.userEmail,
    this.onBack,
  });

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late TextEditingController _nameController;
  bool _isLoading = false;
  String? _errorMessage;

  /// Classes the user is in (BR-3V2P22). Server-only — membership is not
  /// mirrored into Drift, so this is null while loading and stays null
  /// offline, in which case the list is simply not rendered.
  List<ClassroomSummary>? _classrooms;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    if (!canJoinClassroom(ref)) return;
    final result = await ref.read(classroomJoinServiceProvider).myClassrooms();
    if (!mounted || result.isFailure) return;
    setState(() => _classrooms = result.data);
  }

  Future<void> _joinClassroom() async {
    final result = await showClassroomCodeDialog(context, ref);
    if (!mounted || result == null || !result.isJoined) return;
    await _loadClassrooms();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      setState(() {
        _errorMessage = AppStrings.editProfileEmptyNameError;
      });
      return;
    }

    if (newName == widget.userName) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final syncQueue = ref.read(syncQueueProvider);

      // Update locally first and mark as pending sync.
      final activeUser = await db.getActiveUser();
      if (activeUser != null) {
        await db.updateUserName(activeUser.id, newName);
        await db.updateUserSyncStatus(activeUser.id, 1); // pending

        // Queue for sync — will be pushed when online.
        await syncQueue.enqueue(
          tableName: 'users',
          recordId: activeUser.id,
          operation: SyncOperation.update,
          payload: {'name': newName},
        );
      }

      if (mounted) {
        Navigator.of(context).pop(newName);
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppStrings.editProfileSaveError;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      ContentWidth(maxWidth: ContentWidth.reading, child: _buildPage(context));

  /// This page has no wide layout yet, so [ContentWidth] keeps it at phone
  /// width instead of stretching it across a monitor.
  Widget _buildPage(BuildContext context) {
    final isMinor = ref.watch(minorModeProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Header with back and save
            _buildHeader(),
            const SizedBox(height: 32),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar — read-only here, the shop is where it is
                    // assembled. It is on this screen because "my profile"
                    // without the face the user built reads as someone else's
                    // (BR-D6W3CR).
                    _buildAvatar(),
                    const SizedBox(height: 32),
                    // Name field
                    _buildLabel(AppStrings.editProfileNameLabel),
                    const SizedBox(height: 8),
                    _buildNameField(isMinor),
                    const SizedBox(height: 24),
                    // Email field (read-only)
                    _buildLabel(AppStrings.editProfileEmailLabel),
                    const SizedBox(height: 8),
                    _buildEmailField(),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.editProfileEmailReadonly,
                      style: AppTextStyles.meta(color: AppColors.primaryDark48),
                    ),
                    // Classes (BR-3V2P22): the second place, next to the
                    // library's code box, where a student who already has an
                    // account can type the code their teacher handed out.
                    // Hidden for guests and minors, who cannot join.
                    if (canJoinClassroom(ref)) ...[
                      const SizedBox(height: 24),
                      _buildLabel(AppStrings.editProfileClassroomsLabel),
                      const SizedBox(height: 8),
                      _buildClassrooms(),
                      const SizedBox(height: 12),
                      _buildJoinClassroomButton(),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: AppDecorations.radiusS,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextStyles.bodySmall(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Save button
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return PageHeader(
      title: AppStrings.editProfileTitle,
      onBack: widget.onBack,
    );
  }

  Widget _buildAvatar() {
    final avatarIndex =
        ref.watch(activeUserStreamProvider).valueOrNull?.avatarIndex ?? 0;

    return Center(
      child: UserAvatar(size: 96, avatarIndex: avatarIndex),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelMedium(color: AppColors.primaryDark64),
    );
  }

  Widget _buildNameField(bool isMinor) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusM,
        boxShadow: AppDecorations.shadowLight,
      ),
      child: TextField(
        controller: _nameController,
        enabled: !isMinor,
        style: AppTextStyles.statSuffix(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
          hintText: AppStrings.editProfileNameHint,
          hintStyle: AppTextStyles.statSuffix(color: AppColors.primaryDark32),
          helperText: isMinor ? AppStrings.minorNameLocked : null,
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.04),
        borderRadius: AppDecorations.radiusM,
        border: Border.all(
          color: AppColors.primaryDark08,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.userEmail,
              style: AppTextStyles.statSuffix(color: AppColors.primaryDark48),
            ),
          ),
          Icon(
            Icons.lock_outline,
            size: 18,
            color: AppColors.primaryDark32,
          ),
        ],
      ),
    );
  }

  Widget _buildClassrooms() {
    final classrooms = _classrooms;

    // Still loading, or offline: show nothing rather than a wrong "none".
    if (classrooms == null) return const SizedBox.shrink();

    if (classrooms.isEmpty) {
      return Text(
        AppStrings.editProfileNoClassrooms,
        style: AppTextStyles.meta(color: AppColors.primaryDark48),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in classrooms)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppDecorations.radiusM,
              boxShadow: AppDecorations.shadowLight,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(c.name, style: AppTextStyles.bodySmall()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildJoinClassroomButton() {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _joinClassroom,
      icon: const Icon(Icons.add, size: 18),
      label: Text(AppStrings.classroomJoinTitle),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: AppDecorations.radiusM),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _saveProfile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isLoading
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.primary,
          borderRadius: AppDecorations.radiusM,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  AppStrings.editProfileSaveButton,
                  style: AppTextStyles.statValueAlt(color: Colors.white),
                ),
        ),
      ),
    );
  }
}
