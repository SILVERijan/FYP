import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onTap;

  const SearchResultCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fare = result['total_fare'];
    final distance = result['total_distance_km'];
    final List<dynamic> legs = result['legs'];
    final bool isTransfer = legs.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ...legs.asMap().entries.map((entry) {
                            final i = entry.key;
                            final leg = entry.value;
                            final color = Color(int.parse((leg['color'] ?? '#985A26').replaceFirst('#', '0xFF')));
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.directions_bus, color: Colors.white, size: 10),
                                      const SizedBox(width: 4),
                                      Text(leg['route_name'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                if (i < legs.length - 1)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.chevron_right, size: 14, color: Colors.black26),
                                  ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    Text(
                      'NRs. $fare',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isTransfer ? '${legs.length} Buses • $distance km total' : '${legs.first['type']} • $distance km',
                  style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildLeg(Icons.directions_walk, 'Walk ${result['walking_to_start_m']}m to ${result['start_stop']}', isFirst: true),
                ...legs.map((leg) => _buildLeg(
                  Icons.directions_bus, 
                  '${leg['route_name']} to ${leg['to_stop']}', 
                  iconColor: Color(int.parse((leg['color'] ?? '#985A26').replaceFirst('#', '0xFF')))
                )),
                _buildLeg(Icons.directions_walk, 'Walk ${result['walking_from_end_m']}m to destination', isLast: true),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildLeg(IconData icon, String title, {bool isFirst = false, bool isLast = false, Color? iconColor}) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              if (!isFirst) Container(width: 1, height: 8, color: Colors.black12),
              Icon(icon, color: iconColor ?? Colors.black26, size: 16),
              if (!isLast) Container(width: 1, height: 8, color: Colors.black12),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isFirst || isLast ? Colors.black45 : Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
