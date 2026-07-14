import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:kirenz_mobile/features/profile/domain/entities/user_profile.dart';

void main() {
  test('parses the canonical profile response', () {
    final profile = UserProfile.fromJson({
      'id': 'user-1',
      'email': 'person@example.com',
      'username': 'person',
      'displayName': 'Person Example',
      'avatarUrl': 'https://example.com/avatar.jpg',
      'coverPhotoUrl': 'https://example.com/cover.jpg',
      'bio': 'Hello',
      'birthDate': '2000-02-03',
      'gender': 'PREFER_NOT_TO_SAY',
      'location': 'Bangkok',
      'website': 'https://example.com',
      'role': 'MODERATOR',
      'emailVerified': true,
      'createdAt': '2026-01-01T10:00:00Z',
      'updatedAt': '2026-01-02T10:00:00Z',
    });

    expect(profile.id, 'user-1');
    expect(profile.gender, ProfileGender.preferNotToSay);
    expect(profile.role, ProfileRole.moderator);
    expect(profile.birthDate, DateTime(2000, 2, 3));
    expect(profile.emailVerified, isTrue);
  });

  test('serializes only the canonical update fields and enum values', () {
    final update = ProfileUpdate(
      displayName: 'New Name',
      bio: 'New bio',
      birthDate: DateTime(2001, 4, 5),
      gender: ProfileGender.other,
      location: 'Chiang Mai',
      website: 'https://example.com',
    );

    expect(update.toJson(), {
      'displayName': 'New Name',
      'bio': 'New bio',
      'birthDate': '2001-04-05',
      'gender': 'OTHER',
      'location': 'Chiang Mai',
      'website': 'https://example.com',
    });
  });
}
