/// Enums matching PostgreSQL custom types in the ALS-LMS schema.

enum UserRole {
  student,
  teacher,
  centerAdmin,
  schoolAdmin, // Added for compatibility
  systemAdmin,
  devAdmin,    // Added for compatibility
  @Deprecated('Use systemAdmin instead')
  admin;

  /// Convert to/from Postgres enum string
  String toJson() {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.centerAdmin:
        return 'center_admin';
      case UserRole.schoolAdmin:
        return 'school_admin';
      case UserRole.systemAdmin:
      case UserRole.admin:
        return 'system_admin';
      case UserRole.devAdmin:
        return 'dev_admin';
    }
  }

  static UserRole fromJson(String value) {
    switch (value) {
      case 'student':
        return UserRole.student;
      case 'teacher':
        return UserRole.teacher;
      case 'center_admin':
        return UserRole.centerAdmin;
      case 'school_admin':
        return UserRole.schoolAdmin;
      case 'system_admin':
      case 'admin':
        return UserRole.systemAdmin;
      case 'dev_admin':
        return UserRole.devAdmin;
      default:
        return UserRole.student;
    }
  }
}

enum CenterRegistrationStatus {
  pending,
  approved,
  rejected;

  String toJson() => name;
  static CenterRegistrationStatus fromJson(String value) {
    return CenterRegistrationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CenterRegistrationStatus.pending,
    );
  }
}

enum AlsStrand {
  communicationSkills,
  scientificLiteracy,
  mathematicalLiteracy,
  lifeLivelihoodSkills,
  digitalLiteracy,
  understandingSelfSociety;

  String toJson() {
    switch (this) {
      case AlsStrand.communicationSkills:
        return 'communication_skills';
      case AlsStrand.scientificLiteracy:
        return 'scientific_literacy';
      case AlsStrand.mathematicalLiteracy:
        return 'mathematical_literacy';
      case AlsStrand.lifeLivelihoodSkills:
        return 'life_livelihood_skills';
      case AlsStrand.digitalLiteracy:
        return 'digital_literacy';
      case AlsStrand.understandingSelfSociety:
        return 'understanding_self_society';
    }
  }

  static AlsStrand fromJson(String value) {
    switch (value) {
      case 'communication_skills':
        return AlsStrand.communicationSkills;
      case 'scientific_literacy':
        return AlsStrand.scientificLiteracy;
      case 'mathematical_literacy':
        return AlsStrand.mathematicalLiteracy;
      case 'life_livelihood_skills':
        return AlsStrand.lifeLivelihoodSkills;
      case 'digital_literacy':
        return AlsStrand.digitalLiteracy;
      case 'understanding_self_society':
        return AlsStrand.understandingSelfSociety;
      default:
        return AlsStrand.communicationSkills;
    }
  }
}

enum ApprovalStatus {
  pending,
  approved,
  rejected;

  String toJson() => name;
  static ApprovalStatus fromJson(String? value) =>
      ApprovalStatus.values.firstWhere((e) => e.name == value,
          orElse: () => ApprovalStatus.approved);
}

enum EnrollmentStatus {
  active,
  inactive,
  withdrawn,
  completed,
  dropped;

  String toJson() => name;
  static EnrollmentStatus fromJson(String value) =>
      EnrollmentStatus.values.firstWhere((evidence) => evidence.name == value,
          orElse: () => EnrollmentStatus.active);
}

enum ProgressStatus {
  locked,
  available,
  inProgress,
  completed,
  mastered;

  String toJson() {
    switch (this) {
      case ProgressStatus.locked:
        return 'locked';
      case ProgressStatus.available:
        return 'available';
      case ProgressStatus.inProgress:
        return 'in_progress';
      case ProgressStatus.completed:
        return 'completed';
      case ProgressStatus.mastered:
        return 'mastered';
    }
  }

  static ProgressStatus fromJson(String value) {
    switch (value) {
      case 'locked':
        return ProgressStatus.locked;
      case 'available':
        return ProgressStatus.available;
      case 'in_progress':
        return ProgressStatus.inProgress;
      case 'completed':
        return ProgressStatus.completed;
      case 'mastered':
        return ProgressStatus.mastered;
      default:
        return ProgressStatus.locked;
    }
  }
}

enum ModuleType {
  core,
  elective,
  assessment,
  enrichment;

  String toJson() => name;
  static ModuleType fromJson(String value) => ModuleType.values
      .firstWhere((e) => e.name == value, orElse: () => ModuleType.core);
}

enum LessonContentType {
  text,
  video,
  pdf,
  interactive,
  mixed;

  String toJson() => name;
  static LessonContentType fromJson(String value) => LessonContentType.values
      .firstWhere((e) => e.name == value, orElse: () => LessonContentType.text);
}

enum MediaFileType {
  video,
  pdf,
  image,
  audio,
  document;

  String toJson() => name;
  static MediaFileType fromJson(String value) => MediaFileType.values
      .firstWhere((e) => e.name == value, orElse: () => MediaFileType.document);
}

enum QuestionType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  matching,
  essay;

  String toJson() {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.shortAnswer:
        return 'short_answer';
      case QuestionType.matching:
        return 'matching';
      case QuestionType.essay:
        return 'essay';
    }
  }

  static QuestionType fromJson(String value) {
    switch (value) {
      case 'multiple_choice':
        return QuestionType.multipleChoice;
      case 'true_false':
        return QuestionType.trueFalse;
      case 'short_answer':
        return QuestionType.shortAnswer;
      case 'matching':
        return QuestionType.matching;
      case 'essay':
        return QuestionType.essay;
      default:
        return QuestionType.multipleChoice;
    }
  }
}

enum AttendanceStatus {
  present,
  absent,
  late,
  excused;

  String toJson() => name;
  static AttendanceStatus fromJson(String value) =>
      AttendanceStatus.values.firstWhere((e) => e.name == value,
          orElse: () => AttendanceStatus.present);
}

enum SubmissionStatus {
  draft,
  submitted,
  graded,
  returned;

  String toJson() => name;
  static SubmissionStatus fromJson(String value) => SubmissionStatus.values
      .firstWhere((e) => e.name == value, orElse: () => SubmissionStatus.draft);
}

enum SessionStatus {
  scheduled,
  live,
  completed,
  cancelled;

  String toJson() => name;
  static SessionStatus fromJson(String value) =>
      SessionStatus.values.firstWhere((e) => e.name == value,
          orElse: () => SessionStatus.scheduled);
}

enum EnrollmentMethod {
  qrCode,
  pin,
  manual;

  String toJson() {
    switch (this) {
      case EnrollmentMethod.qrCode:
        return 'qr_code';
      case EnrollmentMethod.pin:
        return 'pin';
      case EnrollmentMethod.manual:
        return 'manual';
    }
  }

  static EnrollmentMethod fromJson(String value) {
    switch (value) {
      case 'qr_code':
        return EnrollmentMethod.qrCode;
      case 'pin':
        return EnrollmentMethod.pin;
      case 'manual':
        return EnrollmentMethod.manual;
      default:
        return EnrollmentMethod.pin;
    }
  }
}

enum SystemStatus {
  active,
  maintenance,
  locked;

  String toJson() => name;
  static SystemStatus fromJson(String value) => SystemStatus.values
      .firstWhere((e) => e.name == value, orElse: () => SystemStatus.active);
}
