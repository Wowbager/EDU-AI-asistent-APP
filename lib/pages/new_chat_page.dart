import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/breakpoints.dart';
import '../core/providers/core_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../models/chat_models.dart';
import '../widgets/mentor_card.dart';
import '../widgets/page_header.dart';

/// Ask the user which mentor to start a chat with.
///
/// Resolves to the chosen mentor, or null if the picker was dismissed. A
/// pushed route on a phone and a dialog on desktop — the chat tab's wide
/// layout keeps the conversation list and the open chat side by side, and a
/// full-screen route would cover both.
Future<ChatMentor?> showNewChatPicker(BuildContext context) {
  if (!context.isExpanded) {
    return Navigator.push<ChatMentor>(
      context,
      MaterialPageRoute(builder: (_) => const NewChatPage()),
    );
  }

  return showDialog<ChatMentor>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
        child: ClipRRect(
          borderRadius: AppDecorations.radiusXL,
          child: const NewChatPage(),
        ),
      ),
    ),
  );
}

/// The "Nový chat" mentor list (Figma 515:475).
///
/// Pops with the selected [ChatMentor]; creating the session is the caller's
/// job, because on desktop the new chat opens in a pane rather than a route.
class NewChatPage extends ConsumerStatefulWidget {
  const NewChatPage({super.key});

  @override
  ConsumerState<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends ConsumerState<NewChatPage> {
  @override
  void initState() {
    super.initState();
    // The mentor list is app-scoped, so without this it stays whatever was
    // fetched the first time the picker opened — a mentor switched off in the
    // admin kept being offered until the app was restarted (BR-EER4ME).
    // Refreshing keeps the previous list on screen while the request runs, so
    // there is no flash of the compiled-in six. After the first frame, because
    // a provider cannot be read while initState is still running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(chatMentorsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Server-driven so a mentor added in the admin needs no app release. If the
    // request fails, or the device is offline, the repository stands in with
    // the last list the server sent, or the mentors compiled into this build
    // until there is one, so the screen is never empty on a fresh install
    // (BR-N7FC2B).
    final mentorsAsync = ref.watch(chatMentorsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ContentWidth(
          maxWidth: ContentWidth.reading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              PageHeader(title: AppStrings.chatyNewChat),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppStrings.newChatSubtitle,
                  style: AppTextStyles.caption(color: AppColors.primaryDark48),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: mentorsAsync.when(
                  data: _buildList,
                  // Nothing the server has vouched for yet: the compiled-in
                  // six used to stand in here, so a mentor switched off in the
                  // admin topped the list until the answer arrived
                  // (BR-YSPPYA). A refresh keeps the previous list instead.
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _buildList(ChatMentor.builtIns),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<ChatMentor> mentors) {
    // Every mentor switched off in the admin means there is genuinely nothing
    // to pick, so say that instead of listing mentors the server would refuse
    // (BR-EER4ME).
    if (mentors.isEmpty) return _buildEmpty();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: mentors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (_, index) {
        final mentor = mentors[index];
        return MentorCard(
          mentor: mentor,
          onTap: () => Navigator.pop(context, mentor),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          AppStrings.newChatNoMentors,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(color: AppColors.primaryDark48),
        ),
      ),
    );
  }
}
