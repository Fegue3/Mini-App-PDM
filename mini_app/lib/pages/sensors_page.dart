import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart'; // acesso ao acelerómetro/giroscópio

class SensorsPage extends StatefulWidget {
  const SensorsPage({super.key});

  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  AccelerometerEvent? _accel; // últimos valores do acelerómetro
  GyroscopeEvent? _gyro;      // últimos valores do giroscópio

  StreamSubscription<AccelerometerEvent>? _accelSub; // subscrição do acelerómetro
  StreamSubscription<GyroscopeEvent>? _gyroSub;      // subscrição do giroscópio

  @override
  void initState() {
    super.initState();

    // começa a ouvir eventos do acelerómetro
    _accelSub = accelerometerEvents.listen((event) {
      setState(() => _accel = event);
    });

    // começa a ouvir eventos do giroscópio
    _gyroSub = gyroscopeEvents.listen((event) {
      setState(() => _gyro = event);
    });
  }

  @override
  void dispose() {
    // cancela streams para evitar memory leaks
    _accelSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  // -------- helpers --------

  // formata número com 2 casas decimais (ou '-' se nulo)
  String _fmt(double? v) => v == null ? '-' : v.toStringAsFixed(2);

  // normaliza valor para -1..1 (para usar em Alignment)
  double _normAlign(double? v) {
    if (v == null) return 0;
    const max = 8.0;
    double value = v;
    if (value > max) value = max;
    if (value < -max) value = -max;
    return value / max;
  }

  // -------- widgets --------

  // cartão genérico para mostrar X/Y/Z de um sensor
  Widget _buildSensorCard({
    required String title,
    required IconData icon,
    required double? x,
    required double? y,
    required double? z,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const CircleAvatar(child: Text('X')),
                  label: Text(_fmt(x)),
                ),
                Chip(
                  avatar: const CircleAvatar(child: Text('Y')),
                  label: Text(_fmt(y)),
                ),
                Chip(
                  avatar: const CircleAvatar(child: Text('Z')),
                  label: Text(_fmt(z)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // demo visual: bolinha que se mexe com o acelerómetro
  Widget _buildAccelDemoCard() {
    final ax = _accel?.x;
    final ay = _accel?.y;

    // invertido no X para corresponder à sensação de esquerda/direita
    final alignX = -_normAlign(ax);
    final alignY = _normAlign(ay);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.sports_esports),
                SizedBox(width: 8),
                Text(
                  'Demo acelerómetro',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Inclina o telemóvel – a bolinha move-se na direção da gravidade.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  color: Colors.grey.shade100,
                ),
                child: Align(
                  alignment: Alignment(
                    alignX.clamp(-1.0, 1.0),
                    alignY.clamp(-1.0, 1.0),
                  ),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------- build --------

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSensorCard(
          title: 'Acelerómetro',
          icon: Icons.speed,
          x: _accel?.x,
          y: _accel?.y,
          z: _accel?.z,
        ),
        const SizedBox(height: 16),
        _buildSensorCard(
          title: 'Giroscópio',
          icon: Icons.screen_rotation,
          x: _gyro?.x,
          y: _gyro?.y,
          z: _gyro?.z,
        ),
        const SizedBox(height: 16),
        _buildAccelDemoCard(),
      ],
    );
  }
}
