/// Block v2 models for course content
///
/// Blocks contain steps which are the atomic units of content display.
/// Steps can be static (pre-defined) or AI-scaffolded (generated).

import '../core/strings/app_strings.dart';

/// Type of block
enum BlockType {
  // New atomic types (V2 simplified)
  display,     // Shows content only (replaces motivation, content, org)
  question,    // Interactive question block

  // Legacy types (V2 with steps) - mapped to new types for compatibility
  motivation,  // -> display
  content,     // -> display
  learning,    // -> display
  exercise,    // -> split into display + question blocks
  quiz,        // -> question
  org,         // -> display
}

extension BlockTypeExtension on BlockType {
  String toApiString() {
    switch (this) {
      case BlockType.display:
        return 'display';
      case BlockType.question:
        return 'question';
      case BlockType.motivation:
        return 'motivation';
      case BlockType.content:
        return 'content';
      case BlockType.learning:
        return 'learning';
      case BlockType.exercise:
        return 'exercise';
      case BlockType.quiz:
        return 'quiz';
      case BlockType.org:
        return 'org';
    }
  }

  static BlockType fromString(String value) {
    switch (value) {
      // New atomic types
      case 'display':
        return BlockType.display;
      case 'question':
        return BlockType.question;
      // Legacy types
      case 'motivation':
        return BlockType.motivation;
      case 'content':
        return BlockType.content;
      case 'exercise':
        return BlockType.exercise;
      case 'quiz':
        return BlockType.quiz;
      case 'org':
        return BlockType.org;
      case 'learning':
      default:
        return BlockType.learning;
    }
  }

  /// Whether this is a display-oriented block (no interaction required)
  bool get isDisplayBlock =>
      this == BlockType.display ||
      this == BlockType.motivation ||
      this == BlockType.content ||
      this == BlockType.learning ||
      this == BlockType.org;

  /// Whether this is an interactive/question block
  bool get isInteractiveBlock =>
      this == BlockType.question ||
      this == BlockType.exercise ||
      this == BlockType.quiz;

  /// Whether this is a new atomic block type (no steps)
  bool get isAtomicType =>
      this == BlockType.display || this == BlockType.question;
}

/// Type of step within a block
enum StepType {
  display,         // Show content to user (legacy)
  evaluation,      // Question/answer with evaluation (legacy)
  hint,            // Hint content
  displaySolution, // Show the solution
  displayTask,     // Show task description
  // V2 step types from admin editor
  text,            // Text content step
  image,           // Image content step
  video,           // Video content step
  audio,           // Audio content step
  question,        // Interactive question step
}

extension StepTypeExtension on StepType {
  String toApiString() {
    switch (this) {
      case StepType.display:
        return 'display';
      case StepType.evaluation:
        return 'evaluation';
      case StepType.hint:
        return 'hint';
      case StepType.displaySolution:
        return 'display_solution';
      case StepType.displayTask:
        return 'display_task';
      case StepType.text:
        return 'text';
      case StepType.image:
        return 'image';
      case StepType.video:
        return 'video';
      case StepType.audio:
        return 'audio';
      case StepType.question:
        return 'question';
    }
  }

  static StepType fromString(String value) {
    switch (value) {
      case 'evaluation':
        return StepType.evaluation;
      case 'hint':
        return StepType.hint;
      case 'display_solution':
        return StepType.displaySolution;
      case 'display_task':
        return StepType.displayTask;
      case 'text':
        return StepType.text;
      case 'image':
        return StepType.image;
      case 'video':
        return StepType.video;
      case 'audio':
        return StepType.audio;
      case 'question':
        return StepType.question;
      default:
        return StepType.display;
    }
  }

  /// Whether this is a V2 step type from the admin editor
  bool get isV2Type =>
      this == StepType.text ||
      this == StepType.image ||
      this == StepType.video ||
      this == StepType.audio ||
      this == StepType.question;
}

/// Mode of step content generation
enum StepMode {
  static,        // Pre-defined content
  aiScaffolded,  // AI-generated content
}

extension StepModeExtension on StepMode {
  static StepMode fromString(String value) {
    switch (value) {
      case 'ai_scaffolded':
        return StepMode.aiScaffolded;
      default:
        return StepMode.static;
    }
  }
}

/// Content block for display/hint/solution steps
class StepContent {
  final String? title;
  final String? text;
  final String? htmlText;
  final String? imageUrl;
  final String? imageEmoji;
  final String? videoUrl;
  final String? videoDuration;
  final List<KeyConceptV2>? keyConcepts;

  const StepContent({
    this.title,
    this.text,
    this.htmlText,
    this.imageUrl,
    this.imageEmoji,
    this.videoUrl,
    this.videoDuration,
    this.keyConcepts,
  });

  factory StepContent.fromJson(Map<String, dynamic> json) {
    List<KeyConceptV2>? keyConcepts;
    if (json['key_concepts'] != null) {
      keyConcepts = (json['key_concepts'] as List<dynamic>)
          .map((k) => KeyConceptV2.fromJson(k as Map<String, dynamic>))
          .toList();
    }

    return StepContent(
      title: json['title'] as String?,
      text: json['text'] as String?,
      htmlText: json['html_text'] as String?,
      imageUrl: json['image_url'] as String?,
      imageEmoji: json['image_emoji'] as String?,
      videoUrl: json['video_url'] as String?,
      videoDuration: json['video_duration'] as String?,
      keyConcepts: keyConcepts,
    );
  }
}

/// Key concept item
class KeyConceptV2 {
  final String term;
  final String definition;

  const KeyConceptV2({
    required this.term,
    required this.definition,
  });

  factory KeyConceptV2.fromJson(Map<String, dynamic> json) {
    return KeyConceptV2(
      term: json['term'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
    );
  }
}

/// Video attached to a step
class StepVideo {
  final String url;

  const StepVideo({required this.url});

  factory StepVideo.fromJson(Map<String, dynamic> json) {
    return StepVideo(url: json['url'] as String? ?? '');
  }
}

/// Audio attached to a step
class StepAudio {
  final String url;

  const StepAudio({required this.url});

  factory StepAudio.fromJson(Map<String, dynamic> json) {
    return StepAudio(url: json['url'] as String? ?? '');
  }
}

/// Image attached to a step
class StepImage {
  final String url;
  final String? alt;

