/// Semester grades from the A0809Q WebForms page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../student_data_providers.dart';

class GradesPage extends ConsumerStatefulWidget {
  const GradesPage({super.key});
  @override
  ConsumerState<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends ConsumerState<GradesPage> {
  String? _semester;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gradesProvider(_semester));
    return Scaffold(
      appBar: AppBar(title: const Text('成績'), actions: [
        IconButton(onPressed: () => ref.invalidate(gradesProvider(_semester)), icon: const Icon(Icons.refresh)),
      ]),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: TextButton.icon(
          onPressed: () => ref.invalidate(gradesProvider(_semester)), icon: const Icon(Icons.refresh), label: Text('成績載入失敗，點擊重試：$e'))),
        data: (result) => Column(children: [
          if (result.semesters.isNotEmpty) Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: DropdownButtonFormField<String>(
              value: _semester ?? result.selected,
              decoration: const InputDecoration(labelText: '學期'),
              items: result.semesters.map((s) => DropdownMenuItem(value: s.value, child: Text(s.label))).toList(),
              onChanged: (v) => setState(() => _semester = v),
            ),
          ),
          Expanded(child: result.rows.isEmpty
              ? const Center(child: Text('此學期尚無確定成績'))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.l), itemCount: result.rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
                  itemBuilder: (context, i) => _RecordCard(cells: result.rows[i]),
                )),
        ]),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.cells});
  final List<String> cells;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(AppSpacing.m),
    child: Text(cells.where((v) => v.isNotEmpty).join('　 ·　')),
  ));
}
