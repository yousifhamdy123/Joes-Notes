import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

String _mmss(int totalSeconds) {
  final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Horizontal strip of images and voice recordings shown under the note text.
class AttachmentStrip extends StatelessWidget {
  final List<Attachment> items;
  final void Function(Attachment) onRemove;
  final VoidCallback? onChanged; // a recording was renamed
  final void Function(Attachment, int?)? onPosition; // playback ms (null = stopped)
  const AttachmentStrip({
    super.key,
    required this.items,
    required this.onRemove,
    this.onChanged,
    this.onPosition,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = items[i];
          return a.isImage
              ? _ImageTile(att: a, onRemove: () => onRemove(a))
              : AudioTile(
                  key: ValueKey(a.id),
                  att: a,
                  onRemove: () => onRemove(a),
                  onChanged: onChanged,
                  onPosition: onPosition,
                );
        },
      ),
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 2,
      end: 2,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final Attachment att;
  final VoidCallback onRemove;
  const _ImageTile({required this.att, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final file = Store.i.fileOf(att);
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ImageViewerPage(file: file)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              cacheWidth: 240,
              errorBuilder: (_, __, ___) => Container(
                width: 76,
                height: 76,
                color: kCard,
                child: const Icon(Icons.broken_image_outlined,
                    color: Colors.white38),
              ),
            ),
          ),
        ),
        _RemoveBadge(onTap: onRemove),
      ],
    );
  }
}

class ImageViewerPage extends StatelessWidget {
  final File file;
  const ImageViewerPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(file),
        ),
      ),
    );
  }
}

class AudioTile extends StatefulWidget {
  final Attachment att;
  final VoidCallback onRemove;
  final VoidCallback? onChanged;
  final void Function(Attachment, int?)? onPosition;
  const AudioTile({
    super.key,
    required this.att,
    required this.onRemove,
    this.onChanged,
    this.onPosition,
  });

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
      if (s != PlayerState.playing) widget.onPosition?.call(widget.att, null);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
      widget.onPosition?.call(widget.att, p.inMilliseconds);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _pos = Duration.zero;
          _playing = false;
        });
      }
      widget.onPosition?.call(widget.att, null);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final ctl = TextEditingController(text: widget.att.name);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('rename_rec')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          onSubmitted: (s) => Navigator.pop(ctx, s),
          decoration: InputDecoration(hintText: t('voice_note')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: Text(t('save'), style: TextStyle(color: kOrange)),
          ),
        ],
      ),
    );
    if (v == null) return;
    setState(() => widget.att.name = v.trim());
    widget.onChanged?.call();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
      } else if (_player.state == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player
            .play(DeviceFileSource(Store.i.fileOf(widget.att).path));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final total = (widget.att.durationMs / 1000).round();
    final shown = _playing || _pos > Duration.zero ? _pos.inSeconds : total;
    return Stack(
      children: [
        Container(
          width: 190,
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kCardBorder),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _rename,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_mmss(shown),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.att.name.isEmpty
                                  ? t('voice_note')
                                  : widget.att.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined,
                              size: 12, color: Colors.white38),
                        ],
                      ),
                      if (widget.att.marks.isNotEmpty)
                        Text(t('synced'),
                            style: TextStyle(fontSize: 10, color: kOrange)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _RemoveBadge(onTap: widget.onRemove),
      ],
    );
  }
}

/// Bottom sheet that records audio and returns an [Attachment].
class RecordSheet extends StatefulWidget {
  const RecordSheet({super.key});

  @override
  State<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<RecordSheet> {
  final AudioRecorder _rec = AudioRecorder();
  Timer? _timer;
  String? _path;
  int _sec = 0;
  bool _denied = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      final path = Store.i.newAttachPath('m4a');
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path);
      _path = path;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _sec++);
      });
      if (mounted) setState(() => _started = true);
    } catch (_) {
      if (mounted) setState(() => _denied = true);
    }
  }

  Future<void> _finish({required bool keep}) async {
    _timer?.cancel();
    String? stopped;
    try {
      stopped = await _rec.stop();
    } catch (_) {}
    final path = stopped ?? _path;
    if (!keep || path == null) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context);
      return;
    }
    if (mounted) {
      Navigator.pop(
        context,
        Attachment(
          id: Store.newId(),
          type: 'audio',
          file: path.split('/').last,
          durationMs: _sec * 1000,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_denied) ...[
                const Icon(Icons.mic_off_rounded,
                    size: 40, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(t('mic_denied'), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('close')),
                ),
              ] else ...[
                Text(t('recording'),
                    style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _started ? Colors.redAccent : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_mmss(_sec),
                        style: const TextStyle(
                            fontSize: 38, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _finish(keep: false),
                        child: Text(t('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _started ? () => _finish(keep: true) : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: kOrange,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(t('stop_save')),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
