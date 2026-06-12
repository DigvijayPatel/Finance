import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';

final mutationsProvider =
    Provider<Mutations>((ref) => Mutations(ref.watch(supabaseProvider)));

/// Thin write-side helpers. Reads come from the realtime streams in
/// streams.dart, so none of these need to return data.
class Mutations {
  Mutations(this._db);

  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- Expenses ----

  Future<void> saveExpense({
    String? id,
    required double amount,
    required String? categoryId,
    required String? cardId,
    required String paymentMethod,
    required DateTime spentAt,
    required String note,
  }) async {
    final row = {
      'user_id': _uid,
      'amount': amount,
      'category_id': categoryId,
      'card_id': paymentMethod == 'card' ? cardId : null,
      'payment_method': paymentMethod,
      'spent_at': _dateOnly(spentAt),
      'note': note,
    };
    if (id == null) {
      await _db.from('expenses').insert(row);
    } else {
      await _db.from('expenses').update(row).eq('id', id);
    }
  }

  Future<void> deleteExpense(String id) =>
      _db.from('expenses').delete().eq('id', id);

  // ---- Budgets ----

  Future<void> setBudget({
    required String? categoryId,
    required DateTime month,
    required double amount,
  }) async {
    var query = _db.from('budgets').delete().eq('user_id', _uid).eq('month', _dateOnly(month));
    query = categoryId == null
        ? query.isFilter('category_id', null)
        : query.eq('category_id', categoryId);
    await query;
    if (amount > 0) {
      await _db.from('budgets').insert({
        'user_id': _uid,
        'category_id': categoryId,
        'month': _dateOnly(month),
        'amount': amount,
      });
    }
  }

  // ---- Credit cards ----

  Future<void> saveCard({
    String? id,
    required String name,
    required String last4,
    required double? creditLimit,
    required int statementDay,
    required int graceDays,
  }) async {
    final row = {
      'user_id': _uid,
      'name': name,
      'last4': last4,
      'credit_limit': creditLimit,
      'statement_day': statementDay,
      'grace_days': graceDays,
    };
    if (id == null) {
      await _db.from('credit_cards').insert(row);
    } else {
      await _db.from('credit_cards').update(row).eq('id', id);
    }
  }

  Future<void> deleteCard(String id) =>
      _db.from('credit_cards').delete().eq('id', id);

  // ---- Categories ----

  Future<void> addCategory(String name, String colorHex) =>
      _db.from('categories').insert({
        'user_id': _uid,
        'name': name,
        'color': colorHex,
      });

  // ---- Alerts ----

  Future<void> markAlertRead(String id) =>
      _db.from('alerts').update({'is_read': true}).eq('id', id);

  Future<void> markAllAlertsRead() =>
      _db.from('alerts').update({'is_read': true}).eq('is_read', false);
}
