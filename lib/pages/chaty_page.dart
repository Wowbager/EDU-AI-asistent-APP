import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/connectivity/connectivity_service.dart';
import '../core/database/app_database.dart';
import '../core/providers/core_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../models/chat_models.dart';
import '../routing/deep_link.dart';
import '../widgets/filter_chip_row.dart';
import 'chat_detail_page.dart';
import 'new_chat_page.dart';
import '../core/layout/breakpoints.dart';

/// Chaty (Chats) page displaying list of conversations backed by Drift DB.
class ChatyPage extends ConsumerStatefulWidget {
  const ChatyPage({super.key});

  @override
  ConsumerState<ChatyPage> createState() => _ChatyPageState();
}

/// The conversation shown in the wide layout's right-hand pane.
class _OpenChat {
  final String sessionId;
  final String title;
  final ChatPersona persona;

  const _OpenChat({
    required this.sessionId,
    required this.title,
    required this.persona,
  });
}

class _ChatyPageState extends ConsumerState<ChatyPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = [AppStrings.filterAll, AppStrings.filterInProgress, AppStrings.chatyEndedFilter];

  /// Width of the conversation list beside the open chat.
  static const double _listWidth = 360;

  /// Wide layout only. Null until a conversation is picked.
  _OpenChat? _openChat;

  bool get _isWide => context.widthClass != WidthClass.compact;

  @override
  void initState() {
    super.initState();
    // A `/chat/:mentor` link that landed here on boot: the slug was parked
    // before this page existed, so nothing would notify us of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final slug = ref.read(pendingChatMentorSlugProvider);
      if (slug != null && slug.isNotEmpty) _openMentorDeepLink(slug);
    });
  }

  /// Open a conversation: a pane on wide, a pushed route on a phone.
  void _openSession(BuildContext context, _OpenChat chat) {
    if (_isWide) {
      setState(() => _openChat = chat);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          sessionId: chat.sessionId,
          sessionTitle: chat.title,
          persona: chat.persona,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // And a link that arrives while the tab is already showing: the shell
    // route is reused across URLs, so this page is not rebuilt from scratch.
    ref.listen<String?>(pendingChatMentorSlugProvider, (_, slug) {
      if (slug != null && slug.isNotEmpty) _openMentorDeepLink(slug);
    });

    if (!_isWide) {
      return ContentWidth(
        maxWidth: ContentWidth.reading,
        child: _buildPage(context),
      );
    }

    // Two panes: conversations on the left, the open one on the right. The
    // phone flow pushes the detail as a route; here it is embedded, so the
    // list stays visible and switching chats does not animate the whole view.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: _listWidth, child: _buildPage(context)),
        Container(width: 1, color: AppColors.primaryDark08),
        Expanded(
          child: _openChat == null
              ? _buildNoChatSelected()
              : ChatDetailPage(
                  // Keyed by session so switching conversations rebuilds the
                  // state (messages, stream subscription) instead of reusing
                  // the previous chat's.
                  key: ValueKey(_openChat!.sessionId),
                  sessionId: _openChat!.sessionId,
                  sessionTitle: _openChat!.title,
                  persona: _openChat!.persona,
                  embedded: true,
                ),
        ),
      ],
    );
  }

  Widget _buildNoChatSelected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💬', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              AppStrings.chatyPickConversation,
              style: AppTextStyles.body(color: AppColors.primaryDark48),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final sessionsAsync = ref.watch(chatSessionsStreamProvider);
    final connectivityAsync = ref.watch(connectivityStateProvider);
    final isOffline = connectivityAsync.whenOrNull(
      data: (state) => !state.isOnline,
    ) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.orange,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.chatyOfflineBanner,
                      style: AppTextStyles.caption(color: Colors.white),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildHeader(context),
            const SizedBox(height: 16),
            // Filter chips
            FilterChipRow(
              labels: _filters,
              selectedIndex: _selectedFilterIndex,
              onSelected: (index) {
                setState(() {
                  _selectedFilterIndex = index;
                });
              },
            ),
            const SizedBox(height: 16),
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 1,
                color: AppColors.primaryDark08,
              ),
            ),
            const SizedBox(height: 8),
            // Sessions list / empty / loading
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) => sessions.isEmpty
                    ? _buildEmptyState()
                    : _buildSessionList(sessions, context),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(AppStrings.genericError(e.toString()))),
              ),
            ),
            _buildInfoBanner(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    // The heading lives here on every width. On desktop it used to be dropped
    // in favour of the shell's top bar, which left the "new chat" button a row
    // below the title it belongs next to — and cost the conversation pane the
    // bar's height. The shell now hides that bar for this tab (BR-7VMQ2U), so
    // the column reclaims the space it was said to be wasting.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            AppStrings.chatyTitle,
            style: AppTextStyles.heading1(),
          ),
          const Spacer(),
          // New chat button
          GestureDetector(
            onTap: () => _startNewChat(context),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/plus.svg',
                    width: 18,
                    height: 18,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.chatyNewChat,
                    style: AppTextStyles.actionSmall(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Session list
  // ---------------------------------------------------------------------------

  Widget _buildSessionList(
    List<ChatSessionsTableData> sessions,
    BuildContext context,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < sessions.length - 1 ? 12 : 0,
          ),
          child: _buildSessionCard(sessions[index], context),
        );
      },
    );
  }

  Widget _buildSessionCard(
    ChatSessionsTableData session,
    BuildContext context,
  ) {
    final persona = session.chatPersona;
    final title = (session.title.isNotEmpty) ? session.title : persona.displayName;
    final timeStr = _formatRelativeTime(session.lastMessageAt);

    final bgColor = _avatarColorForPersona(persona);

    return GestureDetector(
      onTap: () => _openSession(
        context,
        _OpenChat(sessionId: session.id, title: title, persona: persona),
      ),
      onLongPress: () => _showDeleteDialog(context, session),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusXL,
          boxShadow: AppDecorations.shadowLight,
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  persona.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name and persona
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.statValue(),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    persona.displayName,
                    style: AppTextStyles.bodySmall(
                      color: AppColors.primaryDark64,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Timestamp aligned right
            Text(
              timeStr,
              style: AppTextStyles.caption(
                color: AppColors.primaryDark48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💬', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              AppStrings.chatEmptyState,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark48),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Info banner
  // ---------------------------------------------------------------------------

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: AppColors.primaryDark48,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.chatyInfoBanner,
              style: AppTextStyles.caption(color: AppColors.primaryDark48),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // New chat
  // ---------------------------------------------------------------------------

  /// Open the conversation a `/chat/:mentor` deep link asked for (BR-HCF5AS).
  ///
  /// The link only names a mentor, so it goes through the same path as picking
  /// one out of the new-chat list. Consumed before the session is created: the
  /// await below gives the page time to rebuild, and a slug still sitting in
  /// the provider would start a second chat.
  Future<void> _openMentorDeepLink(String slug) async {
    ref.read(pendingChatMentorSlugProvider.notifier).state = null;

    // The server list first, so a mentor added in the admin resolves too; the
    // repository already falls back to this build's mentors when it is offline
    // or the request fails, and this adds them again in case it threw.
    List<ChatMentor> mentors;
    try {
      mentors = await ref.read(chatMentorsProvider.future);
    } catch (_) {
      mentors = const [];
    }
    if (!mounted) return;

    ChatMentor? mentor;
    for (final candidate in [...mentors, ...ChatMentor.builtIns]) {
      if (candidate.slug == slug) {
        mentor = candidate;
        break;
      }
    }

    if (mentor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.chatMentorNotFound(slug))),
      );
      return;
    }

    // Resume rather than start over: the link is a bookmark, not a "new chat"
    // button, and on the web build reopening it is how a student comes back to
    // the conversation (BR-VC5HPV).
    await _createSessionAndNavigate(mentor, context, resumeExisting: true);
  }

  /// The mentor list used to be a bottom sheet of emoji tiles; it is now the
  /// designed "Novy chat" screen (BR-E8ZQP2), which knows nothing about chat
  /// sessions -- it hands back a mentor and this page starts the conversation.
  Future<void> _startNewChat(BuildContext context) async {
    final mentor = await showNewChatPicker(context);
    if (mentor == null || !context.mounted) return;

    await _createSessionAndNavigate(mentor, context);
  }

  /// [resumeExisting] reopens the student's last conversation with this mentor
  /// instead of starting another one — what a `/chat/:mentor` link means.
  Future<void> _createSessionAndNavigate(
    ChatMentor mentor,
    BuildContext context, {
    bool resumeExisting = false,
  }) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final user = await ref.read(activeUserProvider.future);
      if (user == null) return;

      final session = resumeExisting
          ? await chatRepo.resumeOrCreateSession(user.id, mentor.slug)
          : await chatRepo.createSession(user.id, mentor.slug);

      if (context.mounted) {
        _openSession(
          context,
          _OpenChat(
            sessionId: session.id,
            title: session.title.isNotEmpty ? session.title : mentor.name,
            persona: mentor.persona,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.chatRequiresInternet),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete confirmation
  // ---------------------------------------------------------------------------

  void _showDeleteDialog(
    BuildContext context,
    ChatSessionsTableData session,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.chatDelete),
        content: Text(AppStrings.chatDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.actionCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final chatRepo = ref.read(chatRepositoryProvider);
              await chatRepo.deleteSession(session.id);
            },
            child: Text(
              AppStrings.chatDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _avatarColorForPersona(ChatPersona persona) {
    switch (persona) {
      case ChatPersona.aiTeacher:
        return AppColors.background;
      case ChatPersona.mathMentor:
        return AppColors.successBg;
      case ChatPersona.studyCoach:
        return AppColors.cardBlue;
      case ChatPersona.languageMentor:
        return AppColors.cardBlue;
      case ChatPersona.skolnik:
        return AppColors.background;
      case ChatPersona.cermatik:
        return AppColors.successBg;
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return AppStrings.chatyTimeNow;
    if (diff.inMinutes < 60) return AppStrings.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return AppStrings.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return AppStrings.timeDaysAgoShort(diff.inDays);
    return '${dateTime.day}.${dateTime.month}.';
  }
}
