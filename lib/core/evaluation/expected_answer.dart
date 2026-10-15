// Comparison grading for open questions, used when the AI cannot grade them.
//
// Every open answer goes to the AI first (BR-N26ACB). This is the fallback for
// when it cannot — offline, a timeout, an error — whatever the question's
// `ai_evaluation` switch says.
//
// The expected answer lists every accepted variant on its own line (BR-RBUR29)
// — "1/4", "čtvrtina", "čtvrtka" — and an answer is right when it equals any
// of them, ignoring case and surrounding whitespace. A one-line expected
// answer grades exactly as it always has.
//
// Splitting on newlines cannot flip an existing verdict: the answer field of
// an exact-match question is single-line, so no student could ever have typed
// a match for a multi-line expected answer.
//
// The expected answer is only ever compared against, never shown: authors
// write it as a grading key, and the editor promises them the student never
// sees it (BR-RBUR29, BR-N26ACB).
library;

/// The accepted variants, trimmed, with blank lines dropped.
List<String> expectedAnswerVariants(String? expected) {
  if (expected == null) return const [];
  return expected
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

/// Whether [answer] matches one of the variants in [expected].
///
/// Nothing to compare against is never a match.
bool matchesExpectedAnswer(String answer, String? expected) {
  final normalized = answer.trim().toLowerCase();
  return expectedAnswerVariants(expected)
      .any((variant) => variant.toLowerCase() == normalized);
}
