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
import 'package:intl/intl.dart';

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
TODAY'S FOCUS STATE
============================================================
Menyimpan ID task yang dipilih sebagai fokus hari ini.
Tidak disimpan ke database (V1).
*/
  Set<int> todayFocusIds = {};
  /*
  ============================================================
  FILTER STATE
  ============================================================
  */

  String filterMode = "active";
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
  final quickController = TextEditingController();

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
QUICK CAPTURE TASK
============================================================
Digunakan untuk menambahkan task dengan cepat.

Metadata default:
priority = Medium
progress = 0
dueDate = null
*/
  Future<void> quickAddTask(String text) async {
    if (text.trim().isEmpty) return;

    final todo = Todo(
      userId: currentUserId,
      description: text.trim(),
      workId: "",
      ref: "",
      priority: "M",
      dueDate: null,
      progress: 0,
      taskDate: DateTime.now(),
      isDone: false,
    );

    await dbHelper.insertTodo(todo);

    quickController.clear();

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          title: const Text(
            "Delete Task",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Are you sure you want to delete this task?"),

              const SizedBox(height: 12),

              Text(
                todo.description,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
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
                await dbHelper.deleteTodo(todo.id!);

                Navigator.pop(context);

                loadTodos();
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

  String formatDate(DateTime? date) {
    if (date == null) return "";
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> toggleTodo(Todo todo) async {
    setState(() {
      todo.isDone = !todo.isDone;

      if (todo.isDone) {
        todo.completedAt = DateTime.now();
      } else {
        todo.completedAt = null;
      }
    });

    await dbHelper.updateTodoStatus(
      todo.id!,
      todo.isDone ? 1 : 0,
      todo.completedAt?.toIso8601String(), // kirim juga completed_at
    );

    await loadTodos();
  }

  String getDuration(Todo todo) {
    if (todo.completedAt == null) return "";

    Duration d = todo.completedAt!.difference(todo.taskDate);

    if (d.inDays > 0) {
      return "${d.inDays} days";
    } else {
      return "${d.inHours} hours";
    }
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
TOGGLE TODAY'S FOCUS
============================================================
Menambahkan / menghapus task dari fokus hari ini.
*/
  void toggleFocus(Todo todo) {
    setState(() {
      if (todayFocusIds.contains(todo.id)) {
        todayFocusIds.remove(todo.id);
      } else {
        todayFocusIds.add(todo.id!);
      }
    });
  }

  /*
============================================================
GET TODAY'S FOCUS TASKS
============================================================
Mengambil task yang ditandai sebagai fokus hari ini.
*/
  List<Todo> getFocusTodos() {
    return todos
        .where((t) => todayFocusIds.contains(t.id) && !t.isDone)
        .toList();
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

                    const SizedBox(height: 16),

                    /*
============================================================
DUE DATE PICKER
============================================================
*/
                    Row(
                      children: [
                        const Text(
                          "Due Date:",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),

                        const SizedBox(width: 12),

                        Text(
                          dueDate == null
                              ? "Not set"
                              : "${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}",
                        ),

                        const Spacer(),

                        TextButton(
                          child: const Text("Pick Date"),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (picked != null) {
                              setStateDialog(() {
                                dueDate = picked;
                              });
                            }
                          },
                        ),
                      ],
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
    final focusTodos = getFocusTodos();

    final filteredTodos = getFilteredTodos();

    final activeCount = todos.where((t) => !t.isDone).length;

    final completedCount = todos.where((t) => t.isDone).length;

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final headerSize = isMobile ? 22.0 : 24.0;

    final titleSize = isMobile ? 16.0 : 18.0;

    final metaSize = isMobile ? 12.0 : 14.0;

    return Scaffold(
      appBar: null,

      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1F3A5F), Color(0xFF4B79A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WorkTracker",
                  style: TextStyle(
                    fontSize: headerSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "Plan • Track • Execute",
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 1,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

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
============================================================
QUICK CAPTURE
============================================================
Input cepat untuk menangkap ide atau task.

User cukup tekan Enter untuk menyimpan task.
*/
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TextField(
              controller: quickController,

              decoration: InputDecoration(
                hintText: "Quick capture task...",
                prefixIcon: const Icon(Icons.flash_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),

              onSubmitted: (value) {
                quickAddTask(value);
              },
            ),
          ),

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
============================================================
TODAY'S FOCUS SECTION
============================================================
Menampilkan task yang dipilih sebagai fokus hari ini.
*/
          if (focusTodos.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.star, size: 16, color: Colors.orange),
                      SizedBox(width: 6),
                      Text(
                        "TODAY'S FOCUS",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  ...focusTodos.map((todo) {
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,

                      leading: const Icon(
                        Icons.star,
                        size: 14,
                        color: Colors.orange,
                      ),

                      title: Text(
                        todo.description,
                        style: const TextStyle(fontWeight:FontWeight.bold),
                      ),

                      onTap: () {
                        openTaskDialog(todo: todo);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],

          Divider(height: 24, thickness: 1, color: Colors.grey.shade300),

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

                      String metaText;

                      if (todo.isDone) {
                        metaText =
                            "WorkID: ${todo.workId}   "
                            "Ref: ${todo.ref}   "
                            "Created: ${formatDate(todo.taskDate)}   "
                            "Completed: ${formatDate(todo.completedAt)}   "
                            "Duration: ${getDuration(todo)}";
                      } else {
                        metaText =
                            "WorkID: ${todo.workId}    "
                            "Ref: ${todo.ref}    "
                            "Priority: ${priorityLabels[todo.priority] ?? "-"}    "
                            "Progress: ${todo.progress}%    "
                            "Due: ${formatDate(todo.dueDate)}";
                      }

                      final isOverdue =
                          todo.dueDate != null &&
                          todo.dueDate!.isBefore(DateTime.now()) &&
                          !todo.isDone;

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ListTile(
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
                                fontSize: titleSize,
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

                                if (todo.isDone)
                                  Text(
                                    metaText,
                                    style: const TextStyle(fontSize: 13),
                                  )
                                else
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 4,
                                    children: [
                                      Text("WorkID: ${todo.workId}"),

                                      Text("Ref: ${todo.ref}"),

                                      Text(
                                        "Priority: ${priorityLabels[todo.priority]}",
                                        style: TextStyle(
                                          color: getPriorityColor(
                                            todo.priority ?? "M",
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      Text("Progress: ${todo.progress}%"),

                                      Text("Due: ${formatDate(todo.dueDate)}"),
                                    ],
                                  ),

                                const SizedBox(height: 8),

                                if (isMobile)
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          openTaskDialog(todo: todo);
                                        },
                                        child: const Text("Edit"),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          confirmDelete(todo);
                                        },
                                      ),
                                    ],
                                  ),

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
                                IconButton(
                                  icon: Icon(
                                    todayFocusIds.contains(todo.id)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () {
                                    toggleFocus(todo);
                                  },
                                ),

                                TextButton(
                                  onPressed: () {
                                    openTaskDialog(todo: todo);
                                  },
                                  child: const Text("Edit"),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    confirmDelete(todo);
                                  },
                                ),
                              ],
                            ),
                          ),
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
