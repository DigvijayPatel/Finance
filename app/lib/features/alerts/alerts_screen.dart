import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/mutations.dart';
import '../../data/streams.dart';
import '../../models/spend_alert.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);
    final unread = ref.watch(unreadAlertCountProvider);

    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load alerts\n$e')),
      data: (alerts) {
        if (alerts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No alerts yet.\n\nSet budgets on the Budget tab — you\'ll be '
                'alerted here when spending crosses 80% or exceeds a budget.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Column(
          children: [
            if (unread > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 4),
                  child: TextButton.icon(
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Mark all read'),
                    onPressed: () =>
                        ref.read(mutationsProvider).markAllAlertsRead(),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: alerts.length,
                itemBuilder: (context, i) => _AlertTile(alert: alerts[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({required this.alert});

  final SpendAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = alert.isExceeded ? theme.colorScheme.error : Colors.orange;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(alert.isExceeded ? Icons.error : Icons.warning_amber,
            color: color),
      ),
      title: Text(
        alert.isExceeded ? 'Budget exceeded' : 'Approaching budget',
        style: TextStyle(
            fontWeight: alert.isRead ? FontWeight.w400 : FontWeight.w700),
      ),
      subtitle: Text('${alert.message}\n'
          '${formatMonth(alert.month)} · ${relativeTime(alert.createdAt)}'),
      isThreeLine: true,
      trailing: alert.isRead
          ? null
          : Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
      onTap: alert.isRead
          ? null
          : () => ref.read(mutationsProvider).markAlertRead(alert.id),
    );
  }
}
