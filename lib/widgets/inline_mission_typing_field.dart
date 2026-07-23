import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class InlineMissionTypingField extends StatefulWidget {
  const InlineMissionTypingField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.targetText,
    required this.hintText,
    required this.textColor,
    required this.mutedTextColor,
    required this.cursorColor,
    required this.errorColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.scale,
    this.displayText,
    this.confirmedProgress,
    this.acceptsInput = true,
    this.showMistakes = true,
    this.onTap,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String targetText;
  final String hintText;
  final Color textColor;
  final Color mutedTextColor;
  final Color cursorColor;
  final Color errorColor;
  final Color backgroundColor;
  final Color borderColor;
  final double scale;
  final String? displayText;
  final double? confirmedProgress;
  final bool acceptsInput;
  final bool showMistakes;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  @override
  State<InlineMissionTypingField> createState() =>
      _InlineMissionTypingFieldState();
}

class _InlineMissionTypingFieldState extends State<InlineMissionTypingField> {
  static final RegExp _typablePattern = RegExp(r'[\p{L}\p{N}]', unicode: true);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant InlineMissionTypingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleTextChanged);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final typableCount = _typableChars(widget.targetText).length;
    final visibleInput = widget.displayText ?? widget.controller.text;
    final confirmedTypableCount = widget.confirmedProgress == null
        ? null
        : (typableCount * widget.confirmedProgress!.clamp(0.0, 1.0)).round();
    final fontSize = 18 * widget.scale;
    final minHeight = 228 * widget.scale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          widget.onTap ??
          (widget.acceptsInput ? widget.focusNode.requestFocus : null),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: EdgeInsets.fromLTRB(
          16 * widget.scale,
          16 * widget.scale,
          16 * widget.scale,
          14 * widget.scale,
        ),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.borderColor),
        ),
        child: Stack(
          children: [
            IgnorePointer(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: widget.mutedTextColor,
                    fontSize: fontSize,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                  children: widget.targetText.trim().isEmpty
                      ? [
                          TextSpan(
                            text: widget.hintText,
                            style: TextStyle(
                              color: widget.mutedTextColor,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ]
                      : _buildStyledTextSpans(
                          fontSize,
                          visibleInput,
                          confirmedTypableCount,
                        ),
                ),
              ),
            ),
            if (widget.acceptsInput)
              Positioned.fill(
                child: CupertinoTextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardAppearance: Brightness.dark,
                  scrollPadding: EdgeInsets.zero,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(_typablePattern),
                    LengthLimitingTextInputFormatter(typableCount),
                  ],
                  style: TextStyle(
                    color: const Color(0x00FFFFFF),
                    fontSize: fontSize,
                    height: 1.55,
                  ),
                  decoration: const BoxDecoration(),
                  cursorColor: const Color(0x00FFFFFF),
                  selectionControls: null,
                  padding: EdgeInsets.zero,
                  placeholder: widget.controller.text.isEmpty
                      ? widget.hintText
                      : null,
                  placeholderStyle: TextStyle(
                    color: const Color(0x00FFFFFF),
                    fontSize: fontSize,
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildStyledTextSpans(
    double fontSize,
    String inputText,
    int? confirmedTypableCount,
  ) {
    final targetChars = widget.targetText.characters.toList();
    final inputChars = _typableChars(inputText);
    final spans = <TextSpan>[];
    var typedIndex = 0;
    var targetTypableIndex = 0;
    var cursorDrawn = false;

    for (final targetChar in targetChars) {
      final typable = _isTypable(targetChar);
      final cursorIndex = confirmedTypableCount ?? inputChars.length;

      if (typable && targetTypableIndex == cursorIndex && !cursorDrawn) {
        spans.add(_cursorSpan(fontSize));
        cursorDrawn = true;
      }

      if (!typable) {
        spans.add(
          TextSpan(
            text: targetChar,
            style: TextStyle(
              color: widget.mutedTextColor.withValues(alpha: 0.42),
            ),
          ),
        );
        continue;
      }

      if (confirmedTypableCount != null) {
        final confirmed = targetTypableIndex < confirmedTypableCount;
        spans.add(
          TextSpan(
            text: targetChar,
            style: TextStyle(
              color: confirmed
                  ? widget.textColor
                  : widget.mutedTextColor.withValues(alpha: 0.48),
              fontWeight: confirmed ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        );
        targetTypableIndex++;
      } else if (typedIndex < inputChars.length) {
        final typedChar = inputChars[typedIndex];
        final correct = typedChar.toLowerCase() == targetChar.toLowerCase();
        spans.add(
          TextSpan(
            text: correct || !widget.showMistakes ? targetChar : typedChar,
            style: TextStyle(
              color: correct || !widget.showMistakes
                  ? widget.textColor
                  : widget.errorColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        typedIndex++;
        targetTypableIndex++;
      } else {
        spans.add(
          TextSpan(
            text: targetChar,
            style: TextStyle(
              color: widget.mutedTextColor.withValues(alpha: 0.48),
            ),
          ),
        );
        targetTypableIndex++;
      }
    }

    if (!cursorDrawn &&
        (confirmedTypableCount ?? inputChars.length) >=
            _typableChars(widget.targetText).length) {
      spans.add(_cursorSpan(fontSize));
    }

    return spans;
  }

  TextSpan _cursorSpan(double fontSize) {
    return TextSpan(
      text: '▌',
      style: TextStyle(
        color: widget.cursorColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  static bool _isTypable(String value) => _typablePattern.hasMatch(value);

  static List<String> _typableChars(String value) {
    return value.characters.where(_isTypable).toList(growable: false);
  }
}
