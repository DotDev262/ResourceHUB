import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class CourseButtonsView extends StatelessWidget {
  final List<String> courseTitles;
  final Function(String) onCoursePressed;
  final bool isGrid;
  final List<IconData> courseIcons;
  final Logger _logger = Logger('CourseButtonsView');

  // Create a reusable ButtonStyle
  static final ButtonStyle _courseButtonStyle = FilledButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    padding: const EdgeInsets.all(20),
    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
  );

  CourseButtonsView({ // Removed const
    super.key,
    required this.courseTitles,
    required this.onCoursePressed,
    this.isGrid = true,
    required this.courseIcons,
  });

  @override
  Widget build(BuildContext context) {
    _logger.fine(
        'Building CourseButtonsView with ${courseTitles.length} courses');
    if (isGrid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return GridView.builder(
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
              return _buildCourseButton(
                  context, courseTitles[index], courseIcons[index]);
            },
          );
        },
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: courseTitles.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: _buildCourseButton(
                context, courseTitles[index], courseIcons[index]),
          );
        },
      );
    }
  }

  Widget _buildCourseButton(
      BuildContext context, String title, IconData icon) {
    return FilledButton.tonal(
      onPressed: () => onCoursePressed(title),
      style: _courseButtonStyle, // Use the reusable ButtonStyle
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
