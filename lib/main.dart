import 'dart:async';
import 'package:flutter/material.dart';
import 'models/task.dart';
import 'services/storage_service.dart';

void main() {
  runApp(const LifeDashboardApp());
}

class LifeDashboardApp extends StatelessWidget {
  const LifeDashboardApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life Dashboard',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B16),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C4DFF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final List<Task> tasks = [
    Task(
      title: 'Learn Java Arrays',
      category: 'Study',
      completed: true,
      completedAt: DateTime.now(),
    ),
    Task(title: 'Solve 2 DSA Problems', category: 'Study', completed: false),
    Task(title: 'Work on Project', category: 'Project', completed: false),
    Task(title: 'Exercise', category: 'Health', completed: false),
    Task(
      title: 'Read 20 Pages',
      category: 'Study',
      completed: true,
      completedAt: DateTime.now(),
    ),
    Task(title: 'Meditation', category: 'Health', completed: false),
  ];

  @override
  void initState() {
    super.initState();
    loadSavedTasks();
    loadSavedFocusStats();
  }

  Future<void> loadSavedFocusStats() async {
    final savedStats = await _storageService.loadFocusStats();

    if (!mounted) {
      return;
    }

    setState(() {
      completedFocusSessions = savedStats['sessions'] ?? 0;
      totalFocusSeconds = savedStats['focusSeconds'] ?? 0;
    });
  }

  Future<void> loadSavedTasks() async {
    final savedTasks = await _storageService.loadTasks();

    if (!mounted || savedTasks.isEmpty) {
      return;
    }

    setState(() {
      tasks
        ..clear()
        ..addAll(savedTasks);
    });
  }

  final TextEditingController taskController = TextEditingController();

  final TextEditingController editTaskController = TextEditingController();

  String selectedCategory = 'Study';
  String editSelectedCategory = 'Study';
  int selectedIndex = 0;
  int remainingSeconds = 25 * 60;
  Timer? focusTimer;
  bool isFocusRunning = false;
  int completedFocusSessions = 0;
  int totalFocusSeconds = 0;
  double get completionRate {
    if (tasks.isEmpty) {
      return 0;
    }

    final completed = tasks.where((task) => task.completed).length;

    return (completed / tasks.length) * 100;
  }

  List<int> get weeklyCompletedTasks {
    final today = DateTime.now();

    final daysSinceSunday = today.weekday % 7;

    final sunday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: daysSinceSunday));

    final counts = List<int>.filled(7, 0);

    for (final task in tasks) {
      final completedAt = task.completedAt;

      if (completedAt == null) {
        continue;
      }

      final completedDate = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );

      final difference = completedDate.difference(sunday).inDays;

      if (difference >= 0 && difference < 7) {
        counts[difference]++;
      }
    }

    return counts;
  }

  String get formattedFocusTime {
    final minutes = totalFocusSeconds ~/ 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    }

    return '$minutes min';
  }

  void toggleTask(int index) {
    setState(() {
      tasks[index].completed = !tasks[index].completed;

      if (tasks[index].completed) {
        tasks[index].completedAt = DateTime.now();
      } else {
        tasks[index].completedAt = null;
      }
    });

    _storageService.saveTasks(tasks);
  }

  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void startFocusTimer() {
    focusTimer?.cancel();
    isFocusRunning = true;

    focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();

        setState(() {
          isFocusRunning = false;
          completedFocusSessions++;
          totalFocusSeconds += 25 * 60;
        });

        final messenger = ScaffoldMessenger.of(context);

        await _storageService.saveFocusStats(
          sessions: completedFocusSessions,
          focusSeconds: totalFocusSeconds,
        );

        if (!mounted) {
          return;
        }

        messenger.showSnackBar(
          const SnackBar(content: Text('Focus session completed! 🎉')),
        );
      }
    });
  }

  void pauseFocusTimer() {
    focusTimer?.cancel();

    setState(() {
      isFocusRunning = false;
    });
  }

  void resetFocusTimer() {
    focusTimer?.cancel();

    setState(() {
      remainingSeconds = 25 * 60;
      isFocusRunning = false;
    });
  }

  void showTaskOptions(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Task Options'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                editTask(index);
              },
              child: const Text('EDIT'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                deleteTask(index);
              },
              child: const Text('DELETE'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );
  }

  void editTask(int index) {
    editTaskController.text = tasks[index].title;
    editSelectedCategory = tasks[index].category;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: editTaskController),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: editSelectedCategory,
                items: const [
                  DropdownMenuItem(value: 'Study', child: Text('Study')),
                  DropdownMenuItem(value: 'Project', child: Text('Project')),
                  DropdownMenuItem(value: 'Health', child: Text('Health')),
                ],
                onChanged: (value) {
                  setState(() {
                    editSelectedCategory = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                tasks[index].title = editTaskController.text;
                tasks[index].category = editSelectedCategory;

                setState(() {});

                _storageService.saveTasks(tasks);

                Navigator.pop(context);
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  void deleteTask(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Task?'),
          content: Text(
            'Are you sure you want to delete "${tasks[index].title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  tasks.removeAt(index);
                });

                final navigator = Navigator.of(context);

                await _storageService.saveTasks(tasks);

                if (!mounted) {
                  return;
                }

                navigator.pop();
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }

  void showAddTaskDialog() {
    taskController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Task'),

          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: taskController,
                    decoration: const InputDecoration(
                      hintText: 'Enter task name',
                    ),
                  ),

                  const SizedBox(height: 16),

                  DropdownButton<String>(
                    value: selectedCategory,
                    items: const [
                      DropdownMenuItem(value: 'Study', child: Text('Study')),
                      DropdownMenuItem(
                        value: 'Project',
                        child: Text('Project'),
                      ),
                      DropdownMenuItem(value: 'Health', child: Text('Health')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                ],
              );
            },
          ),

          actions: [
            TextButton(
              onPressed: () {
                final newTask = Task(
                  title: taskController.text,
                  category: selectedCategory,
                  completed: false,
                );

                setState(() {
                  tasks.add(newTask);
                });

                _storageService.saveTasks(tasks);

                taskController.clear();

                Navigator.pop(context);
              },
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    focusTimer?.cancel();
    taskController.dispose();
    editTaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedTasks = tasks.where((task) => task.completed == true).length;

    final totalTasks = tasks.length;

    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning, Srujan 👋',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Ready to make today amazing?',
              style: TextStyle(fontSize: 13, color: Colors.white60),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),

      body: selectedIndex == 0
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------- PROGRESS CARD ----------------
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF21145C), Color(0xFF101B3D)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 9,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF31D7E8),
                                ),
                              ),

                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$completedTasks/$totalTasks',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Tasks',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 20),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today's Progress",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 12),

                            const Text(
                              '🔥 4 Day Streak',
                              style: TextStyle(color: Colors.orangeAccent),
                            ),

                            const SizedBox(height: 6),

                            const Text(
                              '⚡ Level 7',
                              style: TextStyle(color: Colors.amberAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ---------------- TASK HEADER ----------------
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Tasks",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'View all',
                        style: TextStyle(color: Color(0xFF8C72FF)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ---------------- TASK LIST ----------------
                  ...List.generate(tasks.length, (index) {
                    final task = tasks[index];

                    return TaskCard(
                      title: task.title,
                      category: task.category,
                      completed: task.completed,
                      onTap: () => toggleTask(index),
                      onLongPress: () {
                        showTaskOptions(index);
                      },
                    );
                  }),

                  const SizedBox(height: 24),

                  // ---------------- AI INSIGHT ----------------
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17104A), Color(0xFF101A35)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color.fromRGBO(108, 77, 255, 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 27,
                          backgroundColor: Color(0xFF6C4DFF),
                          child: Icon(Icons.auto_awesome, color: Colors.white),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Text(
                            completedTasks == totalTasks
                                ? "🔥 Everything is done! You've completed all your tasks today."
                                : "You've completed ${(progress * 100).round()}% of today's tasks. Keep going!",
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            )
          : selectedIndex == 1
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TaskCard(
                    title: task.title,
                    category: task.category,
                    completed: task.completed,
                    onTap: () => toggleTask(index),
                    onLongPress: () => showTaskOptions(index),
                  ),
                );
              },
            )
          : selectedIndex == 2
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Focus Timer',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  ElevatedButton(
                    onPressed: isFocusRunning
                        ? pauseFocusTimer
                        : startFocusTimer,
                    child: Text(isFocusRunning ? 'PAUSE' : 'START'),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: resetFocusTimer,
                    child: const Text('RESET'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Task Completion',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Tasks completed from Sunday to Saturday',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    height: 280,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101728),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: WeeklyTaskChart(values: weeklyCompletedTasks),
                  ),

                  const SizedBox(height: 28),

                  _StatValue(
                    label: 'Focus Sessions',
                    value: '$completedFocusSessions',
                  ),

                  const SizedBox(height: 24),

                  _StatValue(
                    label: 'Tasks Completed',
                    value: '$completedTasks',
                  ),

                  const SizedBox(height: 24),

                  _StatValue(
                    label: 'Completion Rate',
                    value: '${completionRate.toStringAsFixed(0)}%',
                  ),

                  const SizedBox(height: 24),

                  _StatValue(label: 'Total Tasks', value: '${tasks.length}'),

                  const SizedBox(height: 24),

                  _StatValue(label: 'Focus Time', value: formattedFocusTime),

                  const SizedBox(height: 16),
                ],
              ),
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C4DFF),
        onPressed: showAddTaskDialog,
        child: const Icon(Icons.add),
      ),

      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0B1020),
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final String title;
  final String category;
  final bool completed;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TaskCard({
    super.key,
    required this.title,
    required this.category,
    required this.completed,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF101728),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: completed ? Colors.greenAccent : Colors.white38,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  decoration: completed ? TextDecoration.lineThrough : null,
                  color: completed ? Colors.white54 : Colors.white,
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: category == 'Study'
                    ? Colors.blue.withAlpha(38)
                    : category == 'Project'
                    ? Colors.purple.withAlpha(38)
                    : Colors.green.withAlpha(38),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 11,
                  color: category == 'Study'
                      ? Colors.lightBlueAccent
                      : category == 'Project'
                      ? Colors.purpleAccent
                      : Colors.greenAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  final String label;
  final String value;

  const _StatValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF101728),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class WeeklyTaskChart extends StatelessWidget {
  final List<int> values;

  const WeeklyTaskChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WeeklyTaskChartPainter(values),
      child: const SizedBox.expand(),
    );
  }
}

