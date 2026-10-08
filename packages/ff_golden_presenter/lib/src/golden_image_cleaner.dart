import 'image_directory_cleaner.dart';

/// Deletes baseline images below exact `golden` directories.
/// Generated failure directories, non-image files, and symlinks are preserved.
final class GoldenImageCleaner extends ImageDirectoryCleaner {
  /// Creates a guarded cleaner rooted at [inputDirectory].
  GoldenImageCleaner({
    required super.inputDirectory,
    super.extensions = const {'png', 'jpg', 'jpeg', 'webp', 'svg'},
  }) : super(
          directoryName: 'golden',
          imageLabel: 'golden',
          excludedDirectories: const {'failures'},
        );
}
