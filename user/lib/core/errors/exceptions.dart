// VIBRO Error Handling
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

// Authentication Errors
class AuthenticationException extends AppException {
  AuthenticationException({required super.message, super.code, super.originalError});
}

// Network Errors
class NetworkException extends AppException {
  NetworkException({required super.message, super.code, super.originalError});
}

// BLE Errors
class BLEException extends AppException {
  BLEException({required super.message, super.code, super.originalError});
}

// Model Training Errors
class ModelTrainingException extends AppException {
  ModelTrainingException({required super.message, super.code, super.originalError});
}

// Storage Errors
class StorageException extends AppException {
  StorageException({required super.message, super.code, super.originalError});
}

// Permission Errors
class PermissionException extends AppException {
  PermissionException({required super.message, super.code, super.originalError});
}
