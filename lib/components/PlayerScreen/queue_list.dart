import 'package:audio_service/audio_service.dart';
import 'package:drag_and_drop_lists/drag_and_drop_list_interface.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

import '../../services/finamp_settings_helper.dart';
import '../album_image.dart';
import '../../models/jellyfin_models.dart' as jellyfin_models;
import '../../services/process_artist.dart';
import '../../services/media_state_stream.dart';
import '../../services/music_player_background_task.dart';
import '../../services/queue_service.dart';
import 'queue_list_item.dart';

class _QueueListStreamState {
  _QueueListStreamState(
    this.mediaState,
    this.playbackState,
    this.queueInfo,
  );

  final MediaState mediaState;
  final PlaybackState playbackState;
  final QueueInfo queueInfo;
}

class QueueList extends StatefulWidget {
  const QueueList({Key? key, required this.scrollController}) : super(key: key);

  final ScrollController scrollController;

  @override
  State<QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<QueueList> {
  final _queueService = GetIt.instance<QueueService>();

  QueueItemSource? _source;

  late List<Widget> _contents;

  @override
  void initState() {
    super.initState();

    _queueService.getQueueStream().listen((queueInfo) {
      _source = queueInfo.source;
    });

    _contents = <Widget>[
      // const SliverPadding(padding: EdgeInsets.only(top: 0)),
      // Previous Tracks
      SliverList.list(
        children: const [],
      ),
      // Current Track
      SliverAppBar(
          pinned: true,
          collapsedHeight: 70.0,
          expandedHeight: 70.0,
          leading: const Padding(
            padding: EdgeInsets.zero,
          ),
          flexibleSpace: ListTile(
              leading: const AlbumImage(
                item: null,
              ),
              title: Text("Unknown song"),
              subtitle: Text("Unknown artist"),
              onTap: () {})),
      SliverPersistentHeader(
          delegate: SectionHeaderDelegate(title: const Text("Queue"))),
      // Queue
      SliverList.list(
        children: const [],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _contents = <Widget>[
      // const SliverPadding(padding: EdgeInsets.only(top: 0)),
      // Previous Tracks
      const PreviousTracksList(),
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
        sliver: SliverPersistentHeader(
          delegate: SectionHeaderDelegate(
              title: const Text("Recently Played"), height: 30.0),
        ),
      ),
      CurrentTrack(),
      NextUpTracksList(),
      SliverPadding(
        padding: const EdgeInsets.only(top: 20.0, bottom: 6.0),
        sliver: SliverPersistentHeader(
          delegate: SectionHeaderDelegate(
            title: Row(
              children: [
                const Text("Playing from "),
                Text(_source?.name ?? "Unknown",
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            // _source != null ? "Playing from ${_source?.name}" : "Queue",
            controls: true,
          ),
        ),
      ),
      // Queue
      const QueueTracksList(),
    ];

    return CustomScrollView(
      controller: widget.scrollController,
      slivers: _contents,
    );
  }
}

Future<dynamic> showQueueBottomSheet(BuildContext context) {
  return showModalBottomSheet(
    // showDragHandle: true,
    useSafeArea: true,
    enableDrag: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    context: context,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 3.5,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3.5),
                ),
              ),
              const SizedBox(height: 10),
              const Text("Queue",
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lexend Deca',
                      fontSize: 18,
                      fontWeight: FontWeight.w300)),
              const SizedBox(height: 20),
              Expanded(
                child: QueueList(
                  scrollController: scrollController,
                ),
              ),
            ],
          );
          // )
          // return QueueList(
          //   scrollController: scrollController,
          // );
        },
      );
    },
  );
}

class PreviousTracksList extends StatefulWidget {
  const PreviousTracksList({
    Key? key,
  }) : super(key: key);

  @override
  State<PreviousTracksList> createState() => _PreviousTracksListState();
}

class _PreviousTracksListState extends State<PreviousTracksList> {
  final _queueService = GetIt.instance<QueueService>();
  List<QueueItem>? _previousTracks;

