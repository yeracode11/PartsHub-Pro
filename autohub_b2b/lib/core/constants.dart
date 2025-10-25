/// App-wide constants
class AppConstants {
  // App info
  static const String appName = 'AutoHub B2B';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Platform for auto dismantlers, car services and car washes';

  // API endpoints
  static const String baseUrl = 'https://api.autohub.kz'; // TODO: Replace with actual API URL
  static const String apiVersion = 'v1';
  
  // Sync settings
  static const Duration syncInterval = Duration(minutes: 5);
  static const int maxSyncRetries = 3;
  static const Duration syncTimeout = Duration(seconds: 30);

  // Item conditions
  static const String conditionNew = 'new';
  static const String conditionUsed = 'used';
  static const String conditionRefurbished = 'refurbished';

  // Order statuses
  static const String orderStatusPending = 'pending';
  static const String orderStatusProcessing = 'processing';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusCancelled = 'cancelled';

  // Payment statuses
  static const String paymentStatusUnpaid = 'unpaid';
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusPartial = 'partial';

  // Movement types
  static const String movementTypeIn = 'in';
  static const String movementTypeOut = 'out';
  static const String movementTypeAdjustment = 'adjustment';

  // Item categories
  static const List<String> itemCategories = [
    'Двигатель',
    'Трансмиссия',
    'Подвеска',
    'Кузов',
    'Электрика',
    'Салон',
    'Другое',
  ];

  // User roles
  static const String roleOwner = 'owner';
  static const String roleManager = 'manager';
  static const String roleStorekeeper = 'storekeeper';
  static const String roleWorker = 'worker';

  // Business types
  static const String businessTypeDismantler = 'dismantler';
  static const String businessTypeService = 'service';
  static const String businessTypeCarwash = 'carwash';

  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;

  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 8.0;
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 100;
  static const int maxDescriptionLength = 500;
}

