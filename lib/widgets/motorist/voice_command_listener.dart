import 'package:flutter/material.dart';

class VoiceCommandListener extends StatefulWidget {
  final Function(String) onCommand;
  final bool isListening;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const VoiceCommandListener({
    Key? key,
    required this.onCommand,
    required this.isListening,
    required this.onStart,
    required this.onStop,
  }) : super(key: key);

  @override
  State<VoiceCommandListener> createState() => _VoiceCommandListenerState();
}

class _VoiceCommandListenerState extends State<VoiceCommandListener> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isListening ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isListening ? 'Listening...' : 'Tap to speak',
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  widget.isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                ),
                onPressed: widget.isListening ? widget.onStop : widget.onStart,
              ),
            ],
          ),
        ],
      ),
    );
  }
}