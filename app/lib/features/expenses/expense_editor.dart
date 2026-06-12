import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/mutations.dart';
import '../../data/streams.dart';
import '../../models/expense.dart';

Future<void> showExpenseEditor(BuildContext context, {Expense? expense}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ExpenseEditor(expense: expense),
    ),
  );
}

class _ExpenseEditor extends ConsumerStatefulWidget {
  const _ExpenseEditor({this.expense});

  final Expense? expense;

  @override
  ConsumerState<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<_ExpenseEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  String? _categoryId;
  String? _cardId;
  late String _method;
  late DateTime _spentAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amount = TextEditingController(
        text: e == null
            ? ''
            : (e.amount == e.amount.roundToDouble()
                ? e.amount.toInt().toString()
                : e.amount.toString()));
    _note = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId;
    _cardId = e?.cardId;
    _method = e?.paymentMethod ?? 'upi';
    _spentAt = e?.spentAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(mutationsProvider).saveExpense(
            id: widget.expense?.id,
            amount: double.parse(_amount.text.trim()),
            categoryId: _categoryId,
            cardId: _cardId,
            paymentMethod: _method,
            spentAt: _spentAt,
            note: _note.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final cards = ref.watch(cardsProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.expense == null ? 'Add expense' : 'Edit expense',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: widget.expense == null,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null || parsed <= 0) return 'Enter an amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: categories.any((c) => c.id == _categoryId)
                  ? _categoryId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Pick a category' : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                for (final m in paymentMethods)
                  ButtonSegment(value: m, label: Text(paymentMethodLabel(m))),
              ],
              selected: {_method},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _method = selection.first),
            ),
            if (_method == 'card') ...[
              const SizedBox(height: 12),
              if (cards.isEmpty)
                Text('Add a credit card on the Cards tab to link it here.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline))
              else
                DropdownButtonFormField<String>(
                  value: cards.any((c) => c.id == _cardId) ? _cardId : null,
                  decoration: const InputDecoration(
                    labelText: 'Card',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in cards)
                      DropdownMenuItem(
                          value: c.id,
                          child: Text(c.last4.isEmpty
                              ? c.name
                              : '${c.name} ·· ${c.last4}')),
                  ],
                  onChanged: (v) => setState(() => _cardId = v),
                  validator: (v) =>
                      _method == 'card' && v == null ? 'Pick a card' : null,
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(formatFullDate(_spentAt)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _spentAt,
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _spentAt = picked);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
