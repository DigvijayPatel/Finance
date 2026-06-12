import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../data/mutations.dart';
import '../../data/streams.dart';
import '../../models/category.dart';
import '../shell/home_shell.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgets = ref.watch(monthBudgetsProvider).valueOrNull ?? const [];
    final expenses = ref.watch(monthExpensesProvider).valueOrNull ?? const [];

    final spentByCategory = <String?, double>{};
    var totalSpent = 0.0;
    for (final e in expenses) {
      spentByCategory[e.categoryId] =
          (spentByCategory[e.categoryId] ?? 0) + e.amount;
      totalSpent += e.amount;
    }
    final budgetByCategory = {for (final b in budgets) b.categoryId: b.amount};

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load budgets\n$e')),
      data: (categories) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const MonthSelector(),
          _BudgetCard(
            title: 'Overall budget',
            color: Theme.of(context).colorScheme.primary,
            budget: budgetByCategory[null],
            spent: totalSpent,
            onTap: () => _editBudget(context, ref, null, 'Overall budget',
                budgetByCategory[null]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Category budgets',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final c in categories)
            _BudgetCard(
              title: c.name,
              color: c.color,
              budget: budgetByCategory[c.id],
              spent: spentByCategory[c.id] ?? 0,
              onTap: () =>
                  _editBudget(context, ref, c, c.name, budgetByCategory[c.id]),
            ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref,
      Category? category, String label, double? current) async {
    final controller = TextEditingController(
        text: current == null ? '' : current.toInt().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly budget (0 to remove)',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v >= 0) Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final month = ref.read(selectedMonthProvider);
    await ref.read(mutationsProvider).setBudget(
        categoryId: category?.id, month: month, amount: result);
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.title,
    required this.color,
    required this.budget,
    required this.spent,
    required this.onTap,
  });

  final String title;
  final Color color;
  final double? budget;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBudget = budget != null && budget! > 0;
    final ratio = hasBudget ? (spent / budget!).clamp(0.0, 1.0) : 0.0;
    final over = hasBudget && spent > budget!;
    final near = hasBudget && !over && spent >= budget! * 0.8;
    final barColor = over
        ? theme.colorScheme.error
        : near
            ? Colors.orange
            : color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (over)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.error,
                          size: 18, color: theme.colorScheme.error),
                    )
                  else if (near)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child:
                          Icon(Icons.warning, size: 18, color: Colors.orange),
                    ),
                  Text(
                    hasBudget
                        ? '${formatAmount(spent)} / ${formatAmount(budget!)}'
                        : '${formatAmount(spent)} · no budget',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
              if (hasBudget) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    color: barColor,
                    backgroundColor: barColor.withOpacity(0.15),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  over
                      ? 'Over by ${formatAmount(spent - budget!)}'
                      : '${formatAmount(budget! - spent)} left',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          over ? theme.colorScheme.error : theme.colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
