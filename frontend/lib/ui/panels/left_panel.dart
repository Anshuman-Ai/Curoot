import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../canvas/add_node_panel.dart';
import '../settings/settings_page.dart';
import 'omni_ingestion_panel.dart';

enum LeftPanelTab { none, profile, home, upload, addNode, search, settings }

class LeftPanelTabNotifier extends Notifier<LeftPanelTab> {
  @override
  LeftPanelTab build() => LeftPanelTab.none;

  void setTab(LeftPanelTab tab) {
    state = tab;
  }
}

final leftPanelTabProvider =
    NotifierProvider<LeftPanelTabNotifier, LeftPanelTab>(() {
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
      width: isExpanded ? 320.0 : 60.0,
      decoration: const BoxDecoration(
        color: Color(0xFF121212), // Sleeker very dark grey
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF121212), // Unify with right panel
                    border: Border(left: BorderSide(color: Colors.white12, width: 1)),
                  ),
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: 260.0,
                      maxWidth: 260.0,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _buildExpandedContent(activeTab),
                          ),
                          Positioned(
                            top: 20,
                            right: 20,
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  size: 20, color: Colors.white54), // sleek close icon
                              onPressed: () {
                                ref
                                    .read(leftPanelTabProvider.notifier)
                                    .setTab(LeftPanelTab.none);
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
        return const OmniIngestionPanel();
      case LeftPanelTab.addNode:
        return const AddNodePanel();
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
    const elegantGreen = Color(0xFF2DD4BF); // Softer teal/mint green glow

    return InkWell(
      onTap: () {
        if (tab == LeftPanelTab.settings) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
          return;
        }

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
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          border: isActive ? const Border(left: BorderSide(color: elegantGreen, width: 3)) : null,
        ),
        child: Icon(
          icon,
          color: isActive ? elegantGreen : Colors.white.withValues(alpha: 0.5),
          size: 24,
        ),
      ),
    );
  }
}

class _PanelPlaceholder extends StatelessWidget {
  final String title;
  const _PanelPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 16),
              Text(
                'Placeholder content for $title.',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
