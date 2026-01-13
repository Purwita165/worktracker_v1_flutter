import 'package:flutter/material.dart';
import '../models/todo.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({Key? key}) : super(key: key);

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  // =====================================================
  // CONFIG
  // =====================================================
  static const List<String> priorities = ['H', 'M', 'L'];

  static const Map<String, String> priorityLabels = {
    'H': 'High',
    'M': 'Medium',
    'L': 'Low',
  };

  String _formatDateId(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final d = date.day.toString().padLeft(2, '0');
    final m = months[date.month - 1];
    final y = date.year;

    return '$d $m $y'; // contoh: 13 Jan 2026
  }

  // =====================================================
  // STATE — HB-ExeCon v1
  // =====================================================

  /// Master list
  List<Todo> todos = [];

  /// ADD (nullable = optional)
  String? soNumber;
  String? ref;
  String? priority;
  DateTime? dueDate;
  int? progress;
  String optionalLabel(String label, String? value) {
    return value == null || value.isEmpty ? '$label (optional)' : label;
  }

  final String currentUserId = 'local-user';

  Widget _metaText(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey));
  }

  Widget _buildTodoMetadataRow(Todo todo) {
    final textStyle = TextStyle(
      fontSize: 12,
      color: todo.isDone ? Colors.grey.shade400 : Colors.grey.shade600,
    );

    List<Widget> items = [];

    if (todo.soNumber != null && todo.soNumber!.isNotEmpty) {
      items.add(Text('SO: ${todo.soNumber}', style: textStyle));
    }

    if (todo.ref != null && todo.ref!.isNotEmpty) {
      items.add(Text('Ref: ${todo.ref}', style: textStyle));
    }

    final prLabel = priorityLabels[todo.priority] ?? todo.priority;
    items.add(Text('Pr: $prLabel', style: textStyle));

    if (todo.dueDate != null) {
      final d = _formatDateId(todo.dueDate!);
      items.add(Text('Due: $d', style: textStyle));
    }

    // =====================
    // PROGRESS (INI YANG HILANG)
    // =====================
    if (todo.progress != null) {
      items.add(Text('Prog: ${todo.progress}%', style: textStyle));
    }

    return Wrap(spacing: 12, runSpacing: 4, children: items);
  }

  /// EDIT
  Todo? editingTodo;
  String? editSoNumber;
  String? editRef;
  String? editPriority;
  DateTime? editDueDate;
  int? editProgress;

  // =====================================================
  // CONTROLLERS
  // =====================================================

  final TextEditingController descController = TextEditingController();
  final TextEditingController soController = TextEditingController();
  final TextEditingController refController = TextEditingController();

  final TextEditingController editDescController = TextEditingController();
  final TextEditingController editSoController = TextEditingController();
  final TextEditingController editRefController = TextEditingController();

  // =====================================================
  // LIFECYCLE
  // =====================================================

  @override
  void dispose() {
    descController.dispose();
    refController.dispose();
    editDescController.dispose();
    editRefController.dispose();
    super.dispose();
  }

  // =====================================================
  // LOGIC (kosong dulu, asal ADA)
  // =====================================================

  void addTodo() {
    if (descController.text.trim().isEmpty || priority == null) return;

    setState(() {
      todos.add(
        Todo(
          userId: currentUserId,
          taskDate: DateTime.now(),

          description: descController.text.trim(),
          soNumber: soNumber,
          ref: refController.text.trim().isEmpty
              ? null
              : refController.text.trim(),
          priority: priority!,
          dueDate: dueDate,
          progress: progress,
          isDone: false,
        ),
      );

      // reset
      descController.clear();
      refController.clear();
      soNumber = null;
      priority = null;
      dueDate = null;
      progress = null;
    });
  }

  void deleteTodo(int index) {
    setState(() {
      todos.removeAt(index);
    });
  }

  void toggleTodo(Todo todo) {
    setState(() {
      todo.isDone = !todo.isDone;
    });
  }

  void showAddDialog() {
    descController.clear();
    soController.clear();
    refController.clear();

    showDialog(
      context: context,
      builder: (_) {
        String? localPriority;
        DateTime? localDueDate;
        int? localProgress;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Add Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // =====================
                    // DESCRIPTION (WAJIB)
                    // =====================
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =====================
                    // SO & REF (OPTIONAL, SEJAJAR)
                    // =====================
                    TextField(
                      controller: soController,
                      decoration: const InputDecoration(
                        labelText: 'SO# (optional)',
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(
                        labelText: 'Ref (optional)',
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =====================
                    // PRIORITY (WAJIB)
                    // =====================
                    DropdownButtonFormField<String>(
                      value: localPriority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'H', child: Text('High')),
                        DropdownMenuItem(value: 'M', child: Text('Medium')),
                        DropdownMenuItem(value: 'L', child: Text('Low')),
                      ],
                      onChanged: (v) => setLocal(() => localPriority = v),
                    ),

                    const SizedBox(height: 12),

                    // =====================
                    // DUE DATE (OPTIONAL)
                    // =====================
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        localDueDate == null
                            ? 'Due Date (optional)'
                            : 'Due Date: ${localDueDate!.toIso8601String().substring(0, 10)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setLocal(() => localDueDate = picked);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // =====================
                    // PROGRESS (OPTIONAL)
                    // =====================
                    // =====================
                    // PROGRESS (OPTIONAL)
                    // =====================
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Progress % (optional)'),
                        Slider(
                          value: (localProgress ?? 0).toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${localProgress ?? 0}%',
                          onChanged: (v) {
                            setLocal(() {
                              localProgress = v.toInt(); // ✅ INI KUNCI
                            });
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('${localProgress ?? 0}%'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // =====================
              // ACTIONS
              // =====================
              actions: [
                TextButton(
                  onPressed: () {
                    descController.clear();
                    soController.clear();
                    refController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (descController.text.trim().isEmpty ||
                        localPriority == null) {
                      return;
                    }

                    // COMMIT KE STATE PAGE (SATU ARAH)

                    priority = localPriority;
                    dueDate = localDueDate;
                    progress = localProgress;

                    soNumber = soController.text.trim().isEmpty
                        ? null
                        : soController.text.trim();

                    ref = refController.text.trim().isEmpty
                        ? null
                        : refController.text.trim();

                    addTodo();
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HB-ExeCon v1')),
      body: todos.isEmpty
          ? const Center(child: Text('No tasks yet'))
          : ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: todo.isDone,
                      onChanged: (_) => toggleTodo(todo),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.description,
                            style: TextStyle(
                              fontWeight: todo.isDone
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              decoration: todo.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildTodoMetadataRow(todo),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
