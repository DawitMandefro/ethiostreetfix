import 'package:flutter/material.dart';
import '../models/report_model.dart';

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.current,
    required this.history,
  });

  final ReportStatus current;
  final List<Map<String, dynamic>> history;

  static const _stages = [
    ReportStatus.pending,
    ReportStatus.inProgress,
    ReportStatus.fixed,
    ReportStatus.rejected,
  ];

  Color _colorForStage(ReportStatus s, ThemeData theme) {
    return s == current
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.4);
  }

  String _labelForStage(ReportStatus s) {
    switch (s) {
      case ReportStatus.pending:
        return 'Submitted';
      case ReportStatus.inProgress:
        return 'In progress';
      case ReportStatus.fixed:
        return 'Resolved';
      case ReportStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: _stages.map((s) {
        final idx = _stages.indexOf(s);
        final isActive = s == current || _stages.indexOf(current) > idx;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _colorForStage(s, theme),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (idx != _stages.length - 1)
                    Container(
                      width: 2,
                      height: 48,
                      color: theme.dividerColor,
                      margin: const EdgeInsets.only(top: 4),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelForStage(s),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isActive
                            ? theme.colorScheme.onBackground
                            : theme.colorScheme.onBackground.withOpacity(0.6),
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (history.isNotEmpty)
                      Text(
                        history
                            .map((e) => e['note'] ?? e['message'] ?? '')
                            .join('\n'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onBackground.withOpacity(
                            0.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
