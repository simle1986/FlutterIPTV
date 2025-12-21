import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

class WindowTitleBar extends StatelessWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const WindowTitleBar({
    super.key,
    this.title = 'Lotus IPTV',
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 32,
        color: AppTheme.backgroundColor,
        child: Row(
          children: [
            // Draggable area
            const Expanded(child: SizedBox()),
            // Window buttons
            _WindowButton(
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
            ),
            _MaximizeButton(),
            _WindowButton(
              icon: Icons.close,
              hoverColor: Colors.red,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered
              ? (widget.hoverColor ?? const Color(0x33FFFFFF))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.hoverColor != null
                ? Colors.white
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MaximizeButton extends StatefulWidget {
  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> {
  bool _isHovered = false;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () async {
          if (_isMaximized) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
          _checkMaximized();
        },
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered ? const Color(0x33FFFFFF) : Colors.transparent,
          child: Icon(
            _isMaximized ? Icons.filter_none : Icons.crop_square,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
