import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/course_model.dart';
import '../core/strings/app_strings.dart';
import '../core/layout/breakpoints.dart';

/// Exercise Page for practicing course content
class ExercisePage extends StatefulWidget {
  final ExerciseSession session;

  const ExercisePage({
    super.key,
    required this.session,
  });

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  int _currentQuestionIndex = 0;

  // Answer state
  String? _selectedOptionId;
  Set<String> _selectedMultiOptions = {};
  String _freeTextAnswer = '';
  final TextEditingController _textController = TextEditingController();

  // Result state
  AnswerResult _answerResult = AnswerResult.unanswered;
  bool _isAnswered = false;

  // Action states
  bool _isBookmarked = false;
  bool _isLiked = false;
  bool _isDisliked = false;

  ExerciseQuestion get _currentQuestion =>
      widget.session.questions[_currentQuestionIndex];

  int get _totalQuestions => widget.session.questions.length;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _selectOption(String optionId) {
    if (_isAnswered) return;
    setState(() {
      _selectedOptionId = optionId;
    });
  }

  void _toggleMultiOption(String optionId) {
    if (_isAnswered) return;
    setState(() {
      if (_selectedMultiOptions.contains(optionId)) {
        _selectedMultiOptions.remove(optionId);
      } else {
        _selectedMultiOptions.add(optionId);
      }
    });
  }

