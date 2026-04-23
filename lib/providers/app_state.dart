import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/account_model.dart';
import '../models/app_settings.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/transaction_entry.dart';
import '../services/cloud_ledger_service.dart';
import '../services/local_storage_service.dart';

class AppState extends ChangeNotifier {
  final CloudLedgerService _cloud = CloudLedgerService();
  final LocalStorageService _storage = LocalStorageService();
  final Uuid _uuid = const Uuid();

  List<TransactionEntry> transactions = [];
  List<CategoryModel> categories = [];
  List<BudgetModel> budgets = [];
  List<AccountModel> accounts = [];
  AppSettings settings = AppSettings.defaults();
  bool isUnlocked = false;

  ThemeMode get themeMode => settings.themeMode;
  Color get accentColor => settings.accentColor;
  String get currentMonthKey => DateFormat('yyyy-MM').format(DateTime.now());
  bool get cloudSyncEnabled => _cloud.isAvailable;
  bool get isCloudSessionActive => _cloud.currentUserId != null;

  Future<void> initialize() async {
    await _loadAll();
    if (_cloud.isAvailable) {
      await _initializeWithCloud();
    } else if (categories.isEmpty && accounts.isEmpty && transactions.isEmpty) {
      await _seedDefaults();
    }
    isUnlocked = !settings.passcodeEnabled;
  }

  Future<void> _initializeWithCloud() async {
    final connected = await _cloud.ensureSession();
    if (!connected) {
      if (categories.isEmpty && accounts.isEmpty && transactions.isEmpty) {
        await _seedDefaults();
      }
      return;
    }

    final snapshot = await _cloud.readSnapshot();
    if (snapshot != null && snapshot.isNotEmpty) {
      _applySnapshot(snapshot);
      await _persistAll(skipCloud: true);
      return;
    }

    if (categories.isEmpty && accounts.isEmpty && transactions.isEmpty) {
      accounts = _defaultAccounts();
      categories = _defaultCategories();
      budgets = [];
      transactions = [];
      settings = AppSettings.defaults();
    }

    await _persistAll();
  }

  Future<void> _loadAll() async {
    transactions = (await _storage.readList(LocalStorageService.transactionsKey))
        .map(TransactionEntry.fromMap)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    categories = (await _storage.readList(LocalStorageService.categoriesKey))
        .map(CategoryModel.fromMap)
        .toList();
    budgets = (await _storage.readList(LocalStorageService.budgetsKey))
        .map(BudgetModel.fromMap)
        .toList();
    accounts = (await _storage.readList(LocalStorageService.accountsKey))
        .map(AccountModel.fromMap)
        .toList();
    final storedSettings = await _storage.readMap(LocalStorageService.settingsKey);
    settings = storedSettings == null ? AppSettings.defaults() : AppSettings.fromMap(storedSettings);
  }

  List<AccountModel> _defaultAccounts() => [
        AccountModel(id: 'wallet', name: 'Wallet', icon: '👛'),
        AccountModel(id: 'card', name: 'Card', icon: '💳'),
        AccountModel(id: 'bank', name: 'Bank', icon: '🏦'),
      ];

  List<CategoryModel> _defaultCategories() => [
        CategoryModel(id: 'salary', name: 'Salary', type: 'income', icon: '💼', colorValue: 0xFF34D399),
        CategoryModel(id: 'freelance', name: 'Freelance', type: 'income', icon: '🧾', colorValue: 0xFF10B981),
        CategoryModel(id: 'gift', name: 'Gift', type: 'income', icon: '🎁', colorValue: 0xFF22C55E),
        CategoryModel(id: 'food', name: 'Food', type: 'expense', icon: '🍔', colorValue: 0xFFF97316),
        CategoryModel(id: 'bills', name: 'Bills', type: 'expense', icon: '💡', colorValue: 0xFFEF4444),
        CategoryModel(id: 'shopping', name: 'Shopping', type: 'expense', icon: '🛍️', colorValue: 0xFF8B5CF6),
        CategoryModel(id: 'travel', name: 'Travel', type: 'expense', icon: '✈️', colorValue: 0xFF06B6D4),
        CategoryModel(id: 'health', name: 'Health', type: 'expense', icon: '🩺', colorValue: 0xFF14B8A6),
      ];

