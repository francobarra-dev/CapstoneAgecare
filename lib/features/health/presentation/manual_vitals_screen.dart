import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../patients/application/patients_providers.dart';
import '../data/vitals_repository.dart';
import '../domain/models.dart';

/// Pantalla de ingreso manual de signos vitales (ticket DAC05-12).
///
/// Permite a la cuidadora registrar FC, SpO2 y temperatura manualmente
/// cuando no hay conexión con el wearable. Los datos se envían al backend
/// mediante POST /patients/{id}/vitals/batch.
class ManualVitalsScreen extends ConsumerStatefulWidget {
  const ManualVitalsScreen({super.key});

  @override
  ConsumerState<ManualVitalsScreen> createState() =>
      _ManualVitalsScreenState();
}

class _ManualVitalsScreenState extends ConsumerState<ManualVitalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hrController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _tempController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _hrController.dispose();
    _spo2Controller.dispose();
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final patient = ref.read(selectedPatientProvider);
    if (patient == null) {
      showAppSnackBar(context, 'Selecciona un paciente primero.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final readings = <VitalReading>[];

      final hr = _hrController.text.trim();
      if (hr.isNotEmpty) {
        readings.add(VitalReading(
          type: VitalType.heartRate,
          value: double.parse(hr),
          measuredAt: now,
          meta: const {'source': 'manual'},
        ));
      }

      final spo2 = _spo2Controller.text.trim();
      if (spo2.isNotEmpty) {
        readings.add(VitalReading(
          type: VitalType.spo2,
          value: double.parse(spo2),
          measuredAt: now,
          meta: const {'source': 'manual'},
        ));
      }

      final temp = _tempController.text.trim();
      if (temp.isNotEmpty) {
        readings.add(VitalReading(
          type: VitalType.temperature,
          value: double.parse(temp),
          measuredAt: now,
          meta: const {'source': 'manual'},
        ));
      }

      if (readings.isEmpty) {
        showAppSnackBar(context, 'Ingresa al menos un signo vital.',
            error: true);
        return;
      }

      final accepted = await ref
          .read(vitalsRepositoryProvider)
          .uploadBatch(patient.patientId, readings);

      if (mounted) {
        showAppSnackBar(context,
            '$accepted lectura(s) registrada(s) correctamente.');
        ref.invalidate(selectedPatientDetailProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(selectedPatientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresar signos vitales'),
      ),
      body: patient == null
          ? const EmptyView(
              icon: Icons.person_search_rounded,
              title: 'Selecciona un paciente',
              subtitle: 'Elige a quién quieres registrar los vitales.')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Paciente: ${patient.fullName}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  const Text('Ritmo cardíaco (FC)',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _hrController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'ppm',
                      hintText: 'Ej. 72',
                      suffixText: 'bpm',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 1.6)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final val = double.tryParse(v.trim());
                      if (val == null || val < 30 || val > 220) {
                        return 'Valor fuera de rango (30-220 bpm)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Oxígeno en sangre (SpO2)',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _spo2Controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '%',
                      hintText: 'Ej. 97',
                      suffixText: '%',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 1.6)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final val = double.tryParse(v.trim());
                      if (val == null || val < 70 || val > 100) {
                        return 'Valor fuera de rango (70-100 %)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Temperatura',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tempController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '°C',
                      hintText: 'Ej. 36.6',
                      suffixText: '°C',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 1.6)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final val = double.tryParse(v.trim());
                      if (val == null || val < 30 || val > 45) {
                        return 'Valor fuera de rango (30-45 °C)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Registrar vitales'),
                  ),
                ],
              ),
            ),
    );
  }
}