class _WeeklyTaskChartPainter extends CustomPainter {
  final List<int> values;

  _WeeklyTaskChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final maxValue = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b);

    // Keep enough headroom for low weekly counts while scaling up
    // in clean steps as the number of completed tasks grows.
    final chartMax = maxValue <= 5 ? 5 : ((maxValue + 4) ~/ 5) * 5;

    const leftPadding = 28.0;
    const rightPadding = 8.0;
    const topPadding = 10.0;
    const bottomPadding = 30.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    final barPaint = Paint()..color = const Color(0xFF6C4DFF);

    final labelStyle = const TextStyle(color: Colors.white60, fontSize: 11);

    final valueStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final gridLines = chartMax < 4 ? chartMax : 4;

    for (var i = 0; i <= gridLines; i++) {
      final y = topPadding + chartHeight - (chartHeight * i / gridLines);

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final gridValue = (chartMax * i / gridLines).round();

      final painter = TextPainter(
        text: TextSpan(text: '$gridValue', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(
        canvas,
        Offset(leftPadding - painter.width - 6, y - painter.height / 2),
      );
    }

    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, topPadding + chartHeight),
      axisPaint,
    );

    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(size.width - rightPadding, topPadding + chartHeight),
      axisPaint,
    );

    final slotWidth = chartWidth / 7;
    final barWidth = slotWidth * 0.48;

    for (var i = 0; i < 7; i++) {
      final value = i < values.length ? values[i] : 0;
      final barHeight = chartHeight * value / chartMax;

      final xCenter = leftPadding + slotWidth * i + slotWidth / 2;
      final left = xCenter - barWidth / 2;
      final top = topPadding + chartHeight - barHeight;

      final radius = Radius.circular(barWidth > 10 ? 8 : barWidth / 2);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          radius,
        ),
        barPaint,
      );

      if (value > 0) {
        final valuePainter = TextPainter(
          text: TextSpan(text: '$value', style: valueStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        valuePainter.paint(
          canvas,
          Offset(
            xCenter - valuePainter.width / 2,
            top - valuePainter.height - 4,
          ),
        );
      }

      final dayPainter = TextPainter(
        text: TextSpan(text: days[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      dayPainter.paint(
        canvas,
        Offset(xCenter - dayPainter.width / 2, topPadding + chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyTaskChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
