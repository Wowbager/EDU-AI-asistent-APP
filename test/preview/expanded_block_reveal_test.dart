import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/theme/app_colors.dart';
import 'package:eduai/models/block_model.dart';
import 'package:eduai/models/step_navigation.dart';
import 'package:eduai/preview/preview_expanded_block.dart';

// "Náhled" draws every question as answered so the author reads its feedback and
// solution, but nobody answered it. Grading that empty answer made a multi-select
// question read „Špatně“ with its right answers in red — the preview calling the
// author's own key wrong. Whatever the type, nothing on the card may say wrong.

ContentBlock _block(Map<String, dynamic> question) {
  return ContentBlock.fromJson({
    'block_id': 'B1',
    'type': 'question',
    'steps': [
      {
        'id': 's1',
        'type': 'question',
        'order': 1,
        'content': 'Otázka',
        'question': question,
      },
    ],
  });
}

const _options = [
  {'id': 'o1', 'text': 'Ano', 'is_correct': false, 'feedback': 'Skoro'},
  {'id': 'o2', 'text': 'Ne', 'is_correct': true, 'feedback': 'Správně'},
];

final _questions = <String, Map<String, dynamic>>{
  'single choice': {'type': 'multiple_choice', 'options': _options},
  'several picks': {
    'type': 'multiple_choice',
    'allow_multiple': true,
    'options': _options,
  },
  'true/false': {
    'type': 'true_false',
    'options': [
      {'id': 'true', 'text': 'Ano', 'is_correct': true},
      {'id': 'false', 'text': 'Ne', 'is_correct': false},
    ],
  },
  'number': {'type': 'numeric', 'correct_number': 7},
  'open answer': {'type': 'open', 'correct_answer': 'sedm'},
};

bool _isError(Color? color) =>
    color != null && color.toARGB32() == AppColors.error.toARGB32();

/// Anything painted in the error colour: an option card's border, a field's
/// outline, a verdict's icon.
int _redThings(WidgetTester tester) {
  var count = 0;
  for (final box in tester.widgetList<Container>(find.byType(Container))) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration) {
      final border = decoration.border;
      if (border is Border && _isError(border.top.color)) count++;
    }
  }
  for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
    final border = field.decoration?.disabledBorder;
    if (border is OutlineInputBorder && _isError(border.borderSide.color)) count++;
  }
  for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
    if (_isError(icon.color)) count++;
  }
  return count;
}

void main() {
  for (final entry in _questions.entries) {
    testWidgets('Náhled grades nothing on a ${entry.key} question', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreviewExpandedBlock(
              block: _block(entry.value),
              exportMode: ExportMode.courseV2,
              onRefTapped: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(_redThings(tester), 0);
    });
  }
}
