import 'package:flutter/material.dart';

import '../../core/audio/podcast_chapters.dart';
import '../../core/audio/radio_audio_handler.dart';

Future<void> showChapterListSheet({
  required BuildContext context,
  required RadioAudioHandler handler,
  required List<PodcastChapter> chapters,
  required Duration position,
}) {
  final toc = PodcastChapterLogic.tocOf(chapters);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final current = PodcastChapterLogic.atPosition(
        chapters: toc.isEmpty ? chapters : toc,
        position: position,
      );
      final visible = toc.isEmpty ? chapters : toc;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('章节', style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final chapter = visible[index];
                    final selected = identical(chapter, current) ||
                        (current != null &&
                            chapter.start == current.start &&
                            chapter.title == current.title);
                    return ListTile(
                      selected: selected,
                      leading: Icon(
                        selected ? Icons.play_arrow : Icons.bookmark_outline,
                      ),
                      title: Text(chapter.title),
                      subtitle: Text(_formatStart(chapter.start)),
                      onTap: () {
                        handler.seek(chapter.start);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatStart(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}
