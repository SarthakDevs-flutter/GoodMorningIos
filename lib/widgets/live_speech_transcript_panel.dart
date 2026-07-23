import 'package:flutter/material.dart';

/// Shows speech-to-text results live while the user reads prayer aloud.
class LiveSpeechTranscriptPanel extends StatelessWidget {
  const LiveSpeechTranscriptPanel({
    super.key,
    required this.transcript,
    required this.labelText,
    required this.hintText,
    this.isListening = false,
  });

  final String transcript;
  final String labelText;
  final String hintText;
  final bool isListening;

  static const _textColor = Color(0xFFFFFFFF);
  static const _hintColor = Color(0xFF888888);
  static const _labelColor = Color(0xFFB0B0B0);
  static const _fillColor = Color(0xFF1A1A1A);
  static const _borderColor = Color(0xFF333333);
  static const _accentColor = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final trimmed = transcript.trim();
    final hasText = trimmed.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isListening ? _accentColor.withValues(alpha: 0.5) : _borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isListening) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  labelText,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: _labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 140),
            child: SingleChildScrollView(
              child: Text(
                hasText ? trimmed : hintText,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: hasText ? _textColor : _hintColor,
                  fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
