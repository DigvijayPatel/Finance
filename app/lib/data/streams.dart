import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/providers.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/credit_card.dart';
import '../models/expense.dart';
import '../models/spend_alert.dart';

/// All streams read whole tables: RLS scopes rows to the signed-in user and
/// personal-finance volumes are small, so month filtering happens client-side.

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(supabaseProvider);
  return db
      .from('categories')
      .stream(primaryKey: ['id'])
      .order('name', ascending: true)
      .map((rows) => rows.map(Category.fromMap).toList());
});

final categoriesByIdProvider = Provider<Map<String, Category>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
  return {for (final c in categories) c.id: c};
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(supabaseProvider);
  return db
      .from('expenses')
      .stream(primaryKey: ['id'])
      .order('spent_at', ascending: false)
      .map((rows) => rows.map(Expense.fromMap).toList());
});

/// Expenses in the month selected on the UI, newest first.
final monthExpensesProvider = Provider<AsyncValue<List<Expense>>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(expensesProvider).whenData(
      (all) => all.where((e) => sameMonth(e.spentAt, month)).toList());
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final db = ref.watch(supabaseProvider);
  return db
      .from('budgets')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map(Budget.fromMap).toList());
});

final monthBudgetsProvider = Provider<AsyncValue<List<Budget>>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(budgetsProvider).whenData(
      (all) => all.where((b) => sameMonth(b.month, month)).toList());
});

final cardsProvider = StreamProvider<List<CreditCard>>((ref) {
  final db = ref.watch(supabaseProvider);
  return db
      .from('credit_cards')
      .stream(primaryKey: ['id'])
      .order('name', ascending: true)
      .map((rows) => rows.map(CreditCard.fromMap).toList());
});

final alertsProvider = StreamProvider<List<SpendAlert>>((ref) {
  final db = ref.watch(supabaseProvider);
  return db
      .from('alerts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(SpendAlert.fromMap).toList());
});

final unreadAlertCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(alertsProvider).valueOrNull ?? const [];
  return alerts.where((a) => !a.isRead).length;
});
