import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../data/streams.dart';
import '../../models/expense.dart';
import '../shell/home_shell.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final month = ref.watch(selectedMonthProvider);

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load insights\n$e')),
      data: (all) {
        final monthExpenses =
            all.where((e) => sameMonth(e.spentAt, month)).toList();
        final prevMonth = DateTime(month.year, month.month - 1);
        final prevExpenses =
            all.where((e) => sameMonth(e.spentAt, prevMonth)).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const MonthSelector(),
            _SummaryRow(
                month: month,
                monthExpenses: monthExpenses,
                prevExpenses: prevExpenses),
            const _SectionTitle('Last 6 months'),
            _TrendChart(all: all, anchorMonth: month),
            const _SectionTitle('By category'),
            _CategoryBreakdown(expenses: monthExpenses),
            const _SectionTitle('Top expenses'),
            _TopExpenses(expenses: monthExpenses),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.month,
    required this.monthExpenses,
    required this.prevExpenses,
  });

  final DateTime month;
  final List<Expense> monthExpenses;
  final List<Expense> prevExpenses;

  @override
  Widget build(BuildContext context) {
    final total = monthExpenses.fold<double>(0, (s, e) => s + e.amount);
    final prevTotal = prevExpenses.fold<double>(0, (s, e) => s + e.amount);

    final now = DateTime.now();
    final daysElapsed = sameMonth(month, now)
        ? now.day
        : DateTime(month.year, month.month + 1, 0).day;
    final perDay = daysElapsed == 0 ? 0.0 : total / daysElapsed;

    String vsLast;
    if (prevTotal == 0) {
      vsLast = '—';
    } else {
      final pct = ((total - prevTotal) / prevTotal * 100).round();
      vsLast = pct >= 0 ? '+$pct%' : '$pct%';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard(label: 'Spent', value: formatAmount(total)),
          _StatCard(label: 'Per day', value: formatAmount(perDay)),
          _StatCard(label: 'vs last month', value: vsLast),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.all, required this.anchorMonth});

  final List<Expense> all;
  final DateTime anchorMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = [
      for (var i = 5; i >= 0; i--)
        DateTime(anchorMonth.year, anchorMonth.month - i),
    ];
    final totals = [
      for (final m in months)
        all
            .where((e) => sameMonth(e.spentAt, m))
            .fold<double>(0, (s, e) => s + e.amount),
    ];
    final maxY = totals.fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 16, 8),
        child: SizedBox(
          height: 180,
          child: maxY == 0
              ? const Center(child: Text('No data yet'))
              : BarChart(
                  BarChartData(
                    maxY: maxY * 1.15,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                          formatAmount(rod.toY),
                          TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _monthShort(months[value.toInt()]),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var i = 0; i < months.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: totals[i],
                            width: 22,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5)),
                            color: i == months.length - 1
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary
                                    .withValues(alpha: 0.45),
                          ),
                        ]),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _monthShort(DateTime m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[m.month - 1];
  }
}

class _CategoryBreakdown extends ConsumerWidget {
  const _CategoryBreakdown({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesByIdProvider);

    final byCategory = <String?, double>{};
    var total = 0.0;
    for (final e in expenses) {
      byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
      total += e.amount;
    }
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (total == 0) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
            height: 80, child: Center(child: Text('No expenses this month'))),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: [
                    for (final entry in entries)
                      PieChartSectionData(
                        value: entry.value,
                        showTitle: false,
                        radius: 32,
                        color: entry.key == null
                            ? Colors.grey
                            : categories[entry.key]?.color ?? Colors.grey,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in entries.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: entry.key == null
                                  ? Colors.grey
                                  : categories[entry.key]?.color ?? Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key == null
                                  ? 'Uncategorised'
                                  : categories[entry.key]?.name ?? 'Unknown',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(entry.value / total * 100).round()}%',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopExpenses extends ConsumerWidget {
  const _TopExpenses({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByIdProvider);
    final top = [...expenses]..sort((a, b) => b.amount.compareTo(a.amount));

    if (top.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final e in top.take(5))
            ListTile(
              dense: true,
              title: Text(e.categoryId == null
                  ? 'Uncategorised'
                  : categories[e.categoryId]?.name ?? 'Unknown'),
              subtitle: Text(
                  '${formatShortDate(e.spentAt)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: Text(formatAmount(e.amount),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
