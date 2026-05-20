import 'package:flutter/material.dart';

import '../design/dpl_theme.dart';

/// Caption + big tabular number cell. Drop a row of 2 or 3 of these
/// inside a [DplCard] to replace the old flat "Plan 12 / Actual 0"
/// layouts.
class DplStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final Color? valueColor;
  final TextStyle? valueStyle;
  final CrossAxisAlignment crossAxisAlignment;

  const DplStatTile({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.valueColor,
    this.valueStyle,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? DplColors.textPrimary;
    final big =
        (valueStyle ?? DplText.numLg()).copyWith(color: color, height: 1.05);
    final small = DplText.bodySm().copyWith(
      color: color,
      fontWeight: FontWeight.w800,
    );

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: DplText.caption()),
        const SizedBox(height: DplSpacing.xs),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: big),
              if (suffix != null && suffix!.isNotEmpty)
                TextSpan(text: suffix, style: small),
            ],
          ),
        ),
      ],
    );
  }
}
