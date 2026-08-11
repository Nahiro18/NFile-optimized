import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class FileItemSkeleton extends StatelessWidget {
  const FileItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListTile(
        leading: Container(
          width: 48.0,
          height: 48.0,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        title: Container(
          height: 16.0,
          width: double.infinity,
          margin: const EdgeInsets.only(right: 48.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
        subtitle: Container(
          height: 14.0,
          width: 100.0,
          margin: const EdgeInsets.only(right: 120.0, top: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
        trailing: Container(
          width: 24.0,
          height: 24.0,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
