// lib/features/todos/presentation/todos_screen.dart
// Phase 2 stub — full implementation in Phase 4.

import 'package:flutter/material.dart';
import 'package:streakin/core/design/tokens.dart';
import 'package:streakin/core/design/icons.dart';

class TodosScreen extends StatelessWidget {
  const TodosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: const Text('Tasks')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.emptyTasks, size: 72, color: colors.textMuted),
            const SizedBox(height: 16),
            Text('Tasks coming in Phase 4',
                style: TextStyle(fontSize: 18, color: colors.textMuted)),
          ],
        ),
      ),
    );
  }
}
