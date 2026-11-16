import 'dart:math' as math;

import 'package:flutter/material.dart';

// Alpha surfaces can sit above a future licensed full-bleed background.
// These values are a readable base treatment, not reference-image parity.
double keypadTileHeight(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  return math.max(64, scaler.scale(22) + scaler.scale(11) + 20);
}

class KeypadSurface extends StatelessWidget {
  const KeypadSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xEB171A29),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x667F89AA)),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: const Color(0xFF194E99),
          backgroundColor: const Color(0xFFE6ECFA),
        ),
      ),
    ),
    child: child,
  );
}

/// Adds dialer legends without replacing the zero child owned by PR #37.
class KeypadTile extends StatelessWidget {
  const KeypadTile({super.key, required this.value, required this.child});
  final String value;
  final Widget child;

  static const legends = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
  };

  @override
  Widget build(BuildContext context) {
    final legend = legends[value];
    return SizedBox(
      height: keypadTileHeight(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Extra bottom padding raises the digit while retaining its button
          // semantics, keyboard focus and the full tile's hit target.
          Theme(
            data: Theme.of(context).copyWith(
              filledButtonTheme: FilledButtonThemeData(
                style: Theme.of(context).filledButtonTheme.style?.copyWith(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.fromLTRB(
                      4,
                      0,
                      4,
                      legend == null
                          ? 0
                          : MediaQuery.textScalerOf(context).scale(11) + 4,
                    ),
                  ),
                ),
              ),
            ),
            child: child,
          ),
          if (legend != null)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      legend,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1,
                        color: Color(0xFFE1BDFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
