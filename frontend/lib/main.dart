import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  bool isCompleted = false;
  String? editingId;
  bool isLoading = false;
  bool isFetching = false;
  String sortBy = 'Date created (newest)';

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

    final body = json.encode({
      'title': title,
      'description': description,
      'completed': isCompleted,
      'category': selectedCategory,
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

  Future<void> toggleCompleted(Map task, bool? value) async {
    await http.put(
      Uri.parse('$baseUrl/${task['id']}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'title': task['title'],
        'description': task['description'],
        'completed': value ?? false,
        'category': task['category'],
      }),
    );
    fetchTasks();
  }

  void startEditing(Map task) {
    setState(() {
      editingId = task['id'];
      titleController.text = task['title'] ?? '';
      descriptionController.text = task['description'] ?? '';
      isCompleted = task['completed'] ?? false;
      selectedCategory = task['category'] ?? 'General';
    });
  }

  void resetForm() {
    setState(() {
      titleController.clear();
      descriptionController.clear();
      isCompleted = false;
      selectedCategory = 'General';
      editingId = null;
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

  Widget buildTaskCard(Map task) {
    final completed = task['completed'] ?? false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor =
        completed
            ? (isDark ? Colors.green[700] : Colors.green[100])
            : (isDark ? Colors.grey[800] : Colors.white.withOpacity(0.85));
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
          Text(
            task['title'] ?? '',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(task['description'] ?? ''),
          const SizedBox(height: 4),
          Text(
            'Category: ${task['category'] ?? '-'}',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
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
                icon: Icon(Icons.edit, color: Colors.indigo),
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

  @override
  Widget build(BuildContext context) {
    final filteredTasks =
        tasks.where((task) {
          final matchesCategory =
              filterCategory == 'All' || task['category'] == filterCategory;
          final isDone = task['completed'] ?? false;
          final matchesStatus =
              filterStatus == 'All' ||
              (filterStatus == 'Completed' && isDone) ||
              (filterStatus == 'Active' && !isDone);

          return matchesCategory && matchesStatus;
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
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Neo TODO'),
        actions: [
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
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
                            () => selectedCategory = value ?? 'General',
                          ),
                    ),
                    CheckboxListTile(
                      title: Text('Done'),
                      value: isCompleted,
                      onChanged:
                          (value) =>
                              setState(() => isCompleted = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    ElevatedButton.icon(
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
                              : Icon(Icons.save),
                      label: Text(editingId == null ? 'Add' : 'Save'),
                      onPressed: isLoading ? null : submitTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 28,
                        ),
                      ),
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
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: sortBy,
                        items:
                            [
                                  'Date created (newest)',
                                  'Date created (oldest)',
                                  'Title A-Z',
                                  'Title Z-A',
                                ]
                                .map(
                                  (sort) => DropdownMenuItem(
                                    value: sort,
                                    child: Text(sort),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            sortBy = value!;
                          });
                        },
                      ),
                      const SizedBox(width: 20),
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
                            (value) =>
                                setState(() => filterCategory = value ?? 'All'),
                      ),
                      const SizedBox(width: 20),
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
                            (value) =>
                                setState(() => filterStatus = value ?? 'All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        isFetching
                            ? Center(child: CircularProgressIndicator())
                            : filteredTasks.isEmpty
                            ? Center(child: Text('No tasks found'))
                            : ListView.builder(
                              itemCount: filteredTasks.length,
                              itemBuilder:
                                  (context, index) =>
                                      buildTaskCard(sortedTasks[index]),
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
