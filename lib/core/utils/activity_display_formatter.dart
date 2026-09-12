/// Centralized, pure utility class for formatting activity log text across
/// both the Dashboard screen (Recent Activity tiles) and the Activity Log screen.
class ActivityDisplayFormatter {
  /// Returns the sanitized top-right text for an activity record.
  static String getTopRightText({
    required String title,
    required String subtitle,
    required String value,
    Map<String, dynamic>? metadata,
  }) {
    final meta = metadata ?? {};

    // 1. Cow records
    if (title == 'New Cow Added' ||
        title == 'Cow Removed' ||
        title == 'Cow Updated' ||
        title == 'Pregnancy Ended' ||
        title == 'Pregnancy Confirmed' ||
        title == 'Heat Repeated' ||
        title == 'Mating Recorded' ||
        title == 'Calving Recorded' ||
        title == 'Status Updated' ||
        title == 'Confirmation Method Updated') {
      if (title == 'New Cow Added' || title == 'Cow Updated' || title == 'Status Updated') {
        return value.isNotEmpty ? value : _formatCowLabel(meta, subtitle);
      }
      return value;
    }

    // 2. Buyer & Financial records (Never duplicate buyer name on top right!)
    if (title == 'Payment Received' ||
        title == 'Milk Sold' ||
        title == 'Advance Given' ||
        title == 'Milk Entry Added' ||
        title == 'Milk Entry Updated' ||
        title == 'Milk Entry Deleted' ||
        title == 'Buyer Added' ||
        title == 'Buyer Updated' ||
        title == 'Buyer Restored' ||
        title == 'Buyer Moved to Bin' ||
        title == 'Buyer Permanently Deleted' ||
        title == 'Ledger Entry Deleted') {
      return value;
    }

    // 3. Auth & System records
    return value;
  }

  /// Returns the left-side detail line(s) for an activity record.
  static List<String> getLeftDetails({
    required String title,
    required String subtitle,
    required String value,
    Map<String, dynamic>? metadata,
  }) {
    final meta = metadata ?? {};

    if (title == 'New Cow Added' ||
        title == 'Cow Updated' ||
        title == 'Cow Removed' ||
        title == 'Pregnancy Ended' ||
        title == 'Pregnancy Confirmed' ||
        title == 'Heat Repeated' ||
        title == 'Mating Recorded' ||
        title == 'Calving Recorded' ||
        title == 'Status Updated' ||
        title == 'Confirmation Method Updated') {
      return [_formatCowLabel(meta, subtitle)];
    }

    if (title == 'Buyer Added' || title == 'Buyer Updated') {
      final phone = _cleanString(meta['phone']);
      return [
        if (phone != null) 'Phone: $phone',
        subtitle,
      ];
    }

    if (title == 'Payment Received' ||
        title == 'Milk Sold' ||
        title == 'Advance Given' ||
        title == 'Milk Entry Added' ||
        title == 'Milk Entry Updated' ||
        title == 'Milk Entry Deleted' ||
        title == 'Buyer Restored' ||
        title == 'Buyer Moved to Bin' ||
        title == 'Buyer Permanently Deleted' ||
        title == 'Ledger Entry Deleted') {
      final name = _cleanString(meta['name']) ?? subtitle;
      return [name];
    }

    return [subtitle];
  }

  /// Formats cow label cleanly from metadata or fallback subtitle.
  static String _formatCowLabel(Map<String, dynamic> meta, String defaultSubtitle) {
    final name = _cleanString(meta['name']);
    final tag = _cleanString(meta['tag']);

    if (name != null && tag != null) {
      if (name.toLowerCase() == tag.toLowerCase()) return 'Cow #$tag';
      if (name.contains('($tag)') || name.contains('#$tag')) return name;
      return '$name (#$tag)';
    }
    if (name != null) return name;
    if (tag != null) return 'Cow #$tag';

    final cleanSub = _cleanString(defaultSubtitle);
    if (cleanSub != null && !cleanSub.contains('null')) {
      if (cleanSub.startsWith('Tag: ')) {
        final rawTag = cleanSub.replaceFirst('Tag: ', '').trim();
        return 'Cow #$rawTag';
      }
      return cleanSub;
    }
    return 'Cow Record';
  }

  static String? _cleanString(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty || str == 'null') return null;
    return str;
  }
}