  Future<void> _seedDefaults() async {
    accounts = _defaultAccounts();
    categories = _defaultCategories();
    budgets = [];
    transactions = [];
    await _persistAll();
  }

  Future<void> _persistAll({bool skipCloud = false}) async {
    await _storage.writeList(
      LocalStorageService.transactionsKey,
      transactions.map((e) => e.toMap()).toList(),
    );
    await _storage.writeList(
      LocalStorageService.categoriesKey,
      categories.map((e) => e.toMap()).toList(),
    );
    await _storage.writeList(
      LocalStorageService.budgetsKey,
      budgets.map((e) => e.toMap()).toList(),
    );
    await _storage.writeList(
      LocalStorageService.accountsKey,
      accounts.map((e) => e.toMap()).toList(),
    );
    await _storage.writeMap(LocalStorageService.settingsKey, settings.toMap());

    if (skipCloud || !_cloud.isAvailable) return;

    try {
      final connected = await _cloud.ensureSession();
      if (!connected) return;
      await _cloud.saveSnapshot(_snapshotMap());
    } catch (_) {
      // Keep the local cache as the source of truth when cloud sync is unavailable.
    }
  }

  Map<String, dynamic> _snapshotMap() => {
        'transactions': transactions.map((e) => e.toMap()).toList(),
        'categories': categories.map((e) => e.toMap()).toList(),
        'budgets': budgets.map((e) => e.toMap()).toList(),
        'accounts': accounts.map((e) => e.toMap()).toList(),
        'settings': settings.toMap(),
      };

