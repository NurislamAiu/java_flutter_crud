import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(TaskApp());

const String baseUrl = 'http://localhost:8080/api/tasks';

class TaskApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ru'),
      title: 'Neo TODO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white.withOpacity(0.95),
          textTheme: GoogleFonts.openSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.tealAccent),
        useMaterial3: true,
      ),
      home: TaskPage(),
    );
  }
}

class TaskPage extends StatefulWidget {
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

  final List<String> categories = ['Общее', 'Учёба', 'Работа', 'Дом', 'Личное'];
  String selectedCategory = 'Общее';
  String filterCategory = 'Все';
  String filterStatus = 'Все';

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
      showMessage('Введите заголовок задачи');
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

      final response = await (method == 'POST'
          ? http.post(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: body)
          : http.put(Uri.parse(url), headers: {'Content-Type': 'application/json'}, body: body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        showMessage(editingId == null ? 'Задача добавлена' : 'Задача обновлена');
        resetForm();
        fetchTasks();
      } else {
        showMessage('Ошибка при сохранении задачи');
      }
    } catch (e) {
      showMessage('Ошибка подключения к серверу');
    }

    setState(() => isLoading = false);
  }

  Future<void> deleteTask(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode == 200) {
      showMessage('Задача удалена');
      fetchTasks();
    } else {
      showMessage('Не удалось удалить задачу');
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
      selectedCategory = task['category'] ?? 'Общее';
    });
  }

  void resetForm() {
    setState(() {
      titleController.clear();
      descriptionController.clear();
      isCompleted = false;
      selectedCategory = 'Общее';
      editingId = null;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget buildTaskCard(Map task) {
    final completed = task['completed'] ?? false;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed ? Colors.teal.withOpacity(0.1) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task['title'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(task['description'] ?? ''),
          const SizedBox(height: 4),
          Text('Категория: ${task['category'] ?? '—'}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: completed,
                onChanged: (value) => toggleCompleted(task, value),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              const Text('Выполнено'),
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
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = tasks.where((task) {
      final matchesCategory = filterCategory == 'Все' || task['category'] == filterCategory;
      final isDone = task['completed'] ?? false;
      final matchesStatus = filterStatus == 'Все' ||
          (filterStatus == 'Выполненные' && isDone) ||
          (filterStatus == 'Активные' && !isDone);
      return matchesCategory && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Neo TODO', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // форма
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Заголовок',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Описание',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Категория',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      onChanged: (value) => setState(() => selectedCategory = value ?? 'Общее'),
                    ),
                    CheckboxListTile(
                      title: Text('Выполнено'),
                      value: isCompleted,
                      onChanged: (value) => setState(() => isCompleted = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    ElevatedButton.icon(
                      icon: isLoading
                          ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(Icons.save),
                      label: Text(editingId == null ? 'Добавить' : 'Сохранить'),
                      onPressed: isLoading ? null : submitTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // список
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: filterCategory,
                        items: ['Все', ...categories].map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (value) => setState(() => filterCategory = value ?? 'Все'),
                      ),
                      const SizedBox(width: 20),
                      DropdownButton<String>(
                        value: filterStatus,
                        items: ['Все', 'Выполненные', 'Активные'].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                        onChanged: (value) => setState(() => filterStatus = value ?? 'Все'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isFetching
                        ? Center(child: CircularProgressIndicator())
                        : filteredTasks.isEmpty
                        ? Center(child: Text('Нет задач'))
                        : ListView.builder(
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) => buildTaskCard(filteredTasks[index]),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}