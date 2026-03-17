import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for quiz data operations (SQLite local cache & Supabase remote).
class QuizRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ─── SQLite Operations ───

  Future<List<QuizModel>> getQuizzesByLesson(String lessonId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableQuizzes,
      where: 'lessonId = ? AND isPublished = 1',
      whereArgs: [lessonId],
    );
    return maps.map((m) => QuizModel.fromMap(m)).toList();
  }

  Future<QuizModel?> getQuizById(String id) async {
    final map = await _db.queryById(DbConstants.tableQuizzes, id);
    return map != null ? QuizModel.fromMap(map) : null;
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

  Future<void> saveQuiz(QuizModel quiz) async {
    await _db.insert(DbConstants.tableQuizzes, quiz.toMap());
  }

  Future<void> saveQuestion(QuestionModel question) async {
    await _db.insert(DbConstants.tableQuestions, question.toMap());
  }

  Future<void> saveQuestions(List<QuestionModel> questions) async {
    for (final q in questions) {
      await _db.insert(DbConstants.tableQuestions, q.toMap());
    }
  }

  Future<void> deleteQuiz(String id) async {
    await _db.delete(DbConstants.tableQuizzes, id);
  }

  // ─── Supabase Remote Operations ───

  Future<List<QuizModel>> fetchRemoteQuizzes(String lessonId) async {
    try {
      final res = await Supabase.instance.client
          .from('quizzes')
          .select()
          .eq('lesson_id', lessonId);
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

  Future<List<QuestionModel>> fetchRemoteQuestions(String quizId) async {
    try {
      final res = await Supabase.instance.client
          .from('questions')
          .select()
          .eq('quiz_id', quizId);
      final items = List<Map<String, dynamic>>.from(res as List);
      final questions = items.map((m) => QuestionModel.fromMap(m)).toList();
      for (final q in questions) {
        await _db.insert(DbConstants.tableQuestions, q.toMap());
      }
      return questions;
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
