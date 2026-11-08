import 'package:flutter/material.dart';

import 'l10n.dart';
import 'lock.dart';
import 'store.dart';
import 'widgets.dart';

/// Covers the whole app with a lock screen when "app lock" is on:
/// at start-up, and after the app has been in the background for a minute.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  static const _grace = Duration(seconds: 60);
  bool _locked = Store.i.appLock;
  bool _authing = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authing || !Store.i.appLock) return;
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (at != null && DateTime.now().difference(at) > _grace && !_locked) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authing) return;
    _authing = true;
    var ok = false;
    try {
      ok = await authenticate();
    } catch (_) {}
    // let the lifecycle events of the prompt pass before listening again
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _authing = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 56, color: kOrange),
                  const SizedBox(height: 16),
                  const Text("Joe's Notes",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          decoration: TextDecoration.none)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _unlock,
                    style: FilledButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(t('unlock_app')),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
