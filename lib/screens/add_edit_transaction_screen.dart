import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction_entry.dart';
import '../providers/app_state.dart';

class AddEditTransactionScreen extends StatefulWidget {
  const AddEditTransactionScreen({super.key, this.transaction});

  final TransactionEntry? transaction;

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  late TransactionType type;
  late TextEditingController amountController;
  late TextEditingController noteController;
  DateTime selectedDate = DateTime.now();
  String? selectedCategoryId;
  String? selectedAccountId;
  String? selectedTransferAccountId;
  String? validationMessage;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    type = tx?.type ?? TransactionType.expense;
    amountController = TextEditingController(text: tx?.amount.toStringAsFixed(0) ?? '');
    noteController = TextEditingController(text: tx?.note ?? '');
    selectedDate = tx?.date ?? DateTime.now();
    selectedCategoryId = tx?.categoryId == 'transfer' ? null : tx?.categoryId;
    selectedAccountId = tx?.accountId;
    selectedTransferAccountId = tx?.transferAccountId;
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final needsCategory = type != TransactionType.transfer;
    final categories = needsCategory
        ? appState.categories.where((item) => item.type == type.name).toList()
        : const [];

    selectedAccountId ??= appState.accounts.isNotEmpty ? appState.accounts.first.id : null;

    if (needsCategory) {
      if (categories.isNotEmpty && !categories.any((item) => item.id == selectedCategoryId)) {
        selectedCategoryId = categories.first.id;
      }
    } else {
      selectedCategoryId = null;
      final destinationAccounts = appState.accounts.where((item) => item.id != selectedAccountId).toList();
      if (destinationAccounts.isNotEmpty && !destinationAccounts.any((item) => item.id == selectedTransferAccountId)) {
        selectedTransferAccountId = destinationAccounts.first.id;
      }
      if (destinationAccounts.isEmpty) {
        selectedTransferAccountId = null;
      }
    }

    final destinationAccounts = appState.accounts.where((item) => item.id != selectedAccountId).toList();
    final typeTitle = {
      TransactionType.expense: 'Expense entry',
      TransactionType.income: 'Income entry',
      TransactionType.transfer: 'Transfer money',
    }[type]!;
    final typeSubtitle = {
      TransactionType.expense: 'Track spending quickly with better context.',
      TransactionType.income: 'Record money coming in and keep your balance current.',
      TransactionType.transfer: 'Move money between accounts without changing total balance.',
    }[type]!;
    final typeIcon = {
      TransactionType.expense: Icons.arrow_upward_rounded,
      TransactionType.income: Icons.arrow_downward_rounded,
      TransactionType.transfer: Icons.swap_horiz_rounded,
    }[type]!;
    final typeColor = {
      TransactionType.expense: Colors.redAccent,
      TransactionType.income: Colors.green,
      TransactionType.transfer: Theme.of(context).colorScheme.primary,
    }[type]!;
    final saveLabel = widget.transaction == null ? 'Save entry' : 'Update entry';

    return Scaffold(
      appBar: AppBar(title: Text(widget.transaction == null ? 'Add entry' : 'Edit entry')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: typeColor.withOpacity(0.14),
                    child: Icon(typeIcon, color: typeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(typeTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(typeSubtitle, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                      ButtonSegment(value: TransactionType.income, label: Text('Income')),
                      ButtonSegment(value: TransactionType.transfer, label: Text('Transfer')),
                    ],
                    selected: {type},
                    onSelectionChanged: (selection) => setState(() {
                      type = selection.first;
                      validationMessage = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: type == TransactionType.transfer ? 'Amount to move' : 'Amount'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation);
              return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
            },
            child: Card(
              key: ValueKey(type.name),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    if (needsCategory) ...[
                      DropdownButtonFormField<String>(
                        value: selectedCategoryId,
                        items: categories
                            .map((category) => DropdownMenuItem<String>(
                                  value: category.id,
                                  child: Text('${category.icon} ${category.name}'),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => selectedCategoryId = value),
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    DropdownButtonFormField<String>(
                      value: selectedAccountId,
                      items: appState.accounts
                          .map((account) => DropdownMenuItem<String>(
                                value: account.id,
                                child: Text('${account.icon} ${account.name}'),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() {
                        selectedAccountId = value;
                        validationMessage = null;
                      }),
                      decoration: InputDecoration(labelText: type == TransactionType.transfer ? 'From account' : 'Account / Payment mode'),
                    ),
                    if (type == TransactionType.transfer) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedTransferAccountId,
                        items: destinationAccounts
                            .map((account) => DropdownMenuItem<String>(
                                  value: account.id,
                                  child: Text('${account.icon} ${account.name}'),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() {
                          selectedTransferAccountId = value;
                          validationMessage = null;
                        }),
                        decoration: const InputDecoration(labelText: 'To account'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Transfers keep your total balance unchanged while moving money between accounts.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date & time'),
                    subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_month_rounded),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate == null || !mounted) return;
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (pickedTime == null) return;
                      setState(() {
                        selectedDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          if (validationMessage != null) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      validationMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0 || selectedAccountId == null) {
                setState(() => validationMessage = 'Enter a valid amount and account.');
                return;
              }

              if (type == TransactionType.transfer) {
                if (selectedTransferAccountId == null) {
                  setState(() => validationMessage = 'Add at least two accounts to use transfers.');
                  return;
                }
                if (selectedTransferAccountId == selectedAccountId) {
                  setState(() => validationMessage = 'Source and destination accounts must be different.');
                  return;
                }
              } else if (selectedCategoryId == null) {
                setState(() => validationMessage = 'Choose a category first.');
                return;
              }

              final tx = TransactionEntry(
                id: widget.transaction?.id ?? appState.newId(),
                type: type,
                amount: amount,
                categoryId: type == TransactionType.transfer ? 'transfer' : selectedCategoryId!,
                accountId: selectedAccountId!,
                transferAccountId: type == TransactionType.transfer ? selectedTransferAccountId : null,
                note: noteController.text.trim(),
                date: selectedDate,
              );
              await appState.addOrUpdateTransaction(tx);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(saveLabel),
          ),
        ],
      ),
    );
  }
}
