import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/utils.dart';
import '../screens/storage_analyzer/storage_analyzer_screen.dart';
import '../../core/app_strings.dart';

class SwipableStorageOverview extends StatelessWidget {
  final Function(String) onBrowseVolume;

  const SwipableStorageOverview({super.key, required this.onBrowseVolume});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final volumes = provider.storageVolumes;

    if (volumes.isEmpty) {
      return _buildSkeleton(context);
    }

    return Column(
      children: [
        for (int i = 0; i < volumes.length; i++)
          _buildVolumeCard(context, volumes[i], i == 0),
        const SizedBox(height: 8),
        _buildAnalyzerButton(context),
      ],
    );
  }

  Widget _buildVolumeCard(BuildContext context, StorageVolume vol, bool expanded) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5);
    final freeBytes = vol.totalBytes - vol.usedBytes;
    final usedFraction = vol.totalBytes > 0 ? vol.usedBytes / vol.totalBytes : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Material(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onBrowseVolume(vol.path),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  vol.isInternal ? Broken.cpu : Icons.sd_storage_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vol.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: usedFraction,
                          minHeight: 4,
                          backgroundColor: borderColor,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.current.freeSpace(FileUtils.formatBytes(freeBytes, 1)),
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                          ),
                          Text(
                            AppStrings.current.totalSpace(FileUtils.formatBytes(vol.totalBytes, 1)),
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzerButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageAnalyzerScreen()));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Broken.chart, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  AppStrings.current.storageAnalyzer,
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5)),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
