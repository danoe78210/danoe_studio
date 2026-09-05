import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/antique_theme.dart';

/// Bouton « laiton / fer forgé » du thème bibliothèque.
/// [onParchment] = encre sépia sur fond clair ; sinon or sur cuir sombre.
class AntiqueButton extends StatefulWidget {
  final String label;
  final String? emoji;
  final IconData? icon;
  final VoidCallback onTap;
  final bool primary;
  final bool onParchment;
  final bool active;
  final bool compact;
  final bool iconOnly;
  final bool enabled;

  const AntiqueButton({
    super.key,
    required this.label,
    this.emoji,
    this.icon,
    required this.onTap,
    this.primary = false,
    this.onParchment = false,
    this.active = false,
    this.compact = false,
    this.iconOnly = false,
    this.enabled = true,
  });

  @override
  State<AntiqueButton> createState() => _AntiqueButtonState();
}

class _AntiqueButtonState extends State<AntiqueButton> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final foreground =
        widget.onParchment ? AntiqueTheme.inkSepia : AntiqueTheme.agedGold;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.active,
      label: widget.label,
      onTap: widget.enabled ? widget.onTap : null,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        child: Focus(
          canRequestFocus: widget.enabled,
          onKeyEvent: (_, event) {
            if (widget.enabled &&
                event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            key: const ValueKey('antique-button-focus'),
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            child: GestureDetector(
              onTap: widget.enabled ? widget.onTap : null,
              onTapDown: widget.enabled
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapUp: widget.enabled
                  ? (_) => setState(() => _pressed = false)
                  : null,
              onTapCancel: widget.enabled
                  ? () => setState(() => _pressed = false)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
                padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 12 : 16,
                    vertical: widget.compact ? 7 : 12),
                decoration: BoxDecoration(
                  color: widget.onParchment
                      ? (widget.active
                          ? AntiqueTheme.parchment
                          : (_hover
                              ? AntiqueTheme.brass.withValues(alpha: 0.08)
                              : AntiqueTheme.inkBlack.withValues(alpha: 0.06)))
                      : (_hover
                          ? AntiqueTheme.leatherDeep
                          : AntiqueTheme.leatherDark),
                  gradient: widget.active && widget.onParchment
                      ? AntiqueTheme.parchmentGradient
                      : widget.primary && widget.enabled
                          ? AntiqueTheme.leatherGradient
                          : null,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: _focused
                          ? AntiqueTheme.candleGlow
                          : AntiqueTheme.brass,
                      width: _focused ? 1.8 : 1.2),
                  boxShadow: (_hover || widget.active)
                      ? [
                          BoxShadow(
                            color: AntiqueTheme.candleGlow
                                .withValues(alpha: widget.active ? 0.32 : 0.25),
                            blurRadius: widget.active ? 12 : 10,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color:
                                AntiqueTheme.inkBlack.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Opacity(
                  opacity: widget.enabled ? 1 : 0.45,
                  child: Row(
                    mainAxisSize:
                        widget.iconOnly ? MainAxisSize.min : MainAxisSize.max,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon,
                            size: widget.compact ? 18 : 20, color: foreground),
                        if (!widget.iconOnly) const SizedBox(width: 10),
                      ],
                      if (widget.emoji != null) ...[
                        Text(widget.emoji!,
                            style:
                                TextStyle(fontSize: widget.compact ? 16 : 18)),
                        const SizedBox(width: 10),
                      ],
                      if (!widget.iconOnly)
                        Expanded(
                          child: Text(
                            widget.label,
                            style: GoogleFonts.cinzel(
                              fontSize: widget.compact ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: foreground,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
