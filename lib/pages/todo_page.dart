/*
============================================================
FILE: todo_page.dart
============================================================

UI Layer dari aplikasi WorkTracker-v1.

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
import '../widgets/todo_card.dart';
import '../services/todo_logic.dart';

enum FilterType { all, active, completed, priority, due }

String? priorityFilter;
String? dueFilter;

class TodoPage extends StatefulWidget {
  const TodoPage({Key? key}) : super(key: key);

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final dbHelper = DBHelper.instance;

  FilterType currentFilter = FilterType.active;

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
  String searchQuery = "";

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
  bool isTypingQuick = false;
  final FocusNode quickFocus = FocusNode();

  String? priority;
  DateTime? startDate;
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
        return Colors.blue;

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

    quickController.addListener(() {
      setState(() {
        isTypingQuick = quickController.text.isNotEmpty;
      });
    });
  }

  /*
  ============================================================
  LOAD DATA
  ============================================================
  */

  Future<void> loadTodos() async {
    final data = await dbHelper.getTodos();

    // 🔥 Cache waktu sekarang (hindari DateTime.now() berkali-kali)
    final now = DateTime.now();

    // 🔥 Precompute diff (cache)
    final Map<Todo, int> diffCache = {};

    for (var t in data) {
      if (t.startDate != null) {
        diffCache[t] = t.startDate!.difference(now).inDays;
      } else {
        diffCache[t] = 9999; // default kalau null
      }
    }

    // 🔥 Sorting pakai cache (cepat)
    data.sort((a, b) {
      return diffCache[a]!.compareTo(diffCache[b]!);
    });

    // 🔥 Update UI
    setState(() {
      todos = data;
    });
  }

  int getDiff(DateTime? date) {
    if (date == null) return 9999; // biar taruh di bawah
    final now = DateTime.now();
    return date.difference(now).inDays;
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
      startDate: startDate,
      dueDate: dueDate,
      progress: progress,
      taskDate: DateTime.now(),
      isDone: false,
      createdAt: DateTime.now(),
    );

    await dbHelper.insertTodo(todo);

    await loadTodos();

    descController.clear();
    workController.clear();
    refController.clear();
    progress = 0;
    priority = "M";
    dueDate = null;
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

    quickFocus.requestFocus(); // fokus kembali ke Quick Capture

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
      startDate: startDate,
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
    return DateFormat('dd-MM-yyyy').format(date);
  }

  Future<void> toggleTodo(Todo todo) async {
    print("BEFORE toggle:");
    print("todo id: ${todo.id}  isDone: ${todo.isDone}");

    setState(() {
      todo.isDone = !todo.isDone;

      if (todo.isDone) {
        todo.completedAt = DateTime.now();

        // hitung duration dari createdAt sampai sekarang
        if (todo.createdAt != null) {
          todo.duration = DateTime.now().difference(todo.createdAt!).inHours;
        }
      } else {
        todo.completedAt = null;
        todo.duration = null;
      }
    });

    print("AFTER toggle:");
    print("todo id: ${todo.id}  isDone: ${todo.isDone}");

    await dbHelper.updateTodoStatus(
      todo.id!,
      todo.isDone ? 1 : 0,
      todo.completedAt?.toIso8601String(),
    );
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
      // SEARCH FILTER
      if (searchText.isNotEmpty) {
        final query = searchText.toLowerCase();

        if (!(t.description.toLowerCase().contains(query) ||
            (t.workId ?? "").toLowerCase().contains(query) ||
            (t.ref ?? "").toLowerCase().contains(query))) {
          return false;
        }
      }

      // ACTIVE FILTER
      if (currentFilter == FilterType.active && t.isDone) {
        return false;
      }

      // COMPLETED FILTER
      if (currentFilter == FilterType.completed && !t.isDone) {
        return false;
      }

      // PRIORITY FILTER (ACTIVE ONLY)
      if (priorityFilter != null) {
        if (t.isDone) return false;

        if (t.priority != priorityFilter) {
          return false;
        }
      }

      // DUE FILTER (ACTIVE ONLY)

      if (dueFilter != null) {
        if (t.isDone) return false;

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
      }

      return true;
    }).toList();
  }

  // SORTING START DATE THE CLOSER THE UPPER

  void sortTodos() {
    todos.sort((a, b) {
      return getDiff(a.startDate).compareTo(getDiff(b.startDate));
    });
  }

  Widget filterText(String label, FilterType type) {
    final selected = currentFilter == type;

    return GestureDetector(
      onTap: () {
        // PRIORITY FILTER
        if (type == FilterType.priority) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Select Priority"),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentFilter = type;
                      priorityFilter = "H";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("High"),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentFilter = type;
                      priorityFilter = "M";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Medium"),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentFilter = type;
                      priorityFilter = "L";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Low"),
                ),
              ],
            ),
          );
          return;
        }

        // DUE FILTER
        if (type == FilterType.due) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Select Due Filter"),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentFilter = type;
                      dueFilter = "overdue";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Overdue"),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentFilter = type;
                      dueFilter = "week";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("This Week"),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentFilter = type;
                      dueFilter = "month";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("This Month"),
                ),
              ],
            ),
          );
          return;
        }

        // FILTER NORMAL
        setState(() {
          currentFilter = type;

          // reset filter tambahan
          if (type == FilterType.all ||
              type == FilterType.active ||
              type == FilterType.completed) {
            priorityFilter = null;
            dueFilter = null;
          }
        });
      },

      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? Colors.blue : Colors.black,
        ),
      ),
    );
  }

  /*
  ============================================================
  TODAY DATE
  ============================================================
  */

  String getToday() {
    final now = DateTime.now();
    return DateFormat('dd-MM-yyyy').format(now);
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
  TOGGLE DONE
  ============================================================
  */

  void toggleDone(Todo todo) async {
    setState(() {
      todo.isDone = !todo.isDone;

      if (todo.isDone) {
        todo.completedAt = DateTime.now();
      } else {
        todo.completedAt = null;
      }
    });

    await dbHelper.updateTodo(todo);
  }

  /*
  ============================================================
  TASK DIALOG
  ============================================================
  */

  void openTaskDialog(Todo? todo) {
    if (todo != null) {
      descController.text = todo.description;
      workController.text = todo.workId ?? "";
      refController.text = todo.ref ?? "";
      priority = todo.priority;
      startDate = todo.startDate;
      dueDate = todo.dueDate;
      progress = todo.progress ?? 0;
    } else {
      descController.clear();
      workController.clear();
      refController.clear();

      priority = "M";
      progress = 0;
      startDate = todo?.startDate ?? DateTime.now();
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
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: descController,
                        keyboardType: TextInputType.multiline,
                        minLines: 2,
                        maxLines: null,
                        decoration: const InputDecoration(
                          labelText: "Description",
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: workController,
                        decoration: const InputDecoration(labelText: "WorkID"),
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: refController,
                        decoration: const InputDecoration(
                          labelText: "Reference",
                        ),
                      ),

                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        value: priority,
                        decoration: const InputDecoration(
                          labelText: "Priority",
                        ),
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

                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Progress: $progress%",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),

                      Slider(
                        value: progress.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: "$progress%",
                        onChanged: (value) {
                          setStateDialog(() {
                            progress = value.toInt();
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      /*
============================================================
START & DUE DATE PICKER
============================================================
*/
                      Row(
                        children: [
                          // Label
                          SizedBox(
                            width: 60,
                            child: Text(
                              "Start",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),

                          // Titik dua
                          const Text(":"),

                          const SizedBox(width: 8),

                          // Tanggal (fleksibel)
                          Expanded(
                            child: Text(
                              startDate == null
                                  ? "Not set"
                                  : "${startDate!.day.toString().padLeft(2, '0')}-"
                                        "${startDate!.month.toString().padLeft(2, '0')}-"
                                        "${startDate!.year}",
                            ),
                          ),

                          // Tombol
                          TextButton(
                            child: const Text("Pick"),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );

                              if (picked != null) {
                                setStateDialog(() {
                                  startDate = picked;
                                });
                              }
                            },
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              "Due",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),

                          const Text(":"),
                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              dueDate == null
                                  ? "Not set"
                                  : "${dueDate!.day.toString().padLeft(2, '0')}-"
                                        "${dueDate!.month.toString().padLeft(2, '0')}-"
                                        "${dueDate!.year}",
                            ),
                          ),

                          TextButton(
                            child: const Text("Pick"),
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
        mainAxisSize: MainAxisSize.min,
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
                  "WorkTracker-v1",
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
              focusNode: quickFocus,

              onSubmitted: (value) {
                quickAddTask(value);
              },
              decoration: InputDecoration(
                hintText: "Quick capture task...",
                prefixIcon: Icon(Icons.flash_on),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),

                suffixIcon: isTypingQuick
                    ? IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () {
                          quickAddTask(quickController.text);
                        },
                      )
                    : null,
              ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              filterText("All", FilterType.all),

              const Text(" | "),

              filterText("Active", FilterType.active),

              const Text(" | "),

              filterText("Completed", FilterType.completed),

              const Text(" | "),

              filterText("Priority", FilterType.priority),

              const Text(" | "),

              filterText("Due", FilterType.due),
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
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

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
                      Icon(Icons.star, size: 20, color: Colors.orange),
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

                  SizedBox(
                    height: 300, // bisa kamu adjust
                    child: ListView(
                      children: focusTodos.map((todo) {
                        final metaText =
                            "WorkID: ${todo.workId}  "
                            "Ref: ${todo.ref}  "
                            "Priority: ${priorityLabels[todo.priority]}  "
                            "Progress: ${todo.progress}%  "
                            "Start: ${formatDate(todo.startDate)}  "
                            "Due: ${formatDate(todo.dueDate)}";

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Checkbox(
                                  value: todo.isDone,
                                  onChanged: (_) => toggleTodo(todo),
                                ),
                                GestureDetector(
                                  onTap: () => toggleFocus(todo),
                                  child: Icon(
                                    todayFocusIds.contains(todo.id)
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    todo.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(metaText),
                                ],
                              ),
                            ),

                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => openTaskDialog(todo),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => confirmDelete(todo),
                                ),
                              ],
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
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
                    child: const Text(
                      "No tasks yet.\nTap +Add Task to add your first task \nor fill Quick capture ",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
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

                      final isOverdue = TodoLogic.isOverdue(todo);

                      return TodoCard(
                        todo: todo,
                        isOverdue: isOverdue,
                        toggleTodo: toggleTodo,
                        toggleFocus: toggleFocus,
                        confirmDelete: confirmDelete,
                        openTaskDialog: openTaskDialog,
                        priorityLabels: priorityLabels,
                        getPriorityColor: getPriorityColor,
                        formatDate: formatDate,
                      );
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: isTypingQuick
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text("Add Task"),

              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,

              onPressed: () {
                openTaskDialog(null);
              },
            ),
    );
  }
}
