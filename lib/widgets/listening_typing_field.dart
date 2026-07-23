import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _textColor = Color(0xFFFFFFFF);
const _hintColor = Color(0xFFB0B0B0);
const _fillColor = Color(0xFF2A2A2A);
const _borderColor = Color(0xFF555555);
const _echoBg = Color(0xFF1A1A1A);

/// Multiline typing field for prayer screens — Cupertino on iOS for visible text.
class ListeningTypingField extends StatefulWidget {
  const ListeningTypingField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.echoLabel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;

  /// Optional label above the echo line (e.g. "What you typed").
  final String? echoLabel;

  @override
  State<ListeningTypingField> createState() => _ListeningTypingFieldState();
}

class _ListeningTypingFieldState extends State<ListeningTypingField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final typed = widget.controller.text;
    final hasText = typed.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: _echoBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.echoLabel != null) ...[
                Text(
                  widget.echoLabel!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _hintColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                hasText ? typed : widget.hintText,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  color: hasText ? _textColor : _hintColor,
                  fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CupertinoTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          keyboardAppearance: Brightness.dark,
          textCapitalization: TextCapitalization.sentences,
          autocorrect: false,
          enableSuggestions: false,
          cursorColor: _textColor,
          style: const TextStyle(
            color: _textColor,
            fontSize: 17,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
          placeholder: widget.hintText,
          placeholderStyle: const TextStyle(
            color: _hintColor,
            fontSize: 16,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
