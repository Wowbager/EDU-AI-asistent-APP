# Preview mode

The surface the course editor embeds. Small and additive: nothing in the student's
app changes, and nothing here runs unless someone opens `/preview`.

## What it adds

| File | What it is |
|---|---|
| `preview_page.dart` | A bare scaffold at `/preview`, **outside `AuthWrapper`**, that renders a block or a lesson from JSON posted in by the editor. |
| `preview_channel*.dart` | The `postMessage` channel. Web-only; the stub keeps mobile and desktop compiling. |
| `preview_mode.dart` | `PreviewScope` / `PreviewMode`, and `PreviewTarget` — the hit-target that reports a `Ref` and draws a hover outline. |
| `preview_ref.dart` | The editor's address for a place in the document. |
| `preview_expanded_block.dart` | **Náhled**: one card, every step at once, with the card's own buttons — none of which can advance anything. |
| `preview_lesson_player.dart` | **Vyzkoušet**: the lesson as a pupil takes it, with back. |

Three files outside this folder change:

- `routing/app_router.dart` — one new route.
- `widgets/step_content_renderer.dart` — passive leaves are wrapped in
  `PreviewTarget`. Outside preview mode `PreviewTarget` returns its child and
  nothing else, so a student's session gains no widget and no rebuild.
- `widgets/block_action_buttons.dart` — the block's action bar and main button,
  extracted from `BlockStepEngine` so that both the engine and Náhled draw the same
  ones. The engine kept the decisions (which label, enabled, complete); the new file
  only paints. A student's session is unchanged.

## The contract

```
editor → player   setBlock {block, exportMode, view, stepId?, remount?, blockLabels?}
                  setLesson {course, lessonId, exportMode, view, startBlockId?}
                  highlight {ref}
                  back
                  restart
                  reset

player → editor   ready
                  stepChanged {stepId, blockId?}
                  clicked {ref}
                  completed {xp, scoreKoef, mark?}
                  navState {canGoBack}
```

`view` is `expanded` or `play`. `blockLabels` maps a `block_id` to what the branch
markers should call it — the player holds one card and cannot look another one up, and
must never print an id, because a teacher is not allowed to see one (plan §8).

Messages are JSON strings, and only from the same origin — the player is served under
`/player/` on the editor's own host.

## Why nothing is written

`BlockStepEngine` owns no persistence: it reports through callbacks and the page
above decides what they mean. `PreviewPage` wires them to the channel or to nothing,
so no progress is saved, no XP awarded, no practice card enrolled, no API called.

`PreviewMode.sideEffectsSuppressed` exists for the code that is *not* here yet. Check
it at the point of effect, not at the call site:

```dart
if (PreviewMode.read(context).sideEffectsSuppressed) return;
await _progressRepository.save(progress);
```

## The two modes

**Náhled** (`PreviewExpandedBlock`) stacks one `StepContentRenderer` per step, with the
same action row underneath from `block_action_buttons.dart`, and **no engine**. It
renders every question as though answered (`StepAnswerState(isAnswered: true)`,
nothing selected) so the author sees the feedback and the solution they wrote, and it
draws preview-only markers for branch targets, hints and help.

**What makes it inert is where the callbacks go, not the absence of buttons.** An
earlier version of this file said the opposite — "there is no button because none was
built" — and that was a consequence mistaken for a cause; the cost was a preview of a
card that omitted the card's own controls, so the author could not see whether the
question mark appears at all or what a quiz card looks like with the thumbs stripped
out. `BlockStepEngine` is still not mounted, so `_currentStepIndex`, `_stepAnswers`,
`onStepProgress` and `onBlockCompleted` are not in the tree: `stepChanged` and
`completed` are impossible here by construction. Every tap terminates in
`onRefTapped`.

The row is drawn in its **completed** state — the green check, not a greyed
"Zkontrolovat". The engine's own name for a step rendered with its answer and solution
showing is a *history* step, and this is the row it pairs with one.

The question mark is gated **per step**, on `step.hint ?? block.hint` /
`step.help ?? block.help`, because every step is on screen at once here: it appears
exactly where the engine would show it if that step were current.

