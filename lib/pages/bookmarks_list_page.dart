import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/providers/core_providers.dart';
import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'package:eduai/core/util/silent_log.dart';
import '../core/layout/breakpoints.dart';

/// A page that displays all saved bookmarks grouped by course.
class BookmarksListPage extends ConsumerStatefulWidget {
  const BookmarksListPage({super.key});

  @override
  ConsumerState<BookmarksListPage> createState() => _BookmarksListPageState();
}

class _BookmarksListPageState extends ConsumerState<BookmarksListPage> {
  List<_BookmarkGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final db = ref.read(appDatabaseProvider);
    final user = await db.getActiveUser();
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final bookmarks = await db.getAllBookmarks(user.id);
    if (bookmarks.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Group bookmarks by courseId
    final grouped = <String, List<BookmarksTableData>>{};
    for (final bm in bookmarks) {
      grouped.putIfAbsent(bm.courseId, () => []).add(bm);
    }

    // For each course, resolve name + block previews
    final groups = <_BookmarkGroup>[];
    for (final entry in grouped.entries) {
      final courseId = entry.key;
      final courseBookmarks = entry.value;

      final courseRow = await db.getCourseByFieldCourseId(courseId);

      String courseName = courseId;
      String courseEmoji = '📖';
      Map<String, dynamic>? courseData;

      if (courseRow != null) {
        courseName = courseRow.name;
        try {
          final parsed = jsonDecode(courseRow.data);
          if (parsed is Map<String, dynamic>) {
            courseData = parsed;
            courseEmoji = parsed['emoji'] as String? ?? '📖';
            // Prefer name from data if available
            final dataName = parsed['name'] as String?;
            if (dataName != null && dataName.isNotEmpty) {
              courseName = dataName;
            }
          }
        } catch (e, st) { silentLog('bookmarks_list_page', e, st); }
      }

      // Build block lookup map from course data
      final blockMap = <String, Map<String, dynamic>>{};
      if (courseData != null) {
        final blocks = courseData['blocks'] as List<dynamic>? ?? [];
        for (final b in blocks) {
          if (b is Map<String, dynamic>) {
            final bid = b['block_id'] as String?;
            if (bid != null) blockMap[bid] = b;
          }
        }
      }

      final items = <_BookmarkItem>[];
      for (final bm in courseBookmarks) {
        // Handle composite blockId (may contain ":" for step-level bookmarks)
        final rawBlockId = bm.blockId;
        final blockIdPart = rawBlockId.contains(':')
            ? rawBlockId.split(':').first
            : rawBlockId;

        String preview = '';
        String blockType = 'display';

        final blockJson = blockMap[blockIdPart];
        if (blockJson != null) {
          blockType = blockJson['type'] as String? ?? 'display';
          preview = _extractPreview(blockJson);
        } else if (courseData == null) {
          preview = AppStrings.bookmarksListCourseNotDownloaded;
        }

        items.add(_BookmarkItem(
          blockId: rawBlockId,
          preview: preview,
          blockType: blockType,
          createdAt: bm.createdAt,
        ));
      }

      groups.add(_BookmarkGroup(
        courseId: courseId,
        courseName: courseName,
        courseEmoji: courseEmoji,
        items: items,
      ));
    }

    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    }
  }

  /// Extract a text preview from a block JSON.
  /// Strips HTML tags and truncates.
  String _extractPreview(Map<String, dynamic> blockJson) {
    // Try direct content first (atomic format)
    final content = blockJson['content'] as String?;
    if (content != null && content.isNotEmpty) {
      return _stripHtmlAndTruncate(content);
    }

    // Try steps — find first step with content
    final steps = blockJson['steps'];
    if (steps is List) {
      for (final step in steps) {
        if (step is Map<String, dynamic>) {
          final stepContent = step['content'] as String?;
          if (stepContent != null && stepContent.isNotEmpty) {
            return _stripHtmlAndTruncate(stepContent);
          }
          // Also check question text
          final question = step['question'] as Map<String, dynamic>?;
          final qText = question?['text'] as String?;
          if (qText != null && qText.isNotEmpty) {
            return _stripHtmlAndTruncate(qText);
          }
        }
      }
    } else if (steps is Map<String, dynamic>) {
      for (final entry in steps.entries) {
        if (entry.value is Map<String, dynamic>) {
          final stepData = entry.value as Map<String, dynamic>;
          final stepContent = stepData['content'] as String?;
          if (stepContent != null && stepContent.isNotEmpty) {
            return _stripHtmlAndTruncate(stepContent);
          }
        }
      }
    }

    // Try question.text (atomic question format)
    final question = blockJson['question'] as Map<String, dynamic>?;
    final qText = question?['text'] as String?;
    if (qText != null && qText.isNotEmpty) {
      return _stripHtmlAndTruncate(qText);
    }

    return '';
  }

  String _stripHtmlAndTruncate(String html, {int maxLength = 120}) {
    // Remove HTML tags
    final stripped = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.length <= maxLength) return stripped;
    return '${stripped.substring(0, maxLength)}…';
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return AppStrings.timeJustNow;
    if (diff.inMinutes < 60) return AppStrings.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return AppStrings.timeHoursAgo(diff.inHours);
    if (diff.inHours < 48) return AppStrings.timeYesterday;
    return AppStrings.timeDaysAgo(diff.inDays);
  }

  IconData _iconForBlockType(String type) {
    switch (type) {
      case 'exercise':
      case 'question':
      case 'quiz':
        return Icons.help_outline;
      case 'display':
      case 'content':
      case 'learning':
        return Icons.article_outlined;
      case 'motivation':
        return Icons.lightbulb_outline;
      default:
        return Icons.article_outlined;
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
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _groups.isEmpty
                      ? _buildEmptyState()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: AppDecorations.shadowStrong,
              ),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.primaryDark,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            AppStrings.bookmarksListTitle,
            style: AppTextStyles.heading3(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppColors.primaryDark32,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.bookmarksListEmpty,
              style: AppTextStyles.bodySmall(color: AppColors.primaryDark64),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header: emoji + name + count
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      group.courseEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.courseName,
                        style: AppTextStyles.subtitle(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${group.items.length}',
                        style: AppTextStyles.labelMedium(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bookmark items card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppDecorations.radiusM,
                  boxShadow: AppDecorations.shadowLight,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < group.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _buildBookmarkRow(group.items[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookmarkRow(_BookmarkItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type icon
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              _iconForBlockType(item.blockType),
              size: 18,
              color: AppColors.primaryDark64,
            ),
          ),
          const SizedBox(width: 10),
          // Preview text
          Expanded(
            child: Text(
              item.preview.isNotEmpty ? item.preview : item.blockId,
              style: AppTextStyles.bodySmall(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Relative date
          Text(
            _formatRelativeDate(item.createdAt),
            style: AppTextStyles.labelMedium(
              color: AppColors.primaryDark32,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private data classes ──

class _BookmarkGroup {
  final String courseId;
  final String courseName;
  final String courseEmoji;
  final List<_BookmarkItem> items;

  const _BookmarkGroup({
    required this.courseId,
    required this.courseName,
    required this.courseEmoji,
    required this.items,
  });
}

class _BookmarkItem {
  final String blockId;
  final String preview;
  final String blockType;
  final DateTime createdAt;

  const _BookmarkItem({
    required this.blockId,
    required this.preview,
    required this.blockType,
    required this.createdAt,
  });
}
