import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_strings.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/file_manager_provider.dart';
import '../screens/global_search_screen.dart';
import '../screens/more_settings_screen.dart';
import '../screens/vault_lock_screen.dart';
import '../screens/ftp_server_screen.dart';
import '../../services/network_connections_service.dart';
import '../screens/network_connection_wizard_screen.dart';
import '../screens/remote_explorer_screen.dart';
import '../screens/about_screen.dart';
import '../screens/web_sharing_screen.dart';
import '../../providers/media_provider.dart';
import 'quick_categories_grid.dart';
import 'nfile_icon.dart';
import '../screens/internal_file_picker_screen.dart';
import '../screens/recycle_bin_screen.dart';

class NFileDrawer extends StatelessWidget {
  final VoidCallback toggleTheme;
  final Function(int)? onNavigateTab;

  const NFileDrawer({super.key, required this.toggleTheme, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fileManager = context.watch<FileManagerProvider>();
    final mediaProvider = context.watch<MediaProvider>();
    final connections = NetworkConnectionsService.getConnections();
    final allCategoriesMap = QuickCategoriesGrid.getAllCategoriesMap(context, isDark, onNavigateTab ?? (index) {});
    final activeList = mediaProvider.categoryOrder
        .where((label) => mediaProvider.activeCategories.contains(label) && allCategoriesMap.containsKey(label))
        .map((label) => allCategoriesMap[label]!)
        .toList();

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header Banner
            _buildDrawerHeader(context, theme, isDark),
            const SizedBox(height: 8),

            // Scrollable Menu Items
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context, AppStrings.current.navigation),
                    _buildDrawerTile(
                      context,
                      icon: Broken.home,
                      title: AppStrings.current.home,
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        onNavigateTab?.call(0);
                      },
                    ),
                    for (final vol in fileManager.storageVolumes)
                      _buildDrawerTile(
                        context,
                        icon: vol.isInternal ? Broken.folder_open : Icons.sd_storage_rounded,
                        title: vol.name,
                        isSelected: fileManager.rootPath == vol.path,
                        onTap: () {
                          Navigator.pop(context);
                          fileManager.setRootPath(vol.path);
                          fileManager.loadDirectory(vol.path);
                          onNavigateTab?.call(1);
                        },
                      ),
                    _buildDrawerTile(
                      context,
                      icon: Broken.cpu,
                      title: AppStrings.current.systemRoot,
                      isSelected: fileManager.rootPath == '/',
                      onTap: () {
                        Navigator.pop(context);
                        fileManager.setRootPath('/');
                        fileManager.loadDirectory('/');
                        onNavigateTab?.call(1);
                      },
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Broken.search_normal,
                      title: AppStrings.current.globalSearch,
                      onTap: () {
                        Navigator.pop(context);
                        onNavigateTab?.call(1);
                        final provider = context.read<FileManagerProvider>();
                        if (!provider.activeTab.isSearchActive) {
                          provider.toggleSearchForActiveTab();
                        }
                        provider.activeTab.currentPath = '/storage/emulated/0';
                        provider.executeSearchForTab(
                          provider.activeTabIndex,
                          '',
                          'All',
                          context.read<MediaProvider>(),
                        );
                      },
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Broken.trash,
                      title: AppStrings.current.recycleBin,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecycleBinScreen()));
                      },
                    ),

                    _buildDivider(context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: NfileIcon(Broken.wifi_square, size: 22, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                          title: Text(
                            AppStrings.current.serversAndTools,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.9)),
                          ),
                          iconColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.primary,
                          collapsedIconColor: theme.colorScheme.onSurface.withOpacity(0.8),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                          children: [
                            _buildDrawerTile(
                              context,
                              icon: Broken.lock,
                              title: AppStrings.current.privateWallet,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultLockScreen()));
                              },
                            ),
                            _buildDrawerTile(
                              context,
                              icon: Broken.wifi,
                              title: AppStrings.current.ftpServer,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const FtpServerScreen()));
                              },
                            ),
                            _buildDrawerTile(
                              context,
                              icon: Icons.language_rounded,
                              title: AppStrings.current.webSharing,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const WebSharingScreen()));
                              },
                            ),
                            ...connections.map((conn) {
                              IconData iconData;
                              switch (conn.type) {
                                case 'LAN/SMB':
                                  iconData = Icons.dns_rounded;
                                  break;
                                case 'FTP':
                                  iconData = Icons.swap_horizontal_circle_rounded;
                                  break;
                                case 'SFTP':
                                  iconData = Icons.vpn_lock_rounded;
                                  break;
                                case 'WebDav':
                                  iconData = Icons.web_rounded;
                                  break;
                                default:
                                  iconData = Broken.wifi;
                              }
                              return _buildDrawerTile(
                                context,
                                icon: iconData,
                                title: conn.name,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RemoteExplorerScreen(connection: conn),
                                    ),
                                  );
                                },
                              );
                            }),
                            _buildDrawerTile(
                              context,
                              icon: Icons.add_link_rounded,
                              title: AppStrings.current.addRemoteConnection,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NetworkConnectionWizardScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                      child: Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: NfileIcon(Icons.category_rounded, size: 22, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                          title: Text(
                            AppStrings.current.quickCategories,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.9)),
                          ),
                          iconColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.primary,
                          collapsedIconColor: theme.colorScheme.onSurface.withOpacity(0.8),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                          children: [
                            ...activeList.map((cat) {
                              final label = cat['label'] as String;
                              final icon = cat['icon'] as IconData;
                              final action = cat['action'] as VoidCallback;

                              return _buildDrawerTile(
                                context,
                                icon: icon,
                                title: label,
                                onTap: () {
                                  Navigator.pop(context);
                                  action();
                                },
                              );
                            }),
                            _buildDrawerTile(
                              context,
                              icon: Icons.add_rounded,
                              title: AppStrings.current.addShortcut,
                              onTap: () async {
                                final fileManager = context.read<FileManagerProvider>();
                                final mediaProvider = context.read<MediaProvider>();
                                final paths = await InternalFilePickerScreen.show(context, rootPath: fileManager.rootPath);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                if (paths != null && paths.isNotEmpty) {
                                  for (final p in paths) {
                                    mediaProvider.addCustomShortcut(p);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    _buildDivider(context),
                    _buildSectionTitle(context, AppStrings.current.customizationAndSettings),
                    _buildDrawerTile(
                      context,
                      icon: isDark ? Broken.sun_1 : Broken.moon,
                      title: isDark ? AppStrings.current.lightMode : AppStrings.current.darkMode,
                      trailing: Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: isDark,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (_) => toggleTheme(),
                        ),
                      ),
                      onTap: toggleTheme,
                    ),

                    _buildDrawerTile(
                      context,
                      icon: Broken.setting_2,
                      title: AppStrings.current.moreSettings,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MoreSettingsScreen()));
                      },
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Broken.info_circle,
                      title: AppStrings.current.aboutNFile,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutNFileScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Footer Version Info
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                AppStrings.current.nfileVersion,
                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: NfileIcon(Broken.folder, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.current.appTitle,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.current.appSubtitle,
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 12.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Material(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.colorScheme.primary.withOpacity(0.15),
          highlightColor: theme.colorScheme.primary.withOpacity(0.08),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: trailing != null ? 4.0 : 12.0),
            child: Row(
              children: [
                NfileIcon(icon, size: 22, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.8)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.9)),
                  ),
                ),
                // ignore: use_null_aware_elements
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1),
    );
  }

}
