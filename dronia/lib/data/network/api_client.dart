import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../services/storage_service.dart';

/// Network exceptions
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = 'Unauthorized'])
    : super(message, statusCode: 401);
}

class NetworkException extends ApiException {
  NetworkException([String message = 'Network error']) : super(message);
}

class ServerException extends ApiException {
  ServerException([String message = 'Server error'])
    : super(message, statusCode: 500);
}

/// HTTP API Client for making REST API calls
class ApiClient {
  final http.Client _client;
  final StorageService _storage;

  static const Duration _timeout = Duration(
    milliseconds: AppConstants.apiTimeout,
  );

  ApiClient({http.Client? client, required StorageService storage})
    : _client = client ?? http.Client(),
      _storage = storage;

  /// Get authorization headers
  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Parse response and handle errors
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic data;

    try {
      if (response.body.isNotEmpty) {
        data = json.decode(response.body);
      }
    } catch (_) {
      data = response.body;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return data;
    }

    final message = data is Map
        ? (data['detail'] ??
              data['message'] ??
              data['error'] ??
              'Unknown error')
        : 'Request failed';

    switch (statusCode) {
      case 401:
        throw UnauthorizedException(message);
      case 403:
        throw ApiException('Forbidden', statusCode: statusCode, data: data);
      case 404:
        throw ApiException('Not found', statusCode: statusCode, data: data);
      case 422:
        throw ApiException(message, statusCode: statusCode, data: data);
      case 500:
      case 502:
      case 503:
        throw ServerException(message);
      default:
        throw ApiException(message, statusCode: statusCode, data: data);
    }
  }

  /// GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint').replace(
        queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
      );

      final headers = await _getHeaders(requiresAuth: requiresAuth);
      print('DEBUG API: GET $uri');
      print('DEBUG API: Headers: ${headers.keys.toList()}');

      final response = await _client
          .get(uri, headers: headers)
          .timeout(_timeout);

      print('DEBUG API: Response status: ${response.statusCode}');
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on http.ClientException {
      throw NetworkException('Connection failed');
    }
  }

  /// POST request
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);

      final response = await _client
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on http.ClientException {
      throw NetworkException('Connection failed');
    }
  }

  /// POST request with form data (application/x-www-form-urlencoded)
  Future<dynamic> postForm(
    String endpoint, {
    required Map<String, String> fields,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final headers = <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      };

      if (requiresAuth) {
        final token = await _storage.getToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }

      print('DEBUG API: POST FORM $uri');
      print('DEBUG API: Form fields: ${fields.keys.toList()}');

      final response = await _client
          .post(uri, headers: headers, body: fields)
          .timeout(_timeout);

      print('DEBUG API: Response status: ${response.statusCode}');
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on http.ClientException {
      throw NetworkException('Connection failed');
    }
  }

  /// PUT request
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);

      final response = await _client
          .put(uri, headers: headers, body: json.encode(body))
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on http.ClientException {
      throw NetworkException('Connection failed');
    }
  }

  /// PATCH request
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);

      final response = await _client
          .patch(uri, headers: headers, body: json.encode(body))
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on http.ClientException {
      throw NetworkException('Connection failed');
    }
  }

  /// DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final headers = await _getHeaders(requiresAuth: requiresAuth);

      print('DEBUG API: DELETE $uri');
      print('DEBUG API: Headers: ${headers.keys.toList()}');

      // DELETE with body requires using http.Request
      final request = http.Request('DELETE', uri);
      request.headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamedResponse = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      print('DEBUG API: DELETE Response status: ${response.statusCode}');
      print('DEBUG API: DELETE Response body: ${response.body}');

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on http.ClientException {
      throw NetworkException('Connection failed');
    }
  }

  /// Multipart POST request for file uploads
  Future<dynamic> uploadFile(
    String endpoint, {
    required File file,
    String fieldName = 'file',
    Map<String, String>? fields,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      if (requiresAuth) {
        final token = await _storage.getToken();
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, file.path),
      );

      // Add additional fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on http.ClientException {
      throw NetworkException('Connection failed');
    }
  }

  /// Close the client
  void dispose() {
    _client.close();
  }
}
