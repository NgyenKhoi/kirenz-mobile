import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../friends/data/repositories/friend_repository.dart';
import '../../../friends/domain/entities/friend_models.dart';
import '../../../posts/domain/entities/post.dart';

final exploreControllerProvider =
    StateNotifierProvider<ExploreController, ExploreState>((ref) {
      return ExploreController(ref.watch(friendRepositoryProvider));
    });

class ExploreState {
  const ExploreState({
    this.query = '',
    this.submittedQuery = '',
    this.people = const [],
    this.peopleLoading = false,
    this.peopleError,
  });

  final String query;
  final String submittedQuery;
  final List<UserSearchResult> people;
  final bool peopleLoading;
  final String? peopleError;

  bool get hasValidQuery => submittedQuery.trim().length >= 2;

  ExploreState copyWith({
    String? query,
    String? submittedQuery,
    List<UserSearchResult>? people,
    bool? peopleLoading,
    String? peopleError,
    bool clearPeopleError = false,
  }) => ExploreState(
    query: query ?? this.query,
    submittedQuery: submittedQuery ?? this.submittedQuery,
    people: people ?? this.people,
    peopleLoading: peopleLoading ?? this.peopleLoading,
    peopleError: clearPeopleError ? null : peopleError ?? this.peopleError,
  );
}

class ExploreController extends StateNotifier<ExploreState> {
  ExploreController(this._repository) : super(const ExploreState());

  final FriendRepository _repository;
  Timer? _debounce;
  int _generation = 0;

  void setQuery(String value, {bool debounce = true}) {
    state = state.copyWith(query: value);
    _debounce?.cancel();
    if (!debounce) {
      unawaited(submit());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), submit);
  }

  Future<void> submit() async {
    _debounce?.cancel();
    final query = state.query.trim();
    final generation = ++_generation;
    if (query.length < 2) {
      state = state.copyWith(
        submittedQuery: query,
        people: const [],
        peopleLoading: false,
        clearPeopleError: true,
      );
      return;
    }
    state = state.copyWith(
      submittedQuery: query,
      peopleLoading: true,
      clearPeopleError: true,
    );
    try {
      final people = await _repository.searchUsers(query);
      if (generation != _generation) return;
      state = state.copyWith(people: people, peopleLoading: false);
    } on Object catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        people: const [],
        peopleLoading: false,
        peopleError: error is ApiException ? error.message : error.toString(),
      );
    }
  }

  Future<void> refreshPeople() => submit();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

List<Post> relatedExplorePosts(List<Post> posts, String query) {
  final normalized = query.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();
  if (normalized.length < 2) return const [];
  return posts
      .where((post) {
        final content = post.content.toLowerCase();
        return content.contains(normalized);
      })
      .toList(growable: false);
}

List<MapEntry<String, int>> trendingExploreHashtags(List<Post> posts) {
  final counts = <String, int>{};
  final pattern = RegExp(r'#[\p{L}\p{N}_-]+', unicode: true);
  for (final post in posts) {
    final unique = pattern
        .allMatches(post.content)
        .map((match) => match.group(0)!.substring(1).toLowerCase())
        .toSet();
    for (final tag in unique) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final ranked = counts.entries.toList()
    ..sort((left, right) {
      final countOrder = right.value.compareTo(left.value);
      return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
    });
  return ranked.take(10).toList(growable: false);
}
