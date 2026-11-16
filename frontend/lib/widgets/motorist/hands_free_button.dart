import 'package:flutter/material.dart';

class HandsFreeButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isListening;

  const HandsFreeButton({
    super.key,
    required this.onPressed,
    this.isListening = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isListening ? Colors.red : Colors.blue,
        boxShadow: [
          BoxShadow(
            color: (isListening ? Colors.red : Colors.blue).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          size: 40,
          color: Colors.white,
        ),
        onPressed: onPressed,
      ),
    );
  }
}