import 'package:flutter/material.dart';

import '../auth/credentials_manager.dart';
import '../core/app_skeleton.dart';
import '../core/app_toast.dart';
import 'company_requests_controller.dart';
import 'request_models.dart';

/// Fleet Manager inbox for their own company.
///
/// Lists both role-access and driver requests and lets the manager approve or
/// reject them. All data and actions go through [CompanyRequestsController], so
/// this widget only renders state and collects confirmations.
class CompanyRequestsPage extends StatefulWidget {
  const CompanyRequestsPage({super.key, this.controller});

  /// Optional controller seam for widget tests. Production always uses the
  /// real company-scoped controller created by the page itself.
  final CompanyRequestsController? controller;

  @override
  State<CompanyRequestsPage> createState() => _CompanyRequestsPageState();
}

class _CompanyRequestsPageState extends State<CompanyRequestsPage> {
  late final CompanyRequestsController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? CompanyRequestsController();
    _controller.addListener(_onControllerChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // A 401 makes the controller sign out; the root listener then swaps in the
    // login screen. No local navigation is needed here.
    if (mounted) setState(() {});
  }

  Future<void> _onRefresh() async {
    await _controller.load();
  }

  Future<void> _confirmApprove(CompanyRequestItem item) async {
    final company = CredentialsManager.instance.currentCompanyName.value;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve request?'),
        content: Text(
          'Grant ${item.fullName} access to '
          '${company.isEmpty ? 'your company' : company} as '
          '${_roleLabel(item.role)}?\n\n'
          'They will be able to use the fleet immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    final ok = await _controller.approve(item);
    if (!mounted) return;
    if (ok) {
      showTopToast(
        context,
        message: 'Request approved. ${item.fullName} can now access the fleet.',
      );
    }
  }

  Future<void> _confirmReject(CompanyRequestItem item) async {
    // null = cancelled; a String (possibly empty) = confirm with that reason.
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => _RejectDialog(name: item.fullName),
    );
    if (reason == null || !mounted) return;

    final ok = await _controller.reject(
      item,
      reason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    if (ok) {
      showTopToast(context, message: 'Request from ${item.fullName} rejected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isDark, scheme),
                const SizedBox(height: 10),
                if (_controller.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ErrorBanner(
                      message: _controller.error!,
                      isDark: isDark,
                      onDismiss: _controller.dismissError,
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: _buildBody(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, ColorScheme scheme) {
    final pending = _controller.pendingCount;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: isDark ? const Color(0xFF8ED0C6) : scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable:
                        CredentialsManager.instance.currentCompanyName,
                    builder: (context, companyName, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Company requests',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            companyName.isEmpty
                                ? 'Review requests for your company'
                                : 'Review requests for $companyName',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Pending'),
                        icon: Icon(Icons.hourglass_top_rounded, size: 16),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('All'),
                        icon: Icon(Icons.list_rounded, size: 16),
                      ),
                    ],
                    selected: {_controller.pendingOnly},
                    onSelectionChanged: _controller.isLoading
                        ? null
                        : (selection) {
                            _controller.setPendingOnly(selection.first);
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3A13B).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pending pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFF0C987)
                          : const Color(0xFF8A5B15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const AppSkeletonList();
    }

    if (_controller.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(
            _controller.pendingOnly
                ? Icons.check_circle_outline_rounded
                : Icons.inbox_outlined,
            size: 56,
            color: isDark ? const Color(0xFF6F9C9B) : const Color(0xFF9AB5B5),
          ),
          const SizedBox(height: 14),
          Text(
            _controller.pendingOnly ? 'No pending requests' : 'No requests yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _controller.pendingOnly
                ? 'New access and driver requests will appear here.'
                : 'Requests from your company will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _controller.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _controller.items[index];
        final acting =
            _controller.isActing && _controller.actingRequestId == item.id;
        return _RequestCard(
          item: item,
          isActing: acting,
          isBusy: _controller.isActing,
          actingAction: acting ? _controller.actingAction : null,
          errorMessage: _controller.errorRequestId == item.id
              ? _controller.error
              : null,
          onApprove: () => _confirmApprove(item),
          onReject: () => _confirmReject(item),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.isActing,
    required this.isBusy,
    this.actingAction,
    this.errorMessage,
    required this.onApprove,
    required this.onReject,
  });

  final CompanyRequestItem item;
  final bool isActing;
  final bool isBusy;
  final RequestAction? actingAction;
  final String? errorMessage;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark
                      ? const Color(0xFF24484A)
                      : const Color(0xFFDCEDEB),
                  child: Text(
                    item.fullName.isEmpty
                        ? '?'
                        : item.fullName[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFBFE4DE)
                          : const Color(0xFF0E5A57),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.contact,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: item.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _InfoPill(
                  icon: item.kind == CompanyRequestKind.driver
                      ? Icons.directions_car_outlined
                      : Icons.badge_outlined,
                  label: item.kind.label,
                  color: scheme.primary,
                  isDark: isDark,
                ),
                _InfoPill(
                  icon: Icons.work_outline_rounded,
                  label: _roleLabel(item.role),
                  color: const Color(0xFF2E9F8D),
                  isDark: isDark,
                ),
                if (item.companyName != null && item.companyName!.isNotEmpty)
                  _InfoPill(
                    icon: Icons.business_outlined,
                    label: item.companyName!,
                    color: const Color(0xFF5A7C9C),
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Requested ${_formatDate(item.createdAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
            if (item.isRejected &&
                item.rejectionReason != null &&
                item.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB00020).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Rejection reason: ${item.rejectionReason}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFF3B9B9)
                        : const Color(0xFF8B1E3F),
                  ),
                ),
              ),
            ],
            if (errorMessage != null && errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB00020).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFF3B9B9)
                        : const Color(0xFF8B1E3F),
                  ),
                ),
              ),
            ],
            if (item.isPending) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (isActing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppSkeleton(width: 18, height: 12),
                        const SizedBox(width: 10),
                        Text(
                          '${actingAction?.label ?? 'Updating'} request…',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isBusy ? null : onReject,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: scheme.error,
                      ),
                      label: Text(
                        'Reject',
                        style: TextStyle(color: scheme.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: scheme.error),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: isBusy ? null : onApprove,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = CompanyRequestItem(
      id: 0,
      kind: CompanyRequestKind.companyAccess,
      status: status,
    );
    final color = item.isApproved
        ? const Color(0xFF2E9F8D)
        : item.isRejected
            ? const Color(0xFFB00020)
            : const Color(0xFFE3A13B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        item.statusLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDark ? color.withValues(alpha: 0.95) : color,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.isDark,
    required this.onDismiss,
  });

  final String message;
  final bool isDark;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFB00020).withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB00020).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: isDark ? const Color(0xFFF3B9B9) : const Color(0xFF8B1E3F),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFF3B9B9)
                    : const Color(0xFF8B1E3F),
              ),
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.name});

  final String name;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject request?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reject the request from ${widget.name}. '
            'They can request access again later.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            maxLength: 240,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g. Unknown employee',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<String?>(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () =>
              Navigator.pop<String?>(context, _reasonController.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

String _roleLabel(String? role) {
  if (role == null || role.isEmpty) return 'Company member';
  return role
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

String _formatDate(String? raw) {
  if (raw == null || raw.isEmpty) return 'recently';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '${local.day} ${months[local.month - 1]} ${local.year}, $time';
}
