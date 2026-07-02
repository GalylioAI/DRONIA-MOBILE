/// User model matching the Next.js / FastAPI backend schema.
class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final Location? location;
  final List<String> plantTypes;
  final String? profileImage;
  final double? totalSurface;
  final String? soilType;
  final UserRole role;
  final UserPlan plan;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.location,
    this.plantTypes = const [],
    this.profileImage,
    this.totalSurface,
    this.soilType,
    this.role = UserRole.user,
    this.plan = UserPlan.free,
  });

  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    if (first.isEmpty && last.isEmpty) return email.split('@').first;
    return '$first $last'.trim();
  }

  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      final first = firstName![0].toUpperCase();
      final last = (lastName != null && lastName!.isNotEmpty)
          ? lastName![0].toUpperCase()
          : '';
      return '$first$last';
    }
    return email.isNotEmpty ? email[0].toUpperCase() : 'U';
  }

  bool get isAdmin => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id']).toString(),
      email: json['email'] as String,
      firstName: (json['firstName'] ?? json['first_name']) as String?,
      lastName: (json['lastName'] ?? json['last_name']) as String?,
      phone: json['phone'] as String?,
      location: json['location'] != null
          ? Location.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      plantTypes:
          (json['plantTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      profileImage: json['profileImage'] as String?,
      totalSurface: (json['totalSurface'] as num?)?.toDouble(),
      soilType: json['soilType'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'user'),
      plan: UserPlan.fromString(json['plan'] as String? ?? 'free'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'location': location?.toJson(),
    'plantTypes': plantTypes,
    'profileImage': profileImage,
    'totalSurface': totalSurface,
    'soilType': soilType,
    'role': role.name,
    'plan': plan.name,
  };

  User copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    Location? location,
    List<String>? plantTypes,
    String? profileImage,
    double? totalSurface,
    String? soilType,
    UserRole? role,
    UserPlan? plan,
  }) {
    return User(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      plantTypes: plantTypes ?? this.plantTypes,
      profileImage: profileImage ?? this.profileImage,
      totalSurface: totalSurface ?? this.totalSurface,
      soilType: soilType ?? this.soilType,
      role: role ?? this.role,
      plan: plan ?? this.plan,
    );
  }
}

/// Role assigned to a user account.
enum UserRole {
  admin,
  user;

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

/// Location model for user location
class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

/// Login request model
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

/// Register request model matching backend
class RegisterRequest {
  final String email;
  final String password;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final Location? location;
  final List<String>? plantTypes;
  final String? profileImage;
  final double? totalSurface;
  final String? soilType;

  RegisterRequest({
    required this.email,
    required this.password,
    this.firstName,
    this.lastName,
    this.phone,
    this.location,
    this.plantTypes,
    this.profileImage,
    this.totalSurface,
    this.soilType,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (phone != null) 'phone': phone,
    if (location != null) 'location': location!.toJson(),
    if (plantTypes != null) 'plantTypes': plantTypes,
    if (profileImage != null) 'profileImage': profileImage,
    if (totalSurface != null) 'totalSurface': totalSurface,
    if (soilType != null) 'soilType': soilType,
  };
}

/// Update profile request model
class UpdateProfileRequest {
  final String? firstName;
  final String? lastName;
  final String? phone;
  final Location? location;
  final List<String>? plantTypes;
  final String? profileImage;
  final double? totalSurface;
  final String? soilType;

  UpdateProfileRequest({
    this.firstName,
    this.lastName,
    this.phone,
    this.location,
    this.plantTypes,
    this.profileImage,
    this.totalSurface,
    this.soilType,
  });

  Map<String, dynamic> toJson() => {
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (phone != null) 'phone': phone,
    if (location != null) 'location': location!.toJson(),
    if (plantTypes != null) 'plantTypes': plantTypes,
    if (profileImage != null) 'profileImage': profileImage,
    if (totalSurface != null) 'totalSurface': totalSurface,
    if (soilType != null) 'soilType': soilType,
  };
}
