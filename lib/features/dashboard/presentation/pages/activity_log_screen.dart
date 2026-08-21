import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/activity_log_provider.dart';
import '../../data/models/activity_log_model.dart';
import 'package:intl/intl.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityLogProvider>(context);
    final activities = provider.activities;

    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      appBar: AppBar(
        backgroundColor: AppColors.bgGrey,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Activity Log',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sageGreen))
          : activities.isEmpty
              ? const Center(
                  child: Text(
                    'No activity yet.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: activities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _ExpandableActivityCard(activity: activity);
                  },
                ),
    );
  }
}

class _ExpandableActivityCard extends StatefulWidget {
  final ActivityLogModel activity;

  const _ExpandableActivityCard({required this.activity});

  @override
  State<_ExpandableActivityCard> createState() => _ExpandableActivityCardState();
}

class _ExpandableActivityCardState extends State<_ExpandableActivityCard> {
  bool _isExpanded = false;

  String _formatTimeAgo(int timeUnix) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timeUnix);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  String _getTopRightText() {
    final meta = widget.activity.metadata ?? {};
    final title = widget.activity.title;
    if (title == 'New Cow Added' || title == 'Cow Removed' || title == 'Cow Updated') {
      final name = meta['name']?.toString() ?? widget.activity.subtitle;
      final tag = meta['tag']?.toString();
      if (tag != null && name != tag) {
        return '$name ($tag)';
      }
      return name;
    }
    if (title == 'Payment Received' || title == 'Milk Sold') {
      return '${widget.activity.subtitle}  ${widget.activity.value}';
    }
    if (title == 'Buyer Added' || title == 'Buyer Removed' || title == 'Buyer Updated') {
      return widget.activity.subtitle;
    }
    return widget.activity.value;
  }

  String _getBottomRightText() {
    final title = widget.activity.title;
    if (title == 'Payment Received' || title == 'Milk Sold' || title == 'Cow Removed' || title == 'Buyer Removed') {
      return _formatExactTime(widget.activity.timeUnix);
    }
    return _formatTimeAgo(widget.activity.timeUnix);
  }

  List<Widget> _buildLeftDetails() {
    final meta = widget.activity.metadata ?? {};
    final title = widget.activity.title;
    
    if (title == 'New Cow Added' || title == 'Cow Updated') {
      return [
        Text(widget.activity.value, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
      ];
    }
    if (title == 'Buyer Added' || title == 'Buyer Updated') {
      return [
        if (meta['phone'] != null)
          Text(meta['phone'].toString(), style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
        Text(widget.activity.value, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
      ];
    }
    if (title == 'Cow Removed' || title == 'Buyer Removed') {
      return [
        Text(widget.activity.value, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
      ];
    }
    return [
      Text(
        widget.activity.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
      ),
    ];
  }

  String _formatExactTime(int timeUnix) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timeUnix);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minutes = dt.minute.toString().padLeft(2, '0');
    final monthStr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1];
    return '$hour:$minutes $ampm, $monthStr ${dt.day}';
  }

  String _formatFullDate(int timeUnix) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timeUnix);
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final valueColor = widget.activity.isPositive == 1
        ? AppColors.deepGreen
        : AppColors.textGrey;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: widget.activity.isPositive == 1
                            ? AppColors.sageTint
                            : const Color(0xFFEEEEEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.activity.icon,
                        color: widget.activity.isPositive == 1
                            ? AppColors.deepGreen
                            : AppColors.textGrey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.activity.title,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ..._buildLeftDetails(),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getTopRightText(),
                          style: TextStyle(
                            color: valueColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getBottomRightText(),
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: !_isExpanded
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 16, left: 54),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 14, color: AppColors.textGrey),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatFullDate(widget.activity.timeUnix),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 14, color: AppColors.textGrey),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.activity.isPositive == 1 ? 'Addition / Entry' : 'Deletion / Removal',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
