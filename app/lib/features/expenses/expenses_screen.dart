import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/mutations.dart';
import '../../data/streams.dart';
import '../../models/expense.dart';
import '../shell/home_shell.dart';
import 'expense_editor.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(monthExpensesProvider);
    return Scaffold(
      body: Column(
        children: [
          const MonthSelector(),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load expenses\n$e',
                  textAlign: TextAlign.center)),
              data: (expenses) => _ExpenseList(expenses: expenses),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Expense'),
      ),
    );
  }
}

class _ExpenseList extends ConsumerWidget {
  const _ExpenseList({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expenses.isEmpty) {
      return const Center(
        child: Text('No expenses this month.\nTap "Expense" to add one.',
            textAlign: TextAlign.center),
      );
    }

    final theme = Theme.of(context);
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Group by day, preserving newest-first order.
    final groups = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final day = DateTime(e.spentAt.year, e.spentAt.month, e.spentAt.day);
      groups.putIfAbsent(day, () => []).add(e);
    }
    final days = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: days.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total spent', style: theme.textTheme.titleMedium),
                    Text(formatAmount(total),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );
        }
        final day = days[i - 1];
        final dayExpenses = groups[day]!;
        final dayTotal =
            dayExpenses.fold<double>(0, (sum, e) => sum + e.amount);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDay(day),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.outline)),
                  Text(formatAmount(dayTotal),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            for (final expense in dayExpenses) _ExpenseTile(expense: expense),
          ],
        );
      },
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByIdProvider);
    final cards = ref.watch(cardsProvider).valueOrNull ?? const [];
    final category =
        expense.categoryId == null ? null : categories[expense.categoryId];
    final cardName = expense.cardId == null
        ? null
        : cards.where((c) => c.id == expense.cardId).firstOrNull?.name;

    final subtitleParts = [
      paymentMethodLabel(expense.paymentMethod),
      if (cardName != null) cardName,
      if (expense.note.isNotEmpty) expense.note,
    ];

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this expense?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      ),
      onDismissed: (_) =>
          ref.read(mutationsProvider).deleteExpense(expense.id),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (category?.color ?? Colors.grey).withValues(alpha: 0.15),
          child: Text(
            category == null ? '?' : category.name.characters.first,
            style: TextStyle(
                color: category?.color ?? Colors.grey,
                fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(category?.name ?? 'Uncategorised'),
        subtitle: Text(subtitleParts.join(' · '),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(formatAmount(expense.amount),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        onTap: () => showExpenseEditor(context, expense: expense),
      ),
    );
  }
}
