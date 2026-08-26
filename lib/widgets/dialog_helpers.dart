import 'package:flutter/material.dart';
import '../theme.dart';

/// Grupperar fält i en bordad, luftig sektion – samma visuella mönster som
/// "Add Policy Properties"-dialogen (From/To-boxarna). Delas av alla
/// overlay-dialoger i appen så att de känns konsekventa istället för att
/// fälten bara radas tätt under varandra.
Widget dialogSection({required String title, required List<Widget> children}) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Text(title, style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    ),
  );
}

Widget dialogField(TextEditingController controller, String label, {String? hint}) {
  return SizedBox(
    height: 56,
    child: TextField(
      controller: controller,
      style: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    ),
  );
}

/// Titelrad med rubrik + stäng-knapp, används överst i alla dialoger.
Widget dialogTitleRow(BuildContext context, String title, VoidCallback onClose) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
      IconButton(
        icon: Icon(Icons.close, size: 16, color: AppColors.textMuted),
        onPressed: onClose,
      ),
    ],
  );
}