  @override
  Widget build(context) {
    return StreamBuilder<List<QueueItem>>(
      // stream: AudioService.queueStream,
      // stream: Rx.combineLatest2<MediaState, QueueInfo, _QueueListStreamState>(
      //     mediaStateStream,
      //     _queueService.getQueueStream(),
      //     (a, b) => _QueueListStreamState(a, b)),
      stream: _queueService.getPreviousTracksStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _previousTracks ??= snapshot.data!;

          return SliverReorderableList(
            onReorder: (oldIndex, newIndex) {
              int draggingOffset = -(_previousTracks!.length - oldIndex);
              int newPositionOffset = -(_previousTracks!.length - newIndex);
              print("$draggingOffset -> $newPositionOffset");
              if (mounted) {
                setState(() {
                  // temporarily update internal queue
                  QueueItem tmp = _previousTracks!.removeAt(oldIndex);
                  _previousTracks!.insert(
                      newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                  // update external queue to commit changes, results in a rebuild
                  _queueService.reorderByOffset(
                      draggingOffset, newPositionOffset);
                });
              }
            },
            itemCount: _previousTracks?.length ?? 0,
            itemBuilder: (context, index) {
              final item = _previousTracks![index];
              final actualIndex = index;
              final indexOffset = -((_previousTracks?.length ?? 0) - index);
              return QueueListItem(
                key: ValueKey(_previousTracks![actualIndex].id),
                item: item,
                listIndex: index,
                actualIndex: actualIndex,
                indexOffset: indexOffset,
                subqueue: _previousTracks!,
                onTap: () async {
                  await _queueService.skipByOffset(indexOffset);
                },
                isCurrentTrack: false,
              );
            },
          );
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }
}

class NextUpTracksList extends StatefulWidget {
  const NextUpTracksList({
    Key? key,
  }) : super(key: key);

  @override
  State<NextUpTracksList> createState() => _NextUpTracksListState();
}

class _NextUpTracksListState extends State<NextUpTracksList> {
  final _queueService = GetIt.instance<QueueService>();
  List<QueueItem>? _nextUp;

  @override
  Widget build(context) {
    return StreamBuilder<QueueInfo>(
      // stream: AudioService.queueStream,
      stream: _queueService.getQueueStream(),
      // stream: _queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _nextUp ??= snapshot.data!.nextUp;

          return SliverPadding(
              padding: const EdgeInsets.only(top: 20.0, left: 8.0, right: 8.0),
              sliver: SliverReorderableList(
                onReorder: (oldIndex, newIndex) {
                  int draggingOffset = oldIndex + 1;
                  int newPositionOffset = newIndex + 1;
                  print("$draggingOffset -> $newPositionOffset");
                  if (mounted) {
                    setState(() {
                      // temporarily update internal queue
                      QueueItem tmp = _nextUp!.removeAt(oldIndex);
                      _nextUp!.insert(
                          newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                      // update external queue to commit changes, results in a rebuild
                      _queueService.reorderByOffset(
                          draggingOffset, newPositionOffset);
                    });
                  }
                },
                itemCount: _nextUp?.length ?? 0,
                itemBuilder: (context, index) {
                  final item = _nextUp![index];
                  final actualIndex = index;
                  final indexOffset = index + 1;
                  return QueueListItem(
                    key: ValueKey(_nextUp![actualIndex].id),
                    item: item,
                    listIndex: index,
                    actualIndex: actualIndex,
                    indexOffset: indexOffset,
                    subqueue: _nextUp!,
                    onTap: () async {
                      await _queueService.skipByOffset(indexOffset);
                    },
                    isCurrentTrack: false,
                  );
                },
              ));
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }
}

class QueueTracksList extends StatefulWidget {
  const QueueTracksList({
    Key? key,
  }) : super(key: key);

  @override
  State<QueueTracksList> createState() => _QueueTracksListState();
}

class _QueueTracksListState extends State<QueueTracksList> {
  final _queueService = GetIt.instance<QueueService>();
  List<QueueItem>? _queue;
  List<QueueItem>? _nextUp;

  @override
  Widget build(context) {
    return StreamBuilder<QueueInfo>(
      // stream: AudioService.queueStream,
      stream: _queueService.getQueueStream(),
      // stream: _queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _queue ??= snapshot.data!.queue;
          _nextUp ??= snapshot.data!.nextUp;

          return SliverReorderableList(
            onReorder: (oldIndex, newIndex) {
              int draggingOffset = oldIndex + (_nextUp?.length ?? 0) + 1;
              int newPositionOffset = newIndex + (_nextUp?.length ?? 0) + 1;
              print("$draggingOffset -> $newPositionOffset");
              if (mounted) {
                setState(() {
                  // temporarily update internal queue
                  QueueItem tmp = _queue!.removeAt(oldIndex);
                  _queue!.insert(
                      newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                  // update external queue to commit changes, results in a rebuild
                  _queueService.reorderByOffset(
                      draggingOffset, newPositionOffset);
                });
              }
            },
            itemCount: _queue?.length ?? 0,
            itemBuilder: (context, index) {
              final item = _queue![index];
              final actualIndex = index;
              final indexOffset = index + 1;
              return QueueListItem(
                key: ValueKey(_queue![actualIndex].id),
                item: item,
                listIndex: index,
                actualIndex: actualIndex,
                indexOffset: indexOffset,
                subqueue: _queue!,
                onTap: () async {
                  await _queueService.skipByOffset(indexOffset);
                },
                isCurrentTrack: false,
              );
            },
          );
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }
}

class CurrentTrack extends StatelessWidget {
  const CurrentTrack({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(context) {
    final queueService = GetIt.instance<QueueService>();
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

    QueueItem? currentTrack;
    MediaState? mediaState;
    PlaybackState? playbackState;

    return StreamBuilder<_QueueListStreamState>(
      stream: Rx.combineLatest3<MediaState, PlaybackState, QueueInfo,
              _QueueListStreamState>(
          mediaStateStream,
          audioHandler.playbackState,
          queueService.getQueueStream(),
          (a, b, c) => _QueueListStreamState(a, b, c)),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          currentTrack ??= snapshot.data!.queueInfo.currentTrack;
          mediaState ??= snapshot.data!.mediaState;
          playbackState ??= snapshot.data!.playbackState;

          return SliverAppBar(
            // key: currentTrackKey,
            pinned: true,
            collapsedHeight: 70.0,
            expandedHeight: 70.0,
            elevation: 10.0,
            leading: const Padding(
              padding: EdgeInsets.zero,
            ),
            flexibleSpace: Container(
              // width: 328,
              height: 70.0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: const ShapeDecoration(
                  color: Color.fromRGBO(188, 136, 86, 0.20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AlbumImage(
                          item: currentTrack!.item.extras?["itemJson"] == null
                              ? null
                              : jellyfin_models.BaseItemDto.fromJson(
                                  currentTrack!.item.extras?["itemJson"]),
                        ),
                        Container(
                            width: 70,
                            height: 70,
                            decoration: const ShapeDecoration(
                              shape: Border(),
                              color: Color.fromRGBO(0, 0, 0, 0.25),
                            ),
                            child: IconButton(
                              onPressed: () {
                                audioHandler.togglePlayback();
                              },
                              icon: playbackState!.playing
                                  ? const Icon(
                                      TablerIcons.player_pause,
                                      size: 32,
                                    )
                                  : const Icon(
                                      TablerIcons.player_play,
                                      size: 32,
                                    ),
                            )),
                      ],
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Container(
                              width: 320 *
                                  (playbackState!.position.inSeconds /
                                      (mediaState?.mediaItem?.duration ??
                                              const Duration(seconds: 0))
                                          .inSeconds),
                              height: 70.0,
                              decoration: const ShapeDecoration(
                                color: Color.fromRGBO(188, 136, 86, 0.75),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                height: 70,
                                width: 150,
                                padding:
                                    const EdgeInsets.only(left: 12, right: 4),
                                // child: Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentTrack?.item.title ?? 'Unknown',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w500,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      processArtist(
                                          currentTrack!.item.artist, context),
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 13,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w300,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                // ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        // '0:00',
                                        playbackState!.position.inHours > 1.0
                                            ? audioHandler.playbackPosition
                                                .toString()
                                                .split('.')[0]
                                            : audioHandler.playbackPosition
                                                .toString()
                                                .substring(2, 7),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '/',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        // '3:44',
                                        (mediaState?.mediaItem?.duration
                                                        ?.inHours ??
                                                    const Duration(seconds: 0)
                                                        .inHours) >
                                                1.0
                                            ? (mediaState
                                                        ?.mediaItem?.duration ??
                                                    const Duration(seconds: 0))
                                                .toString()
                                                .split('.')[0]
                                            : (mediaState
                                                        ?.mediaItem?.duration ??
                                                    const Duration(seconds: 0))
                                                .toString()
                                                .substring(2, 7),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      TablerIcons.heart,
                                      size: 32,
                                      color: Colors.white,
                                      weight: 1.5,
                                    ),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      TablerIcons.dots_vertical,
                                      size: 32,
                                      color: Colors.white,
                                      weight: 1.5,
                                    ),
                                    onPressed: () {},
                                  ),
                                ],
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
          );
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }
}

class SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget title;
  final bool controls;
  final double height;

  SectionHeaderDelegate({
    required this.title,
    this.controls = false,
    this.height = 30.0,
  });

  @override
  Widget build(context, double shrinkOffset, bool overlapsContent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              child: Flex(
                  direction: Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                title,
              ])),
          if (controls)
            IconButton(
              icon: const Icon(TablerIcons.arrows_shuffle),
              onPressed: () {},
            ),
          if (controls)
            IconButton(
              icon: const Icon(TablerIcons.repeat),
              onPressed: () {},
            ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => false;
}
