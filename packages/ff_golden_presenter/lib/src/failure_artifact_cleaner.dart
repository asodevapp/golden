import 'image_directory_cleaner.dart';

/// A fixed, verified set of failure files awaiting cleanup confirmation.
typedef FailureArtifactCleanupPlan = ImageCleanupPlan;

/// Includes partial completion when a failure file becomes unavailable.
typedef FailureArtifactCleanupException = ImageCleanupException;

/// Metadata for an image found below a directory named `failures`.
typedef FailureArtifactFile = ImageCleanupFile;

/// The result of scanning for or deleting failure images.
typedef FailureArtifactCleanupResult = ImageCleanupResult;

/// Deletes generated images below exact `failures` directories.
/// Symlinks are never followed.
final class FailureArtifactCleaner extends ImageDirectoryCleaner {
  /// Creates a guarded cleaner rooted at [inputDirectory].
  FailureArtifactCleaner({
    required super.inputDirectory,
    super.extensions = const {'png'},
  }) : super(directoryName: 'failures', imageLabel: 'failure');
}
