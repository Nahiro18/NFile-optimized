import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../widgets/quick_categories_grid.dart';
import '../../services/preferences_service.dart';
import '../widgets/nfile_icon.dart';
import '../../services/recycle_bin_service.dart';
import 'package:path/path.dart' as p;
import 'internal_file_picker_screen.dart';
import 'backup_settings_screen.dart';
import '../../services/settings_backup_service.dart';
import '../../core/app_strings.dart';

class MoreSettingsScreen extends StatefulWidget {
  const MoreSettingsScreen({super.key});

  @override
  State<MoreSettingsScreen> createState() => _MoreSettingsScreenState();
}

class _MoreSettingsScreenState extends State<MoreSettingsScreen> {
  bool _preferFolders = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _preferFolders = PreferencesService.getPreferFoldersInMedia();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _shouldShow(String title, String subtitle) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return title.toLowerCase().contains(query) || subtitle.toLowerCase().contains(query);
  }

  bool _shouldShowHeader(List<bool> visibilities) {
    if (_searchQuery.isEmpty) return true;
    return visibilities.contains(true);
  }

  Widget _buildCategoryCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget targetScreen,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: theme.colorScheme.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetScreen),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    // Visibilities for global search filtering
    final showAddressBarVis = _shouldShow(AppStrings.current.showAddressBar, AppStrings.current.showAddressBarSub);
    final preferFoldersVis = _shouldShow(AppStrings.current.defaultAlbumView, AppStrings.current.defaultAlbumViewSub);
    final hideNavBarVis = _shouldShow(AppStrings.current.hideAndroidNavBar, AppStrings.current.hideAndroidNavBarSub);
    final resetViewersVis = _shouldShow(AppStrings.current.resetDefaultViewers, AppStrings.current.resetDefaultViewersSub);
    final skipDialogVis = _shouldShow(AppStrings.current.skipOpenWithDialog, AppStrings.current.skipOpenWithDialogSub);
    final defaultBrowseVis = _shouldShow(AppStrings.current.defaultToBrowseScreen, AppStrings.current.defaultToBrowseScreenSub);
    final showFloatingVis = _shouldShow(AppStrings.current.showFloatingButton, AppStrings.current.showFloatingButtonSub);
    final showHiddenVis = _shouldShow(AppStrings.current.showHiddenFiles, AppStrings.current.showHiddenFilesSub);
    final folderFileCountVis = _shouldShow(AppStrings.current.showFolderFileCount, AppStrings.current.showFolderFileCountSub);
    final use24HourVis = _shouldShow(AppStrings.current.use24HourFormat, AppStrings.current.use24HourFormatSub);
    final hideTimeDateVis = _shouldShow(AppStrings.current.hideTimeDate, AppStrings.current.hideTimeDateSub);
    final folderContentsVis = _shouldShow(AppStrings.current.showFolderContentCount, AppStrings.current.showFolderContentCountSub);
    final folderSizesVis = _shouldShow(AppStrings.current.showFolderSize, AppStrings.current.showFolderSizeSub);
    final bottomActionBarVis = _shouldShow(AppStrings.current.showBottomNavBar, AppStrings.current.showBottomNavBarSub);
    final hideActionTextVis = _shouldShow(AppStrings.current.hideActionBarLabels, AppStrings.current.hideActionBarLabelsSub);
    final showHomeBrowseNavVis = _shouldShow(AppStrings.current.showHomeBrowseBar, AppStrings.current.showHomeBrowseBarSub);
    final highlightFolderVis = _shouldShow(AppStrings.current.highlightExitedFolder, AppStrings.current.highlightExitedFolderSub);
    final mediaPreviewsVis = _shouldShow(AppStrings.current.showMediaPreviews, AppStrings.current.showMediaPreviewsSub);
    final adaptiveNamesVis = _shouldShow(AppStrings.current.adaptiveMultiLine, AppStrings.current.adaptiveMultiLineSub);
    final hideActionButtonsVis = _shouldShow(AppStrings.current.hide3DotButtons, AppStrings.current.hide3DotButtonsSub);
    final trailingInfoVis = fileManager.hideActionMenuButtons && _shouldShow(AppStrings.current.threeDotDisabledInfo, AppStrings.current.threeDotDisabledInfoSub);
    final dragDropVis = _shouldShow(AppStrings.current.enableDragAndDrop, AppStrings.current.enableDragAndDropSub);
    final confirmDragVis = fileManager.enableDragDrop && _shouldShow(AppStrings.current.confirmDragDrop, AppStrings.current.confirmDragDropSub);
    final multipleTabsVis = _shouldShow(AppStrings.current.enableMultipleTabs, AppStrings.current.enableMultipleTabsSub);
    final splitScreenVis = _shouldShow(AppStrings.current.enableSplitScreen, AppStrings.current.enableSplitScreenSub);
    final disableLeftBackVis = _shouldShow(AppStrings.current.preventLeftBackGesture, AppStrings.current.preventLeftBackGestureSub);
    final rememberLastFolderVis = _shouldShow(AppStrings.current.rememberLastFolder, AppStrings.current.rememberLastFolderSub);
    final hideNavLabelsVis = _shouldShow(AppStrings.current.hideNavLabels, AppStrings.current.hideNavLabelsSub);
    final exitOptionVis = _shouldShow(AppStrings.current.appExitBehavior, AppStrings.current.appExitBehaviorSub);

    final generalStartupList = [
      defaultBrowseVis,
      rememberLastFolderVis,
      showHomeBrowseNavVis,
      hideNavLabelsVis,
      hideNavBarVis,
      disableLeftBackVis,
      exitOptionVis,
    ];

    final fileExplorerList = [
      showAddressBarVis,
      showFloatingVis,
      showHiddenVis,
      highlightFolderVis,
      multipleTabsVis,
      splitScreenVis,
      dragDropVis,
      confirmDragVis,
    ];

    final listLayoutList = [
      folderFileCountVis,
      folderContentsVis,
      folderSizesVis,
      use24HourVis,
      hideTimeDateVis,
      adaptiveNamesVis,
      hideActionButtonsVis,
      trailingInfoVis,
    ];

    final mediaActionsList = [
      preferFoldersVis,
      mediaPreviewsVis,
      skipDialogVis,
      resetViewersVis,
    ];

    final selectionActionBarList = [
      bottomActionBarVis,
      hideActionTextVis,
    ];

    final recycleBinVis = _shouldShow(AppStrings.current.enableRecycleBin, AppStrings.current.enableRecycleBinSub);
    final autoDeleteDurationVis = RecycleBinService.isEnabled() && _shouldShow(AppStrings.current.autoDeleteTrashDuration, _getAutoDeleteDaysLabel(RecycleBinService.getAutoDeleteDays()));
    final recycleBinList = [recycleBinVis, autoDeleteDurationVis];

    final accentColorVis = _shouldShow(AppStrings.current.accentColorTheme, _getAccentColorLabel(fileManager.accentColorOption));
    final folderIconVis = _shouldShow(AppStrings.current.folderIconStyle, _getFolderIconLabel(fileManager.folderIconOption));
    final menuIconStyleVis = _shouldShow(AppStrings.current.appDrawerButtonStyle, _getMenuIconStyleLabel(fileManager.menuIconStyle));
    final amoledVis = _shouldShow(AppStrings.current.amoledBlackMode, AppStrings.current.amoledBlackModeSub);
    final appIconVis = _shouldShow(AppStrings.current.appIcon, _getAppIconLabel(fileManager.activeAppIcon));
    final typographyVis = _shouldShow(AppStrings.current.appTypography, _getFontFamilyLabel(fileManager.fontFamilyOption));
    final appearanceList = [accentColorVis, folderIconVis, menuIconStyleVis, amoledVis, appIconVis, typographyVis];

    final customizeShortcutsVis = _shouldShow(AppStrings.current.customizeShortcuts, AppStrings.current.customizeShortcutsSub);
    final showRecentVis = _shouldShow(AppStrings.current.showRecentFiles, AppStrings.current.showRecentFilesSub);
    final homeScreenList = [customizeShortcutsVis, showRecentVis];

    final backupSettingsVis = _shouldShow(AppStrings.current.backupSettings, AppStrings.current.backupSettingsSub);
    final restoreSettingsVis = _shouldShow(AppStrings.current.restoreSettings, AppStrings.current.restoreSettingsSub);

    final hasAnyMatch = generalStartupList.contains(true) ||
        fileExplorerList.contains(true) ||
        listLayoutList.contains(true) ||
        mediaActionsList.contains(true) ||
        selectionActionBarList.contains(true) ||
        recycleBinList.contains(true) ||
        appearanceList.contains(true) ||
        homeScreenList.contains(true) ||
        backupSettingsVis ||
        restoreSettingsVis;

    return PopScope(
      canPop: !_isSearching,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.current.searchSettings,
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                )
              : Text(AppStrings.current.moreSettings),
          leading: IconButton(
            icon: const NfileIcon(Broken.arrow_left),
            onPressed: () {
              if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  setState(() {
                    if (_searchController.text.isEmpty) {
                      _isSearching = false;
                    } else {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              )
            else
              IconButton(
                icon: const Icon(Broken.search_normal),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            children: [
              if (_searchQuery.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, left: 4.0),
                  child: Text(
                    AppStrings.current.settingsCategories,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.setting_2,
                  title: AppStrings.current.generalAndBehavior,
                  subtitle: AppStrings.current.generalAndBehaviorSub,
                  targetScreen: const GeneralSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.colorfilter,
                  title: AppStrings.current.appearanceAndThemes,
                  subtitle: AppStrings.current.appearanceAndThemesSub,
                  targetScreen: const AppearanceSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.folder_open,
                  title: AppStrings.current.fileExplorerOptions,
                  subtitle: AppStrings.current.fileExplorerOptionsSub,
                  targetScreen: const ExplorerSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.text,
                  title: AppStrings.current.listAndLayout,
                  subtitle: AppStrings.current.listAndLayoutSub,
                  targetScreen: const LayoutSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.image,
                  title: AppStrings.current.mediaPreferences,
                  subtitle: AppStrings.current.mediaPreferencesSub,
                  targetScreen: const MediaSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.setting_3,
                  title: AppStrings.current.fileActionsAndViewers,
                  subtitle: AppStrings.current.fileActionsAndViewersSub,
                  targetScreen: const ActionsSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.trash,
                  title: AppStrings.current.recycleBinTrash,
                  subtitle: AppStrings.current.recycleBinTrashSub,
                  targetScreen: const TrashSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.document_upload,
                  title: AppStrings.current.backupAndRestore,
                  subtitle: AppStrings.current.backupAndRestoreSub,
                  targetScreen: const BackupSettingsScreen(),
                ),
              ] else ...[
                if (!hasAnyMatch) ...[
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Broken.search_normal,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppStrings.current.noSettingsFound,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.current.trySearchingAnotherKeyword,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (_shouldShowHeader(generalStartupList) || _shouldShowHeader(selectionActionBarList) || _shouldShowHeader(homeScreenList)) ...[
                    _buildSectionHeader(theme, AppStrings.current.generalAndBehavior),
                    if (defaultBrowseVis)
                      SettingsTile(
                        icon: Broken.folder_favorite,
                        title: AppStrings.current.defaultToBrowseScreen,
                        subtitle: AppStrings.current.defaultToBrowseScreenSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.defaultToBrowseScreen,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleDefaultToBrowseScreen(),
                          ),
                        ),
                        onTap: () => fileManager.toggleDefaultToBrowseScreen(),
                      ),
                    if (rememberLastFolderVis)
                      SettingsTile(
                        icon: Broken.folder_open,
                        title: AppStrings.current.rememberLastFolder,
                        subtitle: AppStrings.current.rememberLastFolderSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.rememberLastFolder,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleRememberLastFolder(),
                          ),
                        ),
                        onTap: () => fileManager.toggleRememberLastFolder(),
                      ),
                    if (showHomeBrowseNavVis)
                      SettingsTile(
                        icon: Broken.menu,
                        title: AppStrings.current.showHomeBrowseBar,
                        subtitle: AppStrings.current.showHomeBrowseBarSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showHomeBrowseNav,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleShowHomeBrowseNav(),
                          ),
                        ),
                        onTap: () => fileManager.toggleShowHomeBrowseNav(),
                      ),
                    if (hideNavLabelsVis)
                      SettingsTile(
                        icon: Broken.menu_1,
                        title: AppStrings.current.hideNavLabels,
                        subtitle: AppStrings.current.hideNavLabelsSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideNavLabels,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideNavLabels(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideNavLabels(),
                      ),
                    if (hideNavBarVis)
                      SettingsTile(
                        icon: Icons.android,
                        title: AppStrings.current.hideAndroidNavBar,
                        subtitle: AppStrings.current.hideAndroidNavBarSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideNavigationBar,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideNavigationBar(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideNavigationBar(),
                      ),
                    if (disableLeftBackVis)
                      SettingsTile(
                        icon: Icons.gesture,
                        title: AppStrings.current.preventLeftBackGesture,
                        subtitle: AppStrings.current.preventLeftBackGestureSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.disableLeftBackGesture,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleDisableLeftBackGesture(),
                          ),
                        ),
                        onTap: () => fileManager.toggleDisableLeftBackGesture(),
                      ),
                    if (exitOptionVis)
                      SettingsTile(
                        icon: Icons.logout_rounded,
                        title: AppStrings.current.appExitBehavior,
                        subtitle: fileManager.exitOption == 'confirm'
                            ? AppStrings.current.showConfirmationDialog
                            : 'Double-press back button to exit',
                        onTap: () => _showExitOptionPickerDialog(context, fileManager, theme),
                      ),
                    if (bottomActionBarVis)
                      SettingsTile(
                        icon: Broken.menu,
                        title: AppStrings.current.showBottomNavBar,
                        subtitle: AppStrings.current.showBottomNavBarSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showBottomActionBar,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleBottomActionBar(),
                          ),
                        ),
                        onTap: () => fileManager.toggleBottomActionBar(),
                      ),
                    if (hideActionTextVis)
                      SettingsTile(
                        icon: Icons.label_off_rounded,
                        title: AppStrings.current.hideActionBarLabels,
                        subtitle: AppStrings.current.hideActionBarLabelsSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideActionText,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideActionText(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideActionText(),
                      ),
                    if (customizeShortcutsVis)
                      SettingsTile(
                        icon: Broken.setting_2,
                        title: AppStrings.current.customizeShortcuts,
                        subtitle: AppStrings.current.customizeShortcutsSub,
                        onTap: () => QuickCategoriesGrid.showCustomizeDialog(context),
                      ),
                    if (showRecentVis)
                      SettingsTile(
                        icon: Broken.clock,
                        title: AppStrings.current.showRecentFiles,
                        subtitle: AppStrings.current.showRecentFilesSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showRecentFiles,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleShowRecentFiles(),
                          ),
                        ),
                        onTap: () => fileManager.toggleShowRecentFiles(),
                      ),
                  ],
                  if (_shouldShowHeader(appearanceList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, AppStrings.current.appearanceAndThemes),
                    if (accentColorVis)
                      SettingsTile(
                        icon: Broken.colorfilter,
                        title: AppStrings.current.accentColorTheme,
                        subtitle: _getAccentColorLabel(fileManager.accentColorOption),
                        onTap: () => _showThemePickerDialog(context, fileManager, theme),
                      ),
                    if (folderIconVis)
                      SettingsTile(
                        icon: FileUtils.getFolderIcon(fileManager.folderIconOption),
                        title: AppStrings.current.folderIconStyle,
                        subtitle: _getFolderIconLabel(fileManager.folderIconOption),
                        onTap: () => _showFolderIconPickerDialog(context, fileManager, theme),
                      ),
                    if (menuIconStyleVis)
                      SettingsTile(
                        icon: Broken.category,
                        title: AppStrings.current.appDrawerButtonStyle,
                        subtitle: _getMenuIconStyleLabel(fileManager.menuIconStyle),
                        onTap: () => _showMenuIconStylePickerDialog(context, fileManager, theme),
                      ),
                    if (amoledVis)
                      SettingsTile(
                        icon: Broken.moon,
                        title: AppStrings.current.amoledBlackMode,
                        subtitle: AppStrings.current.amoledBlackModeSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.amoledMode,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleAmoledMode(),
                          ),
                        ),
                        onTap: () => fileManager.toggleAmoledMode(),
                      ),
                    if (appIconVis)
                      SettingsTile(
                        icon: Broken.category,
                        title: AppStrings.current.appIcon,
                        subtitle: _getAppIconLabel(fileManager.activeAppIcon),
                        onTap: () => _showAppIconPickerDialog(context, fileManager, theme),
                      ),
                    if (typographyVis)
                      SettingsTile(
                        icon: Broken.text,
                        title: AppStrings.current.appTypography,
                        subtitle: _getFontFamilyLabel(fileManager.fontFamilyOption),
                        onTap: () => _showFontFamilyPickerDialog(context, fileManager, theme),
                      ),
                  ],
                  if (_shouldShowHeader(fileExplorerList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, 'File Explorer & Navigation'),
                    if (showAddressBarVis)
                      SettingsTile(
                        icon: Broken.edit,
                        title: AppStrings.current.showAddressBar,
                        subtitle: AppStrings.current.showAddressBarSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showAddressBar,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleShowAddressBar(),
                          ),
                        ),
                        onTap: () => fileManager.toggleShowAddressBar(),
                      ),
                    if (showFloatingVis)
                      SettingsTile(
                        icon: Broken.add_square,
                        title: AppStrings.current.showFloatingButton,
                        subtitle: AppStrings.current.showFloatingButtonSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showFloatingAddButton,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleFloatingAddButton(),
                          ),
                        ),
                        onTap: () => fileManager.toggleFloatingAddButton(),
                      ),
                    if (showHiddenVis)
                      SettingsTile(
                        icon: Broken.folder_open,
                        title: AppStrings.current.showHiddenFiles,
                        subtitle: AppStrings.current.showHiddenFilesSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showHiddenFiles,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHiddenFiles(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHiddenFiles(),
                      ),
                    if (highlightFolderVis)
                      SettingsTile(
                        icon: Broken.colorfilter,
                        title: AppStrings.current.highlightExitedFolder,
                        subtitle: AppStrings.current.highlightExitedFolderSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.enableFolderHighlight,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleEnableFolderHighlight(),
                          ),
                        ),
                        onTap: () => fileManager.toggleEnableFolderHighlight(),
                      ),
                    if (multipleTabsVis)
                      SettingsTile(
                        icon: Broken.category,
                        title: AppStrings.current.enableMultipleTabs,
                        subtitle: AppStrings.current.enableMultipleTabsSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.enableMultipleTabs,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleMultipleTabs(),
                          ),
                        ),
                        onTap: () => fileManager.toggleMultipleTabs(),
                      ),
                    if (splitScreenVis)
                      SettingsTile(
                        icon: Icons.splitscreen,
                        title: AppStrings.current.enableSplitScreen,
                        subtitle: AppStrings.current.enableSplitScreenSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.enableSplitScreen,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleSplitScreen(),
                          ),
                        ),
                        onTap: () => fileManager.toggleSplitScreen(),
                      ),
                    if (dragDropVis)
                      SettingsTile(
                        icon: Broken.folder_connection,
                        title: AppStrings.current.enableDragAndDrop,
                        subtitle: AppStrings.current.enableDragAndDropSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.enableDragDrop,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleEnableDragDrop(),
                          ),
                        ),
                        onTap: () => fileManager.toggleEnableDragDrop(),
                      ),
                    if (confirmDragVis)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: SettingsTile(
                          icon: Broken.task_square,
                          title: AppStrings.current.confirmDragDrop,
                          subtitle: AppStrings.current.confirmDragDropSub,
                          trailing: Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: fileManager.showDragDropDialog,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (_) => fileManager.toggleShowDragDropDialog(),
                            ),
                          ),
                          onTap: () => fileManager.toggleShowDragDropDialog(),
                        ),
                      ),
                  ],
                  if (_shouldShowHeader(listLayoutList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, AppStrings.current.listAndLayout),
                    if (folderFileCountVis)
                      SettingsTile(
                        icon: Broken.document_text_1,
                        title: AppStrings.current.showFolderFileCount,
                        subtitle: AppStrings.current.showFolderFileCountSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showFolderFileCount,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleFolderFileCount(),
                          ),
                        ),
                        onTap: () => fileManager.toggleFolderFileCount(),
                      ),
                    if (folderContentsVis)
                      SettingsTile(
                        icon: Broken.folder_open,
                        title: AppStrings.current.showFolderContentCount,
                        subtitle: AppStrings.current.showFolderContentCountSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showFolderContentsCount,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleFolderContentsCount(),
                          ),
                        ),
                        onTap: () => fileManager.toggleFolderContentsCount(),
                      ),
                    if (folderSizesVis)
                      SettingsTile(
                        icon: Broken.document_text_1,
                        title: AppStrings.current.showFolderSize,
                        subtitle: AppStrings.current.showFolderSizeSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showFolderSizes,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleShowFolderSizes(),
                          ),
                        ),
                        onTap: () => fileManager.toggleShowFolderSizes(),
                      ),
                    if (use24HourVis)
                      SettingsTile(
                        icon: Icons.access_time_rounded,
                        title: AppStrings.current.use24HourFormat,
                        subtitle: AppStrings.current.use24HourFormatSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.use24HourFormat,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleUse24HourFormat(),
                          ),
                        ),
                        onTap: () => fileManager.toggleUse24HourFormat(),
                      ),
                    if (hideTimeDateVis)
                      SettingsTile(
                        icon: Icons.visibility_off_rounded,
                        title: AppStrings.current.hideTimeDate,
                        subtitle: AppStrings.current.hideTimeDateSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideTimeAndDate,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideTimeAndDate(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideTimeAndDate(),
                      ),
                    if (adaptiveNamesVis)
                      SettingsTile(
                        icon: Broken.text,
                        title: AppStrings.current.adaptiveMultiLine,
                        subtitle: AppStrings.current.adaptiveMultiLineSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.adaptiveMultiLineNames,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleAdaptiveMultiLineNames(),
                          ),
                        ),
                        onTap: () => fileManager.toggleAdaptiveMultiLineNames(),
                      ),
                    if (hideActionButtonsVis)
                      SettingsTile(
                        icon: Icons.more_vert_rounded,
                        title: AppStrings.current.hide3DotButtons,
                        subtitle: AppStrings.current.hide3DotButtonsSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideActionMenuButtons,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideActionMenuButtons(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideActionMenuButtons(),
                      ),
                    if (trailingInfoVis)
                      SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: AppStrings.current.threeDotDisabledInfo,
                        subtitle: _getTrailingInfoTypeLabel(fileManager.trailingInfoType),
                        onTap: () => _showTrailingInfoTypePickerDialog(context, fileManager, theme),
                      ),
                  ],
                  if (_shouldShowHeader(mediaActionsList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, 'Media & Default Actions'),
                    if (preferFoldersVis)
                      SettingsTile(
                        icon: Broken.folder_2,
                        title: AppStrings.current.defaultAlbumView,
                        subtitle: AppStrings.current.defaultAlbumViewSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _preferFolders,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                _preferFolders = val;
                              });
                              PreferencesService.savePreferFoldersInMedia(val);
                            },
                          ),
                        ),
                        onTap: () {
                          final val = !_preferFolders;
                          setState(() {
                            _preferFolders = val;
                          });
                          PreferencesService.savePreferFoldersInMedia(val);
                        },
                      ),
                    if (mediaPreviewsVis)
                      SettingsTile(
                        icon: Broken.image,
                        title: AppStrings.current.showMediaPreviews,
                        subtitle: AppStrings.current.showMediaPreviewsSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showMediaPreviews,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleMediaPreviews(),
                          ),
                        ),
                        onTap: () => fileManager.toggleMediaPreviews(),
                      ),
                    if (skipDialogVis)
                      SettingsTile(
                        icon: Broken.setting_3,
                        title: AppStrings.current.skipOpenWithDialog,
                        subtitle: AppStrings.current.skipOpenWithDialogSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.skipOpenWithDialog,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleSkipOpenWithDialog(),
                          ),
                        ),
                        onTap: () => fileManager.toggleSkipOpenWithDialog(),
                      ),
                    if (resetViewersVis)
                      SettingsTile(
                        icon: Broken.refresh_2,
                        title: AppStrings.current.resetDefaultViewers,
                        subtitle: AppStrings.current.resetDefaultViewersSub,
                        onTap: () async {
                          await PreferencesService.clearAllDefaultOpenActions();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.current.viewerChoicesReset),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                  ],
                  if (_shouldShowHeader(recycleBinList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, AppStrings.current.recycleBinTrash),
                    if (recycleBinVis)
                      SettingsTile(
                        icon: Broken.trash,
                        title: AppStrings.current.enableRecycleBin,
                        subtitle: AppStrings.current.enableRecycleBinSub,
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: RecycleBinService.isEnabled(),
                            activeColor: theme.colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                RecycleBinService.setEnabled(val);
                              });
                            },
                          ),
                        ),
                        onTap: () {
                          final val = !RecycleBinService.isEnabled();
                          setState(() {
                            RecycleBinService.setEnabled(val);
                          });
                        },
                      ),
                    if (autoDeleteDurationVis)
                      SettingsTile(
                        icon: Icons.access_time_rounded,
                        title: AppStrings.current.autoDeleteTrashDuration,
                        subtitle: _getAutoDeleteDaysLabel(RecycleBinService.getAutoDeleteDays()),
                        onTap: () => _showAutoDeleteDaysPickerDialog(context, theme, () {
                          setState(() {});
                        }),
                      ),
                  ],
                  if (_shouldShowHeader([backupSettingsVis, restoreSettingsVis])) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, AppStrings.current.backupAndRestore),
                    if (backupSettingsVis)
                      SettingsTile(
                        icon: Broken.document_upload,
                        title: AppStrings.current.backupSettings,
                        subtitle: AppStrings.current.backupSettingsSub,
                        onTap: () => SettingsBackupService.backupSettings(context),
                      ),
                    if (restoreSettingsVis)
                      SettingsTile(
                        icon: Broken.document_download,
                        title: AppStrings.current.restoreSettings,
                        subtitle: AppStrings.current.restoreSettingsSub,
                        onTap: () async {
                          final pickedPaths = await InternalFilePickerScreen.show(
                            context,
                            rootPath: '/storage/emulated/0',
                            pickDirectory: false,
                          );

                          if (pickedPaths != null && pickedPaths.isNotEmpty) {
                            final selectedPath = pickedPaths.first;
                            if (selectedPath.toLowerCase().endsWith('.json')) {
                              if (context.mounted) {
                                await SettingsBackupService.restoreSettings(context, selectedPath);
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppStrings.current.pleaseSelectValidBackup),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// Reusable Settings Tile
// ----------------------------------------------------
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: NfileIcon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6))),
        trailing: trailing != null ? IgnorePointer(child: trailing) : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ----------------------------------------------------
// Sub-Category Settings Screens
// ----------------------------------------------------

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.current.generalAndBehavior),
        leading: IconButton(
          icon: const NfileIcon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SettingsTile(
              icon: Broken.global,
              title: AppStrings.current.language,
              subtitle: AppStrings.current.languageSub,
              trailing: Text(
                PreferencesService.getLocale() == 'system' ? AppStrings.current.systemDefault : 
                PreferencesService.getLocale() == 'es' ? AppStrings.current.spanish : AppStrings.current.english,
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(AppStrings.current.language),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    children: [
                      RadioListTile<String>(
                        title: Text(AppStrings.current.systemDefault),
                        value: 'system',
                        groupValue: PreferencesService.getLocale(),
                        onChanged: (val) {
                          AppStrings.setLocale(context, val!);
                          Navigator.pop(ctx);
                        },
                      ),
                      RadioListTile<String>(
                        title: Text(AppStrings.current.spanish),
                        value: 'es',
                        groupValue: PreferencesService.getLocale(),
                        onChanged: (val) {
                          AppStrings.setLocale(context, val!);
                          Navigator.pop(ctx);
                        },
                      ),
                      RadioListTile<String>(
                        title: Text(AppStrings.current.english),
                        value: 'en',
                        groupValue: PreferencesService.getLocale(),
                        onChanged: (val) {
                          AppStrings.setLocale(context, val!);
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            SettingsTile(
              icon: Broken.folder_favorite,
              title: AppStrings.current.defaultToBrowseScreen,
              subtitle: AppStrings.current.defaultToBrowseScreenSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.defaultToBrowseScreen,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleDefaultToBrowseScreen(),
                ),
              ),
              onTap: () => fileManager.toggleDefaultToBrowseScreen(),
            ),
            SettingsTile(
              icon: Broken.folder_open,
              title: AppStrings.current.rememberLastFolder,
              subtitle: AppStrings.current.rememberLastFolderSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.rememberLastFolder,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleRememberLastFolder(),
                ),
              ),
              onTap: () => fileManager.toggleRememberLastFolder(),
            ),
            SettingsTile(
              icon: Broken.menu,
              title: AppStrings.current.showHomeBrowseBar,
              subtitle: AppStrings.current.showHomeBrowseBarSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showHomeBrowseNav,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleShowHomeBrowseNav(),
                ),
              ),
              onTap: () => fileManager.toggleShowHomeBrowseNav(),
            ),
            SettingsTile(
              icon: Broken.menu_1,
              title: AppStrings.current.hideNavLabels,
              subtitle: AppStrings.current.hideNavLabelsSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideNavLabels,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideNavLabels(),
                ),
              ),
              onTap: () => fileManager.toggleHideNavLabels(),
            ),
            SettingsTile(
              icon: Icons.android,
              title: AppStrings.current.hideAndroidNavBar,
              subtitle: AppStrings.current.hideAndroidNavBarSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideNavigationBar,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideNavigationBar(),
                ),
              ),
              onTap: () => fileManager.toggleHideNavigationBar(),
            ),
            SettingsTile(
              icon: Broken.menu,
              title: AppStrings.current.showBottomNavBar,
              subtitle: AppStrings.current.showBottomNavBarSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showBottomActionBar,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleBottomActionBar(),
                ),
              ),
              onTap: () => fileManager.toggleBottomActionBar(),
            ),
            SettingsTile(
              icon: Icons.label_off_rounded,
              title: AppStrings.current.hideActionBarLabels,
              subtitle: AppStrings.current.hideActionBarLabelsSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideActionText,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideActionText(),
                ),
              ),
              onTap: () => fileManager.toggleHideActionText(),
            ),
            SettingsTile(
              icon: Broken.setting_2,
              title: AppStrings.current.customizeShortcuts,
              subtitle: AppStrings.current.customizeShortcutsSub,
              onTap: () => QuickCategoriesGrid.showCustomizeDialog(context),
            ),
            SettingsTile(
              icon: Broken.clock,
              title: AppStrings.current.showRecentFiles,
              subtitle: AppStrings.current.showRecentFilesSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showRecentFiles,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleShowRecentFiles(),
                ),
              ),
              onTap: () => fileManager.toggleShowRecentFiles(),
            ),
            SettingsTile(
              icon: Icons.gesture,
              title: AppStrings.current.preventLeftBackGesture,
              subtitle: AppStrings.current.preventLeftBackGestureSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.disableLeftBackGesture,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleDisableLeftBackGesture(),
                ),
              ),
              onTap: () => fileManager.toggleDisableLeftBackGesture(),
            ),
            SettingsTile(
              icon: Icons.logout_rounded,
              title: AppStrings.current.appExitBehavior,
              subtitle: fileManager.exitOption == 'confirm'
                  ? AppStrings.current.showConfirmationDialog
                  : 'Double-press back button to exit',
              onTap: () => _showExitOptionPickerDialog(context, fileManager, theme),
            ),
          ],
        ),
      ),
    );
  }
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.current.appearanceAndThemes),
        leading: IconButton(
          icon: const NfileIcon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SettingsTile(
              icon: Broken.colorfilter,
              title: AppStrings.current.accentColorTheme,
              subtitle: _getAccentColorLabel(fileManager.accentColorOption),
              onTap: () => _showThemePickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
              icon: FileUtils.getFolderIcon(fileManager.folderIconOption),
              title: AppStrings.current.folderIconStyle,
              subtitle: _getFolderIconLabel(fileManager.folderIconOption),
              onTap: () => _showFolderIconPickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
              icon: Broken.category,
              title: AppStrings.current.appDrawerButtonStyle,
              subtitle: _getMenuIconStyleLabel(fileManager.menuIconStyle),
              onTap: () => _showMenuIconStylePickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
              icon: Broken.moon,
              title: AppStrings.current.amoledBlackMode,
              subtitle: AppStrings.current.amoledBlackModeSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.amoledMode,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleAmoledMode(),
                ),
              ),
              onTap: () => fileManager.toggleAmoledMode(),
            ),
            SettingsTile(
              icon: Broken.category,
              title: AppStrings.current.appIcon,
              subtitle: _getAppIconLabel(fileManager.activeAppIcon),
              onTap: () => _showAppIconPickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
              icon: Broken.text,
              title: AppStrings.current.appTypography,
              subtitle: _getFontFamilyLabel(fileManager.fontFamilyOption),
              onTap: () => _showFontFamilyPickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
              icon: Broken.setting,
              title: AppStrings.current.useMaterialIcons,
              subtitle: AppStrings.current.useMaterialIconsSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.useMaterialIcons,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => fileManager.setUseMaterialIcons(val),
                ),
              ),
              onTap: () => fileManager.setUseMaterialIcons(!fileManager.useMaterialIcons),
            ),
          ],
        ),
      ),
    );
  }
}

