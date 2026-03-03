import 'package:app/infra/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Parsed release notes entry from markdown changelog content.
class ReleaseNoteEntry {
  /// Creates a parsed release notes entry.
  const ReleaseNoteEntry({
    required this.date,
    required this.content,
    this.ffOsTitle,
    this.mobileAppTitle,
  });

  /// Release date header (e.g., "February 24, 2026").
  final String date;

  /// Optional FF OS section title.
  final String? ffOsTitle;

  /// Optional mobile app section title.
  final String? mobileAppTitle;

  /// Raw markdown content for this date section.
  final String content;
}

/// Fetches and parses release notes markdown entries from pubdoc.
class ReleaseNotesService {
  /// Creates a release notes service.
  ReleaseNotesService({
    http.Client? httpClient,
    Uri? baseUri,
    Logger? logger,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri,
       _log = logger ?? Logger('ReleaseNotesService');

  final http.Client _httpClient;
  final Uri? _baseUri;
  final Logger _log;

  /// Loads and parses release notes list from pubdoc.
  Future<List<ReleaseNoteEntry>> getReleaseNotes() async {
    final baseUri = _baseUri ?? Uri.tryParse(AppConfig.releaseNotesMarkdownUrl);
    if (baseUri == null) {
      _log.warning(
        'Release notes unavailable: '
        'RELEASE_NOTES_MARKDOWN_URL is not configured.',
      );
      return const <ReleaseNoteEntry>[];
    }

    final uri = _resolveChangelogUri(baseUri);

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log.warning(
          'Release notes request failed: HTTP ${response.statusCode}.',
        );
        return const <ReleaseNoteEntry>[];
      }
      return parseReleaseNotesMarkdown(response.body);
    } on Exception catch (error, stackTrace) {
      _log.warning('Failed to fetch release notes.', error, stackTrace);
      return const <ReleaseNoteEntry>[];
    }
  }

  Uri _buildChangelogUri(Uri baseUri) {
    final baseSegments = baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    return baseUri.replace(
      pathSegments: <String>[
        ...baseSegments,
        'docs',
        'changelog.md',
      ],
    );
  }

  Uri _resolveChangelogUri(Uri baseUri) {
    // If the configured URL already points to markdown, use it directly.
    if (baseUri.path.toLowerCase().endsWith('.md')) {
      return baseUri;
    }
    return _buildChangelogUri(baseUri);
  }
}

/// Parses changelog markdown into release note entries.
List<ReleaseNoteEntry> parseReleaseNotesMarkdown(String markdown) {
  final normalizedMarkdown = _normalizeChangelogMarkdown(markdown);
  final lines = normalizedMarkdown.split('\n');
  final releaseNotes = <ReleaseNoteEntry>[];

  String? currentDate;
  String? currentFfOsTitle;
  String? currentMobileAppTitle;
  final currentContent = StringBuffer();

  for (final rawLine in lines) {
    final line = rawLine.trimRight();

    if (isReleaseNoteDateHeader(line)) {
      if (currentDate != null) {
        releaseNotes.add(
          ReleaseNoteEntry(
            date: currentDate,
            ffOsTitle: currentFfOsTitle,
            mobileAppTitle: currentMobileAppTitle,
            content: currentContent.toString().trim(),
          ),
        );
        currentContent.clear();
      }

      currentDate = line.replaceFirst(RegExp(r'^##\s*'), '').trim();
      currentFfOsTitle = null;
      currentMobileAppTitle = null;
      currentContent.writeln(line);
      continue;
    }

    if (line.trimLeft().startsWith('###')) {
      final title = line.replaceFirst(RegExp(r'^###\s*'), '').trim();
      final normalizedTitle = title.toLowerCase();

      if (currentDate != null &&
          currentFfOsTitle == null &&
          normalizedTitle.contains('ff os')) {
        currentFfOsTitle = title;
      } else if (currentDate != null &&
          currentMobileAppTitle == null &&
          (normalizedTitle.contains('mobile app') ||
              normalizedTitle.contains('mobile'))) {
        currentMobileAppTitle = title;
      }

      currentContent.writeln(line);
      continue;
    }

    if (currentDate != null) {
      currentContent.writeln(line);
    }
  }

  if (currentDate != null) {
    releaseNotes.add(
      ReleaseNoteEntry(
        date: currentDate,
        ffOsTitle: currentFfOsTitle,
        mobileAppTitle: currentMobileAppTitle,
        content: currentContent.toString().trim(),
      ),
    );
  }

  return releaseNotes;
}

/// Date headers start with `##` but not `###`.
bool isReleaseNoteDateHeader(String line) {
  return line.startsWith('##') && !line.startsWith('###');
}

String _normalizeChangelogMarkdown(String markdown) {
  return markdown
      // Normalize only inline section breaks like "--- ## Dec 2".
      .replaceAllMapped(
        RegExp(r'---\s+(?=##\s+)'),
        (_) => '---\n',
      )
      // Ensure date headers are on their own lines even if inline.
      .replaceAllMapped(
        RegExp(r'(?<![\n#])##\s+'),
        (match) => '\n${match.group(0)}',
      )
      // Ensure subsection headers are on their own lines even if inline.
      .replaceAllMapped(
        RegExp(r'(?<![\n#])###\s+'),
        (match) => '\n${match.group(0)}',
      );
}
