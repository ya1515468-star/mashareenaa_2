import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/repositories/username_credential_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/usecases/transfer_points_usecase.dart';

/// تحويل نقاط بين الأعضاء بواسطة اسم المستخدم. يشترط تأكيد بريد
/// الطرفين إلكترونيًا (تُعرَض رسالة الخادم الواضحة عند الفشل بدل
/// أي رمز غامض).
class TransferPointsPage extends ConsumerStatefulWidget {
  const TransferPointsPage({super.key});

  @override
  ConsumerState<TransferPointsPage> createState() => _TransferPointsPageState();
}

class _TransferPointsPageState extends ConsumerState<TransferPointsPage> {
  final _usernameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _loading = false;
  String? _resultMessage;
  bool? _resultSuccess;

  @override
  void dispose() {
    _usernameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _transfer() async {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (myUid == null) return;

    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _resultSuccess = false;
        _resultMessage = 'أدخل عددًا صحيحًا موجبًا من النقاط';
      });
      return;
    }

    setState(() {
      _loading = true;
      _resultMessage = null;
    });

    final resolveResult =
        await sl<UsernameCredentialRepository>().resolveUidByUsername(
      _usernameController.text.trim(),
    );

    final toUid = resolveResult.fold((failure) => null, (uid) => uid);
    if (!mounted) return;
    if (toUid == null) {
      setState(() {
        _loading = false;
        _resultSuccess = false;
        _resultMessage = 'لا يوجد عضو بهذا اسم المستخدم';
      });
      return;
    }

    final transferResult = await sl<TransferPointsUseCase>().call(
      fromUid: myUid,
      toUid: toUid,
      amount: amount,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      _resultSuccess = transferResult.isRight();
      _resultMessage = transferResult.fold(
        (failure) => failure.message,
        (_) => 'تم تحويل $amount نقطة بنجاح',
      );
    });

    if (transferResult.isRight()) {
      _usernameController.clear();
      _amountController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('تحويل نقاط')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: p.surfaceHighlight,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: p.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'التحويل متاح فقط بين الحسابات المؤكَّد بريدها الإلكتروني',
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                  labelText: 'اسم مستخدم المستلم',
                  prefixIcon: Icon(Icons.alternate_email)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                  labelText: 'عدد النقاط',
                  prefixIcon: Icon(Icons.stars_outlined)),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _resultMessage!,
                style: TextStyle(
                    color: _resultSuccess == true ? p.success : p.error),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _transfer,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تحويل'),
            ),
          ],
        ),
      ),
    );
  }
}
