import 'package:flutter/material.dart';

import '../core/app_skeleton.dart';
import 'fleet_access_controller.dart';

/// Wraps the main app UI and only unlocks it for approved Fleet Managers.
class FleetAccessGate extends StatefulWidget {
  const FleetAccessGate({super.key, required this.child});

  final Widget child;

  @override
  State<FleetAccessGate> createState() => _FleetAccessGateState();
}

class _FleetAccessGateState extends State<FleetAccessGate>
    with WidgetsBindingObserver {
  final FleetAccessController _controller = FleetAccessController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_handleChange);
    _controller.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refresh();
    }
  }

  void _handleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.state == FleetAccessState.allowed) {
      return widget.child;
    }
    return FleetAccessScreen(controller: _controller);
  }
}

class FleetAccessScreen extends StatefulWidget {
  const FleetAccessScreen({super.key, required this.controller});

  final FleetAccessController controller;

  @override
  State<FleetAccessScreen> createState() => _FleetAccessScreenState();
}

class _FleetAccessScreenState extends State<FleetAccessScreen> {
  final TextEditingController _companyCodeController = TextEditingController();

  @override
  void dispose() {
    _companyCodeController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() => widget.controller.refresh();

  Future<void> _submit() async {
    final code = _companyCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your company code')),
      );
      return;
    }
    final ok = await widget.controller.submitRequest(code);
    if (ok && mounted) {
      _companyCodeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    Widget content;
    switch (controller.state) {
      case FleetAccessState.allowed:
        content = const SizedBox.shrink();
      case FleetAccessState.checking:
        // The access check runs silently after sign-in. Never surface a
        // role-checking step in the UI — show a neutral branded placeholder
        // until the gate knows which screen to present.
        content = const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined, size: 48),
            SizedBox(height: 18),
            AppSkeleton(width: 180, height: 14),
            SizedBox(height: 10),
            AppSkeleton(width: 120, height: 11),
            SizedBox(height: 18),
            SizedBox(width: 260, child: AppSkeletonCard(lines: 1)),
          ],
        );
      case FleetAccessState.needsRoleRequest:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.admin_panel_settings_outlined, size: 52, color: primary),
            const SizedBox(height: 16),
            Text(
              'Fleet Manager access required',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              controller.message.isEmpty
                  ? 'Request Fleet Manager access from your company.'
                  : controller.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _companyCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Company code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: controller.busy ? null : _submit,
                child: controller.busy
                    ? const AppSkeleton(
                        width: 20,
                        height: 12,
                        color: Colors.white,
                        opacity: 0.6,
                      )
                    : const Text('Request access'),
              ),
            ),
          ],
        );
      case FleetAccessState.roleRequired:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings_outlined, size: 52, color: primary),
            const SizedBox(height: 16),
            Text(
              'Fleet Manager role required',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              controller.message.isEmpty
                  ? 'Ask an administrator to grant you the Fleet Manager role.'
                  : controller.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Text(
              'Pull down to check again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case FleetAccessState.pendingApproval:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, size: 52, color: primary),
            const SizedBox(height: 16),
            Text(
              'Waiting for approval',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              controller.request?.companyName != null
                  ? 'Your Fleet Manager request for ${controller.request!.companyName} is pending. A fleet manager must approve it.'
                  : 'Your Fleet Manager access request is pending. A fleet manager must approve it.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Text(
              'Pull down to check again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case FleetAccessState.rejected:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 52, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Access not approved',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              controller.message.isEmpty
                  ? 'Your request was not approved.'
                  : controller.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: controller.showRequestForm,
              child: const Text('Request again'),
            ),
          ],
        );
      case FleetAccessState.error:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 52, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Unable to verify access',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              controller.message.isEmpty
                  ? 'Something went wrong. Please try again.'
                  : controller.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Text(
              'Pull down to try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF111A1D), Color(0xFF1A282C)]
                : const [Color(0xFFF2F8F7), Color(0xFFD9E8E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        content,
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: controller.signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
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
