import 'package:flutter/material.dart';

class IconActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool enabled;

  const IconActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<IconActionButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) {
    if (widget.enabled) {
      setState(() => _scale = 0.9);
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.enabled) {
      setState(() => _scale = 1.0);
      widget.onTap?.call();
    }
  }

  void _onTapCancel() {
    if (widget.enabled) {
      setState(() => _scale = 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color circleColor =
        widget.enabled ? (widget.color ?? Colors.orange) : Colors.grey.shade400;

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: Column(
        children: [
          GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: circleColor,
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  widget.enabled ? Colors.black87 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
