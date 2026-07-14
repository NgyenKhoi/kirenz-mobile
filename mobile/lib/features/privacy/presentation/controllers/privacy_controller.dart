import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/privacy_repository.dart';
import '../../domain/entities/privacy_settings.dart';

final currentPrivacyProvider =
    AsyncNotifierProvider<PrivacyController, PrivacySettings>(
      PrivacyController.new,
    );

final userPrivacyProvider = FutureProvider.family<PrivacySettings, String>((
  ref,
  userId,
) {
  return ref.watch(privacyRepositoryProvider).getForUser(userId);
});

class PrivacyController extends AsyncNotifier<PrivacySettings> {
  @override
  Future<PrivacySettings> build() {
    return ref.watch(privacyRepositoryProvider).getCurrent();
  }

  Future<bool> save(PrivacySettings settings) async {
    state = const AsyncLoading<PrivacySettings>().copyWithPrevious(state);
    final result = await AsyncValue.guard(
      () => ref.read(privacyRepositoryProvider).update(settings),
    );
    state = result;
    if (result.hasValue) {
      ref.invalidate(userPrivacyProvider(settings.userId));
      return true;
    }
    return false;
  }
}
