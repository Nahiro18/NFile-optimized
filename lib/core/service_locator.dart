import 'package:get_it/get_it.dart';
import '../repositories/settings_repository.dart';
import '../repositories/file_repository.dart';
import 'events/app_event_bus.dart';

final GetIt locator = GetIt.instance;

void setupServiceLocator() {
  // Event Bus
  locator.registerLazySingleton<AppEventBus>(() => AppEventBus());

  // Repositories
  locator.registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl());
  locator.registerLazySingleton<FileRepository>(() => FileRepositoryImpl());
}
