import 'package:flutter/material.dart';
import 'package:stickeep_app/theme/app_theme.dart';

/// A single shimmering skeleton card that mimics a ReservationCard.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double width, double height) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(_anim.value + 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(120, 14),
              _box(64, 22),
            ],
          ),
          const SizedBox(height: 10),
          _box(80, 11),
          const SizedBox(height: 10),
          Row(
            children: [
              _box(90, 11),
              const SizedBox(width: 12),
              _box(70, 11),
              const SizedBox(width: 12),
              _box(50, 11),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows [count] skeleton cards while data is loading.
class ReservationListSkeleton extends StatelessWidget {
  final int count;
  const ReservationListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonCard(),
    );
  }
}

/// A shimmering placeholder shaped like a generic list row (avatar circle +
/// two lines of text) — used by admin list screens (users, classrooms,
/// seats, reports) while their initial snapshot is loading.
class SkeletonListRow extends StatefulWidget {
  const SkeletonListRow({super.key});

  @override
  State<SkeletonListRow> createState() => _SkeletonListRowState();
}

class _SkeletonListRowState extends State<SkeletonListRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double width, double height, {bool circle = false}) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(_anim.value + 0.3),
          borderRadius: circle ? null : BorderRadius.circular(6),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          _box(40, 40, circle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(140, 14),
                const SizedBox(height: 8),
                _box(90, 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [count] generic skeleton rows while an admin list is loading.
class AdminListSkeleton extends StatelessWidget {
  final int count;
  const AdminListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonListRow(),
    );
  }
}
