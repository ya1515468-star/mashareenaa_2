import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../monitoring/error_monitor.dart';
import 'supabase_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

import '../../features/profile/presentation/providers/profile_provider.dart';
import '../../features/rbac/presentation/widgets/server_user_identity_badges.dart';
import '../../features/store/presentation/profile_cosmetic_store_page.dart';
import '../../features/store/presentation/profile_premium_services_tab.dart';

final globalServerRealtimeSyncProvider = Provider<void>((ref) {
  final client = Supabase.instance.client;
  final authState = ref.watch(authControllerProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return;

  var disposed = false;
  RealtimeChannel? channel;
  Timer? profileTimer;
  Timer? catalogTimer;
  Timer? ownershipTimer;
  Timer? premiumTimer;

  void scheduleProfileRefresh([String? uid]) {
    profileTimer?.cancel();
    profileTimer = Timer(const Duration(milliseconds: 150), () {
      ref.invalidate(currentProfileProvider);
      if (uid != null && uid.isNotEmpty) {
        ref.invalidate(profileByIdProvider(uid));
        ref.invalidate(serverUserIdentityProvider);
        ref.invalidate(serverUserIdentityInRoomProvider);
      } else {
        ref.invalidate(serverUserIdentityProvider);
        ref.invalidate(serverUserIdentityInRoomProvider);
      }
    });
  }

  void scheduleStoreCatalogRefresh() {
    catalogTimer?.cancel();
    catalogTimer = Timer(const Duration(milliseconds: 150), () {
      ref.invalidate(profileCosmeticCatalogProvider);
      ref.invalidate(serverAvatarFramesProvider);
    });
  }

  void scheduleOwnershipRefresh() {
    ownershipTimer?.cancel();
    ownershipTimer = Timer(const Duration(milliseconds: 150), () {
      ref.invalidate(myProfileCosmeticOwnershipProvider);
    });
  }

  void schedulePremiumRefresh() {
    premiumTimer?.cancel();
    premiumTimer = Timer(const Duration(milliseconds: 150), () {
      ref.invalidate(profilePremiumServicesOwnedProvider);
    });
  }

  Future<void> connect() async {
    try {
      await SupabaseService.ensureValidSession();
    } catch (e, stack) {
      if (!disposed) {
        unawaited(ErrorMonitor.report(
          e,
          stack: stack,
          source: 'realtime.global_session_refresh',
          screen: 'realtime.global',
          severity: 'warning',
        ));
      }
      return;
    }
    if (disposed || ref.read(authControllerProvider).valueOrNull?.uid != uid) {
      return;
    }

    final builder = client.channel('global-server-sync')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profiles',
      callback: (change) {
        final uid = change.newRecord['id']?.toString() ?? change.oldRecord['id']?.toString();
        scheduleProfileRefresh(uid);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'avatar_frame_catalog',
      callback: (_) => scheduleStoreCatalogRefresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profile_cosmetic_catalog',
      callback: (_) => scheduleStoreCatalogRefresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profile_cosmetic_purchases',
      callback: (_) => scheduleOwnershipRefresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_profile_services',
      callback: (_) => schedulePremiumRefresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_inventory',
      callback: (_) => scheduleOwnershipRefresh(),
    );

    channel = builder..subscribe();
  }

  unawaited(connect());

  ref.onDispose(() {
    disposed = true;
    profileTimer?.cancel();
    catalogTimer?.cancel();
    ownershipTimer?.cancel();
    premiumTimer?.cancel();
    unawaited(channel?.unsubscribe());
  });
});
