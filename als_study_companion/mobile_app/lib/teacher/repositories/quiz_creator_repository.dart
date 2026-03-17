import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for quiz creation and management.
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
    final map = quiz.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.insert(DbConstants.tableQuizzes, map);
  }

  Future<void> updateQuiz(QuizModel quiz) async {
    final map = quiz.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.update(DbConstants.tableQuizzes, map, quiz.id);
  }

  Future<void> deleteQuiz(String id) async {
    await _db.delete(DbConstants.tableQuizzes, id);
    try {
      await Supabase.instance.client.from('quizzes').delete().eq('id', id);
    } catch (_) {}
  }

  Future<void> addQuestion(QuestionModel question) async {
    final map = question.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.insert(DbConstants.tableQuestions, map);
  }

  Future<void> deleteQuestion(String id) async {
    await _db.delete(DbConstants.tableQuestions, id);
    try {
      await Supabase.instance.client.from('questions').delete().eq('id', id);
    } catch (_) {}
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
}
