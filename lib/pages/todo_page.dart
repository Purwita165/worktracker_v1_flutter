/*
============================================================
FILE: todo_page.dart
============================================================

UI Layer dari aplikasi WorkTracker.

Fungsi utama:

• Menampilkan daftar task
• Menambah task
• Mengedit task
• Menghapus task
• Toggle completed
• Search task
• Filter task
• Statistics task
• Progress indicator
• Highlight overdue

============================================================
*/

import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../database/db_helper.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({Key? key}) : super(key: key);

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final dbHelper = DBHelper.instance;

  List<Todo> todos = [];
  String searchText = "";

  /*
  ============================================================
  FILTER STATE
  ============================================================
  */

  String filterMode = "all";
  String? priorityFilter;
  String? dueFilter;

  /*
  ============================================================
  FORM CONTROLLERS
  ============================================================
  */

  final descController = TextEditingController();
  final workController = TextEditingController();
  final refController = TextEditingController();
  final searchController = TextEditingController();

  String? priority;
  DateTime? dueDate;
  int progress = 0;

  final String currentUserId = "local-user";

  /*
  ============================================================
  PRIORITY LABEL
  ============================================================
  */

  static const Map<String, String> priorityLabels = {
    "H": "High",
    "M": "Medium",
    "L": "Low",
  };

  /*
  ============================================================
  PRIORITY COLOR
  ============================================================
  */

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "H":
        return Colors.red;

      case "M":
        return Colors.orange;

      case "L":
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  /*
  ============================================================
  INIT
  ============================================================
  */

  @override
  void initState() {
    super.initState();
    loadTodos();
  }

  /*
  ============================================================
  LOAD DATA
  ============================================================
  */

  Future<void> loadTodos() async {
    final data = await dbHelper.getTodos();

    setState(() {
      data.sort((a, b) => b.priority.compareTo(a.priority));

      todos = data;
    });
  }

  /*
  ============================================================
  ADD TODO
  ============================================================
  */

  Future<void> addTodo() async {
    if (descController.text.trim().isEmpty) return;

    final todo = Todo(
      userId: currentUserId,
      description: descController.text.trim(),
      workId: workController.text,
      ref: refController.text,
      priority: priority ?? "M",
      dueDate: dueDate,
      progress: progress,
      taskDate: DateTime.now(),
      isDone: false,
    );

    await dbHelper.insertTodo(todo);

    await loadTodos();
  }

  /*
  ============================================================
  UPDATE TODO
  ============================================================
  */

  Future<void> updateTodo(Todo todo) async {
    final updated = Todo(
      id: todo.id,
      userId: todo.userId,
      description: descController.text.trim(),
      workId: workController.text,
      ref: refController.text,
      priority: priority ?? "M",
      dueDate: dueDate,
      progress: progress,
      taskDate: todo.taskDate,
      isDone: todo.isDone,
    );

    await dbHelper.updateTodo(updated);

    await loadTodos();
  }

  /*
  ============================================================
  DELETE TODO
  ============================================================
  */

  Future<void> deleteTodo(int id) async {
    await dbHelper.deleteTodo(id);

    await loadTodos();
  }

  /*
  ============================================================
  DELETE CONFIRMATION
  ============================================================
  */

  Future<void> confirmDelete(Todo todo) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Task"),

          content: Text(
            "Are you sure you want to delete:\n\n${todo.description} ?",
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await deleteTodo(todo.id!);

                Navigator.pop(context);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  /*
  ============================================================
  TOGGLE STATUS
  ============================================================
  */

  Future<void> toggleTodo(Todo todo) async {
    todo.isDone = !todo.isDone;

    await dbHelper.updateTodoStatus(todo.id!, todo.isDone ? 1 : 0);

    await loadTodos();
  }

  /*
  ============================================================
  FILTER ENGINE
  ============================================================
  */

  List<Todo> getFilteredTodos() {
    final now = DateTime.now();

    return todos.where((t) {
      if (filterMode == "active" && t.isDone) return false;

      if (filterMode == "completed" && !t.isDone) return false;

      if (priorityFilter != null && t.priority != priorityFilter) {
        return false;
      }

      if (dueFilter == "overdue") {
        if (t.dueDate == null || !t.dueDate!.isBefore(now)) {
          return false;
        }
      }

      if (dueFilter == "week") {
        if (t.dueDate == null) return false;

        final weekLater = now.add(const Duration(days: 7));

        if (t.dueDate!.isAfter(weekLater)) return false;
      }

      if (dueFilter == "month") {
        if (t.dueDate == null) return false;

        final monthLater = DateTime(now.year, now.month + 1, now.day);

        if (t.dueDate!.isAfter(monthLater)) return false;
      }

      /*
      SEARCH FILTER
      */

      if (searchText.isNotEmpty) {
        if (!t.description.toLowerCase().contains(searchText.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /*
  ============================================================
  TODAY DATE
  ============================================================
  */

  String getToday() {
    final now = DateTime.now();

    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  /*
  ============================================================
  TASK DIALOG
  ============================================================
  */

  void openTaskDialog({Todo? todo}) {
    if (todo != null) {
      descController.text = todo.description;
      workController.text = todo.workId ?? "";
      refController.text = todo.ref ?? "";
      priority = todo.priority;
      dueDate = todo.dueDate;
      progress = todo.progress ?? 0;
    } else {
      descController.clear();
      workController.clear();
      refController.clear();

      priority = "M";
      progress = 0;
      dueDate = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(todo == null ? "Add Task" : "Edit Task"),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: "Description",
                      ),
                    ),

                    TextField(
                      controller: workController,
                      decoration: const InputDecoration(labelText: "WorkID"),
                    ),

                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(labelText: "Reference"),
                    ),

                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(labelText: "Priority"),
                      items: const [
                        DropdownMenuItem(value: "H", child: Text("High")),
                        DropdownMenuItem(value: "M", child: Text("Medium")),
                        DropdownMenuItem(value: "L", child: Text("Low")),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          priority = value;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    Text("Progress: $progress%"),

                    Slider(
                      value: progress.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      onChanged: (value) {
                        setStateDialog(() {
                          progress = value.toInt();
                        });
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (todo == null) {
                      await addTodo();
                    } else {
                      await updateTodo(todo);
                    }

                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /*
================================================
PRIORITY FILTER DIALOG
================================================
*/

  void showPriorityDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Filter Priority"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("High"),
                onTap: () {
                  setState(() {
                    priorityFilter = "H";
                  });
                  Navigator.pop(context);
                },
              ),

              ListTile(
                title: const Text("Medium"),
                onTap: () {
                  setState(() {
                    priorityFilter = "M";
                  });
                  Navigator.pop(context);
                },
              ),

              ListTile(
                title: const Text("Low"),
                onTap: () {
                  setState(() {
                    priorityFilter = "L";
                  });
                  Navigator.pop(context);
                },
              ),

              ListTile(
                title: const Text("Clear"),
                onTap: () {
                  setState(() {
                    priorityFilter = null;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /*
================================================
DUE DATE FILTER DIALOG
================================================
*/

  void showDueDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Filter Due Date"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("Overdue"),
                onTap: () {
                  setState(() {
                    dueFilter = "overdue";
                  });
                  Navigator.pop(context);
                },
              ),

              ListTile(
                title: const Text("This Week"),
                onTap: () {
                  setState(() {
                    dueFilter = "week";
                  });
                  Navigator.pop(context);
                },
              ),

              ListTile(
                title: const Text("This Month"),
                onTap: () {
                  setState(() {
                    dueFilter = "month";
                  });
                  Navigator.pop(context);
                },
              ),

              ListTile(
                title: const Text("Clear"),
                onTap: () {
                  setState(() {
                    dueFilter = null;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /*
  ============================================================
  UI
  ============================================================
  */

  @override
  Widget build(BuildContext context) {
    final filteredTodos = getFilteredTodos();

    final activeCount = todos.where((t) => !t.isDone).length;

    final completedCount = todos.where((t) => t.isDone).length;

    return Scaffold(
      appBar: AppBar(title: const Text("WorkTracker")),

      body: Column(
        children: [
          const SizedBox(height: 6),

          /*
          TODAY DATE
          */
          Text(
            getToday(),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),

          const SizedBox(height: 10),

          /*
          STATISTICS
          */
          Text(
            "Active: $activeCount   Completed: $completedCount",
            style: const TextStyle(fontSize: 14),
          ),

          const SizedBox(height: 10),

          /*
          SEARCH BAR
          */
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search task...",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
          ),

          /*
          FILTER BAR
          */
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text("All"),
                selected: filterMode == "all",
                onSelected: (_) {
                  setState(() => filterMode = "all");
                },
              ),

              FilterChip(
                label: const Text("Active"),
                selected: filterMode == "active",
                onSelected: (_) {
                  setState(() => filterMode = "active");
                },
              ),

              FilterChip(
                label: const Text("Completed"),
                selected: filterMode == "completed",
                onSelected: (_) {
                  setState(() => filterMode = "completed");
                },
              ),

              FilterChip(
                label: const Text("Priority"),
                selected: priorityFilter != null,
                onSelected: (_) {
                  showPriorityDialog();
                },
              ),

              FilterChip(
                label: const Text("Due Date"),
                selected: dueFilter != null,
                onSelected: (_) {
                  showDueDialog();
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          /*
          TASK LIST
          */
          Expanded(
            child: filteredTodos.isEmpty
                ? const Center(
                    child: Text(
                      "No tasks yet",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredTodos.length,

                    itemBuilder: (context, index) {
                      final todo = filteredTodos[index];

                      final isOverdue =
                          todo.dueDate != null &&
                          todo.dueDate!.isBefore(DateTime.now()) &&
                          !todo.isDone;

                      return ListTile(
                        onTap: () {
                          openTaskDialog(todo: todo);
                        },

                        leading: Checkbox(
                          value: todo.isDone,
                          onChanged: (_) => toggleTodo(todo),
                        ),

                        title: Text(
                          todo.description,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? Colors.red : null,
                            decoration: todo.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),

                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),

                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                Text("WorkID: ${todo.workId ?? "-"}"),

                                Text("Ref: ${todo.ref ?? "-"}"),

                                Text(
                                  "Priority: ${priorityLabels[todo.priority]}",
                                  style: TextStyle(
                                    color: getPriorityColor(todo.priority),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                Text("Progress: ${todo.progress ?? 0}%"),

                                if (todo.dueDate != null)
                                  Text(
                                    "Due: ${todo.dueDate!.toLocal().toString().split(' ')[0]}",
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            LinearProgressIndicator(
                              value: (todo.progress ?? 0) / 100,
                              minHeight: 6,
                            ),
                          ],
                        ),

                        /*
  EDIT + DELETE BUTTON
  */
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                openTaskDialog(todo: todo);
                              },
                              child: const Text("Edit"),
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                confirmDelete(todo);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Task"),

        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,

        onPressed: () {
          openTaskDialog();
        },
      ),
    );
  }
}
