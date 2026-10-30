import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Round profile photo with the first letter of the name as fallback (no
/// photo yet, or it cannot be loaded).
class StaffAvatar extends StatelessWidget {
  final String name;
  final String? path; // as sent by the API, e.g. uploads/.../thumb_x.png?v=x
  final double radius;
  final Color? background;
  final Color? foreground;

  const StaffAvatar({
    super.key,
    required this.name,
    this.path,
    this.radius = 24,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = foreground ?? cs.primary;
    final initial = Text(
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
      style: TextStyle(
          color: fg, fontSize: radius * 0.9, fontWeight: FontWeight.bold),
    );
    final url =
        (path == null || path!.isEmpty) ? null : ApiService.fileUrl(path!);
    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? cs.primary.withValues(alpha: 0.12),
      child: url == null
          ? initial
          : ClipOval(
              child: Image.network(
                url,
                key: ValueKey(url),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => initial,
              ),
            ),
    );
  }
}
