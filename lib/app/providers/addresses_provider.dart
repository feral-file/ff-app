import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for addresses.
///
/// Watches ObjectBox address entities and converts to [WalletAddress]
/// for UI (e.g. onboarding). Source of truth for tracked addresses.
final addressesProvider = StreamProvider<List<WalletAddress>>((ref) {
  final appStateService = ref.watch(appStateServiceProvider);
  return appStateService.watchTrackedAddressesAsWalletAddresses();
});
