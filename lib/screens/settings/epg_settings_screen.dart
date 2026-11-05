import '../../utils/guide_enrichment.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/epg_service.dart';
import '../../services/playlist_manager.dart';
import '../../services/storage_service.dart';
import '../../utils/time_format.dart';
import '../../utils/constants.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/settings_section.dart';
import '../../l10n/l10n.dart';

class EpgSettingsScreen extends StatefulWidget {
  const EpgSettingsScreen({super.key});

  @override
  State<EpgSettingsScreen> createState() => _EpgSettingsScreenState();
}

class _EpgSettingsScreenState extends State<EpgSettingsScreen> {
  late int _refreshInterval =
      context.read<StorageService>().getRefreshInterval();

  List<EpgSource> _sources() => context.read<PlaylistManager>().epgSources();

  String? _focusedSource; // No public guide is selected by default.

  Future<void> _choosePlaylists() async {
    final sourceId = _focusedSource;
    if (sourceId == null) return;
    final manager = context.read<PlaylistManager>();
    final playlists = manager.profiles;
    final assignments = manager.supplementaryGuidePlaylists();
    final selected = {...(assignments[sourceId] ?? <String>{})};
    final saved = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: Text(tr('Add to Playlist')),
          content: SizedBox(
            width: 440,
            child: playlists.isEmpty
                ? Text(tr('No playlists added yet.'))
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final playlist in playlists)
                        CheckboxListTile(
                          title: Text(playlist.name),
                          value: selected.contains(playlist.id),
                          onChanged: (value) => update(() {
                            if (value == true) {
                              selected.add(playlist.id);
                            } else {
                              selected.remove(playlist.id);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: Text(tr('Save')),
            ),
          ],
        ),
      ),
    );
    if (saved == null || !mounted) return;
    final newlyAssigned = saved.difference(assignments[sourceId] ?? <String>{});
    assignments[sourceId] = saved;
    await manager.setSupplementaryGuidePlaylists(assignments);
    if (!mounted) return;
    setState(() => _focusedSource = null);
    // Only new assignments trigger a download. Reopening and saving an
    // unchanged selection must not start a costly guide refresh.
    if (newlyAssigned.isNotEmpty) {
      final epg = context.read<EpgService>();
      if (!epg.isLoading) {
        unawaited(epg.refreshSupplementaryOnly());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Guide is already updating. If the new source does not appear, refresh the guide after it finishes.')),
        ));
      }
    }
  }

  Future<void> _applyInterval(int minutes) async {
    setState(() => _refreshInterval = minutes);
    final storage = context.read<StorageService>();
    await storage.setRefreshInterval(minutes);
    if (mounted) {
      final playlist = context.read<PlaylistManager>();
      context.read<EpgService>().startAutoRefresh(minutes, playlist.epgSources);
    }
  }

  Future<void> _updateNow() async {
    final sources = _sources();
    if (sources.isEmpty && context.read<PlaylistManager>().supplementaryGuideSelection().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                tr('Add a guide URL to your playlist to download listings.'))),
      );
      return;
    }
    await context.read<EpgService>().refreshAll();
  }

  Future<void> _clearGuide() async {
    final clear = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(tr('Clear guide listings?')),
              content: Text(tr(
                  'Downloaded programme listings will be removed. Your playlists, favourites and saved guide assignments stay saved.')),
              actions: [
                TextButton(
                    autofocus: true,
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(tr('Cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(tr('Clear listings'))),
              ],
            ));
    if (clear != true || !mounted) return;
    await context.read<EpgService>().clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
            'Guide listings cleared. Use Refresh guide to download them again.'))));
  }

  Widget _sourceTile(String id, String name, String source, bool busy) {
    final assignments = context.read<PlaylistManager>().supplementaryGuidePlaylists();
    final count = assignments[id]?.length ?? 0;
    return TvMenuTile(
      icon: Icons.public,
      title: name,
      subtitle: '$source · $count playlist(s)',
      enabled: true,
      trailing: Icon(
        _focusedSource == id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      onTap: () => setState(() => _focusedSource = id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final epg = context.watch<EpgService>();

    final updates = SettingsSection(title: tr('Guide updates'), children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<int>(
              initialValue: _refreshInterval,
              decoration:
                  InputDecoration(labelText: tr('Refresh automatically')),
              items: AppConstants.refreshIntervalOptions
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(tr('Every {p} hours', {'p': m ~/ 60}))))
                  .toList(),
              onChanged: epg.isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        _applyInterval(value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            Text(
                epg.lastUpdated == null
                    ? tr('No listings downloaded yet')
                    : tr('Updated {p}',
                        {'p': TimeFormat.dateTime(epg.lastUpdated!)}),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(epg.isLoading
                    ? (epg.refreshStatus ?? tr('Refreshing listings…'))
                    : tr('Refresh guide')),
                onPressed: epg.isLoading ? null : _updateNow),
          ])),
    ]);
    final gaps = SettingsSection(title: tr('Fill missing listings'), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Text(
            tr('Choose a public guide, then select Add to Playlist to choose which playlists use it. Only missing listings are filled.'),
            style: Theme.of(context).textTheme.bodySmall),
      ),
      for (final source in guideEnrichmentSources)
        _sourceTile(
            source.country, source.label, 'iptv-epg.org', epg.isLoading),
      _sourceTile('all', 'All Countries', 'EPGShare01 · XMLTV guide', epg.isLoading),
      Padding(
        padding: const EdgeInsets.fromLTRB(56, 0, 12, 12),
        child: Text(
          tr('Requires matching EPGShare channel IDs (tvg-id) to display program listings.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: FilledButton.icon(
          onPressed: _focusedSource == null ? null : _choosePlaylists,
          icon: const Icon(Icons.playlist_add),
          label: Text(tr('Add to Playlist')),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Text(
            tr('Updates only request guides with matching channels. Turning a source off stops future updates and keeps downloaded listings until they expire.'),
            style: Theme.of(context).textTheme.bodySmall),
      ),
    ]);
    final maintenance = SettingsSection(title: tr('Storage'), children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OutlinedButton.icon(
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                onPressed: epg.isLoading ? null : _clearGuide,
                label: Text(tr('Clear guide listings'))),
            const SizedBox(height: 8),
            Text(tr('Removes downloaded programme listings only. Refresh the guide to download them again.'),
                style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
    ]);
    final errors = [
      if (epg.error != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
                tr('Some listings could not be updated. Existing guide data has been kept.'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)))
    ];
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
              title: tr('TV guide'),
              body: LayoutBuilder(
                  builder: (context, constraints) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: constraints.maxWidth >= 760
                            ? [
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                            updates,
                                            ...errors,
                                            maintenance
                                          ])),
                                      const SizedBox(width: 16),
                                      Expanded(child: gaps),
                                    ])
                              ]
                            : [updates, gaps, ...errors, maintenance],
                      )),
            ));
  }
}
