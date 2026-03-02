import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/canvas_cast_request_reply.dart';
import 'package:app/theme/app_color.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Metrics section for FF1 device configuration.
///
/// This widget owns chart state and listens to realtime metrics, so only this
/// subtree rebuilds on polling updates.
class DeviceMetricsSection extends ConsumerStatefulWidget {
  /// Creates a [DeviceMetricsSection].
  const DeviceMetricsSection({
    required this.topicId,
    required this.isConnected,
    super.key,
  });

  /// FF1 topic identifier.
  final String topicId;

  /// Whether device is currently connected.
  final bool isConnected;

  @override
  ConsumerState<DeviceMetricsSection> createState() =>
      _DeviceMetricsSectionState();
}

class _DeviceMetricsSectionState extends ConsumerState<DeviceMetricsSection> {
  static const int _maxDataPoints = 20;

  final List<FlSpot> _cpuPoints = <FlSpot>[];
  final List<FlSpot> _memoryPoints = <FlSpot>[];
  final List<FlSpot> _gpuPoints = <FlSpot>[];
  final List<FlSpot> _cpuTempPoints = <FlSpot>[];
  final List<FlSpot> _gpuTempPoints = <FlSpot>[];
  final List<FlSpot> _fpsPoints = <FlSpot>[];

  @override
  void didUpdateWidget(covariant DeviceMetricsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicId != widget.topicId) {
      _resetMetrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isConnected || widget.topicId.isEmpty) {
      return const SizedBox.shrink();
    }

    ref.listen<AsyncValue<DeviceRealtimeMetrics>>(
      ff1DeviceRealtimeMetricsStreamProvider(widget.topicId),
      (_, next) {
        next.whenData(_updateMetricsFromStream);
      },
    );

