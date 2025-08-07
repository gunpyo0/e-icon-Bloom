import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/providers/membership_provider.dart';

class VipBadge extends ConsumerWidget {
  final double size;
  final bool showText;
  final VipBadgeStyle style;

  const VipBadge({
    super.key,
    this.size = 24,
    this.showText = true,
    this.style = VipBadgeStyle.premium,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipState = ref.watch(membershipProvider);
    
    if (!membershipState.isPremium || membershipState.isExpired) {
      return const SizedBox.shrink();
    }

    return _buildBadge(membershipState);
  }

  Widget _buildBadge(MembershipState state) {
    final colors = _getBadgeColors(state.membershipType);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showText ? 8 : 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getBadgeIcon(state.membershipType),
            color: Colors.white,
            size: size * 0.8,
          ),
          if (showText) ...[
            SizedBox(width: 4),
            Text(
              state.vipTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _getBadgeColors(String membershipType) {
    switch (style) {
      case VipBadgeStyle.premium:
        if (membershipType.contains('Lifetime')) {
          return [
            Color.fromRGBO(255, 215, 0, 1),    // Gold
            Color.fromRGBO(255, 193, 7, 1),    // Amber
            Color.fromRGBO(255, 152, 0, 1),    // Orange
          ];
        } else if (membershipType.contains('Yearly')) {
          return [
            Color.fromRGBO(255, 193, 7, 1),    // Amber
            Color.fromRGBO(255, 152, 0, 1),    // Orange
          ];
        } else {
          return [
            Color.fromRGBO(156, 39, 176, 1),   // Purple
            Color.fromRGBO(123, 31, 162, 1),   // Deep purple
          ];
        }
      case VipBadgeStyle.subtle:
        return [
          Color.fromRGBO(100, 100, 100, 0.8),
          Color.fromRGBO(80, 80, 80, 0.8),
        ];
      case VipBadgeStyle.accent:
        return [
          Color.fromRGBO(33, 150, 243, 1),    // Blue
          Color.fromRGBO(21, 101, 192, 1),    // Dark blue
        ];
    }
  }

  IconData _getBadgeIcon(String membershipType) {
    if (membershipType.contains('Lifetime')) {
      return Icons.workspace_premium;
    } else if (membershipType.contains('Yearly')) {
      return Icons.star;
    } else {
      return Icons.diamond;
    }
  }
}

enum VipBadgeStyle {
  premium,
  subtle,
  accent,
}

class AnimatedVipBadge extends ConsumerStatefulWidget {
  final double size;
  final bool showText;
  final VipBadgeStyle style;

  const AnimatedVipBadge({
    super.key,
    this.size = 24,
    this.showText = true,
    this.style = VipBadgeStyle.premium,
  });

  @override
  ConsumerState<AnimatedVipBadge> createState() => _AnimatedVipBadgeState();
}

class _AnimatedVipBadgeState extends ConsumerState<AnimatedVipBadge>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membershipState = ref.watch(membershipProvider);
    
    if (!membershipState.isPremium || membershipState.isExpired) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _shimmerAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: _buildAnimatedBadge(membershipState),
        );
      },
    );
  }

  Widget _buildAnimatedBadge(MembershipState state) {
    final colors = _getBadgeColors(state.membershipType);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.showText ? 8 : 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Base gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getBadgeIcon(state.membershipType),
                    color: Colors.white,
                    size: widget.size * 0.8,
                  ),
                  if (widget.showText) ...[
                    SizedBox(width: 4),
                    Text(
                      state.vipTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.size * 0.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Shimmer effect
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(_shimmerAnimation.value * 100, 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
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

  List<Color> _getBadgeColors(String membershipType) {
    switch (widget.style) {
      case VipBadgeStyle.premium:
        if (membershipType.contains('Lifetime')) {
          return [
            Color.fromRGBO(255, 215, 0, 1),
            Color.fromRGBO(255, 193, 7, 1),
            Color.fromRGBO(255, 152, 0, 1),
          ];
        } else if (membershipType.contains('Yearly')) {
          return [
            Color.fromRGBO(255, 193, 7, 1),
            Color.fromRGBO(255, 152, 0, 1),
          ];
        } else {
          return [
            Color.fromRGBO(156, 39, 176, 1),
            Color.fromRGBO(123, 31, 162, 1),
          ];
        }
      case VipBadgeStyle.subtle:
        return [
          Color.fromRGBO(100, 100, 100, 0.8),
          Color.fromRGBO(80, 80, 80, 0.8),
        ];
      case VipBadgeStyle.accent:
        return [
          Color.fromRGBO(33, 150, 243, 1),
          Color.fromRGBO(21, 101, 192, 1),
        ];
    }
  }

  IconData _getBadgeIcon(String membershipType) {
    if (membershipType.contains('Lifetime')) {
      return Icons.workspace_premium;
    } else if (membershipType.contains('Yearly')) {
      return Icons.star;
    } else {
      return Icons.diamond;
    }
  }
}

class VipStatusIndicator extends ConsumerWidget {
  const VipStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipState = ref.watch(membershipProvider);
    
    if (!membershipState.isPremium || membershipState.isExpired) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromRGBO(255, 215, 0, 0.2),
            Color.fromRGBO(255, 193, 7, 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color.fromRGBO(255, 215, 0, 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: Color.fromRGBO(255, 215, 0, 1),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            membershipState.vipTitle,
            style: TextStyle(
              color: Color.fromRGBO(255, 215, 0, 1),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}