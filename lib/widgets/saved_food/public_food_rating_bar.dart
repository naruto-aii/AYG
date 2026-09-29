import 'package:flutter/material.dart';

import '../../models/food_rating.dart';
import '../../models/public_food_rating_view.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';

class PublicFoodRatingBar extends StatefulWidget {
  const PublicFoodRatingBar({
    super.key,
    required this.controller,
    required this.food,
    required this.initialView,
    this.onViewChanged,
  });

  final AppController controller;
  final SavedFood food;
  final PublicFoodRatingView initialView;
  final ValueChanged<PublicFoodRatingView>? onViewChanged;

  @override
  State<PublicFoodRatingBar> createState() => _PublicFoodRatingBarState();
}

class _PublicFoodRatingBarState extends State<PublicFoodRatingBar> {
  late PublicFoodRatingView _view;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
  }

  @override
  void didUpdateWidget(covariant PublicFoodRatingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialView != widget.initialView) {
      _view = widget.initialView;
    }
  }

  Future<void> _apply(Future<PublicFoodRatingResult> Function() action) async {
    if (_isSubmitting || !_view.canRate) {
      return;
    }
    setState(() => _isSubmitting = true);
    final result = await action();
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (result.success && result.view != null) {
      setState(() => _view = result.view!);
      widget.onViewChanged?.call(result.view!);
    } else if (result.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _RatingButton(
              label: '👍 Good ${_view.goodCount}',
              selected: _view.myRating == FoodRatingType.good,
              enabled: _view.canRate && !_isSubmitting,
              onPressed: () => _apply(
                () => widget.controller.setPublicFoodGood(widget.food),
              ),
            ),
            const SizedBox(width: 8),
            _RatingButton(
              label: '👎 Bad ${_view.badCount}',
              selected: _view.myRating == FoodRatingType.bad,
              enabled: _view.canRate && !_isSubmitting,
              onPressed: () =>
                  _apply(() => widget.controller.setPublicFoodBad(widget.food)),
            ),
            if (_view.myRating != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _view.canRate && !_isSubmitting
                    ? () => _apply(
                        () => widget.controller.clearPublicFoodRating(
                          widget.food,
                        ),
                      )
                    : null,
                child: const Text('取消'),
              ),
            ],
            if (_isSubmitting) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        const Text('評価は正確性を保証するものではありません', style: TextStyle(fontSize: 12)),
        if (_view.hasLowRating) ...[
          const SizedBox(height: 8),
          Text(
            '低い評価が多い食品です。基準量と栄養情報を確認してから利用してください。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
      child: Text(label),
    );
  }
}
