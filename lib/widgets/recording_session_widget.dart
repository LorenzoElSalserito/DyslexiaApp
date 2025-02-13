// lib/widgets/recording_session_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class RecordingSessionWidget extends StatefulWidget {
  final VoidCallback? onSessionComplete;
  const RecordingSessionWidget({Key? key, this.onSessionComplete}) : super(key: key);

  @override
  State<RecordingSessionWidget> createState() => _RecordingSessionWidgetState();
}

class _RecordingSessionWidgetState extends State<RecordingSessionWidget> {
  final AudioService _audioService = AudioService();
  bool _isRecording = false;
  bool _isWaiting = false;
  bool _isProcessing = false;
  int _currentAttempt = 0;
  double _volumeLevel = 0.0;
  String _statusMessage = '';
  Timer? _countdownTimer;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    await _audioService.initialize();
    _setupListeners();
  }

  void _setupListeners() {
    // Listen for volume updates.
    _audioService.volumeLevel.listen(_handleVolumeUpdate);
    // Listen for recording progress updates.
    _audioService.recordingProgress.listen(_handleProgressUpdate);
    // Listen for audio state changes.
    _audioService.audioState.listen(_handleStateChange);
  }

  void _handleStateChange(AudioState state) {
    setState(() {
      _isRecording = state == AudioState.recording;
      _isWaiting = state == AudioState.waitingNext;
      _updateStatusMessage(state);

      if (state == AudioState.waitingNext) {
        _startCountdown();
      }

      if (state == AudioState.stopped && _audioService.isSessionComplete) {
        widget.onSessionComplete?.call();
      }
    });
  }

  void _handleVolumeUpdate(double volume) {
    setState(() => _volumeLevel = volume);
  }

  void _handleProgressUpdate(int attempt) {
    setState(() => _currentAttempt = attempt);
  }

  void _updateStatusMessage(AudioState state) {
    // Removed the AudioState.paused case because it doesn't exist.
    setState(() {
      _statusMessage = switch (state) {
        AudioState.recording => 'Registrazione $_currentAttempt di ${_audioService.maxAttempts} in corso...',
        AudioState.waitingNext => 'Preparati per la prossima registrazione...',
        AudioState.stopped => _audioService.isSessionComplete
            ? 'Sessione completata!'
            : 'Premi il pulsante per registrare',
      };
    });
  }

  void _startCountdown() {
    _countdown = _audioService.delayBetweenRecordings.inSeconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _toggleRecording() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      if (_isRecording) {
        await _audioService.stopRecording();
      } else {
        await _audioService.startRecording();
      }
    } catch (e) {
      _showErrorDialog('Errore', e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'OpenDyslexic')),
        content: Text(message, style: const TextStyle(fontFamily: 'OpenDyslexic')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontFamily: 'OpenDyslexic')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Progress indicator.
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: LinearProgressIndicator(
            value: _currentAttempt / _audioService.maxAttempts,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _isRecording ? Colors.red[700]! : Colors.blue[700]!,
            ),
          ),
        ),
        Text(
          'Registrazione $_currentAttempt di ${_audioService.maxAttempts}',
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'OpenDyslexic',
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _countdown > 0
              ? '$_statusMessage\nProssima registrazione tra $_countdown secondi'
              : _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontFamily: 'OpenDyslexic'),
        ),
        const SizedBox(height: 30),
        // Volume indicator during recording.
        if (_isRecording)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.grey[200],
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _volumeLevel,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 30),
        // Recording button.
        if (!_audioService.isSessionComplete)
          Stack(
            alignment: Alignment.center,
            children: [
              ElevatedButton(
                onPressed: (_isWaiting || _isProcessing) ? null : _toggleRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: Text(
                  _isRecording ? 'Stop' : _isWaiting ? 'Preparati...' : 'Registra',
                  style: const TextStyle(fontSize: 18, fontFamily: 'OpenDyslexic'),
                ),
              ),
              if (_isProcessing) const CircularProgressIndicator(),
            ],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
