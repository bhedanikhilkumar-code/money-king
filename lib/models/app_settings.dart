import 'package:flutter/material.dart';

class AppSettings {
  AppSettings({
    required this.themeMode,
    required this.accentColorValue,
    required this.passcodeEnabled,
    required this.passcodeHash,
  });

  final ThemeMode themeMode;
  final int accentColorValue;
  final bool passcodeEnabled;
  final String passcodeHash;

  Color get accentColor => Color(accentColorValue);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? accentColorValue,
    bool? passcodeEnabled,
    String? passcodeHash,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      passcodeEnabled: passcodeEnabled ?? this.passcodeEnabled,
      passcodeHash: passcodeHash ?? this.passcodeHash,
    );
  }

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode.name,
        'accentColorValue': accentColorValue,
        'passcodeEnabled': passcodeEnabled,
        'passcodeHash': passcodeHash,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (value) => value.name == map['themeMode'],
        orElse: () => ThemeMode.dark,
      ),
      accentColorValue: (map['accentColorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
      passcodeEnabled: (map['passcodeEnabled'] as bool?) ?? false,
      passcodeHash: (map['passcodeHash'] as String?) ?? '',
    );
  }

  factory AppSettings.defaults() => AppSettings(
        themeMode: ThemeMode.dark,
        accentColorValue: 0xFF6C63FF,
        passcodeEnabled: false,
        passcodeHash: '',
      );
}
