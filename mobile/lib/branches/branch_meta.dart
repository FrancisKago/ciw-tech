import 'package:flutter/material.dart';
import '../models/task.dart';

class BranchMeta {
  const BranchMeta(this.label, this.icon, this.bg, this.fg);
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
}

BranchMeta branchMeta(DomaineTrade? d) {
  switch (d) {
    case DomaineTrade.electricite:
      return const BranchMeta('Électricité', Icons.bolt, Color(0xFFFBF0D6), Color(0xFF854F0B));
    case DomaineTrade.informatique:
      return const BranchMeta('Informatique', Icons.videocam, Color(0xFFE1F0FA), Color(0xFF0C447C));
    case DomaineTrade.plomberie:
      return const BranchMeta('Plomberie', Icons.water_drop, Color(0xFFE1F5EE), Color(0xFF0F6E56));
    case DomaineTrade.autre:
      return const BranchMeta('Autre', Icons.build, Color(0xFFF1EFE8), Color(0xFF444441));
    case null:
      return const BranchMeta('Non précisé', Icons.help_outline, Color(0xFFF1EFE8), Color(0xFF5F6B78));
  }
}
