// Représentation de la session côté mobile (#46). Persistée dans
// `flutter_secure_storage` (cf. ADR 0004 — bearer token mobile via le
// plugin `bearer()` de Better Auth, header `Authorization: Bearer ...`).
//
// On garde volontairement minimal pour le POC : token, user id, email,
// nom (utile pour les écrans Settings). Le reste se rappelle via
// /api/auth/get-session quand on est en ligne.
import 'dart:convert';

class Session {
  const Session({
    required this.token,
    required this.userId,
    required this.email,
    required this.name,
  });

  final String token;
  final String userId;
  final String email;
  final String name;

  Map<String, dynamic> toJson() => {
        'token': token,
        'user_id': userId,
        'email': email,
        'name': name,
      };

  static Session fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String,
        userId: json['user_id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
      );

  String serialize() => jsonEncode(toJson());

  static Session deserialize(String raw) =>
      Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  Session copyWith({
    String? token,
    String? userId,
    String? email,
    String? name,
  }) =>
      Session(
        token: token ?? this.token,
        userId: userId ?? this.userId,
        email: email ?? this.email,
        name: name ?? this.name,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          token == other.token &&
          userId == other.userId &&
          email == other.email &&
          name == other.name;

  @override
  int get hashCode => Object.hash(token, userId, email, name);
}
