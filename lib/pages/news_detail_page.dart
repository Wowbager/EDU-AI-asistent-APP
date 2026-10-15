import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/core_providers.dart';
import '../core/util/silent_log.dart';
import '../models/news_model.dart';
import '../widgets/markdown_media_widget.dart';
import '../core/layout/breakpoints.dart';

class NewsDetailPage extends ConsumerStatefulWidget {
  final int id;

  /// Rendered as the right-hand pane of the two-pane Novinky layout rather
  /// than as a route of its own: no scaffold, no app bar, no width clamp —
  /// the pane supplies all three.
  final bool embedded;

  const NewsDetailPage({
    super.key,
    required this.id,
    this.embedded = false,
  });

  @override
  ConsumerState<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends ConsumerState<NewsDetailPage> {
  late Future<NewsItem> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<NewsItem> _loadDetail() async {
    final repository = ref.read(newsRepositoryProvider);
    final item = await repository.fetchDetail(widget.id);
    // Mark as read once, update the unread badge and refresh the list so the
    // read state is reflected when the user returns.
    _markRead();
    return item;
  }

  Future<void> _markRead() async {
    try {
      final newCount = await ref.read(newsRepositoryProvider).markRead(widget.id);
      if (!mounted) return;
      ref.read(unreadNewsCountProvider.notifier).set(newCount);
      ref.invalidate(newsListProvider);
    } catch (e, st) {
      silentLog('news:mark-read', e, st);
    }
  }

  String _formatDate(DateTime d) => '${d.day}. ${d.month}. ${d.year}';

  @override
  Widget build(BuildContext context) {
    // Embedded: the pane is already the right size and carries the chrome.
    if (widget.embedded) return _buildBody(context);

    // Pushed as a route. Only reachable below `expanded` — the desktop layout
    // opens articles in the pane instead — so this is the unchanged phone and
    // tablet presentation.
    return ContentWidth(
      maxWidth: ContentWidth.reading,
      child: _buildRoutePage(context),
    );
  }

  Widget _buildRoutePage(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryDark),
        title: Text(
          AppStrings.novinkyTitle,
          style: AppTextStyles.heading3(),
        ),
      ),
      body: _buildBody(context),
    );
  }

  /// The article itself. The heading is the article's own title — the section
  /// name is left to whatever chrome is wrapping this (the phone app bar, the
  /// desktop top bar), so the two never stack up as a double heading
  /// (BR-ZT56WM).
  Widget _buildBody(BuildContext context) {
    // The 120px tail clears the floating bottom bar, which only exists on the
    // phone layout.
    final bottomPadding =
        context.widthClass == WidthClass.compact ? 120.0 : 32.0;

    return FutureBuilder<NewsItem>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildError();
        }

        final item = snapshot.data!;
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
          children: [
            Text(
              item.title,
              style: AppTextStyles.heading2Bold(),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(item.publishedAt),
              style: AppTextStyles.body(color: AppColors.primaryDark48),
            ),
            const SizedBox(height: 16),
            MarkdownMediaWidget(content: item.body ?? item.perex),
          ],
        );
      },
    );
  }

  Widget _buildError() {
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
              onPressed: () {
                setState(() {
                  _detailFuture = _loadDetail();
                });
              },
              child: Text(AppStrings.novinkyRetry),
            ),
          ],
        ),
      ),
    );
  }
}
