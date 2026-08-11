import 'package:flutter/material.dart';
import '../../providers/file_manager_provider.dart';

class FileOperationProgressMinibar extends StatelessWidget {
  final FileManagerProvider provider;

  const FileOperationProgressMinibar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FileOperationProgress?>(
      valueListenable: provider.progressNotifier,
      builder: (context, progress, child) {
        if (progress == null) return const SizedBox.shrink();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80.0, left: 16, right: 16),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${progress.operation} (${progress.currentItemIndex}/${progress.totalItems})',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: progress.progress,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${(progress.progress * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
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
}
