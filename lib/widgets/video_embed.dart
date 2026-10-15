import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/theme/app_theme.dart';
import '../core/strings/app_strings.dart';

/// Inline MP4 video player with tap-to-play/pause overlay. Owns its
/// [VideoPlayerController] for the lifetime of the widget so callers
/// don't have to manage controller caches manually.
///
/// Used by lesson cards and by news bodies via [MarkdownMediaWidget]. Screens
/// that show many videos at once (the block step engine) pool controllers
/// themselves instead.
class AppVideoEmbed extends StatefulWidget {
  final String videoUrl;

  const AppVideoEmbed({super.key, required this.videoUrl});

  @override
  State<AppVideoEmbed> createState() => _AppVideoEmbedState();
}

class _AppVideoEmbedState extends State<AppVideoEmbed> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.addListener(_onControllerUpdate);
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() {});
    });
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;

    return ClipRRect(
      borderRadius: AppDecorations.radiusM,
      child: Container(
        width: double.infinity,
        height: 200,
        color: AppColors.videoDark,
        child: value.hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 36, color: Colors.white54),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.lessonVideoError,
                      style: AppTextStyles.caption(color: Colors.white54),
                    ),
                  ],
                ),
              )
            : !value.isInitialized
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                        if (!value.isPlaying)
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
