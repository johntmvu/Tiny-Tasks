class UserPreferences {
  final int? preferenceId;
  final int userId;
  final String defaultView;
  final bool darkMode;
  final bool notificationsEnabled;
  final String halfDayDefault;

  UserPreferences({
    this.preferenceId,
    required this.userId,
    this.defaultView = 'Today',
    this.darkMode = false,
    this.notificationsEnabled = true,
    this.halfDayDefault = 'Morning',
  });

  Map<String, dynamic> toMap() {
    return {
      'Preference_ID': preferenceId,
      'User_ID': userId,
      'Default_View': defaultView,
      'Dark_Mode': darkMode ? 1 : 0,
      'Notifications_Enabled': notificationsEnabled ? 1 : 0,
      'Half_Day_Default': halfDayDefault,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      preferenceId: map['Preference_ID'] as int?,
      userId: map['User_ID'] as int,
      defaultView: map['Default_View'] as String? ?? 'Today',
      darkMode: map['Dark_Mode'] == 1,
      notificationsEnabled: map['Notifications_Enabled'] == 1,
      halfDayDefault: map['Half_Day_Default'] as String? ?? 'Morning',
    );
  }

  UserPreferences copyWith({
    int? preferenceId,
    int? userId,
    String? defaultView,
    bool? darkMode,
    bool? notificationsEnabled,
    String? halfDayDefault,
  }) {
    return UserPreferences(
      preferenceId: preferenceId ?? this.preferenceId,
      userId: userId ?? this.userId,
      defaultView: defaultView ?? this.defaultView,
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      halfDayDefault: halfDayDefault ?? this.halfDayDefault,
    );
  }
}