  const StepImage({
    required this.url,
    this.alt,
  });

  factory StepImage.fromJson(Map<String, dynamic> json) {
    return StepImage(
      url: json['url'] as String? ?? '',
      alt: json['alt'] as String?,
    );
  }

  /// Check if this is a YouTube video URL
  bool get isYouTubeVideo {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }
}

/// Evaluation configuration for evaluation steps
class EvaluationConfig {
  final String type;  // single_select, multi_select, free_text, matching, multiple_choice, open, true_false
  final List<EvaluationOption> options;
  final String? correctAnswer;  // For free text / open questions
  final List<String>? correctOptionIds;  // For multi-select
  final String? question;
  final String? solution;  // Solution explanation
  final bool allowMultiple;  // For multiple_choice: allow selecting multiple options
  final bool showAnswers;    // Whether to show correct answers (false = free-text input for MC)
  final bool showSolution;  // Whether to show solution explanation after answering (default true)
  final StepImage? solutionImage;  // Image alongside solution text
  final double? correctNumber;  // For numeric questions
  final double tolerance;       // Tolerance for numeric comparison (default 0)

  const EvaluationConfig({
    required this.type,
    this.options = const [],
    this.correctAnswer,
    this.correctOptionIds,
    this.question,
    this.solution,
    this.allowMultiple = false,
    this.showAnswers = true,
    this.showSolution = true,
    this.solutionImage,
    this.correctNumber,
    this.tolerance = 0,
  });

