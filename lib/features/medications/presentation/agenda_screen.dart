import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../patients/application/patients_providers.dart';
import '../application/medications_providers.dart';
import '../data/medications_repository.dart';
import '../domain/models.dart';

/// Pantalla dedicada a la agenda de tomas del día (ticket DAC05-14).
///
/// Muestra cada dosis programada con cuenta regresiva y permite marcar
/// Tomada / Omitida. Bloquea "Omitir" si han pasado más de 4h desde la hora
/// programada (regla de negocio: no se puede posponer más de 4h).
///
/// Cada ítem de la lista lleva [ValueKey] para reconciliación correcta
/// en Flutter Web (regla de Layout Safety).
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Si han pasado más de 4h desde scheduledAt, no se permite omitir.
  bool _puedeOmitir(Dose d) {
    final ahora = DateTime.now();
    return ahora.difference(d.scheduledAt).inHours <= 4;
  }

  Future<void> _log(DoseStatus status, Dose dose) async {
    if (status == DoseStatus.skipped && !_puedeOmitir(dose)) {
      if (mounted) {
        showAppSnackBar(
            context,
            'No se puede omitir: han pasado más de 4h desde la hora programada.',
            error: true);
      }
      return;
    }
    try {
      await ref
          .read(medicationsRepositoryProvider)
          .logDose(dose.id, status);
      ref.invalidate(todayDosesProvider);
      ref.invalidate(adherenceProvider);
      if (mounted) {
        showAppSnackBar(context,
            status == DoseStatus.taken ? 'Toma registrada' : 'Dosis omitida');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), error: true);
    }
  }

  String _tiempoRestante(Dose d) {
    final ahora = DateTime.now();
    final diff = d.scheduledAt.difference(ahora);
    if (diff.isNegative) return 'Vencida';
    final min = diff.inMinutes;
    final seg = diff.inSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${seg.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(selectedPatientProvider);
    final doses = ref.watch(todayDosesProvider);

    if (patient == null) {
      return const Scaffold(
        body: EmptyView(
            icon: Icons.person_search_rounded,
            title: 'Selecciona un paciente',
            subtitle: 'Elige a quién quieres ver la agenda de tomas.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de tomas'),
        actions: [
          IconButton(
            tooltip: 'Agregar medicamento',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(
                '/meds/plan?patient=${patient.patientId}'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayDosesProvider);
          ref.invalidate(adherenceProvider);
        },
        child: doses.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(todayDosesProvider)),
          data: (list) => list.isEmpty
              ? const EmptyView(
                  icon: Icons.event_available_rounded,
                  title: 'Sin dosis programadas hoy',
                  subtitle:
                      'Agrega medicamentos para que aparezcan aquí sus tomas del día.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final d = list[index];
                    return _DoseAgendaTile(
                      key: ValueKey('dose-${d.id}'),
                      dose: d,
                      onLog: (status) => _log(status, d),
                      tiempoRestante: _tiempoRestante(d),
                      puedeOmitir: _puedeOmitir(d),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _DoseAgendaTile extends ConsumerStatefulWidget {
  const _DoseAgendaTile({
    super.key,
    required this.dose,
    required this.onLog,
    required this.tiempoRestante,
    required this.puedeOmitir,
  });

  final Dose dose;
  final void Function(DoseStatus) onLog;
  final String tiempoRestante;
  final bool puedeOmitir;

  @override
  ConsumerState<_DoseAgendaTile> createState() => _DoseAgendaTileState();
}

class _DoseAgendaTileState extends ConsumerState<_DoseAgendaTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.dose;
    final done = d.status != DoseStatus.pending;
    final color = _statusColor(d.status);

    return AppCard(
      key: widget.key,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_statusIcon(d.status), color: color, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.medicationName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                          '${d.timeLabel}${d.dose != null ? ' · ${d.dose} ${d.unit ?? ''}'.trimRight() : ''}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(d.status.label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!done) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Próxima toma en ${widget.tiempoRestante}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => widget.onLog(DoseStatus.taken),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Tomada'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _busy || !widget.puedeOmitir ? null : () => widget.onLog(DoseStatus.skipped),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Omitir'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.divider, width: 1.5)),
                    ),
                  ),
                ],
              ),
              if (!widget.puedeOmitir)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No se puede omitir: han pasado más de 4h desde la hora programada.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.statusAttention,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return AppColors.statusOk;
      case DoseStatus.skipped:
        return AppColors.statusWarning;
      case DoseStatus.missed:
        return AppColors.statusAttention;
      case DoseStatus.pending:
        return AppColors.primary;
    }
  }

  IconData _statusIcon(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return Icons.check_circle_rounded;
      case DoseStatus.skipped:
        return Icons.cancel_rounded;
      case DoseStatus.missed:
        return Icons.error_rounded;
      case DoseStatus.pending:
        return Icons.schedule_rounded;
    }
  }
}
