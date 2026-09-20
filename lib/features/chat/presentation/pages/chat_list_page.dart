import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/pages/user_profile_view_page.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../providers/chat_provider.dart';
import '../widgets/mini_chat_overlay.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsProvider);
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات')),
      body: threadsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => const ErrorView(message: 'تعذر تحميل المحادثات الآن. تحقق من الاتصال ثم أعد المحاولة.'),
        data: (threads) {
          if (threads.isEmpty) {
            return const Center(
              child: Text('لا توجد محادثات بعد',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.separated(
            itemCount: threads.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final otherUid =
                  myUid == null ? '' : thread.otherParticipant(myUid);
              final unread = myUid == null ? 0 : thread.unreadFor(myUid);

              return Consumer(
                builder: (context, ref, _) {
                  final profileAsync = ref.watch(profileByIdProvider(otherUid));
                  final name = profileAsync.valueOrNull?.displayName ?? '...';

                  return ListTile(
                    leading: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileViewPage(uid: otherUid),
                        ),
                      ),
                      child: ProfileAvatar(
                        avatarUrl: profileAsync.valueOrNull?.avatarUrl,
                        animatedAvatarUrl: profileAsync.valueOrNull?.animatedAvatarUrl,
                        displayName: name,
                        radius: 23,
                        frameKey: profileAsync.valueOrNull?.avatarFrameKey,
                      ),
                    ),
                    title: ServerUsernameDisplay(
                      uid: otherUid,
                      fallbackName: name,
                      fallbackFontSize: 14,
                      showBadges: true,
                      compactBadges: true,
                    ),
                    subtitle: Text(
                      thread.lastMessageText ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: unread > 0
                        ? CircleAvatar(
                            radius: 11,
                            backgroundColor: AppColors.gold,
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.background),
                            ),
                          )
                        : null,
                    onTap: () {
                      // النافذة العائمة هي المسار الوحيد للمراسلة الخاصة في
                      // كل التطبيق (openPrivateChat موحّدة لكل نقاط الدخول).
                      openPrivateChat(
                        context,
                        ref,
                        threadId: thread.id,
                        peerUid: otherUid,
                        peerName: name,
                        peerAvatar: profileAsync.valueOrNull?.avatarUrl,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
