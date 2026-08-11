import 'package:flutter/material.dart';
import 'file_item_skeleton.dart';
import 'folder_grid_skeleton.dart';

class SkeletonLoader extends StatelessWidget {
  final bool isGridView;
  final int itemCount;

  const SkeletonLoader({
    super.key,
    required this.isGridView,
    this.itemCount = 15,
  });

  @override
  Widget build(BuildContext context) {
    if (isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(12.0),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 0.9,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => const FolderGridSkeleton(),
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => const FileItemSkeleton(),
      );
    }
  }
}
