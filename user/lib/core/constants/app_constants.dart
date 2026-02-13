// VIBRO Application Constants
class AppConstants {
  AppConstants._();

  // Application Info
  static const String appName = 'VIBRO';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'AI-Powered Name Detection & Wearable Alert System';

  // Detection Thresholds
  static const double minConfidenceThreshold = 0.40;
  static const double defaultConfidenceThreshold = 0.49;
  static const double maxConfidenceThreshold = 0.80;

  // Audio Recording
  static const int minAudioClips = 10;
  static const int maxAudioClipDuration = 300; // 5 minutes in seconds
  static const int audioSampleRate = 16000;

  // Model Training
  static const int augmentedSamplesPerClip = 10;
  static const int extraBaseSamples = 10;

  // Subscription Limits (Basic Tier)
  static const int basicMaxModels = 10;
  static const int basicMaxLocations = 15;

  // Subscription Limits (Premium Tier)
  static const int premiumMaxModels = 50;
  static const int premiumMaxLocations = 100;

  // BLE Configuration
  static const String bleDeviceName = 'VIBRO Ring';
  static const int bleScanTimeout = 30; // seconds
  static const int bleReconnectAttempts = 3;

  // Polling Intervals
  static const int modelStatusPollInterval = 25; // seconds
  static const int batteryStatusPollInterval = 60; // seconds

  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double cardPadding = 20.0;
  static const double cardRadius = 16.0;
  static const int animationDurationMs = 250;

  // Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyPhoneNumber = 'phone_number';
  static const String keyUsername = 'username';
  static const String keyPairedDeviceId = 'paired_device_id';
  static const String keyDetectionThreshold = 'detection_threshold';
  
  // Supabase Configuration
  static const String supabaseUrl = 'https://pqtjvdfcitdpveuqzgpk.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_QmBnPMkcqytnWVy3xLzERQ_-eWfnpdY';
  static const String supabaseProjectId = 'pqtjvdfcitdpveuqzgpk';
  
  // Authentication
  static const String authMethod = 'email'; // Email-based authentication
  
  // Storage Buckets
  static const String audioSubmissionsBucket = 'audio_submissions';
  static const String trainedModelsBucket = 'trained_models';
}

// Model Training Status
enum ModelStatus {
  pending,
  uploaded,
  processing,
  completed,
  failed,
}

// Subscription Tiers
enum SubscriptionTier {
  basic,
  premium,
}

// Detection States
enum DetectionState {
  idle,
  active,
  paused,
}

// BLE Connection States
enum BLEConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}
