import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../calls/domain/entities/call_entity.dart';
import '../../../calls/presentation/pages/active_call_page.dart';
import '../../../calls/presentation/providers/call_provider.dart';
import 'home_dashboard_page.dart';
import '../../../chat/presentation/pages/chat_lobby_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../marketplace/presentation/pages/marketplace_page.dart';
import '../../../producer_market/presentation/pages/producer_market_page.dart';
import '../../../../core/media/media_playback_coordinator.dart';
import '../../../admin/presentation/pages/error_monitor_page.dart';

/// نقطة الدخول الوحيدة للمستخدم المسجَّل دخوله — هذا هو "Main Home"
/// المفقود سابقًا. كل وحدة رئيسية جديدة (Feed، Notifications...)
/// تُضاف كتبويب هنا بدل شاشة منفصلة يصل إليها المستخدم بالصدفة.
/// كما تراقب هذه القشرة أي اتصال وارد عالميًا وتفتح شاشته تلقائيًا
/// من أي مكان في التطبيق.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // Canonical public room verified against the current Supabase production data.
  static const String _verifiedPublicRoomId =
      'c4e16a4b-a014-4f03-a16d-8927bbdc9cfa';
  @override
  void initState() {
    super.initState();
    AppMediaPlaybackCoordinator.setScope(null);
    unawaited(_loadOwnerFlag());

    _incomingCallSubscription = ref.listenManual<AsyncValue<CallEntity?>>(
      incomingRingingCallProvider,
      (previous, next) {
        if (!mounted) return;

        final call = next.valueOrNull;
        if (call != null) {
          _handleIncomingCall(call);
        }
      },
    );

    _loadCurrentRoom();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final initialCall = ref.read(incomingRingingCallProvider).valueOrNull;

      if (initialCall != null) {
        _handleIncomingCall(initialCall);
      }
    });
  }

  Future<void> _loadCurrentRoom() async {
    if (!mounted) return;
    setState(() {
      _roomLoading = false;
      _roomError = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('chat_rooms')
          .select('id')
          .eq('is_active', true)
          .eq('is_public', true)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      final roomId = response?['id']?.toString();
      if (roomId == null || roomId.isEmpty) {
        setState(() {
          _currentRoomId = _verifiedPublicRoomId;
          _roomLoading = false;
          _roomError =
              'تعذر العثور على الغرفة العامة؛ تم استخدام الغرفة العامة الموثقة.';
        });
        return;
      }

      setState(() {
        _currentRoomId = roomId;
        _roomLoading = false;
        _roomError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _currentRoomId ??= _verifiedPublicRoomId;
        _roomLoading = false;
        _roomError = _friendlyRoomError(error);
      });
    }
  }

  String _friendlyRoomError(Object error) {
    if (error is PostgrestException) {
      return 'تعذر الوصول إلى غرفة الشات (${error.code}).';
    }
    return 'تعذر فتح الشات حاليًا. تحقق من الاتصال ثم أعد المحاولة.';
  }

  int _index = 0;

  /// The error-monitor tab is owner-only, so the bottom bar is built
  /// conditionally. Ordinary users never see it at all.
  bool _isOwner = false;

  Future<void> _loadOwnerFlag() async {
    try {
      final owner = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (!mounted) return;
      setState(() {
        _isOwner = owner == true;
        // Adding a tab shifts the indices, so keep the current selection valid.
        if (_index >= _pages.length) _index = 0;
      });
    } catch (_) {
      // Not being able to confirm ownership simply means no extra tab.
    }
  }
  String? _currentRoomId = _verifiedPublicRoomId;
  String? _roomError;
  bool _roomLoading = false;
  String? _handledCallId;
  ProviderSubscription<AsyncValue<CallEntity?>>? _incomingCallSubscription;

  Widget _chatEntryPage() {
    final roomId = _currentRoomId ?? _verifiedPublicRoomId;
    if (roomId.isNotEmpty) {
      // Keep the chat room inside HomeShell so the global bottom navigation
      // (الشات / المراقبة / المنصة / الورش / المتجر) never disappears when
      // the user changes rooms.
      return _ChatRoomHostPage(
        roomId: roomId,
        onRoomSelected: (selectedRoomId) {
          if (!mounted || selectedRoomId.trim().isEmpty) return;
          setState(() => _currentRoomId = selectedRoomId.trim());
        },
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              _roomError ?? 'تعذر فتح الشات.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _roomLoading ? null : _loadCurrentRoom,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  int get _producerMarketIndex => _isOwner ? 3 : 2;

  List<Widget> get _pages => [
        _chatEntryPage(),
        if (_isOwner) const ErrorMonitorPage(),
        const HomeDashboardPage(),
        ProducerMarketPage(isActive: _index == _producerMarketIndex),
        const MarketplacePage(),
      ];

  void _handleIncomingCall(CallEntity call) {
    final myUid = ref.read(authControllerProvider).valueOrNull?.uid;
    if (!mounted || myUid == null || call.id == _handledCallId) return;
    _handledCallId = call.id;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(call.type == CallType.video
            ? '📹 مكالمة فيديو واردة'
            : '📞 مكالمة صوتية واردة'),
        content: const Text(
            'لديك مكالمة واردة. يمكنك القبول أو الرفض قبل تشغيل الميكروفون/الكاميرا.'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(callControllerProvider.notifier).updateStatus(
                    callId: call.id,
                    status: CallStatus.declined,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('رفض'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(callControllerProvider.notifier).updateStatus(
                    callId: call.id,
                    status: CallStatus.accepted,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActiveCallPage(
                    callId: call.id,
                    otherUid: call.callerUid,
                    type: call.type,
                    isCaller: false,
                  ),
                ),
              );
            },
            child: const Text('قبول'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    AppMediaPlaybackCoordinator.setScope(null);
    _incomingCallSubscription?.close();
    _incomingCallSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          final producerIndex = _producerMarketIndex;
          AppMediaPlaybackCoordinator.setScope(
            i == producerIndex ? AppMediaPlaybackCoordinator.producerMarket : null,
          );
          setState(() => _index = i);
        },
        // Not a const list: the monitoring tab is added at runtime for the
        // owner only, so the collection cannot be evaluated at compile time.
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'الشات'),
          if (_isOwner)
            const BottomNavigationBarItem(
                icon: Icon(Icons.monitor_heart_outlined), label: 'المراقبة'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), label: 'المنصة'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.movie_creation_outlined), label: 'الورش'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined), label: 'المتجر'),
        ],
      ),
    );
  }
}
class _ChatRoomHostPage extends StatefulWidget {
  final String roomId;
  final ValueChanged<String> onRoomSelected;

  const _ChatRoomHostPage({
    required this.roomId,
    required this.onRoomSelected,
  });

  @override
  State<_ChatRoomHostPage> createState() => _ChatRoomHostPageState();
}

class _ChatRoomHostPageState extends State<_ChatRoomHostPage> {
  late String _roomId;

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId;
  }

  @override
  void didUpdateWidget(covariant _ChatRoomHostPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _roomId = widget.roomId;
    }
  }

  void _selectRoom(String roomId) {
    final normalized = roomId.trim();
    if (normalized.isEmpty || normalized == _roomId || !mounted) return;
    setState(() => _roomId = normalized);
    widget.onRoomSelected(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return ChatLobbyPage(
      key: ValueKey<String>(_roomId),
      roomId: _roomId,
      onRoomSelected: _selectRoom,
    );
  }
}