  factory EvaluationConfig.fromJson(Map<String, dynamic> json) {
    List<EvaluationOption> options = [];
    if (json['options'] != null) {
      options = (json['options'] as List<dynamic>)
          .map((o) => EvaluationOption.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    List<String>? correctOptionIds;
    if (json['correct_option_ids'] != null) {
      correctOptionIds = (json['correct_option_ids'] as List<dynamic>)
          .map((id) => id as String)
          .toList();
    }

    StepImage? solutionImage;
    final solImgRaw = json['solution_image'];
    if (solImgRaw is Map<String, dynamic>) {
      solutionImage = StepImage.fromJson(solImgRaw);
    }

    return EvaluationConfig(
      type: json['type'] as String? ?? 'single_select',
      options: options,
      correctAnswer: json['correct_answer'] as String?,
      correctOptionIds: correctOptionIds,
      question: json['question'] as String?,
      solution: json['solution'] as String?,
      allowMultiple: json['allow_multiple'] as bool? ?? false,
      showAnswers: json['show_answers'] as bool? ?? true,
      showSolution: json['show_solution'] as bool? ?? true,
      solutionImage: solutionImage,
      correctNumber: (json['correct_number'] as num?)?.toDouble(),
      tolerance: (json['tolerance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Option for evaluation questions
class EvaluationOption {
  final String id;
  final String text;
  final String? description;
  final String? imageUrl;
  final String? feedback;
  final StepImage? feedbackImage;  // Image alongside feedback text
  final bool isCorrect;
  final String? mark;  // Grade/score mark for this option
  final String? goTo;  // Step ID to navigate to when selected
  final double scoreKoef;  // Score multiplier for this option

  const EvaluationOption({
    required this.id,
    required this.text,
    this.description,
    this.imageUrl,
    this.feedback,
    this.feedbackImage,
    this.isCorrect = false,
    this.mark,
    this.goTo,
    this.scoreKoef = 1.0,
  });

  factory EvaluationOption.fromJson(Map<String, dynamic> json) {
    StepImage? feedbackImage;
    final fbImgRaw = json['feedback_image'];
    if (fbImgRaw is Map<String, dynamic>) {
      feedbackImage = StepImage.fromJson(fbImgRaw);
    }

    return EvaluationOption(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      feedback: json['feedback'] as String?,
      feedbackImage: feedbackImage,
      isCorrect: json['is_correct'] as bool? ?? false,
      mark: json['mark']?.toString(),
      goTo: json['go_to'] as String?,
      scoreKoef: (json['score_koef'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// User option for navigation within steps
class UserOption {
  final String id;
  final String label;
  final String icon;
  final String? goTo;  // Step ID to navigate to
  final double scoreKoef;  // Score multiplier

  const UserOption({
    required this.id,
    required this.label,
    this.icon = '',
    this.goTo,
    this.scoreKoef = 1.0,
  });

  factory UserOption.fromJson(Map<String, dynamic> json) {
    return UserOption(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      goTo: json['go_to'] as String?,
      scoreKoef: (json['score_koef'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Next actions after evaluation
class NextActions {
  final String? correct;    // Step ID for correct answer
  final String? incorrect;  // Step ID for incorrect answer

  const NextActions({
    this.correct,
    this.incorrect,
  });

  factory NextActions.fromJson(Map<String, dynamic> json) {
    return NextActions(
      correct: json['correct'] as String?,
      incorrect: json['incorrect'] as String?,
    );
  }
}

/// GPF (Generative Pedagogical Framework) metadata
class GpfMetadata {
  final String? topic;
  final String? level;
  final String? bloomsLevel;
  final List<String>? prerequisites;
  final List<String>? outcomes;
  final List<double?>? relationVector;  // 35 elements, values 0/1/2
  final List<double?>? eloVector;       // 35 elements, values 1.0-10.0 or null

  const GpfMetadata({
    this.topic,
    this.level,
    this.bloomsLevel,
    this.prerequisites,
    this.outcomes,
    this.relationVector,
    this.eloVector,
  });

  factory GpfMetadata.fromJson(Map<String, dynamic> json) {
    // Handle level which can be int or String
    String? level;
    if (json['level'] != null) {
      level = json['level'].toString();
    }

    // Parse relation_vector: array of 35 doubles (0/1/2), nulls allowed
    List<double?>? relationVector;
    final rvRaw = json['relation_vector'];
    if (rvRaw is List) {
      relationVector = rvRaw.map((e) {
        if (e == null) return null;
        if (e is num) return e.toDouble();
        return double.tryParse(e.toString());
      }).toList();
    }

    // Parse elo_vector: array of 35 doubles (1.0-10.0), nulls allowed
    List<double?>? eloVector;
    final evRaw = json['elo_vector'];
    if (evRaw is List) {
      eloVector = evRaw.map((e) {
        if (e == null) return null;
        if (e is num) return e.toDouble();
        return double.tryParse(e.toString());
      }).toList();
    }

    return GpfMetadata(
      topic: json['topic'] as String?,
      level: level,
      bloomsLevel: json['blooms_level']?.toString(),
      prerequisites: (json['prerequisites'] as List<dynamic>?)
          ?.map((p) => p.toString())
          .toList(),
      outcomes: (json['outcomes'] as List<dynamic>?)
          ?.map((o) => o.toString())
          .toList(),
      relationVector: relationVector,
      eloVector: eloVector,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (topic != null) 'topic': topic,
      if (level != null) 'level': level,
      if (bloomsLevel != null) 'blooms_level': bloomsLevel,
      if (prerequisites != null) 'prerequisites': prerequisites,
      if (outcomes != null) 'outcomes': outcomes,
      if (relationVector != null) 'relation_vector': relationVector,
      if (eloVector != null) 'elo_vector': eloVector,
    };
  }
}

/// FSRS (Free Spaced Repetition Scheduler) parameters
class FsrsParameters {
  final double stability;
  final double difficulty;
  final int reps;
  final int lapses;
  final DateTime? lastReview;
  final DateTime? dueDate;

  const FsrsParameters({
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.reps = 0,
    this.lapses = 0,
    this.lastReview,
    this.dueDate,
  });

  factory FsrsParameters.fromJson(Map<String, dynamic> json) {
    return FsrsParameters(
      stability: (json['stability'] as num?)?.toDouble() ?? 0.0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0.0,
      reps: json['reps'] as int? ?? 0,
      lapses: json['lapses'] as int? ?? 0,
      lastReview: json['last_review'] != null
          ? DateTime.tryParse(json['last_review'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
    );
  }
}

/// Learning metadata for learning blocks
class LearningMetadata {
  final String? objective;
  final String? summary;

  const LearningMetadata({
    this.objective,
    this.summary,
  });

  factory LearningMetadata.fromJson(Map<String, dynamic> json) {
    return LearningMetadata(
      objective: json['objective'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

/// Output format for step content
enum OutputFormat {
  plainText,
  htmlText,
  markdown,
}

extension OutputFormatExtension on OutputFormat {
  static OutputFormat fromString(String? value) {
    switch (value) {
      case 'html_text':
        return OutputFormat.htmlText;
      case 'markdown':
        return OutputFormat.markdown;
      default:
        return OutputFormat.plainText;
    }
  }
}

/// A step within a block
class BlockStep {
  final String stepId;
  final StepType type;
  final StepMode mode;
  final StepContent? content;
  final EvaluationConfig? evaluationConfig;
  final List<UserOption> userOptions;
  final NextActions? nextActions;
  final OutputFormat outputFormat;
  final String? hint;  // Hint content for this step
  final String? help;  // More detailed help content
  final StepImage? image;  // Image attached to this step
  final StepVideo? video;  // Video attached to this step
  final StepAudio? audio;  // Audio attached to this step
  final String? position;  // "above" (default), "below", "inline" — for image/video steps
  final String? goTo;  // Direct go_to on step (for display/text steps with navigation)
  final bool defaultPractice;  // Display blocks: include this step in practice queue

  const BlockStep({
    required this.stepId,
    required this.type,
    this.mode = StepMode.static,
    this.content,
    this.evaluationConfig,
    this.userOptions = const [],
    this.nextActions,
    this.outputFormat = OutputFormat.plainText,
    this.hint,
    this.help,
    this.image,
    this.video,
    this.audio,
    this.position,
    this.goTo,
    this.defaultPractice = false,
  });

  /// Parse a step from JSON with the step ID provided separately.
  /// The actual JSON format has steps as a Map with keys like "s1", "s2".
  factory BlockStep.fromJsonWithId(String stepId, Map<String, dynamic> json) {

    List<UserOption> userOptions = [];
    if (json['user_options'] != null) {
      userOptions = (json['user_options'] as List<dynamic>)
          .map((o) => UserOption.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    // Parse next_actions - can be a list or object
    NextActions? nextActions;
    if (json['next_actions'] != null) {
      final nextActionsData = json['next_actions'];
      if (nextActionsData is List) {
        // Format: [{"result": {"is_correct": true}, "go_to": "s4"}, ...]
        String? correctGoTo;
        String? incorrectGoTo;
        for (final action in nextActionsData) {
          final actionMap = action as Map<String, dynamic>;
          final result = actionMap['result'] as Map<String, dynamic>?;
          if (result != null && result['is_correct'] == true) {
            correctGoTo = actionMap['go_to'] as String?;
          } else if (result != null && result['is_correct'] == false) {
            incorrectGoTo = actionMap['go_to'] as String?;
          }
        }
        nextActions = NextActions(correct: correctGoTo, incorrect: incorrectGoTo);
      } else if (nextActionsData is Map<String, dynamic>) {
        nextActions = NextActions.fromJson(nextActionsData);
      }
    }

    // Determine step type first — V2 types skip legacy modes.static parsing
    StepContent? content;
    EvaluationConfig? evaluationConfig;
    final stepType = StepTypeExtension.fromString(json['type'] as String? ?? 'display');

    // Legacy content extraction from modes.static.output
    final modesRaw = json['modes'];
    final modes = modesRaw is Map<String, dynamic> ? modesRaw : null;
    final staticModeRaw = modes?['static'];
    final staticMode = staticModeRaw is Map<String, dynamic> ? staticModeRaw : null;
    final outputRaw = staticMode?['output'];
    final outputText = outputRaw is String ? outputRaw : null;

    // Parse expected_output_format (safely - could be String or something else)
    final outputFormatRaw = json['expected_output_format'];
    final outputFormatStr = outputFormatRaw is String ? outputFormatRaw : null;
    final outputFormat = OutputFormatExtension.fromString(outputFormatStr);

    if (stepType.isV2Type) {
      // ─── V2 step types: text, image, video, question ───
      // These have simpler structure — content directly on the step JSON
      if (stepType == StepType.text) {
        final textRaw = json['text'] ?? json['content'];
        final textStr = textRaw is String ? textRaw : null;
        content = StepContent(text: textStr);
      } else if (stepType == StepType.image) {
        final altRaw = json['alt'] ?? json['text'];
        final altStr = altRaw is String ? altRaw : null;
        content = StepContent(text: altStr);
      } else if (stepType == StepType.video) {
        final textRaw = json['text'];
        content = StepContent(text: textRaw is String ? textRaw : null);
      } else if (stepType == StepType.audio) {
        final textRaw = json['text'];
        content = StepContent(text: textRaw is String ? textRaw : null);
      } else if (stepType == StepType.question) {
        final questionRaw = json['question'];
        final questionMap = questionRaw is Map<String, dynamic> ? questionRaw : null;
        final textRaw = json['text'] ?? json['content'] ?? questionMap?['text'];
        final textStr = textRaw is String ? textRaw : null;
        content = StepContent(text: textStr);
        // V2 question config parsed below after image/video section
      }
    } else if (stepType == StepType.evaluation) {
      // For evaluation steps, the output is the question
      final rulesRaw = staticMode?['rules'];
      final rules = rulesRaw is Map<String, dynamic> ? rulesRaw : null;
      List<String>? acceptedAnswers;
      final acceptedAnswersRaw = rules?['accepted_answers'];
      if (acceptedAnswersRaw is List) {
        acceptedAnswers = acceptedAnswersRaw
            .map((a) => a.toString())
            .toList();
      }

      // Check for question.options (multiple choice format)
      final questionRaw = json['question'];
      final question = questionRaw is Map<String, dynamic> ? questionRaw : null;
      final questionTypeRaw = question?['type'];
      final questionType = questionTypeRaw is String ? questionTypeRaw : null;
      final questionOptionsRaw = question?['options'];


      List<EvaluationOption> evalOptions = [];
      String evalType = 'exact_match';

      // Get solution text from question
      final questionSolution = question?['solution'];
      final solutionText = questionSolution is String ? questionSolution : null;

      // Priority 1: Parse question.options if it's multiple_choice or open with options
      if ((questionType == 'multiple_choice' || questionType == 'open') && questionOptionsRaw is List) {
        evalType = questionType ?? 'multiple_choice';
        for (final opt in questionOptionsRaw) {
          if (opt is Map<String, dynamic>) {
            final optId = opt['id'];
            final optText = opt['text'];
            final optIsCorrect = opt['is_correct'];
            final optFeedback = opt['feedback'];
            final optMark = opt['mark'];
            final optGoTo = opt['go_to'];
            evalOptions.add(EvaluationOption(
              id: optId is String ? optId : '',
              text: optText is String ? optText : '',
              isCorrect: optIsCorrect == true,
              feedback: optFeedback is String ? optFeedback : null,
              mark: optMark?.toString(),
              goTo: optGoTo is String ? optGoTo : null,
            ));
          }
        }

        // evaluationConfig already set above with solution
      }
      // Priority 2: Convert userOptions to EvaluationOption for quiz UI
      else if (userOptions.isNotEmpty) {
        evalType = 'single_select';
        for (final opt in userOptions) {
          // Option is correct if:
          // 1. Its goTo matches nextActions.correct, or
          // 2. It has scoreKoef > 1, or
          // 3. Its ID is in acceptedAnswers
          final isCorrect = (nextActions?.correct != null && opt.goTo == nextActions!.correct) ||
                           opt.scoreKoef > 1.0 ||
                           (acceptedAnswers?.contains(opt.id) ?? false);
          evalOptions.add(EvaluationOption(
            id: opt.id,
            text: opt.label,
            isCorrect: isCorrect,
            goTo: opt.goTo,
          ));
        }
        evaluationConfig = EvaluationConfig(
          type: evalType,
          question: outputText,
          correctAnswer: acceptedAnswers?.isNotEmpty == true ? acceptedAnswers!.first : null,
          options: evalOptions,
          solution: solutionText,
        );
      }
      // Priority 3: Use rules.type for free text (open question)
      else {
        final rulesTypeRaw = rules?['type'];
        evalType = questionType ?? (rulesTypeRaw is String ? rulesTypeRaw : 'exact_match');
        evaluationConfig = EvaluationConfig(
          type: evalType,
          question: outputText,
          correctAnswer: acceptedAnswers?.isNotEmpty == true ? acceptedAnswers!.first : null,
          options: evalOptions,
          solution: solutionText,
        );
      }

      // Also set content for display
      content = StepContent(text: outputText);
    } else {
      // For display/hint/solution steps
      // Determine content type based on outputFormat or presence of HTML tags
      final isHtml = outputFormat == OutputFormat.htmlText ||
                     (outputFormat == OutputFormat.plainText && outputText?.contains('<') == true);
      final isMarkdown = outputFormat == OutputFormat.markdown;
      // Extract image URL from static mode (with safe type checks)
      final imageUrlRaw = staticMode?['image_url'];
      final imageUrl = imageUrlRaw is String ? imageUrlRaw : null;
      final imageEmojiRaw = staticMode?['image_emoji'];
      final imageEmoji = imageEmojiRaw is String ? imageEmojiRaw : null;
      content = StepContent(
        // For markdown or plain text, store in text field
        text: (isMarkdown || !isHtml) ? outputText : null,
        htmlText: isHtml ? outputText : null,
        imageUrl: imageUrl,
        imageEmoji: imageEmoji,
      );
    }

    // Parse hint field (can contain HTML or plain text)
    final hintRaw = json['hint'];
    final hint = hintRaw is String ? hintRaw : null;

    // Parse help field (more detailed assistance)
    final helpRaw = json['help'];
    final help = helpRaw is String ? helpRaw : null;

    // Parse image field
    StepImage? image;
    final imageRaw = json['image'];
    if (imageRaw is Map<String, dynamic>) {
      image = StepImage.fromJson(imageRaw);
    }

    // Parse video field
    StepVideo? video;
    final videoRaw = json['video'];
    if (videoRaw is Map<String, dynamic>) {
      video = StepVideo.fromJson(videoRaw);
    }

    // Parse audio field
    StepAudio? audio;
    final audioRaw = json['audio'];
    if (audioRaw is Map<String, dynamic>) {
      audio = StepAudio.fromJson(audioRaw);
    }

    // Parse position for image/video steps (top-level or nested in image/video object)
    final positionRaw = json['position'] ??
        (imageRaw is Map<String, dynamic> ? imageRaw['position'] : null) ??
        (videoRaw is Map<String, dynamic> ? videoRaw['position'] : null);
    final position = positionRaw is String ? positionRaw : null;

    // Parse direct go_to on step
    final stepGoToRaw = json['go_to'];
    final stepGoTo = stepGoToRaw is String ? stepGoToRaw : null;

    // V2 fallbacks: image/video URLs can be directly on step (not nested)
    if (stepType == StepType.image && image == null) {
      final imgUrlRaw = json['url'] ?? json['image_url'];
      final imgUrlStr = imgUrlRaw is String ? imgUrlRaw : null;
      if (imgUrlStr != null) {
        final altRaw = json['alt'] ?? json['text'];
        image = StepImage(url: imgUrlStr, alt: altRaw is String ? altRaw : null);
      }
    }
    if (stepType == StepType.video && video == null) {
      final videoUrlRaw = json['url'] ?? json['video_url'];
      final videoUrlStr = videoUrlRaw is String ? videoUrlRaw : null;
      if (videoUrlStr != null) {
        video = StepVideo(url: videoUrlStr);
      }
    }
    if (stepType == StepType.audio && audio == null) {
      final audioUrlRaw = json['url'] ?? json['audio_url'];
      final audioUrlStr = audioUrlRaw is String ? audioUrlRaw : null;
      if (audioUrlStr != null) {
        audio = StepAudio(url: audioUrlStr);
      }
    }

    // V2 question steps: parse evaluation config from question object
    if (stepType == StepType.question && evaluationConfig == null) {
      final questionRaw = json['question'];
      final questionMap = questionRaw is Map<String, dynamic> ? questionRaw : null;
      if (questionMap != null) {
        final qType = questionMap['type'] as String? ?? 'multiple_choice';
        final qOptions = <EvaluationOption>[];
        final optionsRaw = questionMap['options'];
        if (optionsRaw is List) {
          for (final opt in optionsRaw) {
            if (opt is Map<String, dynamic>) {
              qOptions.add(EvaluationOption.fromJson(opt));
            }
          }
        }
        final qSolution = questionMap['solution'] as String?;
        final qCorrectAnswer = questionMap['correct_answer'] as String?;
        final qAllowMultiple = questionMap['allow_multiple'] as bool? ?? false;
        final qShowAnswers = questionMap['show_answers'] as bool? ?? true;
        final qShowSolution = questionMap['show_solution'] as bool? ?? true;

        StepImage? solImage;
        final solImgRaw = questionMap['solution_image'];
        if (solImgRaw is Map<String, dynamic>) {
          solImage = StepImage.fromJson(solImgRaw);
        }

        evaluationConfig = EvaluationConfig(
          type: qType,
          options: qOptions,
          correctAnswer: qCorrectAnswer,
          question: content?.text,
          solution: qSolution,
          allowMultiple: qAllowMultiple,
          showAnswers: qShowAnswers,
          showSolution: qShowSolution,
          solutionImage: solImage,
        );
      }
    }

    return BlockStep(
      stepId: stepId,
      type: stepType,
      mode: StepModeExtension.fromString(json['mode'] as String? ?? 'static'),
      content: content,
      evaluationConfig: evaluationConfig,
      userOptions: userOptions,
      nextActions: nextActions,
      outputFormat: outputFormat,
      hint: hint,
      help: help,
      image: image,
      video: video,
      audio: audio,
      position: position,
      goTo: stepGoTo,
      defaultPractice: json['default_practice'] == true,
    );
  }

  factory BlockStep.fromJson(Map<String, dynamic> json) {
    // V2 uses 'id', legacy uses 'step_id'
    final stepId = json['id'] as String? ?? json['step_id'] as String? ?? '';
    return BlockStep.fromJsonWithId(stepId, json);
  }

  /// Get the display title for this step
  String get displayTitle {
    if (content?.title != null) return content!.title!;
    switch (type) {
      case StepType.display:
      case StepType.text:
        return AppStrings.blockDisplayTitleContent;
      case StepType.evaluation:
      case StepType.question:
        return AppStrings.blockDisplayTitleQuestion;
      case StepType.hint:
        return AppStrings.blockDisplayTitleHint;
      case StepType.displaySolution:
        return AppStrings.blockDisplayTitleSolution;
      case StepType.displayTask:
        return AppStrings.blockDisplayTitleTask;
      case StepType.image:
        return AppStrings.blockDisplayTitleImage;
      case StepType.video:
        return AppStrings.blockDisplayTitleVideo;
      case StepType.audio:
        return AppStrings.blockDisplayTitleAudio;
    }
  }

  /// Get the display text for this step (plain text, strips HTML)
  String get displayText {
    if (content?.text != null) {
      // Handle literal \n escape sequences from backend
      return content!.text!.replaceAll(r'\n', '\n');
    }
    if (content?.htmlText != null) {
      // Convert block-level HTML tags to newlines, then strip remaining tags
      return content!.htmlText!
          .replaceAll(RegExp(r'<br\s*/?>'), '\n')
          .replaceAll(RegExp(r'</p>'), '\n')
          .replaceAll(RegExp(r'</li>'), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'[^\S\n]+'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }
    if (evaluationConfig?.question != null) {
      return evaluationConfig!.question!.replaceAll(r'\n', '\n');
    }
    return '';
  }

  /// Get the HTML content for this step (if available)
  String? get htmlContent => content?.htmlText;

  /// Whether this step has HTML content
  bool get hasHtmlContent => content?.htmlText != null;

  /// Whether this step has markdown content
  bool get hasMarkdownContent => outputFormat == OutputFormat.markdown;

  /// Get the raw output text (for markdown rendering)
  String? get rawOutputText => content?.text ?? content?.htmlText;

  /// Check if this is a display-type step (shows content, no interaction)
  bool get isDisplayStep => type == StepType.display ||
                             type == StepType.hint ||
                             type == StepType.displaySolution ||
                             type == StepType.displayTask ||
                             type == StepType.text ||
                             type == StepType.image ||
                             type == StepType.video ||
                             type == StepType.audio;

  /// Check if this is an evaluation/question step
  bool get isEvaluationStep => type == StepType.evaluation ||
                                type == StepType.question;

  /// Check if this step has help available
  bool get hasHelp => help != null && help!.isNotEmpty;

  /// Check if this step has an image
  bool get hasImage => image != null && image!.url.isNotEmpty;

  /// Check if this step has audio
  bool get hasAudio => audio != null && audio!.url.isNotEmpty;

  /// Check if this step has a video (YouTube or direct URL)
  bool get hasVideo => video != null || image?.isYouTubeVideo == true || content?.videoUrl != null;

  /// Get the image URL from step-level image or content
  String? get imageUrl => image?.url ?? content?.imageUrl;

  /// Get the image alt text
  String? get imageAlt => image?.alt;

  /// Get solution text for evaluation steps
  String? get solution => evaluationConfig?.solution;
}

/// Question configuration for atomic blocks (new V2 simplified format)
class AtomicQuestion {
  final String type;  // 'multiple_choice', 'open', 'true_false'
  final List<EvaluationOption> options;  // For multiple_choice and true_false
  final String? correctAnswer;  // For open questions
  final bool showAnswers;  // Whether to show correct answers after submission
  final bool showSolution;  // Whether to show solution explanation after answering (default true)
  final String? solution;  // Explanation shown after answering
  final bool allowMultiple;  // For multiple_choice: allow selecting multiple options

  const AtomicQuestion({
    required this.type,
    this.options = const [],
    this.correctAnswer,
    this.showAnswers = true,
    this.showSolution = true,
    this.solution,
    this.allowMultiple = false,
  });

  factory AtomicQuestion.fromJson(Map<String, dynamic> json) {
    List<EvaluationOption> options = [];
    if (json['options'] != null && json['options'] is List) {
      options = (json['options'] as List<dynamic>)
          .map((o) => EvaluationOption.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    return AtomicQuestion(
      type: json['type'] as String? ?? 'multiple_choice',
      options: options,
      correctAnswer: json['correct_answer'] as String?,
      showAnswers: json['show_answers'] as bool? ?? true,
      showSolution: json['show_solution'] as bool? ?? true,
      solution: json['solution'] as String?,
      allowMultiple: json['allow_multiple'] as bool? ?? false,
    );
  }

  /// Check if this is a multiple choice question
  bool get isMultipleChoice => type == 'multiple_choice';

  /// Check if this is an open/free text question
  bool get isOpen => type == 'open';

  /// Check if this is a true/false question
  bool get isTrueFalse => type == 'true_false';

  /// Get the correct option(s) for multiple choice
  List<EvaluationOption> get correctOptions =>
      options.where((o) => o.isCorrect).toList();
}

/// A content block (v2 format - supports both step-based and atomic formats)
class ContentBlock {
  final String blockId;
  final BlockType type;
  final int durationMinutes;
  final int xp;  // XP reward for completing this block
  final GpfMetadata? gpf;
  final LearningMetadata? learning;
  final FsrsParameters? fsrs;

  // Legacy step-based format (V2 with steps)
  final List<BlockStep> steps;

  // New atomic format fields (V2 simplified - direct on block)
  final String? content;           // Direct content text (HTML/Markdown)
  final String? atomicHint;        // Direct hint on block
  final String? atomicHelp;        // Direct help on block
  final StepImage? atomicImage;    // Direct image on block
  final StepVideo? atomicVideo;    // Direct video on block
  final AtomicQuestion? atomicQuestion;  // Direct question config on block

  // Block metadata
  final bool defaultPractice;

  // UI state (not from JSON)
  bool isCompleted;
  bool isBookmarked;
  bool isLiked;
  bool isDisliked;
  int currentStepIndex;
  String? selectedOptionId;

  ContentBlock({
    required this.blockId,
    required this.type,
    this.durationMinutes = 5,
    this.xp = 10,
    this.gpf,
    this.learning,
    this.fsrs,
    this.steps = const [],
    this.content,
    this.atomicHint,
    this.atomicHelp,
    this.atomicImage,
    this.atomicVideo,
    this.atomicQuestion,
    this.defaultPractice = false,
    this.isCompleted = false,
    this.isBookmarked = false,
    this.isLiked = false,
    this.isDisliked = false,
    this.currentStepIndex = 0,
    this.selectedOptionId,
  });

  /// Whether this block uses the new atomic format (no steps)
  bool get isAtomicFormat => type.isAtomicType && steps.isEmpty;

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final blockType = BlockTypeExtension.fromString(json['type'] as String? ?? 'learning');

    // Parse duration - can be string like "5 min" or int
    int durationMinutes = 5;
    final duration = json['duration'];
    if (duration is int) {
      durationMinutes = duration;
    } else if (duration is String) {
      // Parse "5 min" or similar
      final match = RegExp(r'(\d+)').firstMatch(duration);
      if (match != null) {
        durationMinutes = int.tryParse(match.group(1)!) ?? 5;
      }
    } else if (json['duration_minutes'] is int) {
      durationMinutes = json['duration_minutes'] as int;
    }

    // Parse XP (can be int or String from JSON)
    final xpRaw = json['xp'];
    final xp = xpRaw is int ? xpRaw : (int.tryParse(xpRaw?.toString() ?? '') ?? 10);

    // Parse common metadata (defensive — some blocks may have [] instead of {})
    final gpfRaw = json['gpf'];
    final gpf = gpfRaw is Map<String, dynamic> ? GpfMetadata.fromJson(gpfRaw) : null;
    final learningRaw = json['learning'];
    final learning = learningRaw is Map<String, dynamic> ? LearningMetadata.fromJson(learningRaw) : null;
    final fsrsRaw = json['fsrs'];
    final fsrs = fsrsRaw is Map<String, dynamic> ? FsrsParameters.fromJson(fsrsRaw) : null;
    final defaultPractice = json['default_practice'] == true;

    // Check if this is the new atomic format (no steps, direct content).
    // V2 blocks can use display/question types but still have steps — so
    // we must check that the JSON truly has no steps before treating as atomic.
    final hasStepsData = json['steps'] != null;
    final isAtomicFormat = !hasStepsData &&
        (blockType.isAtomicType || json['content'] != null);

    if (isAtomicFormat) {
      // New atomic format - parse direct fields
      final content = json['content'] as String?;
      final hint = json['hint'] as String?;
      final help = json['help'] as String?;

      // Parse image
      StepImage? image;
      final imageData = json['image'];
      if (imageData is Map<String, dynamic>) {
        image = StepImage.fromJson(imageData);
      }

      // Parse video
      StepVideo? video;
      final videoData = json['video'];
      if (videoData is Map<String, dynamic>) {
        video = StepVideo.fromJson(videoData);
      }

      // Parse question (for question blocks)
      AtomicQuestion? question;
      final questionData = json['question'];
      if (questionData is Map<String, dynamic>) {
        question = AtomicQuestion.fromJson(questionData);
      }

      return ContentBlock(
        blockId: json['block_id'] as String? ?? '',
        type: blockType,
        durationMinutes: durationMinutes,
        xp: xp,
        gpf: gpf,
        learning: learning,
        fsrs: fsrs,
        steps: const [],  // No steps in atomic format
        content: content,
        atomicHint: hint,
        atomicHelp: help,
        atomicImage: image,
        atomicVideo: video,
        atomicQuestion: question,
        defaultPractice: defaultPractice,
        isBookmarked: defaultPractice,
      );
    } else {
      // Legacy step-based format - parse steps
      List<BlockStep> steps = [];
      final stepsData = json['steps'];
      if (stepsData != null) {
        if (stepsData is Map<String, dynamic>) {
          // Steps as Map with keys like "s1", "s2"
          final sortedKeys = stepsData.keys.toList()..sort();
          steps = sortedKeys.map((key) {
            return BlockStep.fromJsonWithId(
              key,
              stepsData[key] as Map<String, dynamic>,
            );
          }).toList();
        } else if (stepsData is List<dynamic>) {
          // Steps as List
          steps = stepsData
              .map((s) => BlockStep.fromJson(s as Map<String, dynamic>))
              .toList();
        }
      }

      // Parse block-level hint/help (exist alongside steps in exercise blocks)
      final blockHint = json['hint'] as String?;
      final blockHelp = json['help'] as String?;

      return ContentBlock(
        blockId: json['block_id'] as String? ?? '',
        type: blockType,
        durationMinutes: durationMinutes,
        xp: xp,
        gpf: gpf,
        learning: learning,
        fsrs: fsrs,
        steps: steps,
        atomicHint: blockHint,
        atomicHelp: blockHelp,
        defaultPractice: defaultPractice,
        isBookmarked: defaultPractice,
      );
    }
  }

  /// Get the current step (for legacy step-based blocks)
  BlockStep? get currentStep {
    if (isAtomicFormat) return null;
    if (currentStepIndex < 0 || currentStepIndex >= steps.length) return null;
    return steps[currentStepIndex];
  }

  /// Get display title for the block
  String get displayTitle {
    // For atomic blocks, try to extract title from content or use learning objective
    if (isAtomicFormat) {
      if (learning?.objective != null) return learning!.objective!;
      // Try to extract title from HTML content (look for h3 or h2)
      if (content != null) {
        final titleMatch = RegExp(r'<h[23][^>]*>([^<]+)</h[23]>').firstMatch(content!);
        if (titleMatch != null) return titleMatch.group(1) ?? '';
      }
      return type == BlockType.question
          ? AppStrings.blockDisplayTitleQuestion
          : AppStrings.blockDisplayTitleContent;
    }

    // Legacy step-based: try to get title from first display step
    for (final step in steps) {
      if (step.content?.title != null) {
        return step.content!.title!;
      }
    }
    // Fallback to learning objective or block type
    if (learning?.objective != null) return learning!.objective!;
    return type == BlockType.learning
        ? AppStrings.blockDisplayTitleLearning
        : AppStrings.blockDisplayTitleExercise;
  }

  /// Get the main content text (for display)
  String get displayContent {
    if (isAtomicFormat) {
      // Handle literal \n escape sequences from backend
      return (content ?? '').replaceAll(r'\n', '\n');
    }
    // Legacy: get content from current step
    return currentStep?.displayText ?? '';
  }

  /// Get hint for the current block/step (if available)
  ///
  /// "Current" is [currentStepIndex], which `BlockStepEngine` keeps on the step it
  /// has on screen. Nothing used to move it, so every step of a card offered the
  /// first step's hint. An empty step value counts as absent, so it does not hide
  /// the block's.
  String? get currentHint {
    if (isAtomicFormat) return atomicHint;
    // Step-level hint first, then block-level fallback (exercise blocks)
    return _filled(currentStep?.hint) ?? atomicHint;
  }

  /// Get help for the current block/step (if available)
  String? get currentHelp {
    if (isAtomicFormat) return atomicHelp;
    // Step-level help first, then block-level fallback (exercise blocks)
    return _filled(currentStep?.help) ?? atomicHelp;
  }

  static String? _filled(String? text) =>
      text == null || text.trim().isEmpty ? null : text;

  /// Check if block has a hint
  bool get hasHint {
    return currentHint != null && currentHint!.isNotEmpty;
  }

  /// Check if block has help
  bool get hasHelp {
    return currentHelp != null && currentHelp!.isNotEmpty;
  }

  /// Get the question configuration (for question blocks)
  AtomicQuestion? get question => atomicQuestion;

  /// Check if this is a question block
  bool get isQuestionBlock =>
      type == BlockType.question ||
      (type.isInteractiveBlock && atomicQuestion != null);

  /// Get image for the block
  StepImage? get blockImage {
    if (isAtomicFormat) return atomicImage;
    return currentStep?.image;
  }

  /// Check if block has an image
  bool get hasImage {
    final img = blockImage;
    return img != null && img.url.isNotEmpty;
  }

  /// Get video for the block
  StepVideo? get blockVideo {
    if (isAtomicFormat) return atomicVideo;
    return currentStep?.video;
  }

  /// Check if block has a video (explicit video field)
  bool get hasVideo => blockVideo != null;

  /// Get the video URL for the block
  String? get videoUrl => blockVideo?.url;

  /// Get solution text (for question blocks)
  String? get solutionText {
    if (isAtomicFormat) return atomicQuestion?.solution;
    return currentStep?.solution;
  }

  /// Get step by ID
  BlockStep? getStepById(String stepId) {
    try {
      return steps.firstWhere((s) => s.stepId == stepId);
    } catch (_) {
      return null;
    }
  }

  /// Get step index by ID
  int getStepIndexById(String stepId) {
    return steps.indexWhere((s) => s.stepId == stepId);
  }

  /// Navigate to a step by ID
  bool goToStep(String stepId) {
    final index = getStepIndexById(stepId);
    if (index >= 0) {
      currentStepIndex = index;
      return true;
    }
    return false;
  }

  /// Whether this block has V2 steps (steps with V2 types)
  bool get hasV2Steps => steps.isNotEmpty && steps.any((s) => s.type.isV2Type);

  /// Create a copy with updated values
  ContentBlock copyWith({
    bool? isCompleted,
    bool? isBookmarked,
    bool? isLiked,
    bool? isDisliked,
    int? currentStepIndex,
    String? selectedOptionId,
    bool? defaultPractice,
  }) {
    return ContentBlock(
      blockId: blockId,
      type: type,
      durationMinutes: durationMinutes,
      xp: xp,
      gpf: gpf,
      learning: learning,
      fsrs: fsrs,
      steps: steps,
      content: content,
      atomicHint: atomicHint,
      atomicHelp: atomicHelp,
      atomicImage: atomicImage,
      atomicVideo: atomicVideo,
      atomicQuestion: atomicQuestion,
      defaultPractice: defaultPractice ?? this.defaultPractice,
      isCompleted: isCompleted ?? this.isCompleted,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
    );
  }
}

/// Block binding metadata from lesson → block reference
class LessonBlockBinding {
  final String blockId;
  final int order;
  final String? bgColor;  // Background color for the block card (hex string)
  final bool defaultPractice;  // Whether this block is included in practice mode

  const LessonBlockBinding({
    required this.blockId,
    this.order = 0,
    this.bgColor,
    this.defaultPractice = false,
  });

  factory LessonBlockBinding.fromJson(Map<String, dynamic> json) {
    return LessonBlockBinding(
      blockId: json['block_id'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      bgColor: json['bg_color'] as String?,
      defaultPractice: json['default_practice'] as bool? ?? false,
    );
  }
}

/// Helper to load blocks for a lesson from course data
class BlockLoader {
  /// Load blocks for a specific lesson from course JSON data
  static List<ContentBlock> loadBlocksForLesson({
    required Map<String, dynamic> courseData,
    required String lessonId,
  }) {
    final lessons = courseData['lessons'] as List<dynamic>? ?? [];
    final blocks = courseData['blocks'] as List<dynamic>? ?? [];

    // Find the lesson
    Map<String, dynamic>? lessonJson;
    for (final l in lessons) {
      final lesson = l as Map<String, dynamic>;
      if (lesson['lesson_id'] == lessonId) {
        lessonJson = lesson;
        break;
      }
    }

    if (lessonJson == null) {
      return [];
    }

    // Get block IDs for this lesson
    // Format can be:
    // 1. New v2: blocks: [{block_id: "...", order: 1}, ...]
    // 2. Old: block_ids: ["..."]
    List<String> blockIds = [];

    final lessonBlocks = lessonJson['blocks'];
    if (lessonBlocks != null && lessonBlocks is List<dynamic>) {
      // New format: blocks is an array of objects with block_id
      // Sort by order if present
      final blockRefs = lessonBlocks
          .map((b) => b as Map<String, dynamic>)
          .toList();
      blockRefs.sort((a, b) {
        final orderA = a['order'] as int? ?? 0;
        final orderB = b['order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });
      blockIds = blockRefs
          .map((b) => b['block_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } else if (lessonJson['block_ids'] != null) {
      // Old format: block_ids is an array of strings
      blockIds = (lessonJson['block_ids'] as List<dynamic>)
          .map((id) => id as String)
          .toList();
    }

    // `default_practice` can live in EITHER place depending on how the course
    // was authored: on the global block definition (e.g. A2-Rovnice) or on the
    // lesson→block reference / binding (e.g. demo Zlomky). Treat the block as a
    // practice block if EITHER says so — a binding's default (false) must not
    // override a global true, and vice versa.
    final practiceFlags = <String, bool>{};
    for (final binding in getBlockBindingsForLesson(
      courseData: courseData,
      lessonId: lessonId,
    )) {
      practiceFlags[binding.blockId] = binding.defaultPractice;
    }

    // Find and parse each block
    final result = <ContentBlock>[];
    for (final blockId in blockIds) {
      for (final b in blocks) {
        final blockJson = b as Map<String, dynamic>;
        if (blockJson['block_id'] == blockId) {
          final block = ContentBlock.fromJson(blockJson);
          final bindingPractice = practiceFlags[blockId] ?? false;
          result.add(block.defaultPractice || bindingPractice
              ? block.copyWith(defaultPractice: true)
              : block);
          break;
        }
      }
    }

    return result;
  }

  /// Check if course data has blocks array (v2 format)
  static bool isBlockV2Format(Map<String, dynamic> courseData) {
    final hasBlocks = courseData['blocks'] != null;
    final blocksCount = hasBlocks ? (courseData['blocks'] as List<dynamic>).length : 0;
    return hasBlocks && blocksCount > 0;
  }

  /// Get block bindings for a specific lesson (metadata like bg_color, default_practice)
  static List<LessonBlockBinding> getBlockBindingsForLesson({
    required Map<String, dynamic> courseData,
    required String lessonId,
  }) {
    final lessons = courseData['lessons'] as List<dynamic>? ?? [];

    // Find the lesson
    Map<String, dynamic>? lessonJson;
    for (final l in lessons) {
      final lesson = l as Map<String, dynamic>;
      if (lesson['lesson_id'] == lessonId) {
        lessonJson = lesson;
        break;
      }
    }

    if (lessonJson == null) return [];

    final lessonBlocks = lessonJson['blocks'];
    if (lessonBlocks == null || lessonBlocks is! List<dynamic>) return [];

    // Parse bindings and sort by order
    final bindings = lessonBlocks
        .map((b) => LessonBlockBinding.fromJson(b as Map<String, dynamic>))
        .toList();
    bindings.sort((a, b) => a.order.compareTo(b.order));

    return bindings;
  }

  /// Load blocks with their bindings for a specific lesson
  static List<({ContentBlock block, LessonBlockBinding binding})> loadBlocksWithBindings({
    required Map<String, dynamic> courseData,
    required String lessonId,
  }) {
    final bindings = getBlockBindingsForLesson(
      courseData: courseData,
      lessonId: lessonId,
    );
    final blocks = courseData['blocks'] as List<dynamic>? ?? [];

    final result = <({ContentBlock block, LessonBlockBinding binding})>[];

    for (final binding in bindings) {
      for (final b in blocks) {
        final blockJson = b as Map<String, dynamic>;
        if (blockJson['block_id'] == binding.blockId) {
          result.add((
            block: ContentBlock.fromJson(blockJson),
            binding: binding,
          ));
          break;
        }
      }
    }

    return result;
  }
}
