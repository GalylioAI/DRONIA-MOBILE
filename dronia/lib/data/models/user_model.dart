/// User model representing authenticated user data
class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final UserPlan plan;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.plan = UserPlan.free,
    required this.createdAt,
    this.lastLoginAt,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final s = '$f$l'.toUpperCase();
    return s.isEmpty ? 'U' : s;
  }

  bool get isAdmin => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) {
    final first = (json['first_name'] ?? json['firstName'] ?? '') as String? ?? '';
    final last = (json['last_name'] ?? json['lastName'] ?? '') as String? ?? '';
    final created = json['created_at'] ?? json['createdAt'];
    DateTime parsedCreated;
    if (created is String) {
      parsedCreated = DateTime.tryParse(created) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }
    final lastLogin = json['last_login_at'] ?? json['lastLoginAt'];
    return User(
      id: (json['id'] ?? json['_id']).toString(),
      email: json['email'] as String? ?? '',
      firstName: first,
      lastName: last,
      phone: json['phone'] as String?,
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'] ?? json['profileImage']) as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'user'),
      plan: UserPlan.fromString(json['plan'] as String? ?? 'free'),
      createdAt: parsedCreated,
      lastLoginAt: lastLogin is String ? DateTime.tryParse(lastLogin) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role.name,
      'plan': plan.name,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarUrl,
    UserPlan? plan,
    UserRole? role,
  }) {
    return User(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      plan: plan ?? this.plan,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );
  }
}

/// User roles in the system
enum UserRole {
  admin,
  user,
  operator,
  engineer,
  client;

  static UserRole fromString(String value) {
    final v = value.toLowerCase();
    return UserRole.values.firstWhere(
      (e) => e.name == v,
      orElse: () => UserRole.user,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrateur';
      case UserRole.user:
        return 'Agriculteur';
      case UserRole.operator:
        return 'Opérateur';
      case UserRole.engineer:
        return 'Ingénieur';
      case UserRole.client:
        return 'Client';
    }
  }
}

/// Subscription plan tiers offered by DronIA.
enum UserPlan {
  free,
  premium,
  enterprise;

  static UserPlan fromString(String value) {
    final v = value.toLowerCase();
    return UserPlan.values.firstWhere(
      (e) => e.name == v,
      orElse: () => UserPlan.free,
    );
  }

  String get displayName {
    switch (this) {
      case UserPlan.free:
        return 'Gratuit';
      case UserPlan.premium:
        return 'Premium';
      case UserPlan.enterprise:
        return 'Entreprise';
    }
  }

  String get tagline {
    switch (this) {
      case UserPlan.free:
        return 'Pour découvrir DronIA';
      case UserPlan.premium:
        return 'Pour l\'exploitation au quotidien';
      case UserPlan.enterprise:
        return 'Pour les coopératives';
    }
  }

  List<String> get features {
    switch (this) {
      case UserPlan.free:
        return [
          '5 analyses IA par jour',
          'Cartographie 1 parcelle',
          'Météo locale et historique 7 jours',
        ];
      case UserPlan.premium:
        return [
          'Analyses IA illimitées',
          'Parcelles illimitées',
          'Indices satellite Sentinel-2 complets',
          'Assistant IA Clawdbot avec vision',
          'Génération de rapports PDF',
        ];
      case UserPlan.enterprise:
        return [
          'Toutes les fonctionnalités Premium',
          'Suivi multi-exploitations',
          'Support prioritaire',
          'Tableau de bord agronomique avancé',
        ];
    }
  }
}

/// Authentication tokens
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final access = (json['accessToken'] ?? json['access_token'] ?? json['token']) as String;
    final refresh = (json['refreshToken'] ?? json['refresh_token'] ?? access) as String;
    final exp = json['expires_at'] ?? json['expiresAt'];
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: exp is String ? DateTime.tryParse(exp) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    };
  }
}

/// Login request model
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

/// Register request model
class RegisterRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String? phone;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'first_name': firstName,
    'last_name': lastName,
    if (phone != null) 'phone': phone,
  };
}

/// Auth response containing user and tokens
class AuthResponse {
  final User user;
  final AuthTokens tokens;

  AuthResponse({required this.user, required this.tokens});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final tokensJson = json['tokens'];
    final Map<String, dynamic> tokenMap = tokensJson is Map<String, dynamic>
        ? tokensJson
        : {'accessToken': json['token'] as String? ?? ''};
    final userJson = json['user'];
    final User parsedUser = userJson is Map<String, dynamic>
        ? User.fromJson(userJson)
        : User(
            id: '',
            email: '',
            firstName: '',
            lastName: '',
            role: UserRole.user,
            plan: UserPlan.free,
            createdAt: DateTime.now(),
          );
    return AuthResponse(
      user: parsedUser,
      tokens: AuthTokens.fromJson(tokenMap),
    );
  }
}
