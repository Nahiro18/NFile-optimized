import '../services/preferences_service.dart';

abstract class SettingsRepository {
  bool get isGridView;
  void setGridView(bool value);
  
  String get sortType;
  void setSortType(String value);

  bool get showHiddenFiles;
  void setShowHiddenFiles(bool value);

  // Add more as needed...
}

class SettingsRepositoryImpl implements SettingsRepository {
  @override
  bool get isGridView => PreferencesService.getIsGridView();
  
  @override
  void setGridView(bool value) => PreferencesService.saveIsGridView(value);
  
  @override
  String get sortType => PreferencesService.getSortType().name;
  
  @override
  void setSortType(String value) {
    // Basic mapping, in reality, use enum directly or map strings
  }

  @override
  bool get showHiddenFiles => PreferencesService.getShowHiddenFiles();
  
  @override
  void setShowHiddenFiles(bool value) => PreferencesService.saveShowHiddenFiles(value);
}
