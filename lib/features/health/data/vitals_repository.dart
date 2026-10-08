import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/models.dart';

abstract class VitalsRepository {
  /// Sube un lote de lecturas (endpoint 5.1). Devuelve las aceptadas.
  Future<int> uploadBatch(String patientId, List<VitalReading> readings);

  /// Serie de un vital con agregación (endpoint 5.3).
  Future<VitalSeries> getSeries(
    String patientId,
    VitalType type, {
    required DateTime from,
    required DateTime to,
    String granularity = 'day',
  });

  /// Últimos valores por vital (endpoint 5.4).
  Future<List<LatestVital>> getLatest(String patientId);

  Future<List<Threshold>> getThresholds(String patientId);
}

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------
class VitalsRepositoryHttp implements VitalsRepository {
  VitalsRepositoryHttp(this._api);
  final ApiClient _api;

  @override
  Future<int> uploadBatch(String patientId, List<VitalReading> readings) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/patients/$patientId/vitals/batch',
      data: {'readings': readings.map((r) => r.toJson()).toList()},
    );
    return (res['accepted'] ?? 0) as int;
  }

  @override
  Future<VitalSeries> getSeries(
    String patientId,
    VitalType type, {
    required DateTime from,
    required DateTime to,
    String granularity = 'day',
  }) async {
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final res = await _api.get<Map<String, dynamic>>(
      '/patients/$patientId/vitals',
      query: {
        'type': type.apiValue,
        'date_from': d(from),
        'date_to': d(to),
        'granularity': granularity,
      },
    );
    return VitalSeries(
      type: type,
      points: ((res['points'] ?? []) as List)
          .map((p) => VitalPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      threshold: res['threshold'] != null
          ? Threshold.fromJson(res['threshold'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Future<List<LatestVital>> getLatest(String patientId) async {
    final res =
        await _api.get<Map<String, dynamic>>('/patients/$patientId/vitals/latest');
    return ((res['items'] ?? []) as List)
        .map((e) => LatestVital.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Threshold>> getThresholds(String patientId) async {
    final res = await _api
        .get<Map<String, dynamic>>('/patients/$patientId/vitals/thresholds');
    return ((res['items'] ?? []) as List)
        .map((e) => Threshold.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Mock: genera series realistas y estables por paciente (misma semilla).
// ---------------------------------------------------------------------------
class VitalsRepositoryMock implements VitalsRepository {
  final _uploaded = <String, List<VitalReading>>{};

  static const _thresholds = [
    Threshold(type: VitalType.heartRate, minValue: 50, maxValue: 110),
    Threshold(type: VitalType.spo2, minValue: 92),
    Threshold(type: VitalType.temperature, minValue: 36.1, maxValue: 37.2),
  ];

  Random _rng(String patientId, VitalType type) =>
      Random(patientId.hashCode ^ type.index);

  double _baseline(VitalType type) {
    switch (type) {
      case VitalType.heartRate:
        return 72;
      case VitalType.spo2:
        return 96;
      case VitalType.temperature:
        return 36.6;
      case VitalType.sleep:
        return 6.8;
      case VitalType.steps:
        return 3200;
      case VitalType.sedentaryMin:
        return 540;
      case VitalType.fallEvent:
        return 0;
    }
  }

  double _jitter(VitalType type, Random rng) {
    switch (type) {
      case VitalType.heartRate:
        return rng.nextDouble() * 14 - 7;
      case VitalType.spo2:
        return rng.nextDouble() * 3 - 1.5;
      case VitalType.temperature:
        return rng.nextDouble() * 0.8 - 0.4;
      case VitalType.sleep:
        return rng.nextDouble() * 2.4 - 1.2;
      case VitalType.steps:
        return rng.nextDouble() * 2400 - 1200;
      case VitalType.sedentaryMin:
        return rng.nextDouble() * 120 - 60;
      case VitalType.fallEvent:
        return 0;
    }
  }

  /// Media banda de variacion diaria (min/max) alrededor del valor, para que
  /// la grafica de tendencia pueda mostrar minimos y maximos (AGE-304).
  /// Proporcional al tipo de vital para que se vea razonable en el grafico.
  double _dailySpread(VitalType type) {
    switch (type) {
      case VitalType.heartRate:
        return 10;
      case VitalType.spo2:
        return 2;
      case VitalType.temperature:
        return 0.3;
      case VitalType.sleep:
        return 0.6;
      case VitalType.steps:
        return 600;
      case VitalType.sedentaryMin:
        return 40;
      case VitalType.fallEvent:
        return 0;
    }
  }

  @override
  Future<int> uploadBatch(String patientId, List<VitalReading> readings) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _uploaded.putIfAbsent(patientId, () => []).addAll(readings);
    return readings.length;
  }

  @override
  Future<VitalSeries> getSeries(
    String patientId,
    VitalType type, {
    required DateTime from,
    required DateTime to,
    String granularity = 'day',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final rng = _rng(patientId, type);
    final days = to.difference(from).inDays.clamp(1, 92);
    final points = <VitalPoint>[];
    for (var i = 0; i <= days; i++) {
      final day = from.add(Duration(days: i));
      final value =
          (_baseline(type) + _jitter(type, rng)).clamp(0, double.infinity);
      final spread = _dailySpread(type);
      points.add(VitalPoint(
        ts: day,
        value: double.parse(value.toStringAsFixed(1)),
        min: spread > 0
            ? double.parse((value - spread).clamp(0, double.infinity).toStringAsFixed(1))
            : null,
        max: spread > 0 ? double.parse((value + spread).toStringAsFixed(1)) : null,
      ));
    }
    Threshold? threshold;
    for (final t in _thresholds) {
      if (t.type == type) threshold = t;
    }
    return VitalSeries(type: type, points: points, threshold: threshold);
  }

  @override
  Future<List<LatestVital>> getLatest(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final now = DateTime.now();
    // 'p-jose' simula SpO2 baja para demo del semáforo warning.
    final lowSpo2 = patientId == 'p-jose';
    return [
      LatestVital(
          type: VitalType.heartRate,
          value: 74,
          measuredAt: now.subtract(const Duration(minutes: 12))),
      LatestVital(
          type: VitalType.spo2,
          value: lowSpo2 ? 91 : 97,
          measuredAt: now.subtract(const Duration(minutes: 12)),
          inRange: !lowSpo2),
      LatestVital(
          type: VitalType.temperature,
          value: 36.7,
          measuredAt: now.subtract(const Duration(minutes: 12))),
      LatestVital(
          type: VitalType.sleep,
          value: 6.5,
          measuredAt: DateTime(now.year, now.month, now.day, 7)),
      LatestVital(
          type: VitalType.steps,
          value: 2840,
          measuredAt: now.subtract(const Duration(minutes: 30))),
    ];
  }

  @override
  Future<List<Threshold>> getThresholds(String patientId) async => _thresholds;
}

final vitalsRepositoryProvider = Provider<VitalsRepository>((ref) {
  if (AppConfig.useMocks) return VitalsRepositoryMock();
  return VitalsRepositoryHttp(ref.watch(apiClientProvider));
});
