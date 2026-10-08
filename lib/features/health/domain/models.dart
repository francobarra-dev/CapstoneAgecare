import 'package:flutter/material.dart';

/// Tipos de vital (alineados con enum VitalType de la API).
enum VitalType {
  heartRate('heart_rate', 'Ritmo cardíaco', 'bpm', Icons.favorite_rounded),
  spo2('spo2', 'Oxígeno (SpO2)', '%', Icons.air_rounded),
  temperature('temperature', 'Temperatura', '°C', Icons.thermostat_rounded),
  sleep('sleep', 'Sueño', 'h', Icons.bedtime_rounded),
  steps('steps', 'Pasos', 'pasos', Icons.directions_walk_rounded),
  sedentaryMin('sedentary_min', 'Tiempo sedentario', 'min', Icons.chair_rounded),
  fallEvent('fall_event', 'Caídas', 'eventos', Icons.warning_rounded);

  /// true para los 3 signos vitales "core" que se muestran siempre en Salud
  /// (AGE-304): ritmo cardíaco, SpO2 y temperatura. El resto son datos de
  /// actividad/sueño, que se agrupan aparte.
  bool get isCoreVital =>
      this == heartRate || this == spo2 || this == temperature;

  const VitalType(this.apiValue, this.label, this.unit, this.icon);

  final String apiValue;
  final String label;
  final String unit;
  final IconData icon;

  static VitalType fromApi(String v) => VitalType.values
      .firstWhere((t) => t.apiValue == v, orElse: () => VitalType.heartRate);
}

class VitalReading {
  const VitalReading({
    required this.type,
    required this.value,
    required this.measuredAt,
    this.meta,
  });

  final VitalType type;
  final double value;
  final DateTime measuredAt;
  final Map<String, dynamic>? meta;

  Map<String, dynamic> toJson() => {
        'type': type.apiValue,
        'value': value,
        'measured_at': measuredAt.toUtc().toIso8601String(),
        if (meta != null) 'meta': meta,
      };
}

class VitalPoint {
  const VitalPoint({required this.ts, required this.value, this.min, this.max});

  final DateTime ts;
  final double value;
  final double? min;
  final double? max;

  factory VitalPoint.fromJson(Map<String, dynamic> json) => VitalPoint(
        ts: DateTime.parse(json['ts'] as String),
        value: (json['value'] as num).toDouble(),
        min: (json['min'] as num?)?.toDouble(),
        max: (json['max'] as num?)?.toDouble(),
      );
}

class Threshold {
  const Threshold({required this.type, this.minValue, this.maxValue});

  final VitalType type;
  final double? minValue;
  final double? maxValue;

  bool isOutOfRange(double value) =>
      (minValue != null && value < minValue!) ||
      (maxValue != null && value > maxValue!);

  factory Threshold.fromJson(Map<String, dynamic> json) => Threshold(
        type: VitalType.fromApi(json['type'] as String),
        minValue: (json['min_value'] as num?)?.toDouble(),
        maxValue: (json['max_value'] as num?)?.toDouble(),
      );
}

class VitalSeries {
  const VitalSeries({
    required this.type,
    required this.points,
    this.threshold,
  });

  final VitalType type;
  final List<VitalPoint> points;
  final Threshold? threshold;
}

class LatestVital {
  const LatestVital({
    required this.type,
    required this.value,
    required this.measuredAt,
    this.inRange = true,
  });

  final VitalType type;
  final double value;
  final DateTime measuredAt;
  final bool inRange;

  factory LatestVital.fromJson(Map<String, dynamic> json) => LatestVital(
        type: VitalType.fromApi(json['type'] as String),
        value: (json['value'] as num).toDouble(),
        measuredAt: DateTime.parse(json['measured_at'] as String),
        inRange: (json['in_range'] ?? true) as bool,
      );

  String get displayValue {
    switch (type) {
      case VitalType.steps:
      case VitalType.sedentaryMin:
      case VitalType.fallEvent:
        return value.toInt().toString();
      case VitalType.sleep:
        final h = value.floor();
        final m = ((value - h) * 60).round();
        return '${h}h ${m.toString().padLeft(2, '0')}m';
      case VitalType.temperature:
        return value.toStringAsFixed(1);
      default:
        return value.toStringAsFixed(0);
    }
  }
}
