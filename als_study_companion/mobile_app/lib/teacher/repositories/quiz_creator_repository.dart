import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for quiz creation and management (SQLite local cache & Supabase remote).
class QuizCreatorRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<QuizModel>> getQuizzesByTeacher(String teacherId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableQuizzes,
      where: 'teacherId = ?',
      whereArgs: [teacherId],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((m) => QuizModel.fromMap(m)).toList();
  }

  Future<void> createQuiz(QuizModel quiz) async {
    await _db.insert(DbConstants.tableQuizzes, quiz.toMap());
  }

  Future<void> updateQuiz(QuizModel quiz) async {
    await _db.update(DbConstants.tableQuizzes, quiz.toMap(), quiz.id);
  }

  Future<void> deleteQuiz(String id) async {
    await _db.delete(DbConstants.tableQuizzes, id);
  }

  Future<void> addQuestion(QuestionModel question) async {
    await _db.insert(DbConstants.tableQuestions, question.toMap());
  }

  Future<void> deleteQuestion(String id) async {
    await _db.delete(DbConstants.tableQuestions, id);
  }

  Future<List<QuestionModel>> getQuestionsByQuiz(String quizId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableQuestions,
      where: 'quizId = ?',
      whereArgs: [quizId],
      orderBy: 'orderIndex ASC',
    );
    return maps.map((m) => QuestionModel.fromMap(m)).toList();
  }

  // ─── Supabase Remote Operations ───

  Future<List<QuizModel>> fetchRemoteQuizzes(String teacherId) async {
    try {
      // Get quizzes for lessons owned by this teacher
      final lessonsRes = await Supabase.instance.client
          .from('lessons')
          .select('id')
          .eq('teacher_id', teacherId);
      final lessonIds = List<Map<String, dynamic>>.from(lessonsRes as List)
          .map((m) => m['id'] as String)
          .toList();
      if (lessonIds.isEmpty) return [];

      final res = await Supabase.instance.client
          .from('quizzes')
          .select()
          .inFilter('lesson_id', lessonIds);
      final items = List<Map<String, dynamic>>.from(res as List);
      final quizzes = items.map((m) => QuizModel.fromMap(m)).toList();
      for (final quiz in quizzes) {
        await _db.insert(DbConstants.tableQuizzes, quiz.toMap());
      }
      return quizzes;
    } catch (_) {
      return [];
    }
  }

  Future<void> pushQuiz(QuizModel quiz) async {
    try {
      await Supabase.instance.client.from('quizzes').upsert(quiz.toMap());
    } catch (_) {}
  }

  Future<void> pushQuestion(QuestionModel question) async {
    try {
      await Supabase.instance.client
          .from('questions')
          .upsert(question.toMap());
    } catch (_) {}
  }
}
