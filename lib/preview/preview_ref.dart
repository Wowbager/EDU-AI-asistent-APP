// The address of a place in a CourseV2 document, as the editor speaks it.
//
// The editor calls this a `Ref`: `{ lessonId?, blockId?, stepId?, optionId?, field? }`.
// The player sends one back when the author clicks something in the preview, so the
// editor can put the cursor in the field that produced it.

class PreviewRef {
  final String? lessonId;
  final String? blockId;
  final String? stepId;
  final String? optionId;
  final String? field;

  const PreviewRef({
    this.lessonId,
    this.blockId,
    this.stepId,
    this.optionId,
    this.field,
  });

  Map<String, dynamic> toJson() => {
        if (lessonId != null) 'lessonId': lessonId,
        if (blockId != null) 'blockId': blockId,
        if (stepId != null) 'stepId': stepId,
        if (optionId != null) 'optionId': optionId,
        if (field != null) 'field': field,
      };

  factory PreviewRef.fromJson(Map<String, dynamic> json) => PreviewRef(
        lessonId: json['lessonId'] as String?,
        blockId: json['blockId'] as String?,
        stepId: json['stepId'] as String?,
        optionId: json['optionId'] as String?,
        field: json['field'] as String?,
      );

  PreviewRef copyWith({
    String? lessonId,
    String? blockId,
    String? stepId,
    String? optionId,
    String? field,
  }) =>
      PreviewRef(
        lessonId: lessonId ?? this.lessonId,
        blockId: blockId ?? this.blockId,
        stepId: stepId ?? this.stepId,
        optionId: optionId ?? this.optionId,
        field: field ?? this.field,
      );

  @override
  String toString() => 'PreviewRef(${toJson()})';

  @override
  bool operator ==(Object other) =>
      other is PreviewRef &&
      other.lessonId == lessonId &&
      other.blockId == blockId &&
      other.stepId == stepId &&
      other.optionId == optionId &&
      other.field == field;

  @override
  int get hashCode => Object.hash(lessonId, blockId, stepId, optionId, field);
}
