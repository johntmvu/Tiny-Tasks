class User {
  final int? userId;
  final String name;
  final String email;
  final String? googleId;
  final String? googleToken;
  final DateTime? tokenExpiry;
  final bool rememberMe;
  final DateTime createdAt;

  User({
    this.userId,
    required this.name,
    required this.email,
    this.googleId,
    this.googleToken,
    this.tokenExpiry,
    this.rememberMe = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'User_ID': userId,
      'Name': name,
      'Email': email,
      'Google_ID': googleId,
      'Google_Token': googleToken,
      'Token_Expiry': tokenExpiry?.toIso8601String(),
      'Remember_Me': rememberMe ? 1 : 0,
      'Created_At': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['User_ID'] as int?,
      name: map['Name'] as String,
      email: map['Email'] as String,
      googleId: map['Google_ID'] as String?,
      googleToken: map['Google_Token'] as String?,
      tokenExpiry: map['Token_Expiry'] != null
          ? DateTime.parse(map['Token_Expiry'] as String)
          : null,
      rememberMe: map['Remember_Me'] == 1,
      createdAt: DateTime.parse(map['Created_At'] as String),
    );
  }

  User copyWith({
    int? userId,
    String? name,
    String? email,
    String? googleId,
    String? googleToken,
    DateTime? tokenExpiry,
    bool? rememberMe,
    DateTime? createdAt,
  }) {
    return User(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      googleId: googleId ?? this.googleId,
      googleToken: googleToken ?? this.googleToken,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      rememberMe: rememberMe ?? this.rememberMe,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