class ExplorerSettingsScreen extends StatelessWidget {
  const ExplorerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.current.fileExplorerOptions),
        leading: IconButton(
          icon: const NfileIcon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SettingsTile(
              icon: Broken.edit,
              title: AppStrings.current.showAddressBar,
              subtitle: AppStrings.current.showAddressBarSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showAddressBar,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleShowAddressBar(),
                ),
              ),
              onTap: () => fileManager.toggleShowAddressBar(),
            ),
            SettingsTile(
              icon: Broken.add_square,
              title: AppStrings.current.showFloatingButton,
              subtitle: AppStrings.current.showFloatingButtonSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showFloatingAddButton,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleFloatingAddButton(),
                ),
              ),
              onTap: () => fileManager.toggleFloatingAddButton(),
            ),
            SettingsTile(
              icon: Broken.folder_open,
              title: AppStrings.current.showHiddenFiles,
              subtitle: AppStrings.current.showHiddenFilesSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showHiddenFiles,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHiddenFiles(),
                ),
              ),
              onTap: () => fileManager.toggleHiddenFiles(),
            ),
            SettingsTile(
              icon: Broken.colorfilter,
              title: AppStrings.current.highlightExitedFolder,
              subtitle: AppStrings.current.highlightExitedFolderSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.enableFolderHighlight,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleEnableFolderHighlight(),
                ),
              ),
              onTap: () => fileManager.toggleEnableFolderHighlight(),
            ),
            SettingsTile(
              icon: Broken.category,
              title: AppStrings.current.enableMultipleTabs,
              subtitle: AppStrings.current.enableMultipleTabsSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.enableMultipleTabs,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleMultipleTabs(),
                ),
              ),
              onTap: () => fileManager.toggleMultipleTabs(),
            ),
            SettingsTile(
              icon: Icons.splitscreen,
              title: AppStrings.current.enableSplitScreen,
              subtitle: AppStrings.current.enableSplitScreenSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.enableSplitScreen,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleSplitScreen(),
                ),
              ),
              onTap: () => fileManager.toggleSplitScreen(),
            ),
            SettingsTile(
              icon: Broken.folder_connection,
              title: AppStrings.current.enableDragAndDrop,
              subtitle: AppStrings.current.enableDragAndDropSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.enableDragDrop,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleEnableDragDrop(),
                ),
              ),
              onTap: () => fileManager.toggleEnableDragDrop(),
            ),
            if (fileManager.enableDragDrop)
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: SettingsTile(
                  icon: Broken.task_square,
                  title: AppStrings.current.confirmDragDrop,
                  subtitle: AppStrings.current.confirmDragDropSub,
                  trailing: Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: fileManager.showDragDropDialog,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (_) => fileManager.toggleShowDragDropDialog(),
                    ),
                  ),
                  onTap: () => fileManager.toggleShowDragDropDialog(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LayoutSettingsScreen extends StatelessWidget {
  const LayoutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.current.listAndLayout),
        leading: IconButton(
          icon: const NfileIcon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SettingsTile(
              icon: Broken.document_text_1,
              title: AppStrings.current.showFolderFileCount,
              subtitle: AppStrings.current.showFolderFileCountSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showFolderFileCount,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleFolderFileCount(),
                ),
              ),
              onTap: () => fileManager.toggleFolderFileCount(),
            ),
            SettingsTile(
              icon: Broken.folder_open,
              title: AppStrings.current.showFolderContentCount,
              subtitle: AppStrings.current.showFolderContentCountSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showFolderContentsCount,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleFolderContentsCount(),
                ),
              ),
              onTap: () => fileManager.toggleFolderContentsCount(),
            ),
            SettingsTile(
              icon: Broken.document_text_1,
              title: AppStrings.current.showFolderSize,
              subtitle: AppStrings.current.showFolderSizeSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showFolderSizes,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleShowFolderSizes(),
                ),
              ),
              onTap: () => fileManager.toggleShowFolderSizes(),
            ),
            SettingsTile(
              icon: Icons.access_time_rounded,
              title: AppStrings.current.use24HourFormat,
              subtitle: AppStrings.current.use24HourFormatSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.use24HourFormat,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleUse24HourFormat(),
                ),
              ),
              onTap: () => fileManager.toggleUse24HourFormat(),
            ),
            SettingsTile(
              icon: Icons.visibility_off_rounded,
              title: AppStrings.current.hideTimeDate,
              subtitle: AppStrings.current.hideTimeDateSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideTimeAndDate,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideTimeAndDate(),
                ),
              ),
              onTap: () => fileManager.toggleHideTimeAndDate(),
            ),
            SettingsTile(
              icon: Broken.text,
              title: AppStrings.current.adaptiveMultiLine,
              subtitle: AppStrings.current.adaptiveMultiLineSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.adaptiveMultiLineNames,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleAdaptiveMultiLineNames(),
                ),
              ),
              onTap: () => fileManager.toggleAdaptiveMultiLineNames(),
            ),
            SettingsTile(
              icon: Icons.more_vert_rounded,
              title: AppStrings.current.hide3DotButtons,
              subtitle: AppStrings.current.hide3DotButtonsSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideActionMenuButtons,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideActionMenuButtons(),
                ),
              ),
              onTap: () => fileManager.toggleHideActionMenuButtons(),
            ),
            if (fileManager.hideActionMenuButtons)
              SettingsTile(
                icon: Icons.info_outline_rounded,
                title: AppStrings.current.threeDotDisabledInfo,
                subtitle: _getTrailingInfoTypeLabel(fileManager.trailingInfoType),
                onTap: () => _showTrailingInfoTypePickerDialog(context, fileManager, theme),
              ),
          ],
        ),
      ),
    );
  }
}

