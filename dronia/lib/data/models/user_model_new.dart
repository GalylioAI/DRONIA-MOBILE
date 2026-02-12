/// User model matching the Next.js backend schema
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
    return email[0].toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] as String? ?? json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
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
    );
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
