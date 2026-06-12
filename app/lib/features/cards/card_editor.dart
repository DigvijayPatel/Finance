import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mutations.dart';
import '../../models/credit_card.dart';

Future<void> showCardEditor(BuildContext context, {CreditCard? card}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _CardEditor(card: card),
    ),
  );
}

class _CardEditor extends ConsumerStatefulWidget {
  const _CardEditor({this.card});

  final CreditCard? card;

  @override
  ConsumerState<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends ConsumerState<_CardEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _last4;
  late final TextEditingController _limit;
  late int _statementDay;
  late int _graceDays;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _name = TextEditingController(text: c?.name ?? '');
    _last4 = TextEditingController(text: c?.last4 ?? '');
    _limit = TextEditingController(
        text: c?.creditLimit == null ? '' : c!.creditLimit!.toInt().toString());
    _statementDay = c?.statementDay ?? 1;
    _graceDays = c?.graceDays ?? 18;
  }

  @override
  void dispose() {
    _name.dispose();
    _last4.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final limitText = _limit.text.trim();
      await ref.read(mutationsProvider).saveCard(
            id: widget.card?.id,
            name: _name.text.trim(),
            last4: _last4.text.trim(),
            creditLimit: limitText.isEmpty ? null : double.parse(limitText),
            statementDay: _statementDay,
            graceDays: _graceDays,
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this card?'),
        content: const Text('Expenses paid with it are kept, but unlinked.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(mutationsProvider).deleteCard(widget.card!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.card == null ? 'Add card' : 'Edit card',
                      style: theme.textTheme.titleLarge),
                ),
                if (widget.card != null)
                  IconButton(
                    tooltip: 'Delete card',
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    onPressed: _busy ? null : _delete,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Card name (e.g. HDFC Millennia)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _last4,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Last 4 digits',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _limit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Credit limit',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final parsed = double.tryParse(v.trim());
                      return (parsed == null || parsed <= 0)
                          ? 'Invalid amount'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _statementDay,
                    decoration: const InputDecoration(
                      labelText: 'Statement day',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) => setState(() => _statementDay = v ?? 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _graceDays,
                    decoration: const InputDecoration(
                      labelText: 'Due after (days)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var d = 10; d <= 30; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) => setState(() => _graceDays = v ?? 18),
                  ),
                ),
              ],
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
