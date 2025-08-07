import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/attachment.dart';

class AudioRecorderWidget extends StatefulWidget {
  final String entryId;
  final Function(Attachment) onRecordingComplete;
  final VoidCallback? onCancel;

  const AudioRecorderWidget({
    super.key,
    required this.entryId,
    required this.onRecordingComplete,
    this.onCancel,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  RecorderController? _recorderController;
  PlayerController? _playerController;
  
  bool _isRecording = false;
  bool _isRecordingComplete = false;
  bool _isPlaying = false;
  
  String? _recordedFilePath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorderController?.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _recorderController = RecorderController();
    _playerController = PlayerController();
  }

  Future<void> _startRecording() async {
    try {
      // Check microphone permission first
      final hasPermission = await _recorderController?.checkPermission();
      if (hasPermission != true) {
        _showErrorSnackBar('Microphone permission denied. Please enable microphone access in settings.');
        return;
      }

      // Get temporary directory for recording
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'recording_${_uuid.v4()}.m4a';
      final String filePath = '${tempDir.path}/$fileName';

      await _recorderController?.record(path: filePath);
      
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start duration timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _showErrorSnackBar('Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final String? filePath = await _recorderController?.stop();
      _recordingTimer?.cancel();
      
      if (filePath != null) {
        setState(() {
          _isRecording = false;
          _isRecordingComplete = true;
          _recordedFilePath = filePath;
        });

        // Initialize player with recorded file
        await _playerController?.preparePlayer(
          path: filePath,
          shouldExtractWaveform: true,
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _showErrorSnackBar('Failed to stop recording');
    }
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath == null) return;

    try {
      if (_isPlaying) {
        await _playerController?.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _playerController?.startPlayer();
        setState(() {
          _isPlaying = true;
        });

        // Listen for playback completion
        _playerController?.onCompletion.listen((_) {
          setState(() {
            _isPlaying = false;
          });
        });
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');
      _showErrorSnackBar('Failed to play recording');
    }
  }

  Future<void> _saveRecording() async {
    if (_recordedFilePath == null) return;

    try {
      final File file = File(_recordedFilePath!);
      final int fileSize = await file.length();

      final attachment = Attachment(
        id: _uuid.v4(),
        entryId: widget.entryId,
        type: AttachmentType.audio,
        name: 'Recording ${DateTime.now().toLocal().toString().substring(0, 19)}.m4a',
        path: _recordedFilePath!,
        size: fileSize,
        mimeType: 'audio/m4a',
        createdAt: DateTime.now(),
        metadata: {
          'duration': _recordingDuration.inSeconds.toString(),
          'format': 'm4a',
        },
      );

      widget.onRecordingComplete(attachment);
    } catch (e) {
      debugPrint('Error saving recording: $e');
      _showErrorSnackBar('Failed to save recording');
    }
  }

  void _discardRecording() {
    setState(() {
      _isRecording = false;
      _isRecordingComplete = false;
      _isPlaying = false;
      _recordedFilePath = null;
      _recordingDuration = Duration.zero;
    });
    _recordingTimer?.cancel();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'Audio Recording',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Waveform or Recording Indicator
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildWaveformDisplay(),
          ),
          const SizedBox(height: 20),

          // Duration Display
          Text(
            _formatDuration(_recordingDuration),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),

          // Control Buttons
          if (!_isRecordingComplete) ...[
            // Recording Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel Button
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                
                // Record/Stop Button
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                
                // Spacer (for symmetry)
                const SizedBox(width: 48),
              ],
            ),
          ] else ...[
            // Playback and Save Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Discard Button
                IconButton(
                  onPressed: _discardRecording,
                  icon: const Icon(Icons.delete),
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red,
                  ),
                ),
                
                // Play/Pause Button
                IconButton(
                  onPressed: _playRecording,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 40,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.blue,
                  ),
                ),
                
                // Save Button
                IconButton(
                  onPressed: _saveRecording,
                  icon: const Icon(Icons.check),
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    foregroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // Status Text
          Text(
            _getStatusText(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformDisplay() {
    if (_isRecording && _recorderController != null) {
      return AudioWaveforms(
        recorderController: _recorderController!,
        size: const Size(double.infinity, 80),
        waveStyle: const WaveStyle(
          waveColor: Colors.blue,
          extendWaveform: true,
          showMiddleLine: false,
        ),
      );
    } else if (_isRecordingComplete && _playerController != null) {
      return AudioFileWaveforms(
        playerController: _playerController!,
        size: const Size(double.infinity, 80),
        playerWaveStyle: const PlayerWaveStyle(
          fixedWaveColor: Colors.grey,
          liveWaveColor: Colors.blue,
          spacing: 6,
        ),
      );
    } else {
      return const Center(
        child: Icon(
          Icons.mic,
          size: 40,
          color: Colors.grey,
        ),
      );
    }
  }

  String _getStatusText() {
    if (_isRecording) {
      return 'Recording... Tap stop when finished';
    } else if (_isRecordingComplete) {
      return 'Recording complete. Play to review or save to add to entry';
    } else {
      return 'Tap the microphone to start recording';
    }
  }
}