    return Column(
      children: [
        _performanceMonitoring(context),
        const Divider(
          color: AppColor.primaryBlack,
          thickness: 1,
          height: 40,
        ),
        _temperatureMonitoring(context),
        const Divider(
          color: AppColor.primaryBlack,
          thickness: 1,
          height: 40,
        ),
      ],
    );
  }

  void _updateMetricsFromStream(DeviceRealtimeMetrics metrics) {
    if (!mounted) return;

    setState(() {
      final timestamp = metrics.timestamp.toDouble();

      final cpuUsage = metrics.cpu?.cpuUsage;
      if (cpuUsage != null) {
        _appendAndTrim(_cpuPoints, FlSpot(timestamp, cpuUsage.clamp(0.0, 100.0)));
      }

      final memoryUsage = metrics.memory?.memoryUsage;
      if (memoryUsage != null) {
        _appendAndTrim(
          _memoryPoints,
          FlSpot(timestamp, memoryUsage.clamp(0.0, 100.0)),
        );
      }

      final gpuUsage = metrics.gpu?.gpuUsage;
      if (gpuUsage != null) {
        _appendAndTrim(_gpuPoints, FlSpot(timestamp, gpuUsage.clamp(0.0, 100.0)));
      }

      final cpuTemp = metrics.cpu?.currentTemperature;
      if (cpuTemp != null) {
        _appendAndTrim(
          _cpuTempPoints,
          FlSpot(timestamp, cpuTemp.clamp(0.0, 100.0)),
        );
      }

      final gpuTemp = metrics.gpu?.currentTemperature;
      if (gpuTemp != null) {
        _appendAndTrim(
          _gpuTempPoints,
          FlSpot(timestamp, gpuTemp.clamp(0.0, 100.0)),
        );
      }

      final fps = metrics.screen?.fps;
      if (fps != null) {
        _appendAndTrim(_fpsPoints, FlSpot(timestamp, fps));
      }

      _sortPoints();
    });
  }

  void _appendAndTrim(List<FlSpot> points, FlSpot point) {
    points.add(point);
    while (points.length > _maxDataPoints) {
      points.removeAt(0);
    }
  }

  void _sortPoints() {
    _cpuPoints.sort((a, b) => a.x.compareTo(b.x));
    _memoryPoints.sort((a, b) => a.x.compareTo(b.x));
    _gpuPoints.sort((a, b) => a.x.compareTo(b.x));
    _cpuTempPoints.sort((a, b) => a.x.compareTo(b.x));
    _gpuTempPoints.sort((a, b) => a.x.compareTo(b.x));
    _fpsPoints.sort((a, b) => a.x.compareTo(b.x));
  }

  void _resetMetrics() {
    setState(() {
      _cpuPoints.clear();
      _memoryPoints.clear();
      _gpuPoints.clear();
      _cpuTempPoints.clear();
      _gpuTempPoints.clear();
      _fpsPoints.clear();
    });
  }

  Widget _performanceMonitoring(BuildContext context) {
    const cpuColor = Colors.blue;
    const memoryColor = Colors.green;
    const gpuColor = Colors.red;

    final cpuValue = _cpuPoints.isNotEmpty ? _cpuPoints.last.y : null;
    final memoryValue = _memoryPoints.isNotEmpty ? _memoryPoints.last.y : null;
    final gpuValue = _gpuPoints.isNotEmpty ? _gpuPoints.last.y : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Monitoring',
          style: AppTypography.body(context).white,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColor.primaryBlack,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricDisplay(context, 'CPU', cpuValue, '%', cpuColor),
              _metricDisplay(context, 'Memory', memoryValue, '%', memoryColor),
              _metricDisplay(context, 'GPU', gpuValue, '%', gpuColor),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColor.auGreyBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              minY: -20,
              maxY: 120,
              minX: (_cpuPoints.isEmpty ? 0.0 : _cpuPoints.first.x) - 20.0,
              maxX: (_cpuPoints.isEmpty ? 0.0 : _cpuPoints.last.x) + 20.0,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) {
                  return const FlLine(
                    color: AppColor.feralFileMediumGrey,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _createLineData(_cpuPoints, cpuColor, 'CPU'),
                _createLineData(_memoryPoints, memoryColor, 'Memory'),
                _createLineData(_gpuPoints, gpuColor, 'GPU'),
              ],
              titlesData: FlTitlesData(
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 25,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      if (value < 0 || value > 100) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '${value.toInt()}%',
                        style: AppTypography.body(context).white,
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(
                    reservedSize: 30,
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchCallback: (event, touchResponse) {
                  if (event is FlTapDownEvent) {
                    HapticFeedback.lightImpact();
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.all(12),
                  tooltipMargin: 8,
                  getTooltipItems: (touchedBarSpots) {
                    final sortedSpots = List<LineBarSpot>.from(touchedBarSpots)
                      ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

                    final timestamp = sortedSpots.isNotEmpty
                        ? '\nTime: ${_formatTimestamp(sortedSpots.first.x)}'
                        : '';

                    return sortedSpots.asMap().entries.map((entry) {
                      final index = entry.key;
                      final barSpot = entry.value;

                      final metric = barSpot.barIndex == 0
                          ? 'CPU'
                          : barSpot.barIndex == 1
                          ? 'Memory'
                          : 'GPU';
                      final color = barSpot.barIndex == 0
                          ? cpuColor
                          : barSpot.barIndex == 1
                          ? memoryColor
                          : gpuColor;

                      return LineTooltipItem(
                        '$metric: ${barSpot.y.toStringAsFixed(1)}%',
                        TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: index == sortedSpots.length - 1
                            ? [
                                TextSpan(
                                  text: timestamp,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 10,
                                  ),
                                ),
                              ]
                            : null,
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _temperatureMonitoring(BuildContext context) {
    const cpuTempColor = Colors.blue;
    const gpuTempColor = Colors.red;

    final cpuTempValue = _cpuTempPoints.isNotEmpty ? _cpuTempPoints.last.y : null;
    final gpuTempValue = _gpuTempPoints.isNotEmpty ? _gpuTempPoints.last.y : null;
    const tempUnit = '°C';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Temperature Monitoring',
          style: AppTypography.body(context).white,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColor.primaryBlack,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricDisplay(
                context,
                'CPU Temp',
                cpuTempValue,
                tempUnit,
                cpuTempColor,
              ),
              _metricDisplay(
                context,
                'GPU Temp',
                gpuTempValue,
                tempUnit,
                gpuTempColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColor.auGreyBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              minY: -20,
              maxY: 120,
              minX: (_cpuTempPoints.isEmpty ? 0.0 : _cpuTempPoints.first.x) - 20.0,
              maxX: (_cpuTempPoints.isEmpty ? 0.0 : _cpuTempPoints.last.x) + 20.0,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) {
                  return const FlLine(
                    color: AppColor.feralFileMediumGrey,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _createLineData(_cpuTempPoints, cpuTempColor, 'CPU Temp'),
                _createLineData(_gpuTempPoints, gpuTempColor, 'GPU Temp'),
              ],
              titlesData: FlTitlesData(
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 20,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      if (value < 0 || value > 100) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '${value.toInt()}$tempUnit',
                        style: AppTypography.body(context).white,
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              lineTouchData: LineTouchData(
                touchCallback: (event, touchResponse) {
                  if (event is FlTapDownEvent) {
                    HapticFeedback.lightImpact();
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.all(12),
                  tooltipMargin: 8,
                  getTooltipItems: (touchedBarSpots) {
                    final sortedSpots = List<LineBarSpot>.from(touchedBarSpots)
                      ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

                    final timestamp = sortedSpots.isNotEmpty
                        ? '\nTime: ${_formatTimestamp(sortedSpots.first.x)}'
                        : '';

                    return sortedSpots.asMap().entries.map((entry) {
                      final index = entry.key;
                      final barSpot = entry.value;

                      final metric =
                          barSpot.barIndex == 0 ? 'CPU Temp' : 'GPU Temp';
                      final color =
                          barSpot.barIndex == 0 ? cpuTempColor : gpuTempColor;
                      final value = barSpot.y;

                      return LineTooltipItem(
                        '$metric: ${value.toStringAsFixed(1)}$tempUnit',
                        TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: index == sortedSpots.length - 1
                            ? [
                                TextSpan(
                                  text: timestamp,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 10,
                                  ),
                                ),
                              ]
                            : null,
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricDisplay(
    BuildContext context,
    String label,
    double? value,
    String unit,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.body(context).grey,
        ),
        SizedBox(height: LayoutConstants.space1),
        Text(
          '${value?.toStringAsFixed(1) ?? '--'} $unit',
          style: AppTypography.body(context).white.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  LineChartBarData _createLineData(
    List<FlSpot> points,
    Color color,
    String label,
  ) {
    if (points.isEmpty) {
      return LineChartBarData(
        spots: const [
          FlSpot(0, 0),
          FlSpot(100, 0),
        ],
        dotData: const FlDotData(show: false),
        color: color.withOpacity(0.3),
        barWidth: 1,
        dashArray: [5, 5],
        belowBarData: BarAreaData(),
      );
    }

    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(show: false),
      color: color,
      barWidth: 3,
      isCurved: true,
      preventCurveOverShooting: true,
      preventCurveOvershootingThreshold: 0,
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(40),
      ),
    );
  }

  String _formatTimestamp(double timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}
