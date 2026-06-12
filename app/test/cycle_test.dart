import 'package:finance_app/features/cards/cycle.dart';
import 'package:finance_app/models/credit_card.dart';
import 'package:flutter_test/flutter_test.dart';

CreditCard card({int statementDay = 15, int graceDays = 18}) => CreditCard(
      id: 'c1',
      name: 'Test',
      last4: '0000',
      creditLimit: 100000,
      statementDay: statementDay,
      graceDays: graceDays,
    );

void main() {
  group('statementDateIn', () {
    test('clamps day 31 to short months', () {
      expect(statementDateIn(2026, 2, 31), DateTime(2026, 2, 28));
      expect(statementDateIn(2024, 2, 31), DateTime(2024, 2, 29)); // leap year
      expect(statementDateIn(2026, 4, 31), DateTime(2026, 4, 30));
    });

    test('normalises month overflow', () {
      expect(statementDateIn(2026, 13, 10), DateTime(2027, 1, 10));
      expect(statementDateIn(2026, 0, 10), DateTime(2025, 12, 10));
    });
  });

  group('currentCycle', () {
    test('mid-cycle: after this month\'s statement', () {
      final cycle = currentCycle(card(statementDay: 15), DateTime(2026, 6, 20));
      expect(cycle.lastStatement, DateTime(2026, 6, 15));
      expect(cycle.nextStatement, DateTime(2026, 7, 15));
      expect(cycle.cycleStart, DateTime(2026, 6, 16));
      expect(cycle.dueDate, DateTime(2026, 7, 3)); // 15 Jun + 18 days
    });

    test('before this month\'s statement', () {
      final cycle = currentCycle(card(statementDay: 15), DateTime(2026, 6, 10));
      expect(cycle.lastStatement, DateTime(2026, 5, 15));
      expect(cycle.nextStatement, DateTime(2026, 6, 15));
    });

    test('statement day itself still belongs to the closing cycle', () {
      final cycle = currentCycle(card(statementDay: 15), DateTime(2026, 6, 15));
      expect(cycle.lastStatement, DateTime(2026, 5, 15));
      expect(cycle.nextStatement, DateTime(2026, 6, 15));
      expect(cycle.daysUntilNextStatement(DateTime(2026, 6, 15)), 0);
    });

    test('year boundary', () {
      final cycle = currentCycle(card(statementDay: 25), DateTime(2026, 12, 28));
      expect(cycle.lastStatement, DateTime(2026, 12, 25));
      expect(cycle.nextStatement, DateTime(2027, 1, 25));
    });

    test('previousCycleStart is day after the statement before last', () {
      final cycle = currentCycle(card(statementDay: 15), DateTime(2026, 6, 20));
      expect(previousCycleStart(card(statementDay: 15), cycle),
          DateTime(2026, 5, 16));
    });
  });
}
