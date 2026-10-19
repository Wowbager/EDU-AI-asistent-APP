// The question mark in a played preview, wired the way `lesson_detail_page` wires
// it: always passed to the engine, which offers it on a step that has a hint
// (`ContentBlock.hasHintForStep`) and reports which step was tapped, opening the
// app's own sheet scoped to that step.
//
// Everything the sheet would record — the hint penalty, the practice bookmark, the
// AI mentor, feedback to the teacher — has nowhere to go in a preview, so it goes
// nowhere. The sheet itself is `showMentorSheet`, unchanged, so what the author
// reads is what the pupil reads. It runs with `allowAi: false`, as in a graded
// test: the sheet stops at the help text and reads no provider, and the practice
// option is hidden because there is no bookmark store.

import 'package:flutter/material.dart';

import '../models/course_model.dart';
import '../pages/lesson_detail/mentor_sheet.dart';

void showPreviewHint(BuildContext context, ContentBlock block, String? stepId) {
  if (!block.hasHintForStep(stepId)) return;
  showMentorSheet(
    context: context,
    block: block,
    stepId: stepId,
    buildAiContext: () => '',
    onShown: () {},
    onEscalateToHelp: () {},
    onAskMentor: (_, {required isFirst}) {},
    allowAi: false,
  );
}
