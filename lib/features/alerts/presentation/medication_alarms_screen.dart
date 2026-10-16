import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/network/api_client.dart';
import '../application/alerts_providers.dart';
import '../data/alerts_repository.dart';
import '../domain/models.dart';

/// Pantalla de alarmas de medicación (ticket DAC05-16).
///
/// Filtra las alertas de tipo `medicationMissed` y permite a la cuidadora
/// reconocer cada alarma, resolverla o confirmar la toma del medicamento.
/// Está protegida para roles cuidadora/familiar/médico.
class MedicationAlarmsScreen extends ConsumerWidget {
  const MedicationAlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(activeAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarmas de medicación'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(activeAlertsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(activeAlertsProvider),
        child: alertsAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: e is ApiException ? e.message : 'No pudimos cargar las alarmas.',
            onRetry: () => ref.invalidate(activeAlertsProvider),
          ),
          data: (alerts) {
            final medicationAlarms =
                alerts.where((a) => a.type == AlertType.medicationMissed).toList();

            if (medicationAlarms.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyView(
                    icon: Icons.medication_rounded,
                    title: 'Sin alarmas de medicación',
                    subtitle:
                        'No hay dosis pendientes u omitidas. Te avisamos si se vence una toma.',
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final a in medicationAlarms)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MedicationAlarmCard(alert: a),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MedicationAlarmCard extends ConsumerStatefulWidget {
  const _MedicationAlarmCard({required this.alert});

  final Alert alert;

  @override
  ConsumerState<_MedicationAlarmCard> createState() => _MedicationAlarmCardState();
}

class _MedicationAlarmCardState extends ConsumerState<_MedicationAlarmCard> {
  /// Extrae el ID de la dosis desde el meta de la alerta, si existe.
  String? _doseId() {
    final meta = widget.alert.meta;
    if (meta == null) return null;
    return meta['dose_id'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final color = a.severity.color;
    final isAcknowledged = a.status == AlertStatus.acknowledged;
    final doseId = _doseId();

    return AppCard(
      onTap: () => context.push('/alerts/${a.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_rounded,
                    color: AppColors.statusAttention, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    if (a.patientName.isNotEmpty)
                      Text(a.patientName,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Text(alertTimeAgo(a.createdAt),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(a.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (isAcknowledged) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_rounded,
                    size: 16, color: AppColors.statusOk),
                const SizedBox(width: 4),
                Text('Reconocida${a.acknowledgedBy != null ? ' por ${a.acknowledgedBy}' : ''}',
                    style: const TextStyle(
                        color: AppColors.statusOk, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (!isAcknowledged) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final repo = ref.read(alertsRepositoryProvider);
                      try {
                        await repo.acknowledge(a.id);
                        ref.invalidate(activeAlertsProvider);
                        if (mounted)
                          showAppSnackBar(context, 'Alarma reconocida');
                      } on ApiException catch (e) {
                        if (mounted)
                          showAppSnackBar(context, e.message, error: true);
                      } catch (_) {
                        if (mounted)
                          showAppSnackBar(
                              context, 'No se pudo reconocer la alarma.',
                              error: true);
                      }
                    },
                    icon: const Icon(Icons.done_rounded, size: 18),
                    label: const Text('Reconocer'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () async {
                      final repo = ref.read(alertsRepositoryProvider);
                      try {
                        await repo.resolve(a.id);
                        ref.invalidate(activeAlertsProvider);
                        if (mounted)
                          showAppSnackBar(context, 'Alarma resuelta');
                      } on ApiException catch (e) {
                        if (mounted)
                          showAppSnackBar(context, e.message, error: true);
                      } catch (_) {
                        if (mounted)
                          showAppSnackBar(
                              context, 'No se pudo resolver la alarma.',
                              error: true);
                      }
                    },
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Resolver'),
                  ),
                ),
              ],
            ),
            if (doseId != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/dose/$doseId'),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Confirmar toma'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusOk,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