  void _checkAnswer() {
    dynamic answer;
    switch (_currentQuestion.type) {
      case ExerciseQuestionType.singleSelect:
      case ExerciseQuestionType.singleSelectImage:
        answer = _selectedOptionId;
        break;
      case ExerciseQuestionType.multiSelect:
        answer = _selectedMultiOptions;
        break;
      case ExerciseQuestionType.freeText:
        answer = _freeTextAnswer;
        break;
    }

    final isCorrect = _currentQuestion.checkAnswer(answer);

    setState(() {
      _answerResult = isCorrect ? AnswerResult.correct : AnswerResult.incorrect;
      _isAnswered = true;
    });
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex < _totalQuestions - 1) {
      setState(() {
        _currentQuestionIndex++;
        _resetAnswerState();
      });
    } else {
      // Exercise completed - go back
      Navigator.pop(context);
    }
  }

  void _resetAnswerState() {
    _selectedOptionId = null;
    _selectedMultiOptions = {};
    _freeTextAnswer = '';
    _textController.clear();
    _answerResult = AnswerResult.unanswered;
    _isAnswered = false;
    _isBookmarked = false;
    _isLiked = false;
    _isDisliked = false;
  }

  bool get _canCheckAnswer {
    switch (_currentQuestion.type) {
      case ExerciseQuestionType.singleSelect:
      case ExerciseQuestionType.singleSelectImage:
        return _selectedOptionId != null;
      case ExerciseQuestionType.multiSelect:
        return _selectedMultiOptions.isNotEmpty;
      case ExerciseQuestionType.freeText:
        return _freeTextAnswer.trim().isNotEmpty;
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
      body: Column(
        children: [
          // Fixed header
          _buildHeader(),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question text
                  Text(
                    _currentQuestion.question,
                    style: AppTextStyles.heading2Bold(
                      color: AppColors.primaryDark,
                    ).copyWith(height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  // Instruction text
                  Text(
                    _getInstructionText(),
                    style: AppTextStyles.body(
                      color: AppColors.primaryDark64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Answer options based on question type
                  _buildAnswerSection(),
                  // Extra padding when feedback is shown
                  if (_isAnswered) const SizedBox(height: 280),
                ],
              ),
            ),
          ),
          // Bottom action bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  String _getInstructionText() {
    switch (_currentQuestion.type) {
      case ExerciseQuestionType.singleSelect:
      case ExerciseQuestionType.singleSelectImage:
        return AppStrings.exerciseSelectCorrect;
      case ExerciseQuestionType.multiSelect:
        return AppStrings.exerciseSelectAll;
      case ExerciseQuestionType.freeText:
        return AppStrings.exerciseWriteAnswer;
    }
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppDecorations.shadowStrong,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top row with back button, title, and XP badge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: AppDecorations.circleButton,
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.primaryDark,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.title,
                          style: AppTextStyles.statValue(),
                        ),
                        Text(
                          widget.session.subtitle,
                          style: AppTextStyles.body(
                            color: AppColors.primaryDark64,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // XP Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: AppDecorations.radiusS,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+${widget.session.totalXp} XP',
                          style: AppTextStyles.badge(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildProgressBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentQuestionIndex + 1) / _totalQuestions;

    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final progressWidth = constraints.maxWidth * progress;
          final minProgressWidth = progress > 0 ? 60.0 : 0.0;
          final actualProgressWidth = progressWidth < minProgressWidth ? minProgressWidth : progressWidth;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Background with diagonal stripes
              ClipRRect(
                borderRadius: AppDecorations.radiusXS,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.progressTrack,
                  ),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 24),
                    painter: _DiagonalStripesPainter(
                      stripeColor: AppColors.background,
                      stripeWidth: 4,
                      spacing: 8.964,
                    ),
                  ),
                ),
              ),
              // Progress fill with text
              Container(
                width: actualProgressWidth,
                decoration: BoxDecoration(
                  color: AppColors.progressFill,
                  borderRadius: AppDecorations.radiusXS,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // White progress line at top
                    Positioned(
                      left: 4,
                      top: 4,
                      right: 4,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Progress text at the end of progress bar
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.progressBorder,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_currentQuestionIndex + 1}/$_totalQuestions',
                            style: AppTextStyles.actionText(
                              color: Colors.white,
                            ).copyWith(height: 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnswerSection() {
    switch (_currentQuestion.type) {
      case ExerciseQuestionType.singleSelect:
        return _buildSingleSelectOptions();
      case ExerciseQuestionType.singleSelectImage:
        return _buildSingleSelectImageOptions();
      case ExerciseQuestionType.multiSelect:
        return _buildMultiSelectOptions();
      case ExerciseQuestionType.freeText:
        return _buildFreeTextInput();
    }
  }

  // Single select (simple text options)
  Widget _buildSingleSelectOptions() {
    return Column(
      children: _currentQuestion.options.map((option) {
        final isSelected = _selectedOptionId == option.id;
        final showResult = _isAnswered && isSelected;
        final isCorrect = option.isCorrect;
        final isCorrectOption = _isAnswered && option.isCorrect;

        Color borderColor = AppColors.surfaceLight;
        Color bgColor = AppColors.surface;

        if (isSelected && !_isAnswered) {
          borderColor = AppColors.primaryDark;
        } else if (_isAnswered) {
          if (isCorrectOption) {
            borderColor = AppColors.success;
            bgColor = AppColors.successBg;
          } else if (showResult && !isCorrect) {
            borderColor = AppColors.orange;
            bgColor = AppColors.orangeBg;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _selectOption(option.id),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: AppDecorations.radiusM,
                border: Border.all(
                  color: borderColor,
                  width: isSelected || isCorrectOption ? 2 : 1,
                ),
                boxShadow: AppDecorations.shadowLight,
              ),
              child: Row(
                children: [
                  // Radio indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isAnswered
                          ? (isCorrectOption
                              ? AppColors.success
                              : (showResult && !isCorrect
                                  ? AppColors.orange
                                  : Colors.transparent))
                          : (isSelected ? AppColors.primaryDark : Colors.transparent),
                      border: Border.all(
                        color: _isAnswered
                            ? (isCorrectOption
                                ? AppColors.success
                                : (showResult && !isCorrect
                                    ? AppColors.orange
                                    : AppColors.surfaceLight))
                            : (isSelected
                                ? AppColors.primaryDark
                                : AppColors.surfaceLight),
                        width: 2,
                      ),
                    ),
                    child: (isSelected || (_isAnswered && isCorrectOption))
                        ? Icon(
                            _isAnswered
                                ? (isCorrectOption
                                    ? Icons.check
                                    : (!isCorrect ? Icons.close : null))
                                : Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.text,
                      style: AppTextStyles.body(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Single select with images
  Widget _buildSingleSelectImageOptions() {
    return Column(
      children: _currentQuestion.options.map((option) {
        final isSelected = _selectedOptionId == option.id;
        final showResult = _isAnswered && isSelected;
        final isCorrect = option.isCorrect;
        final isCorrectOption = _isAnswered && option.isCorrect;

        Color borderColor = AppColors.surfaceLight;
        Color bgColor = AppColors.surface;

        if (isSelected && !_isAnswered) {
          borderColor = AppColors.primaryDark;
        } else if (_isAnswered) {
          if (isCorrectOption) {
            borderColor = AppColors.success;
            bgColor = AppColors.successBg;
          } else if (showResult && !isCorrect) {
            borderColor = AppColors.orange;
            bgColor = AppColors.orangeBg;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _selectOption(option.id),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: AppDecorations.radiusM,
                border: Border.all(
                  color: borderColor,
                  width: isSelected || isCorrectOption ? 2 : 1,
                ),
                boxShadow: AppDecorations.shadowLight,
              ),
              child: Row(
                children: [
                  // Radio indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isAnswered
                          ? (isCorrectOption
                              ? AppColors.success
                              : (showResult && !isCorrect
                                  ? AppColors.orange
                                  : Colors.transparent))
                          : (isSelected ? AppColors.primaryDark : Colors.transparent),
                      border: Border.all(
                        color: _isAnswered
                            ? (isCorrectOption
                                ? AppColors.success
                                : (showResult && !isCorrect
                                    ? AppColors.orange
                                    : AppColors.surfaceLight))
                            : (isSelected
                                ? AppColors.primaryDark
                                : AppColors.surfaceLight),
                        width: 2,
                      ),
                    ),
                    child: (isSelected || (_isAnswered && isCorrectOption))
                        ? Icon(
                            _isAnswered
                                ? (isCorrectOption
                                    ? Icons.check
                                    : (!isCorrect ? Icons.close : null))
                                : Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.text,
                          style: AppTextStyles.statValue(),
                        ),
                        if (option.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            option.description!,
                            style: AppTextStyles.meta(
                              color: AppColors.primaryDark64,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Image placeholder
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: AppDecorations.radiusS,
                    ),
                    child: Center(
                      child: Icon(
                        _getAnimalIcon(option.imageUrl),
                        size: 40,
                        color: AppColors.primaryDark48,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getAnimalIcon(String? imageKey) {
    switch (imageKey) {
      case 'bat':
        return Icons.nightlight;
      case 'eagle':
        return Icons.flutter_dash;
      case 'frog':
        return Icons.pest_control;
      case 'penguin':
        return Icons.ac_unit;
      case 'amoeba':
        return Icons.bubble_chart;
      case 'jellyfish':
        return Icons.waves;
      case 'caterpillar':
        return Icons.bug_report;
      case 'coral':
        return Icons.eco;
      default:
        return Icons.image;
    }
  }

  // Multi-select (chip style)
  Widget _buildMultiSelectOptions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _currentQuestion.options.map((option) {
        final isSelected = _selectedMultiOptions.contains(option.id);
        final isCorrect = option.isCorrect;
        final showCorrect = _isAnswered && isCorrect;
        final showIncorrect = _isAnswered && isSelected && !isCorrect;

        Color borderColor = AppColors.surfaceLight;
        Color bgColor = AppColors.surface;
        Color textColor = AppColors.primaryDark;

        if (!_isAnswered && isSelected) {
          borderColor = AppColors.primaryDark;
          bgColor = AppColors.background;
        } else if (_isAnswered) {
          if (showCorrect) {
            borderColor = AppColors.success;
            bgColor = AppColors.successBg;
            textColor = AppColors.success;
          } else if (showIncorrect) {
            borderColor = AppColors.orange;
            bgColor = AppColors.orangeBg;
            textColor = AppColors.orange;
          }
        }

        return GestureDetector(
          onTap: () => _toggleMultiOption(option.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppDecorations.radiusM,
              border: Border.all(
                color: borderColor,
                width: isSelected || showCorrect ? 2 : 1,
              ),
              boxShadow: AppDecorations.shadowLight,
            ),
            child: Text(
              option.text,
              style: AppTextStyles.bodySemiBold(
                color: textColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Free text input
  Widget _buildFreeTextInput() {
    final showCorrect = _isAnswered && _answerResult == AnswerResult.correct;
    final showIncorrect = _isAnswered && _answerResult == AnswerResult.incorrect;

    Color borderColor = AppColors.surfaceLight;
    Color bgColor = AppColors.surface;

    if (showCorrect) {
      borderColor = AppColors.success;
      bgColor = AppColors.successBg;
    } else if (showIncorrect) {
      borderColor = AppColors.orange;
      bgColor = AppColors.orangeBg;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppDecorations.radiusM,
            border: Border.all(
              color: borderColor,
              width: _isAnswered ? 2 : 1,
            ),
            boxShadow: AppDecorations.shadowLight,
          ),
          child: TextField(
            controller: _textController,
            enabled: !_isAnswered,
            maxLines: 5,
            onChanged: (value) {
              setState(() {
                _freeTextAnswer = value;
              });
            },
            decoration: InputDecoration(
              hintText: AppStrings.exerciseAnswerHint,
              hintStyle: AppTextStyles.body(
                color: AppColors.primaryDark48,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: AppTextStyles.body(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.exerciseCharCount(_freeTextAnswer.length),
          style: AppTextStyles.meta(
            color: AppColors.primaryDark48,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    // When answered, show expanded feedback panel
    if (_isAnswered) {
      return _buildFeedbackBottomBar();
    }

    // When not answered, show simple button bar
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark16,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _canCheckAnswer ? _checkAnswer : null,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: _canCheckAnswer
                ? AppColors.primaryDark
                : AppColors.disabledButton,
            borderRadius: AppDecorations.radiusS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppStrings.actionContinue,
                style: AppTextStyles.statValue(color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBottomBar() {
    final isCorrect = _answerResult == AnswerResult.correct;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark16,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Result banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect
                  ? AppColors.successBg
                  : AppColors.orangeBg,
              borderRadius: AppDecorations.radiusM,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? AppColors.success
                        : AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCorrect ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCorrect ? AppStrings.exerciseCorrect : AppStrings.exerciseIncorrect,
                        style: AppTextStyles.cardTitleSmall(
                          color: isCorrect
                              ? AppColors.success
                              : AppColors.orange,
                        ),
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.exerciseCorrectAnswer(_currentQuestion.getCorrectAnswerText()),
                          style: AppTextStyles.bodySmall(
                            color: AppColors.primaryDark72,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Explanation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.hintBg,
              borderRadius: AppDecorations.radiusM,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.hintIcon,
                    borderRadius: AppDecorations.radiusXS,
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.exerciseExplanationLabel,
                        style: AppTextStyles.statValue(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentQuestion.explanation,
                        style: AppTextStyles.bodySmall(
                          color: AppColors.primaryDark72,
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bottom row with actions and continue button
          Row(
            children: [
              // Action buttons
              // Bookmark hidden (TODO: re-enable when ready)
              _buildActionButton(
                icon: Icons.thumb_up_outlined,
                isActive: _isLiked,
                activeColor: AppColors.success,
                onTap: () => setState(() {
                  _isLiked = !_isLiked;
                  if (_isLiked) _isDisliked = false;
                }),
              ),
              _buildActionButton(
                icon: Icons.thumb_down_outlined,
                isActive: _isDisliked,
                activeColor: AppColors.orange,
                onTap: () => setState(() {
                  _isDisliked = !_isDisliked;
                  if (_isDisliked) _isLiked = false;
                }),
              ),
              _buildActionButton(
                icon: Icons.help_outline,
                isActive: false,
                onTap: () {
                  // TODO: Ask question
                },
              ),
              const Spacer(),
              // Continue button
              GestureDetector(
                onTap: _goToNextQuestion,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: AppDecorations.radiusS,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.actionContinue,
                        style: AppTextStyles.statValue(color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? (activeColor ?? AppColors.primaryDark) : AppColors.disabled,
          size: 24,
        ),
      ),
    );
  }
}

/// Custom painter for diagonal stripes pattern
class _DiagonalStripesPainter extends CustomPainter {
  final Color stripeColor;
  final double stripeWidth;
  final double spacing;

  _DiagonalStripesPainter({
    required this.stripeColor,
    required this.stripeWidth,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    final double step = stripeWidth + spacing;
    final double diagonal = size.width + size.height;

    for (double i = -size.height; i < diagonal; i += step) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
