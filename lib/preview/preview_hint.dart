// The question mark in a played preview, wired the way `lesson_detail_page` wires
// it: gated on `block.hasHint`, opening the app's own sheet.
//
// Everything the sheet would record — the hint penalty, the practice bookmark, the
// AI chat, feedback to the teacher — has nowhere to go in a preview, so it goes
// nowhere. The sheet itself is `showLessonHintSheet`, unchanged, so what the author
// reads is what the pupil reads.

import 'package:flutter/material.dart';

import '../models/course_model.dart';
import '../pages/lesson_detail/hint_sheet.dart';

void showPreviewHint(BuildContext context, ContentBlock block) {
  if (!block.hasHint) return;
  showLessonHintSheet(
    context: context,
    block: block,
    onShown: () {},
    onEscalateToHelp: () {},
    onSavePractice: () {},
    onAskAi: () {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('V náhledu asistent není k dispozici.')),
      );
    },
    onSendFeedback: (_) {},
  );
}
