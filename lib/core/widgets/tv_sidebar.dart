import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../navigation/app_router.dart';
import '../i18n/app_strings.dart';
import 'tv_focusable.dart';

/// TV端共享侧边栏组件
/// 失去焦点收起，获得焦点展开
class TVSidebar extends StatefulWidget {
  final int selectedIndex;
  final Widget child;
  final VoidCallback? onRight;  // 按右键时的回调
  
  /// 用于外部获取菜单焦点节点列表
  static List<FocusNode>? menuFocusNodes;

  const TVSidebar({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.onRight,
  });

  @override
  State<TVSidebar> createState() => _TVSidebarState();
}

class _TVSidebarState extends State<TVSidebar> {
  bool _expanded = false;
  final List<FocusNode> _menuFocusNodes = [];

  @override
  void initState() {
    super.initState();
    // 创建5个菜单项的焦点节点
    for (int i = 0; i < 5; i++) {
      _menuFocusNodes.add(FocusNode());
    }
    // 暴露给外部
    TVSidebar.menuFocusNodes = _menuFocusNodes;
  }

  @override
  void dispose() {
    for (final node in _menuFocusNodes) {
      node.dispose();
    }
    TVSidebar.menuFocusNodes = null;
    super.dispose();
  }

  List<_NavItem> _getNavItems(BuildContext context) {
    return [
      _NavItem(icon: Icons.home_rounded, label: AppStrings.of(context)?.home ?? 'Home', route: null),
      _NavItem(icon: Icons.live_tv_rounded, label: AppStrings.of(context)?.channels ?? 'Channels', route: AppRouter.channels),
      _NavItem(icon: Icons.favorite_rounded, label: AppStrings.of(context)?.favorites ?? 'Favorites', route: AppRouter.favorites),
      _NavItem(icon: Icons.search_rounded, label: AppStrings.of(context)?.search ?? 'Search', route: AppRouter.search),
      _NavItem(icon: Icons.settings_rounded, label: AppStrings.of(context)?.settings ?? 'Settings', route: AppRouter.settings),
    ];
  }

  void _onNavItemTap(int index, String? route) {
    if (index == widget.selectedIndex) return;
    
    if (index == 0) {
      // 返回首页：先 pop 到 splash，再 push 新的 home
      // 这样 home 会被销毁重建，焦点状态会被正确重置
      Navigator.of(context).popUntil((r) => r.settings.name == AppRouter.splash);
      Navigator.pushNamed(context, AppRouter.home);
    } else if (route != null) {
      if (widget.selectedIndex == 0) {
        // 从首页跳转
        Navigator.pushNamed(context, route);
      } else {
        // 从其他页面跳转，先返回首页再跳转
        Navigator.of(context).popUntil((r) => r.settings.name == AppRouter.splash);
        Navigator.pushNamed(context, AppRouter.home);
        Navigator.pushNamed(context, route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getNavItems(context);
    final width = _expanded ? 150.0 : 52.0;

    return Row(
      children: [
        // 侧边栏
        Focus(
          onFocusChange: (hasFocus) {
            setState(() => _expanded = hasFocus);
          },
          child: Container(
            width: width,
            color: AppTheme.surfaceColor,
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Logo
                _buildLogo(),
                const SizedBox(height: 16),
                // Nav Items
                Expanded(
                  child: TVFocusTraversalGroup(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: _expanded ? 6 : 4),
                      itemCount: navItems.length,
                      itemBuilder: (context, index) => _buildNavItem(index, navItems[index]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        // 主内容
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _expanded ? 10 : 8),
      child: _expanded
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/icons/app_icon.png', width: 24, height: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.lotusGradient.createShader(bounds),
                    child: const Text('Lotus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            )
          : Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/icons/app_icon.png', width: 24, height: 24),
              ),
            ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = widget.selectedIndex == index;
    final focusNode = index < _menuFocusNodes.length ? _menuFocusNodes[index] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Focus(
        focusNode: focusNode,
        autofocus: index == widget.selectedIndex,
        onFocusChange: (hasFocus) {
          // 强制刷新UI
          if (mounted) setState(() {});
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space) {
            _onNavItemTap(index, item.route);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
            widget.onRight!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => _onNavItemTap(index, item.route),
          child: Builder(
            builder: (context) {
              // 直接检查 FocusNode 的实际焦点状态
              final isFocused = focusNode?.hasFocus ?? false;
              // 只有当侧边栏展开时才显示焦点高亮
              final showHighlight = isFocused && _expanded;
              final showSelected = isSelected && !showHighlight;
              
              return Container(
                padding: EdgeInsets.symmetric(horizontal: _expanded ? 10 : 8, vertical: 10),
                decoration: BoxDecoration(
                  gradient: showHighlight ? AppTheme.lotusGradient : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _expanded
                    ? Row(
                        children: [
                          Icon(item.icon, color: showHighlight ? Colors.white : (showSelected ? AppTheme.primaryColor : AppTheme.textMuted), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.label, style: TextStyle(
                              color: showHighlight ? Colors.white : (showSelected ? AppTheme.primaryColor : AppTheme.textSecondary), 
                              fontSize: 12, 
                              fontWeight: (showHighlight || showSelected) ? FontWeight.w600 : FontWeight.normal,
                            )),
                          ),
                        ],
                      )
                    : Center(child: Icon(item.icon, color: showHighlight ? Colors.white : (showSelected ? AppTheme.primaryColor : AppTheme.textMuted), size: 18)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String? route;
  const _NavItem({required this.icon, required this.label, required this.route});
}
