class AppConfig {
  // Backend API Configuration
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = 'v1';

  // Sync Endpoints
  static const String syncUpload = '/api/$apiVersion/sync/upload';
  static const String syncDownload = '/api/$apiVersion/sync/download';
  static const String syncStatus = '/api/$apiVersion/sync/status';

  // Hazard Endpoints
  static const String hazardPredict = '/api/$apiVersion/hazards/predict';
  static const String hazardBatchPredict = '/api/$apiVersion/hazards/predict-batch';

  // Red Zone Endpoints
  static const String redZones = '/api/$apiVersion/red-zones';

  // Habitation Endpoints
  static const String habitations = '/api/$apiVersion/habitations';
  static const String habitationAssess = '/api/$apiVersion/habitations/assess';

  // Shelter Endpoints
  static const String shelters = '/api/$apiVersion/shelters';
  static const String shelterEvaluate = '/api/$apiVersion/shelters/evaluate';

  // Priority Endpoints
  static const String priorities = '/api/$apiVersion/priorities';
  static const String prioritiesImmediate = '/api/$apiVersion/priorities/immediate';

  // Data Endpoints
  static const String dataStatus = '/api/$apiVersion/data/status';

  // Time Horizon Categories
  static const String timeHorizonImmediate = 'IMMEDIATE';
  static const String timeHorizonShortTerm = 'SHORT_TERM';
  static const String timeHorizonMediumTerm = 'MEDIUM_TERM';

  // Priority Categories
  static const String priorityImmediate = 'IMMEDIATE';
  static const String priorityShortTerm = 'SHORT_TERM';
  static const String priorityMediumTerm = 'MEDIUM_TERM';

  // Path Status
  static const String pathClear = 'CLEAR';
  static const String pathBlocked = 'BLOCKED';
  static const String pathDamaged = 'DAMAGED';

  // Capacity Status
  static const String capacityLow = 'LOW';
  static const String capacityMedium = 'MEDIUM';
  static const String capacityHigh = 'HIGH';
  static const String capacityCritical = 'CRITICAL';

  // Hazard Types
  static const String hazardLandslide = 'LANDSLIDE';
  static const String hazardFlood = 'FLOOD';
  static const String hazardEarthquake = 'EARTHQUAKE';
  static const String hazardCyclone = 'CYCLONE';

  // Risk Levels
  static const String riskLow = 'LOW';
  static const String riskMedium = 'MEDIUM';
  static const String riskHigh = 'HIGH';
  static const String riskCritical = 'CRITICAL';

  // Shelter Types
  static const String shelterSchool = 'SCHOOL';
  static const String shelterCommunityCenter = 'COMMUNITY_CENTER';
  static const String shelterTemple = 'TEMPLE';
  static const String shelterGovtBuilding = 'GOVT_BUILDING';
}
