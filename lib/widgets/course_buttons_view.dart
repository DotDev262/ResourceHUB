import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class CourseButtonsView extends StatelessWidget {
  final List<String> courseTitles;
  final Function(String) onCoursePressed;
  final bool isGrid;
  final List<IconData> courseIcons;
  final Logger _logger = Logger('CourseButtonsView');

  // Enhanced reusable ButtonStyle with animations
  static ButtonStyle get _courseButtonStyle => FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      );

  CourseButtonsView({
    super.key,
    required this.courseTitles,
    required this.onCoursePressed,
    this.isGrid = true,
    required this.courseIcons,
  }) : assert(courseTitles.length == courseIcons.length,
            'Course titles and icons must have the same length');

  @override
  Widget build(BuildContext context) {
    _logger.fine('Building CourseButtonsView with ${courseTitles.length} courses');
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            child: child,
          ),
        );
      },
      child: isGrid ? _buildGridLayout() : _buildListLayout(),
    );
  }

  Widget _buildGridLayout() {
    return GridView.builder(
      key: const ValueKey('grid_view'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      padding: const EdgeInsets.all(16),
      itemCount: courseTitles.length,
      itemBuilder: (context, index) {
        return _buildAnimatedCourseButton(
          context,
          courseTitles[index],
          courseIcons[index],
          index,
        );
      },
    );
  }

  Widget _buildListLayout() {
    return ListView.builder(
      key: const ValueKey('list_view'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: courseTitles.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _buildAnimatedCourseButton(
            context,
            courseTitles[index],
            courseIcons[index],
            index,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedCourseButton(
    BuildContext context,
    String title,
    IconData icon,
    int index,
  ) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.95, end: 1.0),
      duration: Duration(milliseconds: 200 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: _buildCourseButton(context, title, icon),
    );
  }

  Widget _buildCourseButton(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: FilledButton.tonal(
        onPressed: () => onCoursePressed(title),
        style: _courseButtonStyle.copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return Theme.of(context).colorScheme.primary.withOpacity(0.1);
              }
              if (states.contains(WidgetState.hovered)) {
                return Theme.of(context).colorScheme.primary.withOpacity(0.05);
              }
              return Colors.transparent;
            },
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}