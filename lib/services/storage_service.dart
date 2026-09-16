import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class StorageService {
  static const String tasksKey = 'tasks';
  static const String focusSessionsKey = 'focusSessions';
  static const String focusTimeKey = 'focusTime';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<void> saveTasks(List<Task> tasks) async {
    final tasksJson = tasks.map((task) {
      return {
        'title': task.title,
        'category': task.category,
        'completed': task.completed,
        'completedAt': task.completedAt?.toIso8601String(),
      };
    }).toList();

    await _prefs.setString(tasksKey, jsonEncode(tasksJson));
  }

  Future<List<Task>> loadTasks() async {
    final savedData = await _prefs.getString(tasksKey);

    if (savedData == null) {
      return [];
    }

    final List<dynamic> decodedData = jsonDecode(savedData);

    return decodedData.map((item) {
      return Task(
        title: item['title'],
        category: item['category'],
        completed: item['completed'],
        completedAt: item['completedAt'] != null
            ? DateTime.parse(item['completedAt'])
            : null,
      );
    }).toList();
  }

  Future<void> saveFocusStats({
    required int sessions,
    required int focusSeconds,
  }) async {
    await _prefs.setInt(focusSessionsKey, sessions);
    await _prefs.setInt(focusTimeKey, focusSeconds);
  }

  Future<Map<String, int>> loadFocusStats() async {
    final sessions = await _prefs.getInt(focusSessionsKey) ?? 0;
    final focusSeconds = await _prefs.getInt(focusTimeKey) ?? 0;

    return {'sessions': sessions, 'focusSeconds': focusSeconds};
  }
}
 