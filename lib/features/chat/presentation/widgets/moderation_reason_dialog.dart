import 'package:flutter/material.dart';

class ModerationReasonResult {
  final String reason;
  final int? durationMinutes;

  const ModerationReasonResult({
    required this.reason,
    this.durationMinutes,
  });
}

Future<ModerationReasonResult?> showModerationReasonDialog(
  BuildContext context, {
  required String title,
  bool duration = false,
}) async {
  final reasonController = TextEditingController();
  int? selectedDuration;

  try {
    return await showDialog<ModerationReasonResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'السبب',
                    ),
                  ),
                  if (duration)
                    DropdownButton<int>(
                      value: selectedDuration,
                      hint: const Text('المدة'),
                      items: const [
                        DropdownMenuItem(
                          value: 10,
                          child: Text('10 دقائق'),
                        ),
                        DropdownMenuItem(
                          value: 60,
                          child: Text('ساعة'),
                        ),
                        DropdownMenuItem(
                          value: 1440,
                          child: Text('يوم'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDuration = value;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    ModerationReasonResult(
                      reason: reasonController.text.trim(),
                      durationMinutes: selectedDuration,
                    ),
                  ),
                  child: const Text('تنفيذ'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    reasonController.dispose();
  }
}
