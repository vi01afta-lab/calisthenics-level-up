import 'package:flutter/material.dart';
import '../core/constants.dart';

enum MuscleStatus { optimo, precaucion, critico }

class MuscleData {
  final String id;
  final String nombre;
  final bool esFrontal;
  final Offset posRelativa;
  final double labelSide;
  DateTime? cooldownExpiry;

  MuscleData({
    required this.id,
    required this.nombre,
    required this.esFrontal,
    required this.posRelativa,
    required this.labelSide,
    this.cooldownExpiry,
  });

  bool get enCooldown =>
      cooldownExpiry != null && DateTime.now().isBefore(cooldownExpiry!);

  Duration get tiempoRestante {
    if (cooldownExpiry == null) return Duration.zero;
    final r = cooldownExpiry!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  MuscleStatus get status {
    if (!enCooldown) return MuscleStatus.optimo;
    return tiempoRestante.inHours >= 24
        ? MuscleStatus.critico
        : MuscleStatus.precaucion;
  }

  Color get statusColor {
    switch (status) {
      case MuscleStatus.critico:
        return kCritico;
      case MuscleStatus.precaucion:
        return kPrecaucion;
      case MuscleStatus.optimo:
        return kOptimo;
    }
  }

  static List<MuscleData> defaultList() => [
        MuscleData(id: 'pectoral', nombre: 'Pectoral Mayor', esFrontal: true, posRelativa: const Offset(0.5, 0.29), labelSide: 1),
        MuscleData(id: 'biceps', nombre: 'Biceps', esFrontal: true, posRelativa: const Offset(0.10, 0.30), labelSide: -1),
        MuscleData(id: 'deltoides', nombre: 'Deltoides', esFrontal: true, posRelativa: const Offset(0.18, 0.21), labelSide: -1),
        MuscleData(id: 'core', nombre: 'Recto Abdominal', esFrontal: true, posRelativa: const Offset(0.5, 0.41), labelSide: 1),
        MuscleData(id: 'cuadriceps', nombre: 'Cuadriceps', esFrontal: true, posRelativa: const Offset(0.37, 0.67), labelSide: -1),
        MuscleData(id: 'dorsal', nombre: 'Dorsal Ancho', esFrontal: false, posRelativa: const Offset(0.5, 0.31), labelSide: -1),
        MuscleData(id: 'triceps', nombre: 'Triceps', esFrontal: false, posRelativa: const Offset(0.90, 0.30), labelSide: 1),
        MuscleData(id: 'gluteo', nombre: 'Gluteo Mayor', esFrontal: false, posRelativa: const Offset(0.5, 0.535), labelSide: 1),
        MuscleData(id: 'isquio', nombre: 'Isquiotibiales', esFrontal: false, posRelativa: const Offset(0.37, 0.67), labelSide: -1),
        MuscleData(id: 'trapecio', nombre: 'Trapecio', esFrontal: false, posRelativa: const Offset(0.5, 0.195), labelSide: 1),
      ];
}
