import 'package:flutter/material.dart';

import '../auth/credentials_manager.dart';
import 'vehicle_registration_controller.dart';
import 'vehicle_registration_models.dart';

/// Native vehicle registration screen for the signed-in Fleet Manager.
///
/// There is no company picker: the vehicle is always registered for the
/// manager's approved company through the backend's authenticated-user
/// resolution. The created device password is shown once on this screen.
class VehicleRegistrationPage extends StatefulWidget {
  const VehicleRegistrationPage({super.key, this.controller});

  /// Optional controller seam for widget tests. Production uses a session
  /// scoped controller owned by this page.
  final VehicleRegistrationController? controller;

  @override
  State<VehicleRegistrationPage> createState() =>
      _VehicleRegistrationPageState();
}

class _VehicleRegistrationPageState extends State<VehicleRegistrationPage> {
  late final VehicleRegistrationController _controller;
  late final bool _ownsController;

  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _pubKeyController = TextEditingController();

  VehicleRegistrationType? _vehicleType;
  VehicleRegistrationStatus _status = VehicleRegistrationStatus.available;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? VehicleRegistrationController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _capacityController.dispose();
    _pubKeyController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final draft = VehicleRegistrationDraft(
      make: _makeController.text,
      model: _modelController.text,
      licensePlate: _plateController.text,
      capacity: int.tryParse(_capacityController.text.trim()) ?? 0,
      vehicleType: _vehicleType ?? VehicleRegistrationType.sedan,
      pubKey: _pubKeyController.text,
      status: _status,
    );
    final validationError = draft.validate();
    final typeError = _vehicleType == null ? 'Select a vehicle type.' : null;
    final error = validationError ?? typeError;
    if (error != null) {
      setState(() => _formError = error);
      return;
    }

    setState(() {
      _formError = null;
    });
    await _controller.register(draft);
    if (!mounted || _controller.created != null) return;
    setState(() {
      _formError =
          _controller.error ??
          'Could not register the vehicle. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final created = _controller.created;
    if (created != null) {
      return _SuccessView(
        vehicle: created,
        onDone: () => Navigator.of(context).pop(),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final busy = _controller.isCreating;
    final error = _formError ?? _controller.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Register Vehicle')),
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
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_rounded,
                          color: isDark
                              ? const Color(0xFF8ED0C6)
                              : scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ValueListenableBuilder<String>(
                            valueListenable:
                                CredentialsManager.instance.currentCompanyName,
                            builder: (context, companyName, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vehicle registration',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    companyName.isEmpty
                                        ? 'Registered under your company'
                                        : 'Registered under $companyName',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              );
                            },
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
                          'Vehicle details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('vehicle-make-field'),
                          controller: _makeController,
                          enabled: !busy,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Make *',
                            hintText: 'e.g. Toyota',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('vehicle-model-field'),
                          controller: _modelController,
                          enabled: !busy,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Model *',
                            hintText: 'e.g. Hiace',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('vehicle-plate-field'),
                          controller: _plateController,
                          enabled: !busy,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'License plate *',
                            hintText: 'e.g. RAB123X',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('vehicle-capacity-field'),
                          controller: _capacityController,
                          enabled: !busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Capacity (seats) *',
                            hintText: 'At least 1',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<VehicleRegistrationType>(
                          key: const Key('vehicle-type-dropdown'),
                          initialValue: _vehicleType,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle type *',
                            border: OutlineInputBorder(),
                          ),
                          items: VehicleRegistrationType.values
                              .map(
                                (type) =>
                                    DropdownMenuItem<VehicleRegistrationType>(
                                      value: type,
                                      child: Text(type.label),
                                    ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) => setState(() => _vehicleType = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<VehicleRegistrationStatus>(
                          key: const Key('vehicle-status-dropdown'),
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Initial status',
                            border: OutlineInputBorder(),
                          ),
                          items: VehicleRegistrationStatus.values
                              .map(
                                (status) =>
                                    DropdownMenuItem<VehicleRegistrationStatus>(
                                      value: status,
                                      child: Text(status.label),
                                    ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) => setState(
                                  () => _status =
                                      value ??
                                      VehicleRegistrationStatus.available,
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('vehicle-pubkey-field'),
                          controller: _pubKeyController,
                          enabled: !busy,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Device public key *',
                            hintText: 'Base64 public key',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (error != null && error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(
                    message: error,
                    onDismiss: () {
                      setState(() => _formError = null);
                      _controller.dismissError();
                    },
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('register-vehicle-button'),
                  onPressed: busy ? null : _submit,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(
                    busy ? 'Registering vehicle…' : 'Register Vehicle',
                  ),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.error,
              ),
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.vehicle, required this.onDone});

  final RegisteredVehicle vehicle;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Registered')),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 56,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Vehicle registered',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${vehicle.licensePlate} · ${vehicle.displayName}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Device password',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Shown only once. Copy it before closing this screen.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E9F8D,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            key: const Key('initial-password-text'),
                            vehicle.initialPassword ??
                                'Not returned by the backend',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: isDark
                                  ? const Color(0xFF8ED0C6)
                                  : const Color(0xFF0E5A57),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('registration-done-button'),
                  onPressed: onDone,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Done'),
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
