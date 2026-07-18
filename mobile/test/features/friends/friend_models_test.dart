import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/friends/domain/entities/friend_models.dart';

void main() {
  test('maps every documented relationship status', () {
    expect(relationshipStatusFromJson('SELF'), RelationshipStatus.self);
    expect(relationshipStatusFromJson('FRIENDS'), RelationshipStatus.friends);
    expect(
      relationshipStatusFromJson('OUTGOING_REQUEST'),
      RelationshipStatus.outgoingRequest,
    );
    expect(
      relationshipStatusFromJson('INCOMING_REQUEST'),
      RelationshipStatus.incomingRequest,
    );
    expect(relationshipStatusFromJson('BLOCKED'), RelationshipStatus.blocked);
    expect(
      relationshipStatusFromJson('BLOCKED_BY_TARGET'),
      RelationshipStatus.blockedByTarget,
    );
    expect(relationshipStatusFromJson('NONE'), RelationshipStatus.none);
  });

  test('preserves unknown relationship status as unsupported', () {
    expect(
      relationshipStatusFromJson('FUTURE_STATUS'),
      RelationshipStatus.unsupported,
    );
  });

  test('parses user search response using canonical fields', () {
    final result = UserSearchResult.fromJson({
      'id': 'user-1',
      'username': 'mai',
      'displayName': 'Mai Nguyen',
      'avatarUrl': 'https://example.test/avatar.jpg',
      'bio': 'Hello',
      'relationshipStatus': 'NONE',
    });

    expect(result.id, 'user-1');
    expect(result.resolvedName, 'Mai Nguyen');
    expect(result.relationshipStatus, RelationshipStatus.none);
    expect(result.allowDirectMessages, isNull);
  });

  test('preserves an explicit direct-message permission projection', () {
    final result = UserSearchResult.fromJson({
      'id': 'user-2',
      'username': 'private_user',
      'relationshipStatus': 'NONE',
      'allowDirectMessages': false,
    });

    expect(result.allowDirectMessages, isFalse);
  });
}