class MediaSettingsScreen extends StatefulWidget {
  const MediaSettingsScreen({super.key});

  @override
  State<MediaSettingsScreen> createState() => _MediaSettingsScreenState();
}

class _MediaSettingsScreenState extends State<MediaSettingsScreen> {
  bool _preferFolders = false;

  @override
  void initState() {
    super.initState();
    _preferFolders = PreferencesService.getPreferFoldersInMedia();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.current.mediaPreferences),
        leading: IconButton(
          icon: const NfileIcon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SettingsTile(
              icon: Broken.folder_2,
              title: AppStrings.current.defaultAlbumView,
              subtitle: AppStrings.current.defaultAlbumViewSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _preferFolders,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _preferFolders = val;
                    });
                    PreferencesService.savePreferFoldersInMedia(val);
                  },
                ),
              ),
              onTap: () {
                final val = !_preferFolders;
                setState(() {
                  _preferFolders = val;
                });
                PreferencesService.savePreferFoldersInMedia(val);
              },
            ),
            SettingsTile(
              icon: Broken.image,
              title: AppStrings.current.showMediaPreviews,
              subtitle: AppStrings.current.showMediaPreviewsSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showMediaPreviews,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleMediaPreviews(),
                ),
              ),
              onTap: () => fileManager.toggleMediaPreviews(),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionsSettingsScreen extends StatelessWidget {
  const ActionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.current.fileActionsAndViewers),
        leading: IconButton(
          icon: const NfileIcon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SettingsTile(
              icon: Broken.setting_3,
              title: AppStrings.current.skipOpenWithDialog,
              subtitle: AppStrings.current.skipOpenWithDialogSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.skipOpenWithDialog,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleSkipOpenWithDialog(),
                ),
              ),
              onTap: () => fileManager.toggleSkipOpenWithDialog(),
            ),
            SettingsTile(
              icon: Broken.refresh_2,
              title: AppStrings.current.resetDefaultViewers,
              subtitle: AppStrings.current.resetDefaultViewersSub,
              onTap: () async {
                await PreferencesService.clearAllDefaultOpenActions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.current.viewerChoicesReset),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TrashSettingsScreen extends StatefulWidget {
  const TrashSettingsScreen({super.key});

  @override
  State<TrashSettingsScreen> createState() => _TrashSettingsScreenState();
}

class _TrashSettingsScreenState extends State<TrashSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.current.recycleBinTrash),
        leading: IconButton(
          icon: const NfileIcon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            SettingsTile(
              icon: Broken.trash,
              title: AppStrings.current.enableRecycleBin,
              subtitle: AppStrings.current.enableRecycleBinSub,
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: RecycleBinService.isEnabled(),
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      RecycleBinService.setEnabled(val);
                    });
                  },
                ),
              ),
              onTap: () {
                final val = !RecycleBinService.isEnabled();
                setState(() {
                  RecycleBinService.setEnabled(val);
                });
              },
            ),
            if (RecycleBinService.isEnabled())
              SettingsTile(
                icon: Icons.access_time_rounded,
                title: AppStrings.current.autoDeleteTrashDuration,
                subtitle: _getAutoDeleteDaysLabel(RecycleBinService.getAutoDeleteDays()),
                onTap: () => _showAutoDeleteDaysPickerDialog(context, theme, () {
                  setState(() {});
                }),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// Global Helper Labels & Dialogs for Themes & Settings
// ----------------------------------------------------

String _getAccentColorLabel(String option) {
  switch (option) {
    case 'dynamic': return 'Material You (Dynamic Wallpaper Colors)';
    case 'orange': return AppStrings.current.vibrantOrange;
    case 'purple': return AppStrings.current.royalPurple;
    case 'green': return AppStrings.current.emeraldGreen;
    case 'red': return AppStrings.current.crimsonRed;
    case 'gold': return AppStrings.current.amberGold;
    case 'pink': return AppStrings.current.cyberpunkPink;
    case 'sapphire': return AppStrings.current.sapphireBlue;
    case 'forest': return AppStrings.current.forestGreen;
    case 'peach': return AppStrings.current.sunsetPeach;
    case 'blue':
    default:
      return 'Original Default (Signature Blue)';
  }
}

String _getFolderIconLabel(String option) {
  switch (option) {
    case 'solid': return 'Classic Solid (Material)';
    case 'rounded': return 'Modern Rounded (Material)';
    case 'special': return 'Starred Special (Material)';
    case 'snippet': return 'Snippet Document (Material)';
    case 'outlined': return 'Minimal Outlined (Material)';
    case 'broken':
    default:
      return 'NFile Broken Outline (Default)';
  }
}

String _getMenuIconStyleLabel(String option) {
  switch (option) {
    case 'category': return 'Category Grid / Vuesax Grid';
    case 'hamburger':
    default:
      return 'Hamburger / Classic Menu';
  }
}

String _getAppIconLabel(String option) {
  switch (option) {
    case 'logo1': return AppStrings.current.logo1;
    case 'logo2': return AppStrings.current.logo2;
    case 'logo3': return AppStrings.current.logo3;
    case 'logo4': return AppStrings.current.logo4;
    case 'default':
    default:
      return AppStrings.current.defaultLogo;
  }
}

String _getFontFamilyLabel(String option) {
  switch (option) {
    case 'nothing': return 'Dot-Matrix & Sans';
    case 'outfit': return AppStrings.current.outfitModernSans;
    case 'jetbrains': return AppStrings.current.jetBrainsTechMono;
    case 'montserrat': return AppStrings.current.montserratUrbanSans;
    case 'custom': return AppStrings.current.customImportedFont;
    case 'default':
    default:
      return AppStrings.current.signatureDefaultFont;
  }
}

String _getAutoDeleteDaysLabel(int days) {
  if (days <= 0) return 'Never (Auto-delete disabled)';
  if (days == 1) return 'After 1 Day';
  return 'After $days Days';
}

String _getTrailingInfoTypeLabel(String option) {
  switch (option) {
    case 'dateTime': return AppStrings.current.dateTimeTitle;
    case 'sizeAndCount': return AppStrings.current.fileSizeItemCount;
    case 'none':
    default:
      return AppStrings.current.noneHideInfo;
  }
}

void _showTrailingInfoTypePickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = fileManager.trailingInfoType;
      final options = [
        {'key': 'none', 'name': AppStrings.current.noneHideInfo, 'desc': AppStrings.current.noneHideInfoDesc},
        {'key': 'dateTime', 'name': AppStrings.current.dateTimeTitle, 'desc': AppStrings.current.dateTimeDesc},
        {'key': 'sizeAndCount', 'name': AppStrings.current.fileSizeItemCount, 'desc': AppStrings.current.fileSizeItemCountDesc},
      ];

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(AppStrings.current.chooseTrailingInfoStyle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Choose what is displayed on the right side of files and folders when the 3-dot action buttons are hidden.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final opt = options[i];
                      final key = opt['key'] as String;
                      final name = opt['name'] as String;
                      final desc = opt['desc'] as String;
                      final isSelected = current == key;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            key == 'none'
                                ? Icons.visibility_off_rounded
                                : key == 'dateTime'
                                    ? Icons.access_time_rounded
                                    : Icons.info_outline_rounded,
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                        subtitle: Text(desc, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                        trailing: isSelected
                            ? Icon(Icons.radio_button_checked_rounded, color: theme.colorScheme.primary)
                            : Icon(Icons.radio_button_off_rounded, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                        onTap: () {
                          fileManager.setTrailingInfoType(key);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showExitOptionPickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = fileManager.exitOption;
      final options = [
        {'key': 'confirm', 'name': AppStrings.current.confirmDialogTitle, 'desc': AppStrings.current.confirmDialogDesc},
        {'key': 'double_press', 'name': AppStrings.current.doublePressToExit, 'desc': AppStrings.current.doublePressToExitDesc},
      ];

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(AppStrings.current.chooseExitBehavior, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final opt = options[i];
                      final key = opt['key'] as String;
                      final name = opt['name'] as String;
                      final desc = opt['desc'] as String;
                      final isSelected = current == key;

                      return ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
                        trailing: isSelected 
                            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) 
                            : Icon(Icons.circle_outlined, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                        onTap: () {
                          fileManager.setExitOption(key);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showThemePickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = fileManager.accentColorOption;
      final options = [
        {'key': 'blue', 'name': 'Original Default (Signature Blue)', 'color': const Color(0xFF369FE7)},
        {'key': 'dynamic', 'name': 'Material You (Dynamic Wallpaper Colors)', 'color': Colors.teal},
        {'key': 'orange', 'name': AppStrings.current.vibrantOrange, 'color': const Color(0xFFFF6D00)},
        {'key': 'purple', 'name': AppStrings.current.royalPurple, 'color': const Color(0xFF8E24AA)},
        {'key': 'green', 'name': AppStrings.current.emeraldGreen, 'color': const Color(0xFF00C853)},
        {'key': 'red', 'name': AppStrings.current.crimsonRed, 'color': const Color(0xFFD50000)},
        {'key': 'gold', 'name': AppStrings.current.amberGold, 'color': const Color(0xFFFFD600)},
        {'key': 'pink', 'name': AppStrings.current.cyberpunkPink, 'color': const Color(0xFFFF2E93)},
        {'key': 'sapphire', 'name': AppStrings.current.sapphireBlue, 'color': const Color(0xFF0F52BA)},
        {'key': 'forest', 'name': AppStrings.current.forestGreen, 'color': const Color(0xFF228B22)},
        {'key': 'peach', 'name': AppStrings.current.sunsetPeach, 'color': const Color(0xFFFF7F50)},
      ];

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(AppStrings.current.chooseAccentTheme, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final opt = options[i];
                      final key = opt['key'] as String;
                      final name = opt['name'] as String;
                      final color = opt['color'] as Color;
                      final isSelected = current == key;

                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: key == 'dynamic' ? theme.colorScheme.primary : color,
                            shape: BoxShape.circle,
                          ),
                          child: key == 'dynamic' 
                              ? const Icon(Broken.colorfilter, color: Colors.white, size: 20)
                              : isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                        ),
                        title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: isSelected ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        onTap: () {
                          fileManager.setAccentColorOption(key);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showFolderIconPickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = fileManager.folderIconOption;
      final options = [
        {'key': 'broken', 'name': 'NFile Broken Outline (Default)', 'icon': Broken.folder},
        {'key': 'rounded', 'name': 'Modern Rounded (Material)', 'icon': Icons.folder_rounded},
        {'key': 'solid', 'name': 'Classic Solid (Material)', 'icon': Icons.folder},
        {'key': 'special', 'name': 'Starred Special (Material)', 'icon': Icons.folder_special_rounded},
        {'key': 'snippet', 'name': 'Snippet Document (Material)', 'icon': Icons.snippet_folder_rounded},
        {'key': 'outlined', 'name': 'Minimal Outlined (Material)', 'icon': Icons.folder_outlined},
      ];

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(AppStrings.current.chooseFolderIconStyle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final opt = options[i];
                      final key = opt['key'] as String;
                      final name = opt['name'] as String;
                      final icon = opt['icon'] as IconData;
                      final isSelected = current == key;

                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary, size: 20),
                        ),
                        title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: isSelected ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        onTap: () {
                          fileManager.setFolderIconOption(key);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showMenuIconStylePickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = fileManager.menuIconStyle;
      final options = [
        {'key': 'hamburger', 'name': 'Hamburger / Classic Menu', 'icon': Broken.menu},
        {'key': 'category', 'name': 'Category Grid / Vuesax Grid', 'icon': Broken.category},
      ];

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(AppStrings.current.chooseDrawerButtonStyle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final opt = options[i];
                      final key = opt['key'] as String;
                      final name = opt['name'] as String;
                      final icon = opt['icon'] as IconData;
                      final isSelected = current == key;

                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary, size: 20),
                        ),
                        title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: isSelected ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        onTap: () {
                          fileManager.setMenuIconStyle(key);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showAppIconPickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppStrings.current.appIconPicker,
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim1, anim2, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(
          opacity: anim1,
          child: AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Broken.category, color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: 12),
                Text(AppStrings.current.appLauncherIcon, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose a custom logo for the application launcher icon. Note that some launchers may take a few seconds to update.',
                    style: TextStyle(fontSize: 13, height: 1.3, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                        children: [
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'default',
                            title: AppStrings.current.logo,
                            imagePath: 'assets/ic_launcher.webp',
                          ),
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'logo1',
                            title: AppStrings.current.logo1,
                            imagePath: 'assets/logo/n1.png',
                          ),
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'logo2',
                            title: AppStrings.current.logo2,
                            imagePath: 'assets/logo/n2.png',
                          ),
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'logo3',
                            title: AppStrings.current.logo3,
                            imagePath: 'assets/logo/n3.png',
                          ),
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'logo4',
                            title: AppStrings.current.logo4,
                            imagePath: 'assets/logo/n4.png',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.current.close),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildIconOptionCard(
  BuildContext context,
  FileManagerProvider fileManager,
  ThemeData theme, {
  required String id,
  required String title,
  required String imagePath,
}) {
  final isSelected = fileManager.activeAppIcon == id;

  return Card(
    color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.surfaceVariant.withOpacity(0.15),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.08),
        width: isSelected ? 2.0 : 1.0,
      ),
    ),
    child: InkWell(
      onTap: () {
        fileManager.setActiveAppIcon(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.current.appIconSwitched(title)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey.withOpacity(0.2),
                  child: const Icon(Icons.broken_image, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

void _showFontFamilyPickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = fileManager.fontFamilyOption;
      final hasCustomFont = fileManager.customFontPath != null;
      final options = [
        {'key': 'default', 'name': AppStrings.current.signatureDefaultFont, 'desc': AppStrings.current.signatureDefaultFontDesc},
        {'key': 'nothing', 'name': 'Nothing Dot-Matrix & Sans', 'desc': 'High-tech retro dot matrix headings + clean body'},
        {'key': 'outfit', 'name': AppStrings.current.outfitModernSans, 'desc': AppStrings.current.outfitFontDesc},
        {'key': 'jetbrains', 'name': AppStrings.current.jetBrainsTechMono, 'desc': AppStrings.current.jetBrainsFontDesc},
        {'key': 'montserrat', 'name': AppStrings.current.montserratUrbanSans, 'desc': AppStrings.current.montserratFontDesc},
        if (hasCustomFont)
          {'key': 'custom', 'name': AppStrings.current.customFontTitle(p.basename(fileManager.customFontPath!)), 'desc': AppStrings.current.customFontDesc},
      ];

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'App Typography',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'LexendDeca'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select a beautiful typeface to customize NFile\'s overall visual theme',
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13, fontFamily: 'LexendDeca'),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final isSelected = current == opt['key'];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(
                        opt['name']!,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          fontFamily: 'LexendDeca',
                        ),
                      ),
                      subtitle: Text(
                        opt['desc']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontFamily: 'LexendDeca',
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.radio_button_checked_rounded, color: theme.colorScheme.primary)
                          : Icon(Icons.radio_button_off_rounded, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                      onTap: () {
                        fileManager.setFontFamilyOption(opt['key']!);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Broken.document_upload, size: 20),
                    label: Text(
                      hasCustomFont ? AppStrings.current.replaceCustomFontFile : AppStrings.current.importCustomFontFile,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'LexendDeca'),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final picked = await InternalFilePickerScreen.show(
                        context,
                        rootPath: fileManager.rootPath,
                      );
                      if (picked != null && picked.isNotEmpty) {
                        final filePat = picked.first;
                        final ext = p.extension(filePat).toLowerCase();
                        if (ext == '.ttf' || ext == '.otf') {
                          final success = await fileManager.setCustomFontPath(filePat);
                          if (success) {
                            fileManager.setFontFamilyOption('custom');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppStrings.current.customFontLoaded)),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppStrings.current.failedToLoadFont)),
                              );
                            }
                          }
                        } else {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(AppStrings.current.invalidFileType),
                                content: Text(AppStrings.current.invalidFileTypeMessage),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(AppStrings.current.ok),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                  if (hasCustomFont) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Broken.trash, size: 18, color: Colors.redAccent),
                      label: Text(AppStrings.current.removeCustomFont, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'LexendDeca')),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await fileManager.setCustomFontPath(null);
                        if (current == 'custom') {
                          fileManager.setFontFamilyOption('default');
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppStrings.current.customFontRemoved)),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showAutoDeleteDaysPickerDialog(BuildContext context, ThemeData theme, VoidCallback onChanged) {
  showModalBottomSheet(
    context: context,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = RecycleBinService.getAutoDeleteDays();
      final options = [
        {'days': 7, 'label': AppStrings.current.days7},
        {'days': 15, 'label': AppStrings.current.days15},
        {'days': 30, 'label': AppStrings.current.days30Recommended},
        {'days': 0, 'label': AppStrings.current.neverManuallyClean},
      ];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  AppStrings.current.autoDeleteTrashDuration,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  AppStrings.current.trashDeletionWarning,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final days = opt['days'] as int;
                final label = opt['label'] as String;
                final isSelected = current == days;

                return Card(
                  color: isSelected ? theme.colorScheme.primary.withOpacity(0.12) : theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.08)),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      RecycleBinService.setAutoDeleteDays(days);
                      onChanged();
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_circle, color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
