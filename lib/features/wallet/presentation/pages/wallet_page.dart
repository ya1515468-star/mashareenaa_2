import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/entities/ledger_entry_entity.dart';
import '../providers/wallet_provider.dart';
import '../widgets/balance_card.dart';
import 'transfer_page.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentWalletProvider);
    final historyAsync = ref.watch(walletHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: walletAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (wallet) {
          if (wallet == null) {
            return const ErrorView(message: 'تعذّر تحميل المحفظة');
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(walletHistoryProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: BalanceCard(money: wallet.shamCashBalance)),
                    const SizedBox(width: 12),
                    Expanded(child: BalanceCard(money: wallet.usdBalance)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('تحويل رصيد'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TransferPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('سجل المعاملات',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                historyAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: LoadingIndicator(),
                  ),
                  error: (error, _) => ErrorView(message: error.toString()),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('لا توجد معاملات بعد')),
                      );
                    }
                    return Column(
                      children:
                          entries.map((e) => _LedgerTile(entry: e)).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final LedgerEntryEntity entry;
  const _LedgerTile({required this.entry});

  bool get _isCredit => [
        LedgerEntryType.topUp,
        LedgerEntryType.transferReceived,
        LedgerEntryType.sale,
        LedgerEntryType.dailyReward,
        LedgerEntryType.refund,
      ].contains(entry.type);

  String get _label {
    switch (entry.type) {
      case LedgerEntryType.topUp:
        return 'شحن رصيد';
      case LedgerEntryType.transferSent:
        return 'تحويل صادر';
      case LedgerEntryType.transferReceived:
        return 'تحويل وارد';
      case LedgerEntryType.purchase:
        return 'عملية شراء';
      case LedgerEntryType.sale:
        return 'عملية بيع';
      case LedgerEntryType.dailyReward:
        return 'مكافأة يومية';
      case LedgerEntryType.refund:
        return 'استرداد';
      case LedgerEntryType.adjustment:
        return 'تسوية رصيد';
      case LedgerEntryType.pointsPurchase:
        return 'شراء نقاط';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (_isCredit ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.12),
        child: Icon(
          _isCredit ? Icons.arrow_downward : Icons.arrow_upward,
          color: _isCredit ? AppColors.success : AppColors.error,
        ),
      ),
      title: Text(_label),
      subtitle: entry.note != null ? Text(entry.note!) : null,
      trailing: Text(
        '${_isCredit ? '+' : '-'}${entry.amount.formatted}',
        style: TextStyle(
          color: _isCredit ? AppColors.success : AppColors.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
