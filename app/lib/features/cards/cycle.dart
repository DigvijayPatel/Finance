import 'dart:math';

import '../../models/credit_card.dart';

/// Billing-cycle window for a card. The cycle runs from the day after one
/// statement to the next statement date (inclusive).
class CardCycle {
  final DateTime lastStatement;
  final DateTime nextStatement;
  final DateTime dueDate; // payment due for the last statement

  const CardCycle({
    required this.lastStatement,
    required this.nextStatement,
    required this.dueDate,
  });

  DateTime get cycleStart => lastStatement.add(const Duration(days: 1));

  int daysUntilNextStatement(DateTime today) =>
      nextStatement.difference(_dayOf(today)).inDays;

  int daysUntilDue(DateTime today) => dueDate.difference(_dayOf(today)).inDays;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Statement date in a given month, clamping day 29-31 to month length.
DateTime statementDateIn(int year, int month, int statementDay) {
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, min(statementDay, lastDayOfMonth));
}

CardCycle currentCycle(CreditCard card, DateTime now) {
  final today = _dayOf(now);
  final thisMonth = statementDateIn(today.year, today.month, card.statementDay);

  final DateTime last;
  final DateTime next;
  if (today.isAfter(thisMonth)) {
    last = thisMonth;
    next = statementDateIn(today.year, today.month + 1, card.statementDay);
  } else {
    last = statementDateIn(today.year, today.month - 1, card.statementDay);
    next = thisMonth;
  }

  return CardCycle(
    lastStatement: last,
    nextStatement: next,
    dueDate: last.add(Duration(days: card.graceDays)),
  );
}

/// Start of the cycle that ended with [cycle.lastStatement], i.e. the window
/// whose spend makes up the latest statement amount.
DateTime previousCycleStart(CreditCard card, CardCycle cycle) {
  final last = cycle.lastStatement;
  return statementDateIn(last.year, last.month - 1, card.statementDay)
      .add(const Duration(days: 1));
}
