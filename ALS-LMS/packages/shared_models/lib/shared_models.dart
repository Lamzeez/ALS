/// Shared data models for the ALS-LMS system.
///
/// These models match the PostgreSQL schema defined in the Supabase migrations
/// and are used across all apps (student, teacher, admin).
library shared_models;

// Core
export 'src/district.dart';
export 'src/profile.dart';
export 'src/cohort.dart';
export 'src/enrollment.dart';
export 'src/learning_center.dart';

// Curriculum
export 'src/course.dart';
export 'src/course_enrollment.dart';
export 'src/module.dart';
export 'src/lesson.dart';
export 'src/lesson_media.dart';
export 'src/quiz.dart';
export 'src/quiz_question.dart';

// Progress & Grading
export 'src/module_progress.dart';
export 'src/score.dart';
export 'src/attendance.dart';
export 'src/submission.dart';
export 'src/submission_comment.dart';

// Communication
export 'src/announcement.dart';
export 'src/announcement_comment.dart';

// System & Admin
export 'src/system_setting.dart';
export 'src/activity_log.dart';

// Sync & Audit
export 'src/sync_metadata.dart';

// Enums
export 'src/enums.dart';
