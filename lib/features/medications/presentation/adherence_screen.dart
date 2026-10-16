import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../patients/application/patients_providers.dart';
import '../application/medications_providers.dart';
import '../domain/models.dart';

/// Pantalla de adherencia al tratamiento (ticket DAC05-15).
///
/// Muestra el porcentaje de cumplimiento calculado desde el servidor,
/// el desglose por medicamento y la gráfica de adherencia diaria de los
/// últimos 7 días.
class AdherenceScreen extends ConsumerWidget {
  const AdherenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(selectedPatientProvider);
    final adherence = ref.watch(adherenceProvider);

    if (patient == null) {
      return const Scaffold(
        body: EmptyView(
            icon: Icons.person_search_rounded,
            title: 'Selecciona un paciente',
            subtitle: 'Elige a quién quieres ver la adherencia.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adherencia al tratamiento'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adherenceProvider);
          ref.invalidate(todayDosesProvider);
        },
        child: adherence.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(adherenceProvider)),
          data: (data) {
            if (data == null) {
              return const EmptyView(
                  icon: Icons.insights_rounded,
                  title: 'Sin datos de adherencia',
                  subtitle: 'No se pudo calcular la adherencia del servidor.');
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Tarjeta principal de adherencia general.
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Adherencia general (7 días)',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700)),
                            ),
                            Text('${data.pct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: _pctColor(data.pct))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: _AdherenceBarChart(points: data.byDay),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Desglose por medicamento.
                if (data.byMedication.isNotEmpty) ...[
                  const Text('Por medicamento',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...data.byMedication.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.medication_rounded,
                                color: AppColors.primary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.medicationName,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('Adherencia individual',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Text('${m.pct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: _pctColor(m.pct))),
                          ],
                        ),
                      ),
                    ),
                  )),
                ] else
                  const EmptyView(
                      icon: Icons.medication_rounded,
                      title: 'Sin medicamentos registrados',
                      subtitle:
                          'Agrega medicamentos para ver su adherencia individual.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

Color _pctColor(double pct) {
  if (pct >= 80) return AppColors.statusOk;
  if (pct >= 50) return AppColors.statusWarning;
  return AppColors.statusAttention;
}

class _AdherenceBarChart extends StatelessWidget {
  const _AdherenceBarChart({required this.points});

  final List<AdherencePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxPct = points.map((p) => p.pct).reduce((a, b) => a > b ? a : b);
    final maxY = (maxPct / 25).ceil() * 25 + 25;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY.toDouble(),
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true, reservedSize: 32, interval: 25),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(DateFormat('E', 'es').format(points[i].date),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: points[i].pct,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                color: _pctColor(points[i].pct),
              ),
            ]),
        ],
      ),
    );
  }
}
