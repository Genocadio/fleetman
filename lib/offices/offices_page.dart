import 'package:flutter/material.dart';

import '../auth/credentials_manager.dart';
import '../core/app_skeleton.dart';
import '../core/app_toast.dart';
import '../sync/sync_models.dart';
import 'office_models.dart';
import 'offices_controller.dart';

/// Native office screen for the signed-in Fleet Manager.
///
/// Lists the company's offices and lets the manager create new ones. All
/// mutations go through [OfficesController], which injects the company from
/// the session; there is deliberately no company picker here.
class OfficesPage extends StatefulWidget {
  const OfficesPage({super.key, this.controller});

  /// Optional controller seam for widget tests. Production uses the real
  /// session-scoped controller created by the page.
  final OfficesController? controller;

  @override
  State<OfficesPage> createState() => _OfficesPageState();
}

class _OfficesPageState extends State<OfficesPage> {
  late final OfficesController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? OfficesController();
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
    // A 401 signs the user out; the root listener then swaps in the login
    // screen. No local navigation is needed here.
    if (mounted) setState(() {});
  }

  Future<void> _onRefresh() => _controller.load();

  Future<void> _openNewOffice() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OfficeFormPage(controller: _controller),
      ),
    );
    if (!mounted || created != true) return;
    await _controller.load();
    if (!mounted) return;
    showTopToast(context, message: 'Office created successfully.');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Offices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewOffice,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('New Office'),
      ),
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
                      onRetry: _controller.load,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              Icons.business_outlined,
              color: isDark ? const Color(0xFF8ED0C6) : scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: CredentialsManager.instance.currentCompanyName,
                builder: (context, companyName, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company offices',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        companyName.isEmpty
                            ? 'Offices for your company'
                            : 'Offices for $companyName',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF2E9F8D).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_controller.items.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFF8ED0C6)
                      : const Color(0xFF0E5A57),
                ),
              ),
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
            Icons.add_business_outlined,
            size: 56,
            color: isDark ? const Color(0xFF6F9C9B) : const Color(0xFF9AB5B5),
          ),
          const SizedBox(height: 14),
          Text(
            'No offices yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Use New Office to add an office for your company.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _controller.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _OfficeCard(office: _controller.items[index]),
    );
  }
}

/// Full-screen create form. Offices always belong to the signed-in manager's
/// company, so only office details and a cavgotrips location are collected.
class OfficeFormPage extends StatefulWidget {
  const OfficeFormPage({super.key, required this.controller});

  final OfficesController controller;

  @override
  State<OfficeFormPage> createState() => _OfficeFormPageState();
}

class _OfficeFormPageState extends State<OfficeFormPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _contactEmailsController = TextEditingController();
  final TextEditingController _contactPhonesController = TextEditingController();

  LocationEntity? _location;
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _contactEmailsController.dispose();
    _contactPhonesController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await showDialog<LocationEntity>(
      context: context,
      builder: (_) => _LocationPickerDialog(search: widget.controller.searchLocations),
    );
    if (picked != null && mounted) {
      setState(() => _location = picked);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Enter an office name.');
      return;
    }
    final location = _location;
    if (location == null) {
      setState(
        () => _formError = 'Select a location from the synced trips locations.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    final created = await widget.controller.create(
      OfficeDraft(
        name: name,
        location: location,
        email: _emailController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        city: _cityController.text,
        contactEmails: _splitContacts(_contactEmailsController.text),
        contactPhones: _splitContacts(_contactPhonesController.text),
      ),
    );

    if (created && mounted) {
      Navigator.of(context).pop<bool>(true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _formError = widget.controller.error ??
          'Could not create the office. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy = _submitting || widget.controller.isCreating;

    return Scaffold(
      appBar: AppBar(title: const Text('New Office')),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Office details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          enabled: !busy,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Office name *',
                            hintText: 'e.g. Kigali Main Office',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _pickLocation,
                          icon: const Icon(Icons.place_outlined),
                          label: Text(
                            _location?.displayName ?? 'Select location *',
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          enabled: !busy,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Address (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _cityController,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'City (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Office contacts (optional)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactEmailsController,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Contact emails',
                            hintText: 'ops@example.com, hr@example.com',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contactPhonesController,
                          enabled: !busy,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Contact phones',
                            hintText: '+250700000000, +250700000001',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(
                            alpha: 0.10,
                          ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error.withValues(
                              alpha: 0.35,
                            ),
                      ),
                    ),
                    child: Text(
                      _formError!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('create-office-button'),
                  onPressed: busy ? null : _submit,
                  icon: busy
                      ? const AppSkeleton(
                          width: 18,
                          height: 12,
                          color: Colors.white,
                          opacity: 0.6,
                        )
                      : const Icon(Icons.add_business_rounded),
                  label: Text(busy ? 'Creating office…' : 'Create Office'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _splitContacts(String raw) {
  return raw
      .split(RegExp(r'[,;\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({required this.search});

  final Future<List<LocationEntity>> Function(String query) search;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  final TextEditingController _queryController = TextEditingController();
  List<LocationEntity> _results = const <LocationEntity>[];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.search(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select location'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _queryController,
              onChanged: _runSearch,
              decoration: const InputDecoration(
                labelText: 'Search synced locations',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const AppSkeletonList(items: 3)
                  : _results.isEmpty
                      ? const Center(
                          child: Text('No locations found. Sync trips data first.'),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final location = _results[index];
                            return ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(location.displayName),
                              subtitle: Text('Location #${location.id}'),
                              onTap: () =>
                                  Navigator.of(context).pop<LocationEntity>(location),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.office});

  final OfficeItem office;

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
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark
                      ? const Color(0xFF24484A)
                      : const Color(0xFFDCEDEB),
                  child: Icon(
                    Icons.business_outlined,
                    size: 18,
                    color: isDark
                        ? const Color(0xFFBFE4DE)
                        : const Color(0xFF0E5A57),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        office.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (office.contactLabel.isNotEmpty)
                        Text(
                          office.contactLabel,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _InfoPill(
                  icon: Icons.place_outlined,
                  label: office.locationLabel,
                  color: scheme.primary,
                  isDark: isDark,
                ),
                if (office.companyCode != null && office.companyCode!.isNotEmpty)
                  _InfoPill(
                    icon: Icons.qr_code_2_outlined,
                    label: office.companyCode!,
                    color: const Color(0xFF5A7C9C),
                    isDark: isDark,
                  ),
              ],
            ),
          ],
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
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFB00020).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB00020).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFF8B1E3F),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B1E3F),
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
