import 'package:flutter/material.dart';

/// Represents different avatar characters
enum AvatarCharacter {
  alex('Alex', 'Professional male', AvatarGender.male, 'assets/avatars/alex/'),
  sarah('Sarah', 'Friendly female', AvatarGender.female, 'assets/avatars/sarah/'),
  jordan('Jordan', 'Casual non-binary', AvatarGender.neutral, 'assets/avatars/jordan/'),
  maria('Maria', 'Elegant female', AvatarGender.female, 'assets/avatars/maria/'),
  david('David', 'Business male', AvatarGender.male, 'assets/avatars/david/'),
  lisa('Lisa', 'Young female', AvatarGender.female, 'assets/avatars/lisa/'),
  robot('Roboto', 'AI assistant', AvatarGender.neutral, 'assets/animations/'),
  ;

  final String displayName;
  final String description;
  final AvatarGender gender;
  final String assetPath;

  const AvatarCharacter(this.displayName, this.description, this.gender, this.assetPath);

  bool get isHuman => this != AvatarCharacter.robot;
}

enum AvatarGender {
  male('Male', Icons.male, Colors.blue),
  female('Female', Icons.female, Colors.pink),
  neutral('Neutral', Icons.person, Colors.purple);

  final String label;
  final IconData icon;
  final Color color;

  const AvatarGender(this.label, this.icon, this.color);
}

/// Avatar expression states
enum AvatarExpression {
  neutral,
  happy,
  thinking,
  surprised,
  concerned,
  speaking,
  listening,
}

/// Avatar configuration
class AvatarConfig {
  final AvatarCharacter character;
  final AvatarExpression expression;
  final double scale;
  final bool enableLipSync;
  final bool enableBlinking;
  final bool enableBreathing;
  final Color? backgroundColor;

  const AvatarConfig({
    this.character = AvatarCharacter.sarah,
    this.expression = AvatarExpression.neutral,
    this.scale = 1.0,
    this.enableLipSync = true,
    this.enableBlinking = true,
    this.enableBreathing = true,
    this.backgroundColor,
  });

  AvatarConfig copyWith({
    AvatarCharacter? character,
    AvatarExpression? expression,
    double? scale,
    bool? enableLipSync,
    bool? enableBlinking,
    bool? enableBreathing,
    Color? backgroundColor,
  }) {
    return AvatarConfig(
      character: character ?? this.character,
      expression: expression ?? this.expression,
      scale: scale ?? this.scale,
      enableLipSync: enableLipSync ?? this.enableLipSync,
      enableBlinking: enableBlinking ?? this.enableBlinking,
      enableBreathing: enableBreathing ?? this.enableBreathing,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

/// Lip sync data for animation
class LipSyncData {
  final List<double> visemeValues;
  final double intensity;
  final Duration timestamp;

  LipSyncData({
    required this.visemeValues,
    required this.intensity,
    required this.timestamp,
  });

  /// Create a stream from this data
  Stream<LipSyncData> get stream async* {
    yield this;
  }
}

/// Viseme types for lip syncing
enum Viseme {
  silence,      // No sound
  aa,           // "a" as in "bat"
  eh,           // "e" as in "bet"
  ih,           // "i" as in "bit"
  oh,           // "o" as in "bot"
  ou,           // "u" as in "but"
  ee,           // "ee" as in "beet"
  oo,           // "oo" as in "boot"
  th,           // "th" sound
  f,            // "f" and "v"
  m,            // "m", "b", "p"
  l,            // "l" and "d"
  s,            // "s" and "z"
  ch,           // "ch", "j", "sh"
  r,            // "r"
  w,            // "w" and "q"
}

/// Avatar presets for quick selection
class AvatarPresets {
  static const List<AvatarCharacter> professional = [
    AvatarCharacter.alex,
    AvatarCharacter.david,
    AvatarCharacter.maria,
  ];

  static const List<AvatarCharacter> casual = [
    AvatarCharacter.sarah,
    AvatarCharacter.jordan,
    AvatarCharacter.lisa,
  ];

  static const List<AvatarCharacter> allHumans = [
    AvatarCharacter.alex,
    AvatarCharacter.sarah,
    AvatarCharacter.jordan,
    AvatarCharacter.maria,
    AvatarCharacter.david,
    AvatarCharacter.lisa,
  ];

  static List<AvatarCharacter> byGender(AvatarGender gender) {
    return AvatarCharacter.values
        .where((c) => c.gender == gender && c.isHuman)
        .toList();
  }
}
