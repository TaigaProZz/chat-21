import 'package:flutter/material.dart';

class CallOverlay extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String callStateText;
  final bool isAudioMuted;
  final bool isSpeakerOn;
  final bool showMute;
  final bool showSpeaker;
  final bool showHangUp;
  final VoidCallback? onMute;
  final VoidCallback? onSpeaker;
  final VoidCallback onHangUp;
  final String? callDuration;

  const CallOverlay({
    super.key,
    required this.name,
    required this.callStateText,
    required this.isAudioMuted,
    required this.isSpeakerOn,
    required this.showMute,
    required this.showSpeaker,
    required this.showHangUp,
    this.avatarUrl,
    this.onMute,
    this.onSpeaker,
    required this.onHangUp,
    this.callDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, size: 60)
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            callStateText,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (callDuration != null) ...[
            const SizedBox(height: 10),
            Text(
              callDuration!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (showMute)
                FloatingActionButton(
                  onPressed: onMute,
                  backgroundColor: isAudioMuted ? Colors.red : Colors.grey,
                  child: Icon(
                    isAudioMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              if (showSpeaker)
                FloatingActionButton(
                  onPressed: onSpeaker,
                  backgroundColor: isSpeakerOn ? Colors.blue : Colors.grey,
                  child: Icon(
                    isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    color: Colors.white,
                  ),
                ),
              if (showHangUp)
                FloatingActionButton(
                  onPressed: onHangUp,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