  void _applySnapshot(Map<String, dynamic> snapshot) {
    transactions = _mapList(snapshot['transactions'])
        .map(TransactionEntry.fromMap)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    categories = _mapList(snapshot['categories']).map(CategoryModel.fromMap).toList();
    budgets = _mapList(snapshot['budgets']).map(BudgetModel.fromMap).toList();
    accounts = _mapList(snapshot['accounts']).map(AccountModel.fromMap).toList();

    final storedSettings = snapshot['settings'];
    settings = storedSettings is Map
        ? AppSettings.fromMap(Map<String, dynamic>.from(storedSettings))
        : AppSettings.defaults();
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<TransactionEntry> transactionsForMonth(DateTime month) {
    return transactions.where((tx) => tx.date.year == month.year && tx.date.month == month.month).toList();
  }

  double totalIncomeForMonth(DateTime month) => transactionsForMonth(month)
      .where((tx) => tx.type == TransactionType.income)
      .fold(0, (sum, tx) => sum + tx.amount);

  double totalExpenseForMonth(DateTime month) => transactionsForMonth(month)
      .where((tx) => tx.type == TransactionType.expense)
      .fold(0, (sum, tx) => sum + tx.amount);

  double totalBalance() {
    double income = 0;
    double expense = 0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.income) income += tx.amount;
      if (tx.type == TransactionType.expense) expense += tx.amount;
    }
    return income - expense;
  }

  CategoryModel? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  AccountModel? accountById(String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Future<void> addOrUpdateTransaction(TransactionEntry transaction) async {
    final index = transactions.indexWhere((item) => item.id == transaction.id);
    if (index == -1) {
      transactions.add(transaction);
    } else {
      transactions[index] = transaction;
    }
    transactions.sort((a, b) => b.date.compareTo(a.date));
    await _persistAll();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    transactions.removeWhere((item) => item.id == id);
    await _persistAll();
    notifyListeners();
  }

  Future<void> clearTransactions() async {
    transactions = [];
    await _persistAll();
    notifyListeners();
  }

  Future<void> saveCategory(CategoryModel category) async {
    final index = categories.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      categories.add(category);
    } else {
      categories[index] = category;
    }
    await _persistAll();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    categories.removeWhere((item) => item.id == id);
    budgets.removeWhere((item) => item.categoryId == id);
    transactions.removeWhere((item) => item.type != TransactionType.transfer && item.categoryId == id);
    await _persistAll();
    notifyListeners();
  }

  Future<void> resetCategoriesToDefault() async {
    categories = _defaultCategories();
    final allowedIds = categories.map((item) => item.id).toSet();
    budgets.removeWhere((item) => !allowedIds.contains(item.categoryId));
    transactions.removeWhere(
      (item) => item.type != TransactionType.transfer && !allowedIds.contains(item.categoryId),
    );
    await _persistAll();
    notifyListeners();
  }

  Future<void> saveAccount(AccountModel account) async {
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      accounts.add(account);
    } else {
      accounts[index] = account;
    }
    await _persistAll();
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    accounts.removeWhere((item) => item.id == id);
    transactions.removeWhere(
      (item) => item.accountId == id || item.transferAccountId == id,
    );
    await _persistAll();
    notifyListeners();
  }

  Future<void> resetAccountsToDefault() async {
    accounts = _defaultAccounts();
    final allowedIds = accounts.map((item) => item.id).toSet();
    transactions.removeWhere(
      (item) => !allowedIds.contains(item.accountId) ||
          (item.transferAccountId != null && !allowedIds.contains(item.transferAccountId!)),
    );
    await _persistAll();
    notifyListeners();
  }

  Future<void> saveBudget(BudgetModel budget) async {
    final index = budgets.indexWhere(
      (item) => item.categoryId == budget.categoryId && item.month == budget.month,
    );
    if (index == -1) {
      budgets.add(budget);
    } else {
      budgets[index] = budget;
    }
    await _persistAll();
    notifyListeners();
  }

  Future<void> deleteBudget(String categoryId, String month) async {
    budgets.removeWhere((item) => item.categoryId == categoryId && item.month == month);
    await _persistAll();
    notifyListeners();
  }

  Future<void> clearBudgets() async {
    budgets = [];
    await _persistAll();
    notifyListeners();
  }

  Future<void> resetAllData() async {
    await _storage.clearManagedData();
    accounts = _defaultAccounts();
    categories = _defaultCategories();
    budgets = [];
    transactions = [];
    settings = AppSettings.defaults();
    isUnlocked = true;
    await _persistAll();
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    settings = settings.copyWith(themeMode: mode);
    await _persistAll();
    notifyListeners();
  }

  Future<void> updateAccentColor(Color color) async {
    settings = settings.copyWith(accentColorValue: color.value);
    await _persistAll();
    notifyListeners();
  }

  Future<void> setPasscode(String passcode) async {
    settings = settings.copyWith(
      passcodeEnabled: true,
      passcodeHash: sha256.convert(utf8.encode(passcode)).toString(),
    );
    isUnlocked = true;
    await _persistAll();
    notifyListeners();
  }

  Future<void> disablePasscode() async {
    settings = settings.copyWith(passcodeEnabled: false, passcodeHash: '');
    isUnlocked = true;
    await _persistAll();
    notifyListeners();
  }

  void lockApp() {
    if (!settings.passcodeEnabled || !isUnlocked) return;
    isUnlocked = false;
    notifyListeners();
  }

  bool unlock(String passcode) {
    final candidate = sha256.convert(utf8.encode(passcode)).toString();
    final ok = candidate == settings.passcodeHash;
    isUnlocked = ok;
    notifyListeners();
    return ok;
  }

  void unlockWithBiometric() {
    if (!settings.passcodeEnabled) return;
    isUnlocked = true;
    notifyListeners();
  }

  Map<CategoryModel, double> expenseBreakdown(DateTime month) {
    final Map<CategoryModel, double> result = {};
    for (final tx in transactionsForMonth(month).where((tx) => tx.type == TransactionType.expense)) {
      final category = categoryById(tx.categoryId);
      if (category == null) continue;
      result.update(category, (value) => value + tx.amount, ifAbsent: () => tx.amount);
    }
    return result;
  }

  double spentForCategoryMonth(String categoryId, String month) {
    return transactions
        .where((tx) => tx.type == TransactionType.expense)
        .where((tx) => tx.categoryId == categoryId)
        .where((tx) => DateFormat('yyyy-MM').format(tx.date) == month)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  double accountBalance(String accountId) {
    double total = 0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense && tx.accountId == accountId) {
        total -= tx.amount;
      }
      if (tx.type == TransactionType.income && tx.accountId == accountId) {
        total += tx.amount;
      }
      if (tx.type == TransactionType.transfer) {
        if (tx.accountId == accountId) total -= tx.amount;
        if (tx.transferAccountId == accountId) total += tx.amount;
      }
    }
    return total;
  }

  String newId() => _uuid.v4();
}
