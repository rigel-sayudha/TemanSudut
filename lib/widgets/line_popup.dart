import 'package:flutter/material.dart';

/// A reusable popup widget inspired by the LINE Design System.
/// Clean, minimal, centered text, large rounded corners.
class LinePopup extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? icon;
  final Widget? content;
  final List<LinePopupAction> actions;

  const LinePopup({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.content,
    this.actions = const [],
  });

  /// Show a simple confirmation popup (single button).
  static Future<void> showConfirm(
    BuildContext context, {
    required String title,
    String? description,
    Widget? icon,
    String confirmText = 'Konfirmasi',
    VoidCallback? onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => LinePopup(
        title: title,
        description: description,
        icon: icon,
        actions: [
          LinePopupAction(
            label: confirmText,
            style: LinePopupActionStyle.textBold,
            onTap: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
          ),
        ],
      ),
    );
  }

  /// Show a dual-action popup with dismiss/affirmative text buttons.
  static Future<T?> showDual<T>(
    BuildContext context, {
    required String title,
    String? description,
    Widget? icon,
    String dismissText = 'Batal',
    String affirmText = 'Ya',
    Color? affirmColor,
    VoidCallback? onDismiss,
    VoidCallback? onAffirm,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => LinePopup(
        title: title,
        description: description,
        icon: icon,
        actions: [
          LinePopupAction(
            label: dismissText,
            style: LinePopupActionStyle.textNormal,
            onTap: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
          ),
          LinePopupAction(
            label: affirmText,
            style: LinePopupActionStyle.textBold,
            color: affirmColor ?? const Color(0xFF5D4037),
            onTap: () {
              Navigator.of(context).pop();
              onAffirm?.call();
            },
          ),
        ],
      ),
    );
  }

  /// Show a stacked-button popup (primary filled + secondary outlined + cancel text).
  static Future<T?> showStacked<T>(
    BuildContext context, {
    required String title,
    String? description,
    Widget? icon,
    required String primaryText,
    String? secondaryText,
    String cancelText = 'Batal',
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
    VoidCallback? onCancel,
  }) {
    final List<LinePopupAction> actions = [
      LinePopupAction(
        label: primaryText,
        style: LinePopupActionStyle.filled,
        onTap: () {
          Navigator.of(context).pop();
          onPrimary?.call();
        },
      ),
    ];
    if (secondaryText != null) {
      actions.add(
        LinePopupAction(
          label: secondaryText,
          style: LinePopupActionStyle.outlined,
          onTap: () {
            Navigator.of(context).pop();
            onSecondary?.call();
          },
        ),
      );
    }
    actions.add(
      LinePopupAction(
        label: cancelText,
        style: LinePopupActionStyle.textBold,
        onTap: () {
          Navigator.of(context).pop();
          onCancel?.call();
        },
      ),
    );

    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => LinePopup(
        title: title,
        description: description,
        icon: icon,
        actions: actions,
      ),
    );
  }

  /// Show a dual popup that returns true/false (for WillPopScope etc.)
  static Future<bool> showConfirmChoice(
    BuildContext context, {
    required String title,
    String? description,
    Widget? icon,
    String dismissText = 'Batal',
    String affirmText = 'Ya',
    Color? affirmColor,
  }) async {
    return (await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.4),
          builder: (_) => LinePopup(
            title: title,
            description: description,
            icon: icon,
            actions: [
              LinePopupAction(
                label: dismissText,
                style: LinePopupActionStyle.textNormal,
                onTap: () => Navigator.of(context).pop(false),
              ),
              LinePopupAction(
                label: affirmText,
                style: LinePopupActionStyle.textBold,
                color: affirmColor ?? const Color(0xFF5D4037),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Separate text-style actions (inline row) from button-style actions (stacked)
    final inlineActions = actions
        .where(
          (a) =>
              a.style == LinePopupActionStyle.textBold ||
              a.style == LinePopupActionStyle.textNormal,
        )
        .toList();
    final buttonActions = actions
        .where(
          (a) =>
              a.style == LinePopupActionStyle.filled ||
              a.style == LinePopupActionStyle.outlined,
        )
        .toList();

    final bool hasButtons = buttonActions.isNotEmpty;
    final bool hasInline = inlineActions.isNotEmpty && !hasButtons;
    final bool hasMixed = buttonActions.isNotEmpty && inlineActions.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Optional icon
            if (icon != null) ...[icon!, const SizedBox(height: 20)],
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.3,
              ),
            ),
            // Description
            if (description != null) ...[
              const SizedBox(height: 10),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
            ],
            // Custom Content
            if (content != null) ...[const SizedBox(height: 16), content!],
            const SizedBox(height: 24),
            // Button-style actions (filled/outlined) — stacked
            if (hasButtons || hasMixed) ...[
              ...buttonActions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildButtonAction(action),
                ),
              ),
            ],
            // Text-style actions — inline row or single centered
            if (hasMixed) ...[
              // Cancel/dismiss text below buttons
              ...inlineActions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildTextAction(action),
                ),
              ),
            ] else if (hasInline) ...[
              if (inlineActions.length == 1)
                _buildTextAction(inlineActions.first)
              else
                Row(
                  children: inlineActions
                      .map(
                        (action) => Expanded(child: _buildTextAction(action)),
                      )
                      .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtonAction(LinePopupAction action) {
    if (action.style == LinePopupActionStyle.filled) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: action.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: action.color ?? const Color(0xFF5D4037),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            action.label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      // Outlined
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: action.onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            side: BorderSide(color: Colors.grey[300]!),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            action.label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }
  }

  Widget _buildTextAction(LinePopupAction action) {
    return TextButton(
      onPressed: action.onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      child: Text(
        action.label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: action.style == LinePopupActionStyle.textBold
              ? FontWeight.bold
              : FontWeight.normal,
          color:
              action.color ??
              (action.style == LinePopupActionStyle.textBold
                  ? Colors.black
                  : Colors.grey[600]),
        ),
      ),
    );
  }
}

enum LinePopupActionStyle {
  textBold, // Bold text button (confirm/affirmative)
  textNormal, // Normal text button (dismiss/cancel)
  filled, // Full-width filled button (primary action)
  outlined, // Full-width outlined button (secondary action)
}

class LinePopupAction {
  final String label;
  final LinePopupActionStyle style;
  final Color? color;
  final VoidCallback? onTap;

  const LinePopupAction({
    required this.label,
    required this.style,
    this.color,
    this.onTap,
  });
}
