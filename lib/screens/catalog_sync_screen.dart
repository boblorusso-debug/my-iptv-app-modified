import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_preferences.dart';
import '../services/playlist_manager.dart';
import '../utils/tv_theme.dart';
import '../widgets/mode_button.dart';
import '../l10n/l10n.dart';

/// The actual progress UI for a full catalog sync — phase text + a
/// progress bar off [PlaylistManager]'s existing warm-up counters.
/// Extracted from [CatalogSyncScreen] so the exact same content can be
/// shown two ways: as the app's root during main.dart's bootstrap gate
/// (no Navigator/MaterialApp exists yet there), or pushed as a normal
/// full-screen route when the user manually triggers "Update Content"
/// from within the already-running app.
class CatalogSyncBody extends StatelessWidget {
  const CatalogSyncBody({super.key, required this.playlist, this.footer});

  final PlaylistManager playlist;

  /// Shown at the bottom in a dimmer style — the automatic (launch-time)
  /// and manual ("Update Content") triggers word this differently, since
  /// only the automatic one is about *not* having to see this again soon.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ListenableBuilder(
            listenable: playlist,
            builder: (context, _) {
              final total = playlist.warmCatalogTotal;
              final done = playlist.warmCatalogDone;
              final hasProgress = total > 0;
              final fraction =
                  hasProgress ? (done / total).clamp(0.0, 1.0) : null;
              final phase = playlist.loadingPhase ??
                  (hasProgress
                      ? tr('Loading movies & TV shows...')
                      : tr('Connecting to server...'));
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_sync_outlined,
                      color: Colors.white70, size: 48),
                  const SizedBox(height: 24),
                  Text(
                    tr('Updating Content'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    phase,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 260,
                    child: LinearProgressIndicator(value: fraction),
                  ),
                  if (hasProgress) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr('{done} / {total} categories',
                          {'done': done, 'total': total}),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 32),
                    Text(
                      footer!,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Blocking "Updating..." screen shown while the *automatic* full catalog
/// sync runs at launch — see [PlaylistManager.runFullCatalogSync] and
/// [CatalogSyncBody] for the shared progress UI. This variant wraps its
/// own MaterialApp/Scaffold because it renders from main.dart's bootstrap
/// gate, before the app's real MaterialApp tree exists yet.
class CatalogSyncScreen extends StatelessWidget {
  const CatalogSyncScreen({super.key, required this.playlist});

  final PlaylistManager playlist;

  @override
  Widget build(BuildContext context) {
    // Same fix, same reason, as CatalogSyncPromptScreen's own doc comment
    // — this also renders from main.dart's bootstrap gate with its own
    // MaterialApp, which previously meant CatalogSyncBody's progress
    // indicator fell back to Flutter's stock default ColorScheme instead
    // of the user's palette.
    final palette = context.watch<AppPreferences>().palette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(palette),
      home: Scaffold(
        body: CatalogSyncBody(
          playlist: playlist,
          footer: tr(
              'This happens every few days to keep your catalog current — everyday launches open straight in.'),
        ),
      ),
    );
  }
}

/// Confirms and runs [PlaylistManager.runFullCatalogSync] behind a blocking progress screen.
/// Returns true if the sync ran, or false if cancelled.
Future<bool> confirmAndRunFullCatalogSync(
    BuildContext context, PlaylistManager playlist) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Update content now?')),
      content: Text(
        tr('Re-checks every visible category for new content. This can take a few minutes on a large catalog.'),
      ),
      // Use ModeButton to distinguish actual D-pad focus from the default appearance of a
      // filled action.
      actions: [
        ModeButton(
            label: tr('Cancel'),
            selected: false,
            onTap: () => Navigator.of(context).pop(false)),
        ModeButton(
            label: tr('Update'),
            selected: false,
            onTap: () => Navigator.of(context).pop(true)),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final syncFuture = playlist.runFullCatalogSync();
  if (!context.mounted) return false;
  final navigator = Navigator.of(context);
  unawaited(navigator.push(MaterialPageRoute(
    builder: (_) => Scaffold(
        body: CatalogSyncBody(playlist: playlist)),
  )));
  await syncFuture;
  if (context.mounted) navigator.pop();
  return true;
}


/// Pick a specific enabled playlist, or explicitly choose to refresh all.
/// Native focusable ListTiles keep the Shield D-pad inside this modal route.
Future<bool> chooseAndRefreshPlaylists(
    BuildContext context, PlaylistManager playlist) async {
  final enabled = playlist.profiles.where((p) => p.enabled).toList();
  if (enabled.isEmpty) return false;
  const allId = '__all_playlists__';
  final selectedId = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('Refresh playlists')),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < enabled.length; i++)
              ListTile(
                autofocus: i == 0,
                leading: Icon(enabled[i].isXtream ? Icons.dns : Icons.link),
                title: Text(enabled[i].name),
                subtitle: Text(enabled[i].isXtream ? 'Xtream' : 'M3U'),
                onTap: () => Navigator.of(dialogContext).pop(enabled[i].id),
              ),
            if (enabled.length > 1)
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(tr('Update All Playlists')),
                onTap: () => Navigator.of(dialogContext).pop(allId),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(tr('Cancel')),
        ),
      ],
    ),
  );
  if (selectedId == null || !context.mounted) return false;
  final selected = selectedId == allId
      ? enabled
      : enabled.where((p) => p.id == selectedId).toList();
  if (selected.isEmpty) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('Update content now?')),
      content: Text(selectedId == allId
          ? tr('Refresh all enabled playlists?')
          : 'Refresh ${selected.first.name}?'),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(tr('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(tr('Update')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final navigator = Navigator.of(context);
  // Show the existing progress UI for Xtream sync, but do not open a
  // second confirmation window or touch any unselected playlists.
  final hasXtream = selected.any((p) => p.isXtream);
  if (hasXtream) {
    unawaited(navigator.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: CatalogSyncBody(playlist: playlist)),
    )));
  }
  try {
    for (final profile in selected) {
      if (profile.isXtream) {
        await playlist.runFullCatalogSyncFor(profile.id);
      } else {
        await playlist.loadPlaylist(profile.id);
      }
    }
  } finally {
    if (hasXtream && context.mounted && navigator.canPop()) {
      navigator.pop();
    }
  }
  return true;
}
