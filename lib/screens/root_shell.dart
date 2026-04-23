import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account_model.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/transaction_entry.dart';
import '../providers/app_state.dart';
import 'add_edit_transaction_screen.dart';
import 'lock_screen.dart';

enum ShellTab { home, insights, budgets, manage }
enum ManageSection { accounts, categories, settings, data }

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  ShellTab currentTab = ShellTab.home;
  ManageSection manageSection = ManageSection.accounts;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool showIntroOverlay = true;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playIntro();
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _playIntro() {
    _introTimer?.cancel();
    setState(() => showIntroOverlay = true);
    _introTimer = Timer(const Duration(milliseconds: 1450), () {
      if (mounted) setState(() => showIntroOverlay = false);
    });
  }

  void _switchToTab(ShellTab tab, {ManageSection? section}) {
    setState(() {
      currentTab = tab;
      if (section != null) {
        manageSection = section;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!mounted) return;
      context.read<AppState>().lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.settings.passcodeEnabled && !state.isUnlocked) {
      return const LockScreen();
    }

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_titleForTab()),
                Text(
                  _subtitleForTab(state),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                      ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('${currentTab.name}-${manageSection.name}-${selectedMonth.toIso8601String()}'),
                child: _screenForCurrentTab(state),
              ),
            ),
          ),
          floatingActionButton: currentTab == ShellTab.home
              ? FloatingActionButton.extended(
                  heroTag: 'add_transaction',
                  onPressed: () => _openTransactionEditor(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add entry'),
                )
              : null,
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                height: 74,
                selectedIndex: currentTab.index,
                onDestinationSelected: (value) => setState(() => currentTab = ShellTab.values[value]),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.pie_chart_rounded), label: 'Insights'),
                  NavigationDestination(icon: Icon(Icons.savings_rounded), label: 'Budgets'),
                  NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Manage'),
                ],
              ),
            ),
          ),
        ),
        IgnorePointer(
          ignoring: !showIntroOverlay,
          child: AnimatedOpacity(
            opacity: showIntroOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            child: _introOverlay(),
          ),
        ),
      ],
    );
  }

  String _titleForTab() {
    switch (currentTab) {
      case ShellTab.home:
        return 'Money King';
      case ShellTab.insights:
        return 'Insights';
      case ShellTab.budgets:
        return 'Budgets';
      case ShellTab.manage:
        return 'Manage';
    }
  }

  String _subtitleForTab(AppState state) {
    switch (currentTab) {
      case ShellTab.home:
        return 'Track money with fewer taps';
      case ShellTab.insights:
        return DateFormat('MMMM yyyy').format(selectedMonth);
      case ShellTab.budgets:
        return '${state.budgets.length} budget rules active';
      case ShellTab.manage:
        return 'Accounts, categories, settings, and reset tools';
    }
  }

  Widget _screenForCurrentTab(AppState state) {
    switch (currentTab) {
      case ShellTab.home:
        return _homeScreen(state);
      case ShellTab.insights:
        return _analysisScreen(state);
      case ShellTab.budgets:
        return _budgetScreen(state);
      case ShellTab.manage:
        return _manageScreen(state);
    }
  }

  Widget _homeScreen(AppState state) {
    final monthTransactions = state.transactionsForMonth(selectedMonth);
    final grouped = <String, List<TransactionEntry>>{};
    for (final tx in monthTransactions) {
      final key = DateFormat('dd MMM yyyy').format(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _reveal(index: 0, child: _welcomePanel(state)),
        const SizedBox(height: 16),
        _reveal(index: 1, child: _portfolioDeck(state)),
        const SizedBox(height: 16),
        _reveal(index: 2, child: _moneyFlowPanel(state)),
        const SizedBox(height: 16),
        _reveal(index: 3, child: _quickActionStrip(state)),
        const SizedBox(height: 16),
        _reveal(index: 4, child: _monthSelector()),
        const SizedBox(height: 18),
        _reveal(index: 5, child: _summaryCards(state)),
        const SizedBox(height: 18),
        _sectionHeader(
          title: 'Recent activity',
          subtitle: '${monthTransactions.length} entries in ${DateFormat('MMMM').format(selectedMonth)}',
        ),
        const SizedBox(height: 12),
        if (grouped.isEmpty)
          _reveal(
            index: 6,
            child: _emptyState(
              title: 'No transactions yet',
              message: 'Tap “Add entry” and your records will start appearing here.',
              icon: Icons.receipt_long_rounded,
            ),
          )
        else
          ...grouped.entries.toList().asMap().entries.map(
                (groupEntry) => _reveal(
                  index: 6 + groupEntry.key,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            groupEntry.value.key,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        ...groupEntry.value.value.map((tx) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _transactionTile(state, tx),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _welcomePanel(AppState state) {
    final monthlyBalance = state.totalIncomeForMonth(selectedMonth) - state.totalExpenseForMonth(selectedMonth);
    final syncLabel = state.cloudSyncEnabled
        ? (state.isCloudSessionActive ? 'Cloud sync live' : 'Cloud ready')
        : 'Local-first mode';
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive = monthlyBalance >= 0;
    final monthLabel = DateFormat('MMMM').format(selectedMonth);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF08121D),
            Color(0xFF0E1A2A),
            Color(0xFF09111B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _showcasePill('MONEY KING', icon: Icons.diamond_outlined),
                const Spacer(),
                _showcasePill(
                  syncLabel,
                  icon: state.isCloudSessionActive ? Icons.cloud_done_rounded : Icons.lock_outline_rounded,
                  subtle: true,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'A cleaner, premium view of your money.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay on top of $monthLabel with faster actions, tighter control, and a sharper dashboard.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.62),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 22),
            Text(
              'Net worth',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withOpacity(0.68),
                    letterSpacing: 0.3,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _money(state.totalBalance()),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _showcasePill(
                  '${isPositive ? '+' : ''}${_money(monthlyBalance)} this month',
                  icon: isPositive ? Icons.north_east_rounded : Icons.south_east_rounded,
                  subtle: true,
                ),
                _showcasePill(
                  '${state.transactionsForMonth(selectedMonth).length} entries',
                  icon: Icons.receipt_long_rounded,
                  subtle: true,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _showcaseMetric(
                    'Income',
                    _money(state.totalIncomeForMonth(selectedMonth)),
                    tone: const Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _showcaseMetric(
                    'Expense',
                    _money(state.totalExpenseForMonth(selectedMonth)),
                    tone: const Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _showcaseMetric(
                    'Accounts',
                    state.accounts.length.toString(),
                    tone: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0C1521),
                    ),
                    onPressed: () => _openTransactionEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Quick add'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    ),
                    onPressed: () => _switchToTab(ShellTab.insights),
                    icon: const Icon(Icons.insights_rounded),
                    label: const Text('Open insights'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _portfolioDeck(AppState state) {
    final accounts = [...state.accounts]
      ..sort((a, b) => state.accountBalance(b.id).compareTo(state.accountBalance(a.id)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Portfolio view',
          subtitle: 'Your top balances in one premium glance',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 146,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 188,
              child: _accountPreviewCard(
                account: accounts[index],
                balance: state.accountBalance(accounts[index].id),
                accentIndex: index,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountPreviewCard({
    required AccountModel account,
    required double balance,
    required int accentIndex,
  }) {
    const gradients = [
      [Color(0xFF131C2B), Color(0xFF1B2940)],
      [Color(0xFF10261F), Color(0xFF16372D)],
      [Color(0xFF281A1B), Color(0xFF382224)],
      [Color(0xFF18172A), Color(0xFF24203B)],
    ];
    final colors = gradients[accentIndex % gradients.length];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.10),
                ),
                child: Center(
                  child: Text(account.icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const Spacer(),
              Icon(Icons.more_horiz_rounded, color: Colors.white.withOpacity(0.55)),
            ],
          ),
          const Spacer(),
          Text(
            account.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(balance),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Available balance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.58),
                ),
          ),
        ],
      ),
    );
  }

  Widget _moneyFlowPanel(AppState state) {
    final income = state.totalIncomeForMonth(selectedMonth);
    final expense = state.totalExpenseForMonth(selectedMonth);
    final totalFlow = (income + expense) <= 0 ? 1.0 : (income + expense);
    final incomeRatio = income / totalFlow;
    final expenseRatio = expense / totalFlow;
    final monthKey = DateFormat('yyyy-MM').format(selectedMonth);
    final monthBudgets = state.budgets.where((item) => item.month == monthKey).toList();
    final totalBudget = monthBudgets.fold<double>(0, (sum, item) => sum + item.limit);
    final totalSpent = monthBudgets.fold<double>(0, (sum, item) => sum + state.spentForCategoryMonth(item.categoryId, item.month));
    final budgetRatio = totalBudget == 0 ? 0.0 : (totalSpent / totalBudget).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money flow',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track how cash is moving this month',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                ),
                child: Text(
                  DateFormat('MMM').format(selectedMonth).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _flowMetric(
            label: 'Income runway',
            value: _money(income),
            ratio: incomeRatio,
            color: const Color(0xFF22C55E),
          ),
          const SizedBox(height: 14),
          _flowMetric(
            label: 'Expense burn',
            value: _money(expense),
            ratio: expenseRatio,
            color: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 14),
          _flowMetric(
            label: 'Budget usage',
            value: totalBudget == 0 ? 'No budget set' : '${_money(totalSpent)} / ${_money(totalBudget)}',
            ratio: budgetRatio,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _flowMetric({
    required String label,
    required String value,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: ratio.clamp(0.0, 1.0).toDouble(),
            color: color,
            backgroundColor: color.withOpacity(0.10),
          ),
        ),
      ],
    );
  }

  Widget _quickActionStrip(AppState state) {
    final actions = <({IconData icon, String title, String subtitle, VoidCallback onTap})>[
      (
        icon: Icons.add_circle_outline_rounded,
        title: 'Add entry',
        subtitle: 'Income, expense, or transfer',
        onTap: () => _openTransactionEditor(),
      ),
      (
        icon: Icons.pie_chart_rounded,
        title: 'Insights',
        subtitle: 'See where money went',
        onTap: () => _switchToTab(ShellTab.insights),
      ),
      (
        icon: Icons.savings_rounded,
        title: 'Budgets',
        subtitle: state.budgets.isEmpty ? 'Create your first limit' : '${state.budgets.length} active rules',
        onTap: () => _switchToTab(ShellTab.budgets),
      ),
      (
        icon: Icons.inventory_2_rounded,
        title: 'Data tools',
        subtitle: 'Accounts, categories, reset',
        onTap: () => _switchToTab(ShellTab.manage, section: ManageSection.data),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Quick actions',
          subtitle: 'Everything important is one tap away now',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 460 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: width,
                      child: _actionTile(
                        icon: action.icon,
                        title: action.title,
                        subtitle: action.subtitle,
                        onTap: action.onTap,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.12),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primary.withOpacity(0.10)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: colorScheme.primary.withOpacity(0.14),
                      ),
                      child: Icon(icon, color: colorScheme.primary),
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withOpacity(0.10),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _showcasePill(String label, {IconData? icon, bool subtle = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: subtle ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white.withOpacity(0.82)),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.82),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _showcaseMetric(String label, String value, {required Color tone}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.58),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  Widget _reveal({required int index, required Widget child}) {
    final step = index.clamp(0, 6).toInt();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (step * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _analysisScreen(AppState state) {
    final breakdown = state.expenseBreakdown(selectedMonth);
    final total = breakdown.values.fold<double>(0, (sum, value) => sum + value);
    final entries = breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _heroPanel(
          title: 'Expense insights',
          value: _money(state.totalExpenseForMonth(selectedMonth)),
          subtitle: 'Where your money went this month',
          icon: Icons.insights_rounded,
        ),
        const SizedBox(height: 16),
        _monthSelector(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              height: 280,
              child: total == 0
                  ? _emptyState(
                      title: 'No expense data yet',
                      message: 'Add a few expenses to unlock category analytics.',
                      icon: Icons.pie_chart_outline_rounded,
                    )
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 70,
                        sections: entries
                            .map(
                              (entry) => PieChartSectionData(
                                value: entry.value,
                                title: '${((entry.value / total) * 100).round()}%',
                                color: Color(entry.key.colorValue),
                                radius: 86,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader(
          title: 'Category breakdown',
          subtitle: total == 0 ? 'No categories to show' : '${entries.length} categories active',
        ),
        const SizedBox(height: 12),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(entry.key.colorValue),
                  child: Text(entry.key.icon),
                ),
                title: Text(entry.key.name),
                subtitle: Text('${((entry.value / total) * 100).toStringAsFixed(1)}% of monthly expenses'),
                trailing: Text(
                  _money(entry.value),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _budgetScreen(AppState state) {
    final monthKey = DateFormat('yyyy-MM').format(selectedMonth);
    final monthBudgets = state.budgets.where((item) => item.month == monthKey).toList();
    final totalBudget = monthBudgets.fold<double>(0, (sum, item) => sum + item.limit);
    final totalSpent = monthBudgets.fold<double>(0, (sum, item) => sum + state.spentForCategoryMonth(item.categoryId, item.month));
    final remaining = (totalBudget - totalSpent).clamp(0, double.infinity).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _heroPanel(
          title: 'Monthly budget',
          value: _money(totalBudget),
          subtitle: '${_money(remaining)} remaining this month',
          icon: Icons.savings_rounded,
        ),
        const SizedBox(height: 16),
        _monthSelector(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text('${_money(totalSpent)} spent of ${_money(totalBudget)}'),
                const SizedBox(height: 12),
                  LinearProgressIndicator(
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(999),
                  value: totalBudget == 0 ? 0 : (totalSpent / totalBudget).clamp(0, 1).toDouble(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader(
          title: 'Budget rules',
          subtitle: monthBudgets.isEmpty ? 'No budgets set yet' : '${monthBudgets.length} active rules',
        ),
        const SizedBox(height: 12),
        if (monthBudgets.isEmpty)
          _emptyState(
            title: 'No budgets for this month',
            message: 'Create category budgets to track how much is left.',
            icon: Icons.savings_outlined,
          )
        else
          ...monthBudgets.map((budget) {
            final category = state.categoryById(budget.categoryId);
            if (category == null) return const SizedBox.shrink();
            final spent = state.spentForCategoryMonth(budget.categoryId, budget.month);
            final ratio = budget.limit == 0 ? 0.0 : spent / budget.limit;
            final color = ratio >= 1 ? Colors.red : ratio >= 0.8 ? Colors.amber : Colors.green;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(backgroundColor: Color(category.colorValue), child: Text(category.icon)),
                  title: Text(category.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('${_money(spent)} / ${_money(budget.limit)}'),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                        value: ratio.clamp(0.0, 1.0).toDouble(),
                        color: color,
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showBudgetDialog(state, budget: budget);
                      } else {
                        await state.deleteBudget(budget.categoryId, budget.month);
                        _showSnack('Budget removed');
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showBudgetDialog(state),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Set monthly budget'),
        ),
      ],
    );
  }

  Widget _manageScreen(AppState state) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _heroPanel(
          title: 'Control center',
          value: '${state.accounts.length} accounts • ${state.categories.length} categories',
          subtitle: 'Cleaner controls with less clutter at the bottom',
          icon: Icons.tune_rounded,
        ),
        const SizedBox(height: 16),
        _manageSectionTabs(state),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(begin: const Offset(0.02, 0.04), end: Offset.zero).animate(animation);
            return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
          },
          child: KeyedSubtree(
            key: ValueKey(manageSection.name),
            child: _manageSectionBody(state),
          ),
        ),
      ],
    );
  }

  String _manageSectionLabel(ManageSection section) {
    switch (section) {
      case ManageSection.accounts:
        return 'Accounts';
      case ManageSection.categories:
        return 'Categories';
      case ManageSection.settings:
        return 'Settings';
      case ManageSection.data:
        return 'Data';
    }
  }

  Widget _manageSectionTabs(AppState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 460 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ManageSection.values
              .map(
                (section) => SizedBox(
                  width: width,
                  child: _manageSectionCard(
                    section: section,
                    value: _manageSectionValue(state, section),
                    subtitle: _manageSectionDescription(section),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _manageSectionCard({
    required ManageSection section,
    required String value,
    required String subtitle,
  }) {
    final selected = manageSection == section;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: selected
            ? LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.22),
                  colorScheme.primary.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Card(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() => manageSection = section),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primary.withOpacity(selected ? 0.18 : 0.10),
                  child: Icon(_manageSectionIcon(section), color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_manageSectionLabel(section), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selected ? colorScheme.primary : null,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _manageSectionIcon(ManageSection section) {
    switch (section) {
      case ManageSection.accounts:
        return Icons.account_balance_wallet_rounded;
      case ManageSection.categories:
        return Icons.category_rounded;
      case ManageSection.settings:
        return Icons.palette_rounded;
      case ManageSection.data:
        return Icons.cleaning_services_rounded;
    }
  }

  String _manageSectionValue(AppState state, ManageSection section) {
    switch (section) {
      case ManageSection.accounts:
        return state.accounts.length.toString();
      case ManageSection.categories:
        return state.categories.length.toString();
      case ManageSection.settings:
        return state.settings.passcodeEnabled ? 'On' : 'Off';
      case ManageSection.data:
        return state.transactions.length.toString();
    }
  }

  String _manageSectionDescription(ManageSection section) {
    switch (section) {
      case ManageSection.accounts:
        return 'Balances and payment sources';
      case ManageSection.categories:
        return 'Income and expense groups';
      case ManageSection.settings:
        return 'Theme, passcode, preferences';
      case ManageSection.data:
        return 'Cleanup, reset, and recovery';
    }
  }

  Widget _manageSectionBody(AppState state) {
    switch (manageSection) {
      case ManageSection.accounts:
        return _accountsSection(state);
      case ManageSection.categories:
        return _categoriesSection(state);
      case ManageSection.settings:
        return _settingsSection(state);
      case ManageSection.data:
        return _dataSection(state);
    }
  }

  Widget _accountsSection(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title: 'Accounts', subtitle: 'Track balances by source'),
        const SizedBox(height: 12),
        ...state.accounts.map(
          (account) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(account.icon)),
                title: Text(account.name),
                subtitle: const Text('Local account balance'),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _money(state.accountBalance(account.id)),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _showAccountDialog(state, account: account);
                        } else {
                          await _confirmAndRun(
                            title: 'Delete account?',
                            message: 'Transactions linked to ${account.name} will also be removed.',
                            confirmLabel: 'Delete',
                            onConfirm: () => state.deleteAccount(account.id),
                            successMessage: 'Account deleted',
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'delete',
                          enabled: state.accounts.length > 1,
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _showAccountDialog(state),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add account'),
        ),
      ],
    );
  }

  Widget _categoriesSection(AppState state) {
    final income = state.categories.where((item) => item.type == 'income').toList();
    final expense = state.categories.where((item) => item.type == 'expense').toList();

    Widget buildSection(String title, List<CategoryModel> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title: title, subtitle: '${items.length} items'),
          const SizedBox(height: 10),
          ...items.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Color(category.colorValue), child: Text(category.icon)),
                  title: Text(category.name),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showCategoryDialog(state, category: category);
                      } else {
                        await _confirmAndRun(
                          title: 'Delete category?',
                          message: 'Linked budgets and transactions for ${category.name} will be removed.',
                          confirmLabel: 'Delete',
                          onConfirm: () => state.deleteCategory(category.id),
                          successMessage: 'Category deleted',
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSection('Income categories', income),
        const SizedBox(height: 16),
        buildSection('Expense categories', expense),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _showCategoryDialog(state),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add category'),
        ),
      ],
    );
  }

  Widget _settingsSection(AppState state) {
    final accentChoices = [
      const Color(0xFF6C63FF),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF06B6D4),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {state.settings.themeMode},
                  onSelectionChanged: (value) => state.updateThemeMode(value.first),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: accentChoices
                      .map(
                        (color) => GestureDetector(
                          onTap: () => state.updateAccentColor(color),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: color,
                            child: state.accentColor.value == color.value
                                ? const Icon(Icons.check, size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: SwitchListTile(
            title: const Text('Passcode protection'),
            subtitle: Text(state.settings.passcodeEnabled ? 'Locks again when app goes to background' : 'Disabled'),
            value: state.settings.passcodeEnabled,
            onChanged: (value) async {
              if (value) {
                await _showPasscodeDialog(state);
                _showSnack('Passcode enabled');
              } else {
                await state.disablePasscode();
                _showSnack('Passcode disabled');
              }
            },
          ),
        ),
        const SizedBox(height: 14),
        _dashboardWidget(state),
      ],
    );
  }

  Widget _dataSection(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reset & cleanup', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Delete only what you want, or wipe everything and start fresh like a new install.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _countChip('Transactions', state.transactions.length.toString()),
                    _countChip('Budgets', state.budgets.length.toString()),
                    _countChip('Accounts', state.accounts.length.toString()),
                    _countChip('Categories', state.categories.length.toString()),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _dangerActionCard(
          icon: Icons.delete_sweep_rounded,
          title: 'Clear all transactions',
          subtitle: 'Budgets, categories, and accounts stay intact.',
          actionLabel: 'Clear transactions',
          onTap: () => _confirmAndRun(
            title: 'Clear all transactions?',
            message: 'This removes every income, expense, and transfer entry.',
            confirmLabel: 'Clear',
            onConfirm: state.clearTransactions,
            successMessage: 'All transactions cleared',
          ),
        ),
        const SizedBox(height: 12),
        _dangerActionCard(
          icon: Icons.layers_clear_rounded,
          title: 'Clear all budgets',
          subtitle: 'Category rules will be removed for every month.',
          actionLabel: 'Clear budgets',
          onTap: () => _confirmAndRun(
            title: 'Clear all budgets?',
            message: 'All budget limits will be deleted.',
            confirmLabel: 'Clear',
            onConfirm: state.clearBudgets,
            successMessage: 'Budgets cleared',
          ),
        ),
        const SizedBox(height: 12),
        _dangerActionCard(
          icon: Icons.restart_alt_rounded,
          title: 'Reset accounts to default',
          subtitle: 'Custom accounts and linked transactions will be removed.',
          actionLabel: 'Reset accounts',
          onTap: () => _confirmAndRun(
            title: 'Reset accounts?',
            message: 'Wallet, Card, and Bank will remain. Linked custom-account transactions will be removed.',
            confirmLabel: 'Reset',
            onConfirm: state.resetAccountsToDefault,
            successMessage: 'Accounts reset to default',
          ),
        ),
        const SizedBox(height: 12),
        _dangerActionCard(
          icon: Icons.category_outlined,
          title: 'Reset categories to default',
          subtitle: 'Custom categories and linked transactions/budgets will be removed.',
          actionLabel: 'Reset categories',
          onTap: () => _confirmAndRun(
            title: 'Reset categories?',
            message: 'Default categories will be restored and linked custom-category records removed.',
            confirmLabel: 'Reset',
            onConfirm: state.resetCategoriesToDefault,
            successMessage: 'Categories reset to default',
          ),
        ),
        const SizedBox(height: 12),
        _dangerActionCard(
          icon: Icons.warning_amber_rounded,
          title: 'Factory reset app',
          subtitle: 'Deletes all saved data and settings, then starts fresh.',
          actionLabel: 'Factory reset',
          isCritical: true,
          onTap: () => _confirmAndRun(
            title: 'Factory reset Money King?',
            message: 'Everything will be wiped: transactions, budgets, categories, accounts, theme, and passcode settings.',
            confirmLabel: 'Reset app',
            onConfirm: () async {
              await state.resetAllData();
              if (mounted) {
                setState(() {
                  currentTab = ShellTab.home;
                  manageSection = ManageSection.accounts;
                  selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
                });
                _playIntro();
              }
            },
            successMessage: 'App reset complete',
          ),
        ),
      ],
    );
  }

  Widget _heroPanel({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.18),
            colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: colorScheme.primary.withOpacity(0.14),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _monthNavButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1)),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  ),
                  child: Text(
                    DateFormat('MMMM yyyy').format(selectedMonth),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            _monthNavButton(
              icon: Icons.chevron_right_rounded,
              onTap: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthNavButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        ),
        child: Icon(icon),
      ),
    );
  }

  Widget _summaryCards(AppState state) {
    final items = <({String label, String value, Color color, IconData icon})>[
      (
        label: 'Income',
        value: _money(state.totalIncomeForMonth(selectedMonth)),
        color: Colors.green,
        icon: Icons.arrow_downward_rounded,
      ),
      (
        label: 'Expense',
        value: _money(state.totalExpenseForMonth(selectedMonth)),
        color: Colors.redAccent,
        icon: Icons.arrow_upward_rounded,
      ),
      (
        label: 'Balance',
        value: _money(state.totalIncomeForMonth(selectedMonth) - state.totalExpenseForMonth(selectedMonth)),
        color: Theme.of(context).colorScheme.primary,
        icon: Icons.account_balance_wallet_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 420 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        colors: [
                          item.color.withOpacity(0.14),
                          Theme.of(context).cardColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: item.color.withOpacity(0.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: item.color.withOpacity(0.14),
                              child: Icon(item.icon, color: item.color),
                            ),
                            const Spacer(),
                            Text(
                              item.label.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          item.value,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: item.color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Month snapshot',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _transactionTile(AppState state, TransactionEntry tx) {
    final category = state.categoryById(tx.categoryId);
    final account = state.accountById(tx.accountId);
    final transferAccount = tx.transferAccountId == null ? null : state.accountById(tx.transferAccountId!);
    final isTransfer = tx.type == TransactionType.transfer;
    final amountColor = isTransfer
        ? Theme.of(context).colorScheme.primary
        : tx.type == TransactionType.expense
            ? Colors.redAccent
            : Colors.green;

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete entry?'),
                content: const Text('This transaction will be removed permanently.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        state.deleteTransaction(tx.id);
        _showSnack('Transaction deleted');
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              amountColor.withOpacity(0.08),
              Theme.of(context).cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: amountColor.withOpacity(0.12)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openTransactionEditor(transaction: tx),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: isTransfer
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
                          : category == null
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.10)
                              : Color(category.colorValue).withOpacity(0.20),
                    ),
                    child: Center(
                      child: Text(
                        isTransfer ? '↔️' : category?.icon ?? '•',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTransfer ? 'Transfer' : category?.name ?? 'Unknown category',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          tx.note.isEmpty ? 'No note added' : tx.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _entryInfoChip(account?.name ?? 'Unknown'),
                            if (isTransfer) _entryInfoChip(transferAccount?.name ?? 'Unknown'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: amountColor.withOpacity(0.12),
                        ),
                        child: Text(
                          isTransfer ? _money(tx.amount) : '${tx.type == TransactionType.expense ? '-' : '+'}${_money(tx.amount)}',
                          style: TextStyle(color: amountColor, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        DateFormat('hh:mm a').format(tx.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _dashboardWidget(AppState state) {
    final latest = state.transactions.isEmpty ? null : state.transactions.first;
    final latestLabel = latest == null
        ? 'No transactions yet'
        : latest.type == TransactionType.transfer
            ? 'Transfer • ${_money(latest.amount)}'
            : '${state.categoryById(latest.categoryId)?.name ?? 'Unknown'} • ${_money(latest.amount)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick snapshot', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metricTile('Total balance', _money(state.totalBalance()))),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricTile(
                    'This month',
                    _money(state.totalIncomeForMonth(selectedMonth) - state.totalExpenseForMonth(selectedMonth)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _metricTile('Last transaction', latestLabel),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _emptyState({required String title, required String message, required IconData icon}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _countChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _dangerActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required Future<void> Function() onTap,
    bool isCritical = false,
  }) {
    final tone = isCritical ? Colors.red : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tone.withOpacity(0.12),
                  child: Icon(icon, color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = Color.lerp(colorScheme.primary, Colors.white, 0.18) ?? colorScheme.primary;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF09111C),
            Color(0xFF10192A),
            Color(0xFF0B1320),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -120, right: -70, child: _introGlow(colorScheme.primary.withOpacity(0.22))),
          Positioned(bottom: -150, left: -90, child: _introGlow(highlight.withOpacity(0.14))),
          SafeArea(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 820),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value.clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(scale: value, child: child),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Text(
                            'MONEY KING',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withOpacity(0.78),
                                  letterSpacing: 2.8,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          width: 94,
                          height: 94,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: LinearGradient(
                              colors: [
                                highlight,
                                colorScheme.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.32),
                                blurRadius: 34,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Money King',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Track. Control. Grow.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white.withOpacity(0.78),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A cleaner finance dashboard is loading for you.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.58),
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _introChip(Icons.lock_outline_rounded, 'Private'),
                            _introChip(Icons.cloud_done_rounded, 'Live sync'),
                            _introChip(Icons.flash_on_rounded, 'Fast start'),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.07)),
                          ),
                          child: Column(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 1050),
                                curve: Curves.easeOutCubic,
                                builder: (context, progress, _) => ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 7,
                                    valueColor: AlwaysStoppedAnimation<Color>(highlight),
                                    backgroundColor: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Preparing your dashboard',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.66),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _introGlow(Color color) {
    return IgnorePointer(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 120,
              spreadRadius: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _introChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.82)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.78),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  void _openTransactionEditor({TransactionEntry? transaction}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: AddEditTransactionScreen(transaction: transaction),
        ),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(animation);
          return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
        },
      ),
    );
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
        ],
      ),
    );

    if (confirmed == true) {
      await onConfirm();
      _showSnack(successMessage);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Future<void> _showBudgetDialog(AppState state, {BudgetModel? budget}) async {
    final expenseCategories = state.categories.where((item) => item.type == 'expense').toList();
    if (expenseCategories.isEmpty) {
      _showSnack('Create an expense category first');
      return;
    }

    final controller = TextEditingController(text: budget?.limit.toStringAsFixed(0) ?? '');
    String categoryId = budget?.categoryId ?? expenseCategories.first.id;
    final month = DateFormat('yyyy-MM').format(selectedMonth);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(budget == null ? 'Set budget' : 'Edit budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: categoryId,
              items: expenseCategories
                  .map((item) => DropdownMenuItem<String>(value: item.id, child: Text('${item.icon} ${item.name}')))
                  .toList(),
              onChanged: (value) => categoryId = value ?? categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monthly limit'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final limit = double.tryParse(controller.text.trim());
              if (limit == null || limit <= 0) return;
              await state.saveBudget(BudgetModel(categoryId: categoryId, limit: limit, month: month));
              if (context.mounted) {
                Navigator.pop(context);
                _showSnack('Budget saved');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountDialog(AppState state, {AccountModel? account}) async {
    final nameController = TextEditingController(text: account?.name ?? '');
    final iconController = TextEditingController(text: account?.icon ?? '💳');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account == null ? 'Add account' : 'Edit account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: iconController, decoration: const InputDecoration(labelText: 'Emoji / Icon')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final icon = iconController.text.trim();
              if (name.isEmpty || icon.isEmpty) return;
              await state.saveAccount(AccountModel(id: account?.id ?? state.newId(), name: name, icon: icon));
              if (context.mounted) {
                Navigator.pop(context);
                _showSnack(account == null ? 'Account added' : 'Account updated');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryDialog(AppState state, {CategoryModel? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final iconController = TextEditingController(text: category?.icon ?? '🏷️');
    String type = category?.type ?? 'expense';
    Color selectedColor = Color(category?.colorValue ?? const Color(0xFF6C63FF).value);
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF06B6D4),
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          title: Text(category == null ? 'Add category' : 'Edit category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: iconController, decoration: const InputDecoration(labelText: 'Emoji / Icon')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                ],
                onChanged: (value) => setLocalState(() => type = value ?? type),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors
                    .map(
                      (color) => GestureDetector(
                        onTap: () => setLocalState(() => selectedColor = color),
                        child: CircleAvatar(
                          backgroundColor: color,
                          child: selectedColor.value == color.value ? const Icon(Icons.check, color: Colors.white) : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final icon = iconController.text.trim();
                if (name.isEmpty || icon.isEmpty) return;
                await state.saveCategory(
                  CategoryModel(
                    id: category?.id ?? state.newId(),
                    name: name,
                    type: type,
                    icon: icon,
                    colorValue: selectedColor.value,
                  ),
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  _showSnack(category == null ? 'Category added' : 'Category updated');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPasscodeDialog(AppState state) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set 4-digit passcode'),
        content: TextField(
          controller: controller,
          maxLength: 4,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Passcode'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().length != 4) return;
              await state.setPasscode(controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  String _money(double value) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);
}
