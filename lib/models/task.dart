class Task {
  String title;
  String category;
  bool completed;
  DateTime? completedAt;

  Task({
    required this.title,
    required this.category,
    required this.completed,
    this.completedAt,
  });
}