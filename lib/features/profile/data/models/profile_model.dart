import '../../domain/entities/profile_entity.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.uid,
    required super.displayName,
    required super.email,
    super.bio,
    super.avatarUrl,
    super.coverUrl,
    super.statusText,
    super.profileMusicUrl,
    super.profileMusicDurationMs,
    super.profileMusicSizeBytes,
    super.country,
    super.city,
    super.profession,
    super.experiences,
    super.socialLinks,
    super.verified,
    super.visibility,
    super.accountType,
    super.usernameColor,
    super.usernameFontSize,
    super.usernameFontFamily,
    super.messageFontFamily,
    super.messageColor,
    super.statusFontSize,
    super.statusBold,
    super.statusItalic,
    super.statusColor,
    super.animatedAvatarUrl,
    super.avatarFrameKey,
    super.usernameTemplateKey,
    super.usernameEffect,
    super.usernameBackgroundKey,
    super.usernameBackgroundMode,
    super.usernameBackgroundColor1,
    super.usernameBackgroundColor2,
    super.usernameBackgroundOpacity,
    super.usernameBackgroundExternalEffect,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProfileModel.fromMap(String uid, Map<String, dynamic> map) {
    final rawExperiences = map['experiences'];
    final rawSocialLinks = map['socialLinks'];

    final experiences = rawExperiences is List
        ? rawExperiences.whereType<String>().toList(growable: false)
        : const <String>[];

    final socialLinks = rawSocialLinks is List
        ? rawSocialLinks
            .whereType<Map>()
            .map((e) => SocialLink.fromMap(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <SocialLink>[];

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    double? parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    return ProfileModel(
      uid: uid,
      displayName: map['displayName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      bio: map['bio']?.toString() ?? '',
      avatarUrl: map['avatarUrl']?.toString(),
      coverUrl: map['coverUrl']?.toString(),
      statusText: map['statusText']?.toString(),
      profileMusicUrl: map['profileMusicUrl']?.toString(),
      profileMusicDurationMs: parseInt(map['profileMusicDurationMs']),
      profileMusicSizeBytes: parseInt(map['profileMusicSizeBytes']),
      country: map['country']?.toString(),
      city: map['city']?.toString(),
      profession: map['profession']?.toString(),
      experiences: experiences,
      socialLinks: socialLinks,
      verified: map['verified'] == true,
      visibility: ProfileVisibilityX.fromWire(map['visibility']?.toString()),
      accountType: AccountTypeX.fromWire(map['accountType']?.toString()),
      usernameColor: parseInt(map['usernameColor']),
      usernameFontSize: parseDouble(map['usernameFontSize']) ?? 12,
      usernameFontFamily: map['usernameFontFamily']?.toString() ?? '',
      messageFontFamily: map['messageFontFamily']?.toString() ?? '',
      messageColor: parseInt(map['messageColor']) ?? 4294967295,
      statusFontSize: parseDouble(map['statusFontSize']) ?? 12.5,
      statusBold: map['statusBold'] == true,
      statusItalic: map['statusItalic'] == true,
      statusColor: parseInt(map['statusColor']),
      animatedAvatarUrl: map['animatedAvatarUrl']?.toString(),
      avatarFrameKey: map['avatarFrameKey']?.toString(),
      usernameTemplateKey: map['usernameTemplateKey']?.toString(),
      usernameEffect: map['usernameEffect']?.toString() ?? 'none',
      usernameBackgroundKey: map['usernameBackgroundKey']?.toString(),
      usernameBackgroundMode: map['usernameBackgroundMode']?.toString(),
      usernameBackgroundColor1: map['usernameBackgroundColor1']?.toString(),
      usernameBackgroundColor2: map['usernameBackgroundColor2']?.toString(),
      usernameBackgroundOpacity:
          parseDouble(map['usernameBackgroundOpacity']) ?? .82,
      usernameBackgroundExternalEffect:
          map['usernameBackgroundExternalEffect']?.toString(),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory ProfileModel.fromEntity(ProfileEntity entity) {
    return ProfileModel(
      uid: entity.uid,
      displayName: entity.displayName,
      email: entity.email,
      bio: entity.bio,
      avatarUrl: entity.avatarUrl,
      coverUrl: entity.coverUrl,
      statusText: entity.statusText,
      profileMusicUrl: entity.profileMusicUrl,
      profileMusicDurationMs: entity.profileMusicDurationMs,
      profileMusicSizeBytes: entity.profileMusicSizeBytes,
      country: entity.country,
      city: entity.city,
      profession: entity.profession,
      experiences: entity.experiences,
      socialLinks: entity.socialLinks,
      verified: entity.verified,
      visibility: entity.visibility,
      accountType: entity.accountType,
      usernameColor: entity.usernameColor,
      usernameFontSize: entity.usernameFontSize,
      usernameFontFamily: entity.usernameFontFamily,
      messageFontFamily: entity.messageFontFamily,
      messageColor: entity.messageColor,
      statusFontSize: entity.statusFontSize,
      statusBold: entity.statusBold,
      statusItalic: entity.statusItalic,
      statusColor: entity.statusColor,
      animatedAvatarUrl: entity.animatedAvatarUrl,
      avatarFrameKey: entity.avatarFrameKey,
      usernameTemplateKey: entity.usernameTemplateKey,
      usernameEffect: entity.usernameEffect,
      usernameBackgroundKey: entity.usernameBackgroundKey,
      usernameBackgroundMode: entity.usernameBackgroundMode,
      usernameBackgroundColor1: entity.usernameBackgroundColor1,
      usernameBackgroundColor2: entity.usernameBackgroundColor2,
      usernameBackgroundOpacity: entity.usernameBackgroundOpacity,
      usernameBackgroundExternalEffect: entity.usernameBackgroundExternalEffect,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final dynamic candidate = value;
    try {
      final parsed = candidate?.toDate();
      if (parsed is DateTime) return parsed;
    } catch (_) {}
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap({bool isCreate = false}) {
    return {
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'statusText': statusText,
      'profileMusicUrl': profileMusicUrl,
      'profileMusicDurationMs': profileMusicDurationMs,
      'profileMusicSizeBytes': profileMusicSizeBytes,
      'country': country,
      'city': city,
      'profession': profession,
      'experiences': experiences,
      'socialLinks': socialLinks.map((e) => e.toMap()).toList(),
      'verified': verified,
      'visibility': visibility.wire,
      'accountType': accountType.wire,
      'usernameColor': usernameColor,
      'usernameFontSize': usernameFontSize,
      'usernameFontFamily': usernameFontFamily,
      'messageFontFamily': messageFontFamily,
      'messageColor': messageColor,
      'statusFontSize': statusFontSize,
      'statusBold': statusBold,
      'statusItalic': statusItalic,
      'statusColor': statusColor,
      'animatedAvatarUrl': animatedAvatarUrl,
      'avatarFrameKey': avatarFrameKey,
      'usernameTemplateKey': usernameTemplateKey,
      'usernameEffect': usernameEffect,
      'usernameBackgroundKey': usernameBackgroundKey,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}
