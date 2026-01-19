import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Minimal, dependency-free map picker used as a graceful interactive
/// fallback for platforms where a full map SDK isn't available.
///
/// - Shows a simple static map image when `staticMapUrl` is provided.
/// - Allows tapping to set coordinates (approximates lat/lng using bounding box).
/// - Exposes callbacks when coordinates change.
class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.onChanged,
    this.staticMapUrl,
  });

  final double latitude;
  final double longitude;
  final ValueChanged<Offset?>?
  onChanged; // returns (lat, lng) encoded in Offset(dx, dy)
  final String? staticMapUrl;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late double _lat;
  late double _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.latitude;
    _lng = widget.longitude;
  }

  void _setFromLocalPosition(Offset local, Size size) {
    // crude mapping: assume the image shows +-0.05 deg around center
    final dx = (local.dx / size.width) - 0.5;
    final dy = (local.dy / size.height) - 0.5;
    final lat = _lat + -dy * 0.1; // invert y
    final lng = _lng + dx * 0.1;
    setState(() {
      _lat = double.parse(lat.toStringAsFixed(6));
      _lng = double.parse(lng.toStringAsFixed(6));
    });
    widget.onChanged?.call(Offset(_lat, _lng));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          math.min(constraints.maxWidth * 0.6, 240),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTapDown: (e) => _setFromLocalPosition(e.localPosition, size),
              onPanUpdate: (e) => _setFromLocalPosition(e.localPosition, size),
              child: Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  image: widget.staticMapUrl != null
                      ? DecorationImage(
                          image: NetworkImage(widget.staticMapUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Center(
                  child: Stack(
                    children: [
                      Positioned(
                        left: size.width / 2 - 12,
                        top: size.height / 2 - 24,
                        child: Icon(
                          Icons.location_on,
                          size: 36,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lat: ${_lat.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Lng: ${_lng.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
