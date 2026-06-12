import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/mutations.dart';
import '../../data/streams.dart';
import '../../models/credit_card.dart';
import '../../models/expense.dart';
import 'card_editor.dart';
import 'cycle.dart';

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);
    return Scaffold(
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load cards\n$e')),
        data: (cards) => cards.isEmpty
            ? const Center(
                child: Text(
                    'No credit cards yet.\nAdd one to track its billing cycle.',
                    textAlign: TextAlign.center),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  for (final card in cards) _CardTile(card: card),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCardEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Card'),
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.card});

  final CreditCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final cycle = currentCycle(card, now);
    final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];

    final cycleSpend = _spendBetween(
        expenses, card.id, cycle.cycleStart, _endOfDay(now));
    final statementAmount = _spendBetween(expenses, card.id,
        previousCycleStart(card, cycle), _endOfDay(cycle.lastStatement));

    final daysToStatement = cycle.daysUntilNextStatement(now);
    final daysToDue = cycle.daysUntilDue(now);
    final utilization = card.creditLimit == null || card.creditLimit! <= 0
        ? null
        : (cycleSpend / card.creditLimit!).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showCardEditor(context, card: card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      card.last4.isEmpty
                          ? card.name
                          : '${card.name}  ·· ${card.last4}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(formatAmount(cycleSpend),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'This cycle · ${formatShortDate(cycle.cycleStart)} – ${formatShortDate(cycle.nextStatement)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.receipt_long,
                    label: 'Statement in $daysToStatement d',
                    detail: formatShortDate(cycle.nextStatement),
                  ),
                  if (statementAmount > 0)
                    _InfoChip(
                      icon: Icons.request_quote,
                      label: 'Last bill ${formatAmount(statementAmount)}',
                      detail: daysToDue >= 0
                          ? 'due ${formatShortDate(cycle.dueDate)} ($daysToDue d)'
                          : 'was due ${formatShortDate(cycle.dueDate)}',
                      emphasize: daysToDue >= 0 && daysToDue <= 5,
                    ),
                ],
              ),
              if (utilization != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: utilization,
                    minHeight: 8,
                    color: utilization > 0.3
                        ? Colors.orange
                        : theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(utilization * 100).round()}% of ${formatAmount(card.creditLimit!)} limit used this cycle',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  double _spendBetween(
      List<Expense> expenses, String cardId, DateTime from, DateTime to) {
    return expenses
        .where((e) =>
            e.cardId == cardId &&
            !e.spentAt.isBefore(from) &&
            !e.spentAt.isAfter(to))
        .fold(0.0, (sum, e) => sum + e.amount);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.detail,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        emphasize ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label · $detail',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
