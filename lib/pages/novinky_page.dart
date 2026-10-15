import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/core_providers.dart';
import '../core/util/drag_scroll_behavior.dart';
import '../models/news_model.dart';
import 'news_detail_page.dart';
import '../core/layout/breakpoints.dart';

class NovinkyPage extends ConsumerStatefulWidget {
  const NovinkyPage({super.key});

  @override
  ConsumerState<NovinkyPage> createState() => _NovinkyPageState();
}

class _NovinkyPageState extends ConsumerState<NovinkyPage> {
  static const double _listWidth = 360;

  /// Wide layout only. Null until an article is picked.
  int? _openId;

  String _formatDate(DateTime d) => '${d.day}. ${d.month}. ${d.year}';

  Future<void> _refresh() async {
    ref.invalidate(newsListProvider);
    await ref.read(newsListProvider.future);
  }

  /// Open an article: a pane on desktop, a pushed route otherwise.
  void _openArticle(NewsItem item) {
    if (context.isExpanded) {
      setState(() => _openId = item.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewsDetailPage(id: item.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!context.isExpanded) {
      return ContentWidth(
        maxWidth: ContentWidth.reading,
        child: _buildPage(context),
      );
    }

    // Two panes: the feed on the left, the open article on the right. The
    // phone flow pushes the detail as a route; here it is embedded, so the
    // list stays visible and switching articles does not animate the whole
    // view. Same shape as the chat tab (BR-ZT56WM).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: _listWidth, child: _buildPage(context)),
        Container(width: 1, color: AppColors.primaryDark08),
        Expanded(
          child: _openId == null
              ? _buildNoArticleSelected()
              // The pane is as wide as the monitor allows, but an article is
              // prose — left unclamped its lines ran the full width and became
              // unreadable, so the pane sets the measure the embedded page
              // deliberately does not.
              : ContentWidth(
                  maxWidth: ContentWidth.reading,
                  child: NewsDetailPage(
                    // Keyed by article so switching rebuilds the state (the
                    // detail future and its mark-read call) instead of reusing
                    // the previous article's.
                    key: ValueKey(_openId),
                    id: _openId!,
                    embedded: true,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context) {
    final newsAsync = ref.watch(newsListProvider);
    // The desktop top bar already shows the page title.
    final showTitle = !context.isExpanded;
    // The floating bottom bar the list has to clear only exists on phones —
    // the tablet rail and the desktop sidebar are beside the content.
    final isPhone = context.widthClass == WidthClass.compact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (showTitle) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppStrings.novinkyTitle,
              style: AppTextStyles.heading2Bold(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: ScrollConfiguration(
            behavior: const DragScrollBehavior(),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: newsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildEmptyState(),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 0, 16, isPhone ? 120 : 32),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildNewsCard(items[index]),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildErrorState(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard(NewsItem item) {
    // In the two-pane layout the card is what tells the user which article the
    // right-hand pane is showing — without it the panes read as unrelated.
    final isOpen = _openId == item.id && context.isExpanded;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openArticle(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusXL,
          boxShadow: AppDecorations.shadowMedium,
          // Always drawn, so selecting a card does not nudge its contents by
          // the border width.
          border: Border.all(
            color: isOpen ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!item.isRead) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    item.title,
                    style: AppTextStyles.bodyBold(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.perex,
              style: AppTextStyles.bodyLarge(color: AppColors.primaryDark48),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(item.publishedAt),
              style: AppTextStyles.body(color: AppColors.primaryDark48),
            ),
          ],
        ),
      ),
    );
  }

  /// Right-hand pane before the user has picked anything.
  Widget _buildNoArticleSelected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📰', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              AppStrings.novinkyPickArticle,
              style: AppTextStyles.body(color: AppColors.primaryDark48),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📰', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.novinkyEmpty,
              style: AppTextStyles.heading4(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.novinkyError,
              style: AppTextStyles.bodyLarge(color: AppColors.primaryDark64),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.invalidate(newsListProvider),
              child: Text(AppStrings.novinkyRetry),
            ),
          ],
        ),
      ),
    );
  }
}
