import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() => runApp(TaskApp());

const String baseUrl = 'http://localhost:8080/api/tasks';

class TaskApp extends StatefulWidget {
  @override
  State<TaskApp> createState() => _TaskAppState();
}

class _TaskAppState extends State<TaskApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = _themeMode == ThemeMode.dark;
    await prefs.setBool('isDarkMode', !isDark);
    setState(() => _themeMode = !isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neo TODO',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[100],
        textTheme: GoogleFonts.openSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.tealAccent),
        cardColor: Colors.white.withOpacity(0.9),
        shadowColor: Colors.black12,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        textTheme: GoogleFonts.openSansTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
        cardColor: Colors.grey[850],
        shadowColor: Colors.black54,
        useMaterial3: true,
      ),
      home: TaskPage(onToggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

class TaskPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const TaskPage({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  List tasks = [];
  List<Map<String, dynamic>> subtasks = [];
  final titleController = TextEditingController();
  final subtaskController = TextEditingController();
  final descriptionController = TextEditingController();
  bool isCompleted = false;
  String? editingId;
  bool isLoading = false;
  bool isFetching = false;
  String sortBy = 'Date created (newest)';
  DateTime? selectedDeadline;
  final List<String> priorities = ['Low', 'Medium', 'High'];
  String selectedPriority = 'Low';
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  late Map<DateTime, List<Map<String, dynamic>>> events = {};

  final List<String> categories = [
    'General',
    'Study',
    'Work',
    'Home',
    'Personal',
  ];
  String selectedCategory = 'General';
  String filterCategory = 'All';
  String filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    setState(() => isFetching = true);
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      setState(() {
        tasks = json.decode(response.body);
        events = groupTasksByDate();
        isFetching = false;
      });
    }
  }

  Future<void> submitTask() async {
    setState(() => isLoading = true);
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      showMessage('Enter a task title');
      setState(() => isLoading = false);
      return;
    }

    if (selectedDeadline == null) {
      showMessage('Please select a deadline');
      setState(() => isLoading = false);
      return;
    }

    final body = json.encode({
      'title': title,
      'description': description,
      'subtasks': subtasks,
      'completed': isCompleted,
      'category': selectedCategory,
      'deadline': selectedDeadline!.toIso8601String(),
      'priority': selectedPriority,
    });

    try {
      final url = editingId == null ? baseUrl : '$baseUrl/$editingId';
      final method = editingId == null ? 'POST' : 'PUT';

      final response =
          await (method == 'POST'
              ? http.post(
                Uri.parse(url),
                headers: {'Content-Type': 'application/json'},
                body: body,
              )
              : http.put(
                Uri.parse(url),
                headers: {'Content-Type': 'application/json'},
                body: body,
              ));

      if (response.statusCode == 200 || response.statusCode == 201) {
        showMessage(editingId == null ? 'Task added' : 'Task updated');
        resetForm();
        fetchTasks();
      } else {
        showMessage('Failed to save task');
      }
    } catch (e) {
      showMessage('Server connection error');
    }

    setState(() => isLoading = false);
  }

  Future<void> deleteTask(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode == 200) {
      showMessage('Task deleted');
      fetchTasks();
    } else {
      showMessage('Failed to delete task');
    }
  }

  Future<void> toggleSubtask(Map task, int index, bool value) async {
    final List subtasks = List.from(task['subtasks'] ?? []);
    if (index >= subtasks.length) return;

    subtasks[index]['done'] = value;

    await http.put(
      Uri.parse('$baseUrl/${task['id']}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'title': task['title'],
        'description': task['description'],
        'completed': task['completed'],
        'category': task['category'],
        'deadline': task['deadline'],
        'subtasks': subtasks,
      }),
    );

    await fetchTasks();
  }

  Future<void> toggleCompleted(Map task, bool? value) async {
    await http.put(
      Uri.parse('$baseUrl/${task['id']}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'title': task['title'],
        'description': task['description'],
        'completed': value ?? false,
        'category': task['category'],
        'deadline': task['deadline'],
        'subtasks': task['subtasks'],
      }),
    );

    fetchTasks();
  }

  void startEditing(Map task) {
    setState(() {
      editingId = task['id'];
      titleController.text = task['title'] ?? '';
      descriptionController.text = task['description'] ?? '';
      subtasks = List<Map<String, dynamic>>.from(task['subtasks'] ?? []);
      isCompleted = task['completed'] ?? false;
      selectedCategory = task['category'] ?? 'General';
      selectedDeadline =
          task['deadline'] != null ? DateTime.tryParse(task['deadline']) : null;
      selectedPriority = task['priority'] ?? 'Low';
    });
  }

  void resetForm() {
    setState(() {
      subtasks = [];
      titleController.clear();
      descriptionController.clear();
      subtaskController.clear();
      isCompleted = false;
      selectedCategory = 'General';
      editingId = null;
      selectedPriority = 'Low';
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<DateTime, List<Map<String, dynamic>>> groupTasksByDate() {
    Map<DateTime, List<Map<String, dynamic>>> map = {};
    for (var task in tasks) {
      if (task['deadline'] != null) {
        final date = DateTime.parse(task['deadline']);
        final key = DateTime(date.year, date.month, date.day);

        if (!map.containsKey(key)) {
          map[key] = [];
        }
        map[key]!.add(task);
      }
    }
    return map;
  }

  Widget buildTaskCard(Map task) {
    Color getPriorityColor(String priority) {
      switch (priority) {
        case 'High':
          return Colors.red;
        case 'Medium':
          return Colors.orange;
        default:
          return Colors.green;
      }
    }

    final completed = task['completed'] ?? false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor =
        isDark
            ? Colors.grey[850]!.withOpacity(completed ? 0.7 : 1.0)
            : Colors.white.withOpacity(completed ? 0.7 : 0.95);

    DateTime? deadline =
        task['deadline'] != null ? DateTime.tryParse(task['deadline']) : null;

    final now = DateTime.now();
    Color? deadlineColor;
    if (deadline != null) {
      if (deadline.isBefore(now)) {
        deadlineColor = Colors.redAccent;
      } else if (deadline.day == now.day &&
          deadline.month == now.month &&
          deadline.year == now.year) {
        deadlineColor = Colors.amber;
      } else {
        deadlineColor = Colors.green;
      }
    }

    final List subtasks = task['subtasks'] ?? [];
    final priority = task['priority'] ?? 'Low';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Priority + Completed Badge
          Row(
            children: [
              Expanded(
                child: Text(
                  task['title'] ?? '',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      completed
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      completed ? Icons.check_circle : Icons.close,
                      color: completed ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      completed ? 'Completed' : 'No Completed',
                      style: TextStyle(
                        color: completed ? Colors.green[700] : Colors.red[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          if ((task['description'] ?? '').toString().isNotEmpty)
            Text(task['description'], style: TextStyle(fontSize: 14)),

          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Category: ${task['category'] ?? '-'}',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getPriorityColor(priority).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Priority: $priority',
                  style: TextStyle(
                    color: getPriorityColor(priority),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (deadline != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Due: ${DateFormat.yMMMd().format(deadline)}',
                style: TextStyle(
                  color: deadlineColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          if (subtasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...List.generate(subtasks.length, (index) {
              final subtask = subtasks[index];
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: subtask['done'] == true,
                      onChanged: (value) {
                        toggleSubtask(task, index, value ?? false);
                      },
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(
                        color: Colors.teal.withOpacity(0.6),
                        width: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtask['title'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          decoration:
                              subtask['done'] == true
                                  ? TextDecoration.lineThrough
                                  : null,
                          color: subtask['done'] == true ? Colors.grey : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: completed,
                onChanged: (value) => toggleCompleted(task, value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const Text('Done'),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                onPressed: () => startEditing(task),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => deleteTask(task['id']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showMonthYearPicker(BuildContext context) async {
    DateTime tempFocusedDay = focusedDay;
    DateTime? tempSelectedDay = selectedDay;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select date',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            selectedDay = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            );
                            focusedDay = selectedDay!;
                          });
                        },
                        icon: Icon(Icons.today),
                        label: Text('Today'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TableCalendar(
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: tempFocusedDay,
                    selectedDayPredicate:
                        (day) => isSameDay(tempSelectedDay, day),
                    onDaySelected: (selected, focused) {
                      setModalState(() {
                        tempSelectedDay = selected;
                        tempFocusedDay = focused;
                      });
                    },
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.indigo,
                        shape: BoxShape.circle,
                      ),
                    ),

                    eventLoader: (day) {
                      final key = DateTime(day.year, day.month, day.day);
                      final todayEvents = events[key] ?? [];
                      return todayEvents;
                    },

                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, eventsForDay) {
                        if (eventsForDay.isEmpty) return SizedBox.shrink();

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                              eventsForDay.take(3).map((task) {
                                final map =
                                    task
                                        as Map<
                                          String,
                                          dynamic
                                        >; // ← приведение типа
                                final priority = map['priority'] ?? 'Low';

                                Color color;
                                switch (priority) {
                                  case 'High':
                                    color = Colors.red;
                                    break;
                                  case 'Medium':
                                    color = Colors.amber;
                                    break;
                                  default:
                                    color = Colors.green;
                                }

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                    vertical: 1.5,
                                  ),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        child: Text('Clear filter'),
                        onPressed: () {
                          setState(() {
                            selectedDay = null;
                          });
                          Navigator.pop(context);
                        },
                      ),
                      SizedBox(width: 20),
                      ElevatedButton.icon(
                        icon: Icon(Icons.check),
                        label: Text('Apply'),
                        onPressed: () {
                          setState(() {
                            if (tempSelectedDay != null) {
                              selectedDay = tempSelectedDay;
                              focusedDay = tempFocusedDay;
                            }
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStatsBottomSheet(BuildContext context) {
    final completedTasks = tasks.where((task) => task['completed'] == true);
    final totalTasks = tasks.length;

    final now = DateTime.now();
    int completedThisWeek = 0;
    int completedThisMonth = 0;

    for (var task in completedTasks) {
      if (task['createdAt'] != null && task['createdAt']['seconds'] != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(
            task['createdAt']['seconds'] * 1000);
        if (now.difference(date).inDays < 7) completedThisWeek++;
        if (now.month == date.month && now.year == date.year)
          completedThisMonth++;
      }
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Task Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            Text('Total tasks: $totalTasks'),
            Text('Completed: ${completedTasks.length}'),
            Text('This week: $completedThisWeek'),
            Text('This month: $completedThisMonth'),
            SizedBox(height: 20),
            LinearProgressIndicator(
              value: totalTasks == 0
                  ? 0
                  : completedTasks.length / totalTasks,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
              color: Colors.teal,
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                '${((completedTasks.length / totalTasks) * 100).toStringAsFixed(1)}% Completed',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    int totalTasks = tasks.length;
    int completedTasks = tasks.where((task) => task['completed'] == true).length;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final filteredTasks =
        tasks.where((task) {
          final matchesCategory =
              filterCategory == 'All' || task['category'] == filterCategory;

          final isDone = task['completed'] ?? false;
          final matchesStatus =
              filterStatus == 'All' ||
              (filterStatus == 'Completed' && isDone) ||
              (filterStatus == 'Active' && !isDone);

          final taskDeadlineStr = task['deadline'];
          DateTime? taskDeadline =
              taskDeadlineStr != null
                  ? DateTime.tryParse(taskDeadlineStr)
                  : null;

          final matchesDate =
              selectedDay == null ||
              (taskDeadline != null &&
                  taskDeadline.year == selectedDay!.year &&
                  taskDeadline.month == selectedDay!.month &&
                  taskDeadline.day == selectedDay!.day);

          return matchesCategory && matchesStatus && matchesDate;
        }).toList();

    List sortedTasks = [...filteredTasks];

    if (sortBy == 'Date created (newest)') {
      sortedTasks.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        final aSeconds =
            aTime is Map && aTime['seconds'] != null
                ? aTime['seconds'] as int
                : 0;
        final bSeconds =
            bTime is Map && bTime['seconds'] != null
                ? bTime['seconds'] as int
                : 0;
        return bSeconds.compareTo(aSeconds);
      });
    } else if (sortBy == 'Date created (oldest)') {
      sortedTasks.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        final aSeconds =
            aTime is Map && aTime['seconds'] != null
                ? aTime['seconds'] as int
                : 0;
        final bSeconds =
            bTime is Map && bTime['seconds'] != null
                ? bTime['seconds'] as int
                : 0;
        return aSeconds.compareTo(bSeconds);
      });
    } else if (sortBy == 'Title A-Z') {
      sortedTasks.sort(
        (a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''),
      );
    } else if (sortBy == 'Title Z-A') {
      sortedTasks.sort(
        (a, b) => (b['title'] ?? '').compareTo(a['title'] ?? ''),
      );
    } else if (sortBy == 'Priority (High → Low)') {
      const order = {'High': 3, 'Medium': 2, 'Low': 1};
      sortedTasks.sort(
        (a, b) =>
            (order[b['priority']] ?? 0).compareTo(order[a['priority']] ?? 0),
      );
    } else if (sortBy == 'Priority (Low → High)') {
      const order = {'High': 3, 'Medium': 2, 'Low': 1};
      sortedTasks.sort(
        (a, b) =>
            (order[a['priority']] ?? 0).compareTo(order[b['priority']] ?? 0),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Neo TODO'),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart_rounded),
            onPressed: () => _showStatsBottomSheet(context),
          ),
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'New Task',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: subtaskController,
                          decoration: InputDecoration(
                            labelText: 'Add subtask',
                            suffixIcon: IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                final text = subtaskController.text.trim();
                                if (text.isNotEmpty) {
                                  setState(() {
                                    subtasks.add({
                                      'title': text,
                                      'done': false,
                                    });
                                    subtaskController.clear();
                                  });
                                }
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),

                        ...subtasks.map(
                          (subtask) => ListTile(
                            dense: true,
                            title: Text(subtask['title']),
                            leading: Checkbox(
                              value: subtask['done'] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  subtask['done'] = value;
                                });
                              },
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  subtasks.remove(subtask);
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items:
                                    categories
                                        .map(
                                          (cat) => DropdownMenuItem(
                                            value: cat,
                                            child: Text(cat),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (value) => setState(
                                      () =>
                                          selectedCategory = value ?? 'General',
                                    ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedPriority,
                                decoration: InputDecoration(
                                  labelText: 'Priority',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items:
                                    priorities
                                        .map(
                                          (level) => DropdownMenuItem(
                                            value: level,
                                            child: Text(level),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (value) => setState(
                                      () => selectedPriority = value ?? 'Low',
                                    ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: Text('Done'),
                                value: isCompleted,
                                onChanged:
                                    (value) => setState(
                                      () => isCompleted = value ?? false,
                                    ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: TextButton.icon(
                                icon: Icon(Icons.calendar_today),
                                label: Text(
                                  selectedDeadline == null
                                      ? 'Select deadline'
                                      : 'Deadline: ${DateFormat.yMMMd().format(selectedDeadline!)}',
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        selectedDeadline ?? DateTime.now(),
                                    firstDate: DateTime.now().subtract(
                                      Duration(days: 365),
                                    ),
                                    lastDate: DateTime.now().add(
                                      Duration(days: 365 * 5),
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDeadline = picked);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon:
                                isLoading
                                    ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Icon(
                                      Icons.save,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onBackground,
                                    ),
                            label: Text(
                              editingId == null ? 'Add' : 'Save',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            onPressed: isLoading ? null : submitTask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),

            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onTap: () => _showMonthYearPicker(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat.yMMMM().format(focusedDay),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  TableCalendar(
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: focusedDay,
                    selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        selectedDay = selected;
                        focusedDay = focused;
                      });
                    },
                    calendarFormat: CalendarFormat.week,
                    availableCalendarFormats: const {
                      CalendarFormat.week: 'Week',
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.indigo,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sort'),
                          DropdownButton<String>(
                            value: sortBy,
                            items:
                                [
                                      'Date created (newest)',
                                      'Date created (oldest)',
                                      'Title A-Z',
                                      'Title Z-A',
                                      'Priority (High → Low)',
                                      'Priority (Low → High)',
                                    ]
                                    .map(
                                      (sort) => DropdownMenuItem(
                                        value: sort,
                                        child: Text(sort),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setState(
                                  () =>
                                      sortBy = value ?? 'Date created (newest)',
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category'),
                          DropdownButton<String>(
                            value: filterCategory,
                            items:
                                ['All', ...categories]
                                    .map(
                                      (cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setState(
                                  () => filterCategory = value ?? 'All',
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status'),
                          DropdownButton<String>(
                            value: filterStatus,
                            items:
                                ['All', 'Completed', 'Active']
                                    .map(
                                      (status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setState(
                                  () => filterStatus = value ?? 'All',
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        isFetching
                            ? Center(child: CircularProgressIndicator())
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (selectedDay != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.event, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Showing tasks for ${DateFormat.yMMMMd().format(selectedDay!)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Expanded(
                                  child:
                                      sortedTasks.isEmpty
                                          ? Center(
                                            child: Text('No tasks found'),
                                          )
                                          : ListView.builder(
                                            itemCount: sortedTasks.length,
                                            itemBuilder:
                                                (context, index) =>
                                                    buildTaskCard(
                                                      sortedTasks[index],
                                                    ),
                                          ),
                                ),
                              ],
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
