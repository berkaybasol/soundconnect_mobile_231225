part of 'venue_event_management_event_card.dart';

class _VenueCalendarEventFooter extends StatelessWidget {
  final String performerName;
  final String title;

  _VenueCalendarEventFooter({required this.performerName, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navBlueDeep,
            Theme.of(
              context,
            ).colorScheme.surfaceContainer.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _InfoInlineBlock(text: performerName)),
              ],
            ),
          ),
          SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoInlineBlock extends StatelessWidget {
  final String text;

  _InfoInlineBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