**Vyzkoušet** (`PreviewLessonPlayer`) mirrors `lesson_detail_page`: a growing list,
one `isCurrent` block, auto-advance and scroll on completion. Cross-block `go_to`
actually jumps, so branching is testable.

`back` is not in the engine, and deliberately so: `_currentStepIndex` only ever
increments, and rewriting that would make every app upgrade a merge. The player keeps
a history of `(blockIndex, stepIndex)` and re-mounts at an earlier one. **Answers after
that point are lost** — re-mounting resets `_stepAnswers`. That is the honest outcome:
the reason to go back is to give different answers.

## Click-to-edit

Passive leaves report where they came from: step content (`content`), media
(`image.url`, `video.url`), the solution (`question.solution`) and an option's
feedback (`feedback`).

In Náhled the question mark and the hint/help markers report `hint` and `help` as
well. A *step*-level hint is sent with its `stepId`; a *card*-level one is sent
**without**, because the editor reads a ref carrying a `stepId` as addressing the step
and would otherwise write the card's hint onto a step that never had one. The
bookmark, thumbs and check have no authored field behind them and report the step
alone — honest, and better than a dead zone that reads as a broken preview.

Answer options report `text` **only when `PreviewMode.interactive` is false** — that
is, only in Náhled. In Vyzkoušet a tap on an answer answers the question, because that
is what trying it has to mean. The flag defaults to `true`, so a student's session is
unchanged.

## Acceptance

Run, on Flutter 3.47.4 / Dart 3.13.3 (the SDK lives at `~/flutter`; add
`~/flutter/bin` to `PATH`):

- `flutter analyze lib/preview lib/widgets/block_action_buttons.dart lib/widgets/block_step_engine.dart test/preview` — clean.
- `flutter test test/preview test/widgets` — passes. The widget suite is the guard on
  the button extraction: it pumps a real `BlockStepEngine` and asserts on the labels,
  so it fails if moving the drawing out changed what a student sees.
- `flutter build web --release --base-href /player/` — builds.

Two things about running `flutter test` on the **whole** suite here, neither caused by
this folder:

- The Drift-backed tests need `libsqlite3.so`, and Debian ships only the versioned
  `libsqlite3.so.0` unless `libsqlite3-dev` is installed. Either install it, or point
  `LD_LIBRARY_PATH` at a directory holding a `libsqlite3.so` symlink to it.
- `test/widget_test.dart` is the untouched `flutter create` scaffold: it pumps `MyApp`
  with no `ProviderScope` and looks for a counter this app does not have. It has always
  failed. Delete it or write it; do not read it as a regression.
- `/preview` opened directly renders the placeholder, accepts a `setBlock` posted from
  the console, renders the block with its Markdown and LaTeX intact, and answers.
- A click on the rendered text posts
  `{"type":"clicked","ref":{"blockId":"T1","stepId":"s1","field":"content"}}` back up.
- Embedded in the editor, the same loop drives the live preview end to end.

To repeat it by hand, open `/preview` and, from the browser console:

```js
window.postMessage(JSON.stringify({
  type: 'setBlock',
  exportMode: 'course_v2',
  block: { block_id: 'T1', type: 'question', steps: [
    { id: 's1', type: 'text', order: 1, content: 'Zlomek $\\frac{5}{7}$.' },
    { id: 's2', type: 'question', order: 2, question: { type: 'multiple_choice', options: [
      { id: 'a', text: 'Čitatel je 5', is_correct: true, feedback: 'Správně.' },
      { id: 'b', text: 'Čitatel je 7', is_correct: false, feedback: 'Prohodil/a jsi je.' }
    ]}}
  ]}
}), window.location.origin);
```

It renders, answers, and writes nothing to Drift or the API. A click on the text posts
`clicked` back with `{blockId: 'T1', stepId: 's1', field: 'content'}`.

Note that messages are **JSON strings**, not structured objects — see
`preview_channel_web.dart`. One encoding in both directions is what keeps the channel
debuggable from the console.
