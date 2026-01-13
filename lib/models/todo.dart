class Todo {
  int? id;

  // Identity (future hook)
  final String userId;

  /// Wajib
  String description;

  /// Optional (HB-ExeCon v1)
  final String? soNumber;
  final String? ref;
  final String priority;
  final DateTime? dueDate;
  final int? progress;

  // Timeline
  final DateTime taskDate;

  /// Derived status
  bool isDone;

  Todo({
    this.id,
    required this.userId,
    required this.description,
    this.soNumber,
    this.ref,
    required this.priority,
    this.dueDate,
    this.progress,
    required this.taskDate,
    this.isDone = false,
  });

  // =====================================================
  // SQLite helper (future-proof)
  // =====================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'description': description,
      'priority': priority,
      'so_number': soNumber,
      'ref': ref,
      'due_date': dueDate?.toIso8601String(),
      'progress': progress,
      'task_date': taskDate?.toIso8601String(),
      'is_done': isDone ? 1 : 0,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'],
      userId: map['userId'],
      description: map['description'],
      priority: map['priority'],
      soNumber: map['so_number'],
      ref: map['ref'],
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      progress: map['progress'],
      taskDate: map['task_date'] != null
          ? DateTime.parse(map['task_date'])
          : DateTime.now(),
      isDone: map['is_done'] == 1,
    );
  }
}
