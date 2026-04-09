import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LeftPanelTab { none, profile, home, upload, addNode, search, settings }

class LeftPanelTabNotifier extends Notifier<LeftPanelTab> {
  @override
  LeftPanelTab build() => LeftPanelTab.none;

  void setTab(LeftPanelTab tab) {
    state = tab;
  }
}

final leftPanelTabProvider = NotifierProvider<LeftPanelTabNotifier, LeftPanelTab>(() {
  return LeftPanelTabNotifier();
});

class LeftPanel extends ConsumerWidget {
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(leftPanelTabProvider);
    final isExpanded = activeTab != LeftPanelTab.none;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isExpanded ? 300.0 : 61.0,
      decoration: BoxDecoration(
        color: const Color(0xFF161618), // Dark charcoal
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: ClipRect(
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Tray
              SizedBox(
                width: 60,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _TrayIcon(
                      icon: Icons.person_outline,
                      tab: LeftPanelTab.profile,
                      activeTab: activeTab,
                    ),
                    const SizedBox(height: 16),
                    _TrayIcon(
                      icon: Icons.home_outlined,
                      tab: LeftPanelTab.home,
                      activeTab: activeTab,
                    ),
                    const SizedBox(height: 16),
                    _TrayIcon(
                      icon: Icons.file_upload_outlined,
                      tab: LeftPanelTab.upload,
                      activeTab: activeTab,
                    ),
                    const SizedBox(height: 16),
                    _TrayIcon(
                      icon: Icons.add_circle_outline,
                      tab: LeftPanelTab.addNode,
                      activeTab: activeTab,
                    ),
                    const SizedBox(height: 16),
                    _TrayIcon(
                      icon: Icons.search,
                      tab: LeftPanelTab.search,
                      activeTab: activeTab,
                    ),
                    const Spacer(),
                    _TrayIcon(
                      icon: Icons.settings_outlined,
                      tab: LeftPanelTab.settings,
                      activeTab: activeTab,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Expanded Content Area
              if (isExpanded)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: 239.0,
                        maxWidth: 239.0,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _buildExpandedContent(activeTab),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                                onPressed: () {
                                  ref.read(leftPanelTabProvider.notifier).setTab(LeftPanelTab.none);
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    );
  }

  Widget _buildExpandedContent(LeftPanelTab tab) {
    switch (tab) {
      case LeftPanelTab.profile:
        return const _PanelPlaceholder(title: 'User Profile');
      case LeftPanelTab.home:
        return const _PanelPlaceholder(title: 'Home');
      case LeftPanelTab.upload:
        return const _PanelPlaceholder(title: 'Upload/Share');
      case LeftPanelTab.addNode:
        return const _PanelPlaceholder(title: 'Add Node', subtitle: 'Discovery & Onboarding workflow');
      case LeftPanelTab.search:
        return const _PanelPlaceholder(title: 'Search');
      case LeftPanelTab.settings:
        return const _PanelPlaceholder(title: 'Settings');
      case LeftPanelTab.none:
        return const SizedBox.shrink();
    }
  }
}

class _TrayIcon extends ConsumerWidget {
  final IconData icon;
  final LeftPanelTab tab;
  final LeftPanelTab activeTab;

  const _TrayIcon({
    required this.icon,
    required this.tab,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = tab == activeTab;
    const neonGreen = Color(0xFF39FF14);

    return InkWell(
      onTap: () {
        final current = ref.read(leftPanelTabProvider);
        if (current == tab) {
          ref.read(leftPanelTabProvider.notifier).setTab(LeftPanelTab.none);
        } else {
          ref.read(leftPanelTabProvider.notifier).setTab(tab);
        }
      },
      child: Container(
        height: 50,
        width: 60,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: isActive ? neonGreen : Colors.white54,
          size: 26,
        ),
      ),
    );
  }
}

class _PanelPlaceholder extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _PanelPlaceholder({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48.0, left: 16.0, right: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle ?? 'Placeholder content for $title.',
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
