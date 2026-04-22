import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class JourneyResultCard extends StatelessWidget {
  final Map<String, dynamic> journey;
  final VoidCallback onTap;
  final bool isSelected;

  const JourneyResultCard({
    super.key,
    required this.journey,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> legs = journey['legs'] ?? [];
    final fare = journey['total_fare'] ?? 0;
    final distance = (journey['total_distance_km'] as num?)?.toDouble() ?? 0.0;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1E1E) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentCrimson.withOpacity(0.5) : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.accentCrimson.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: legs.asMap().entries.map((entry) {
                      final i = entry.key;
                      final leg = entry.value;
                      
                      Widget legWidget;
                      if (leg['type'] == 'walk') {
                        legWidget = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.directions_walk, color: Colors.white70, size: 14),
                        );
                      } else {
                        final color = Color(int.parse((leg['color'] ?? '#E31C23').replaceFirst('#', '0xFF')));
                        legWidget = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.directions_bus, color: color, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                leg['route_name'] != null && leg['route_name'].length > 15 
                                  ? '${leg['route_name'].substring(0, 12)}...' 
                                  : leg['route_name'] ?? 'Bus',
                                style: TextStyle(
                                  color: color, 
                                  fontSize: 11, 
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          legWidget,
                          if (i < legs.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white24),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. $fare',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      '$distance km',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time_filled, size: 14, color: Colors.white.withOpacity(0.3)),
                const SizedBox(width: 6),
                Text(
                  'Best Route • ${_estimateTime(distance)} mins',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppTheme.accentCrimson, size: 20)
                else
                  Icon(Icons.arrow_forward, color: Colors.white.withOpacity(0.2), size: 18),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, duration: 400.ms);
  }

  String _estimateTime(double distance) {
    // Rough estimate: 20km/h average in city traffic
    int mins = (distance / 20 * 60).round();
    return mins.toString();
  }
}
