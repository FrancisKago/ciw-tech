import 'package:flutter/material.dart';
import '../models/task.dart';
import 'branch_meta.dart';

/// Puce compacte représentant la branche métier d'une tâche.
class BranchChip extends StatelessWidget {
  const BranchChip(this.domaine, {super.key});
  final DomaineTrade? domaine;

  @override
  Widget build(BuildContext context) {
    final m = branchMeta(domaine);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: m.bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(m.icon, size: 14, color: m.fg),
          const SizedBox(width: 4),
          Text(m.label, style: TextStyle(fontSize: 12, color: m.fg)),
        ],
      ),
    );
  }
}
