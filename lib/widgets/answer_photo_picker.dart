import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../core/theme/app_text_styles.dart';

/// A photograph the student picked but has not yet sent.
class PickedAnswerPhoto {
  final Uint8List bytes;
  final String filename;

  const PickedAnswerPhoto({required this.bytes, required this.filename});
}

/// Attach-a-photo control for open questions with `allow_photo` (BR-P745Q8).
///
/// Rendered only when the question allows it. The brief is specific that a
/// disabled affordance is not acceptable — when the switch is off the student
/// must not see the option at all — so the decision lives in the caller and
/// this widget assumes it may be shown.
///
/// The picker deliberately caps resolution: an 8 MP phone photo of a page of
/// exercise-book handwriting is legible at 1600px, and the vision model is
/// billed by image tokens. Downscaling on the device also keeps the upload
/// inside the API's size limit without a round trip to find out.
class AnswerPhotoPicker extends StatelessWidget {
  /// Locally picked photo, before upload.
  final PickedAnswerPhoto? picked;

  /// Set once the upload succeeded — the handle the API issued.
  final String? uploadedName;

  final bool isUploading;

  /// The last evaluation said it could not read the photo. Kept attached on
  /// purpose so the student can replace it rather than start over.
  final bool unreadable;

  /// Null disables interaction — used while an evaluation is in flight.
  final ValueChanged<PickedAnswerPhoto>? onPicked;
  final VoidCallback? onRemoved;

  const AnswerPhotoPicker({
    super.key,
    this.picked,
    this.uploadedName,
    this.isUploading = false,
    this.unreadable = false,
    this.onPicked,
    this.onRemoved,
  });

  bool get _hasPhoto => picked != null || uploadedName != null;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();

    final file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    onPicked?.call(
      PickedAnswerPhoto(bytes: bytes, filename: file.name),
    );
  }

  Future<void> _choose(BuildContext context) async {
    // On the web there is no gallery/camera distinction worth offering — the
    // browser shows its own file chooser either way — so skip the sheet.
    if (kIsWeb) {
      await _pick(context, ImageSource.gallery);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(AppStrings.openPhotoCamera),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(AppStrings.openPhotoGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPhoto) {
      // Full-width and filled, matching the block's primary buttons
      // (BR-HF7F2H). As a left-aligned TextButton this read as a footnote, and
      // students answering on paper never found it — yet for those questions
      // the photo is the answer, not a garnish.
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPicked == null ? null : () => _choose(context),
          icon: const Icon(Icons.add_a_photo_outlined, size: 20),
          label: Text(
            AppStrings.openPhotoAdd,
            style: AppTextStyles.buttonLarge(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.disabledButton,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.radiusS,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppDecorations.radiusS,
        border: Border.all(
          color: unreadable ? AppColors.warning : AppColors.primaryDark16,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (picked != null)
                ClipRRect(
                  borderRadius: AppDecorations.radiusS,
                  child: Image.memory(
                    picked!.bytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Icon(Icons.image_outlined, size: 32, color: AppColors.primaryDark80),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isUploading
                      ? AppStrings.openPhotoUploading
                      : AppStrings.openPhotoAttached,
                  style: AppTextStyles.meta(color: AppColors.primaryDark80),
                ),
              ),
              if (isUploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (onRemoved != null)
                IconButton(
                  onPressed: onRemoved,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: AppStrings.openPhotoRemove,
                ),
            ],
          ),
          if (unreadable) ...[
            const SizedBox(height: 6),
            Text(
              AppStrings.openPhotoUnreadable,
              style: AppTextStyles.meta(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}
