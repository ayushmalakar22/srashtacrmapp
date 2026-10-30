import 'package:flutter/material.dart';
import 'sort_button.dart';

/// One status chip: [value] null means "All".
class FilterOption {
  final String? value;
  final String label;
  const FilterOption(this.value, this.label);
}

/// A date window for filtering lists by their `yyyy-MM-dd` date.
class DateFilter {
  final String label;
  final DateTime? from;
  final DateTime? to; // inclusive

  const DateFilter(this.label, {this.from, this.to});

  static const all = DateFilter('All time');

  bool get isActive => from != null || to != null;

  /// `yyyy-MM-dd` for the API, or null when that end is open.
  static String? ymd(DateTime? d) => d == null
      ? null
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? get fromYmd => ymd(from);
  String? get toYmd => ymd(to);

  /// [ymd] is the record's date as `yyyy-MM-dd` (extra time part is ignored).
  bool contains(String? ymd) {
    if (!isActive) return true;
    final d = DateTime.tryParse((ymd ?? '').split(' ').first);
    if (d == null) return false;
    if (from != null && d.isBefore(from!)) return false;
    if (to != null && d.isAfter(to!)) return false;
    return true;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static List<DateFilter> presets([DateTime? now]) {
    final today = _day(now ?? DateTime.now());
    final thisMonth = DateTime(today.year, today.month, 1);
    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final lastMonthEnd = thisMonth.subtract(const Duration(days: 1));
    return [
      all,
      DateFilter('This month', from: thisMonth, to: today),
      DateFilter('Last month', from: lastMonthStart, to: lastMonthEnd),
      DateFilter('Last 30 days',
          from: today.subtract(const Duration(days: 29)), to: today),
      DateFilter('This year', from: DateTime(today.year, 1, 1), to: today),
    ];
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static DateFilter custom(DateTimeRange r) =>
      DateFilter('${_fmt(r.start)} - ${_fmt(r.end)}',
          from: _day(r.start), to: _day(r.end));
}

/// Scrollable status chips with optional group and date chips at the end,
/// all in one row.
class ListFilters extends StatelessWidget {
  final List<FilterOption> statuses;
  final String? status;
  final ValueChanged<String?> onStatus;
  final DateFilter? dateFilter;
  final ValueChanged<DateFilter>? onDate;

  /// Optional group picker (e.g. customer groups): [groups] without the
  /// "all" entry, [group] the chosen id (null = all).
  final List<FilterOption>? groups;
  final String? group;
  final ValueChanged<String?>? onGroup;

  /// Optional sort chip at the start of the row. The first option is the
  /// default; the chip is highlighted while another one is active.
  final List<SortOption>? sortOptions;
  final String? sort;
  final ValueChanged<String>? onSort;

  const ListFilters({
    super.key,
    required this.statuses,
    required this.status,
    required this.onStatus,
    this.dateFilter,
    this.onDate,
    this.groups,
    this.group,
    this.onGroup,
    this.sortOptions,
    this.sort,
    this.onSort,
  });

  Future<void> _pickGroup(BuildContext context) async {
    final all = [const FilterOption(null, 'All groups'), ...groups!];
    final choice = await showModalBottomSheet<FilterOption>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Filter by group',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final g in all)
                    ListTile(
                      title: Text(g.label),
                      trailing: g.value == group
                          ? Icon(Icons.check_circle,
                              color: Theme.of(ctx).colorScheme.primary)
                          : null,
                      onTap: () => Navigator.pop(ctx, g),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) onGroup?.call(choice.value);
  }

  Future<void> _pickDate(BuildContext context) async {
    final presets = DateFilter.presets();
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Filter by date',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final p in presets)
              ListTile(
                title: Text(p.label),
                trailing: p.label == dateFilter?.label
                    ? Icon(Icons.check_circle,
                        color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, p),
              ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Custom range...'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice is DateFilter) return onDate?.call(choice);

    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: dateFilter?.isActive == true
          ? DateTimeRange(start: dateFilter!.from!, end: dateFilter!.to!)
          : null,
    );
    if (range != null) onDate?.call(DateFilter.custom(range));
  }

  Widget _sortChip(BuildContext context, ColorScheme cs) {
    final options = sortOptions!;
    final current =
        options.firstWhere((o) => o.value == sort, orElse: () => options.first);
    final changed = current.value != options.first.value;
    return ActionChip(
      avatar: Icon(Icons.swap_vert_rounded,
          size: 18, color: changed ? cs.primary : null),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(changed ? current.label : 'Sort'),
        const SizedBox(width: 2),
        const Icon(Icons.arrow_drop_down, size: 20),
      ]),
      side: changed ? BorderSide(color: cs.primary) : null,
      onPressed: () async {
        final picked = await showSortSheet(context,
            options: options, value: current.value);
        if (picked != null && picked != current.value) onSort!(picked);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (sortOptions != null && onSort != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _sortChip(context, cs),
            ),
          for (final o in statuses)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o.label),
                selected: o.value == status,
                onSelected: (_) => onStatus(o.value),
              ),
            ),
          if (groups != null && groups!.isNotEmpty && onGroup != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: Icon(Icons.groups_outlined,
                    size: 18, color: group != null ? cs.primary : null),
                label: Text(group == null
                    ? 'All groups'
                    : groups!
                        .firstWhere((g) => g.value == group,
                            orElse: () => const FilterOption(null, 'Group'))
                        .label),
                side: group != null ? BorderSide(color: cs.primary) : null,
                onPressed: () => _pickGroup(context),
              ),
            ),
          if (onDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: Icon(Icons.calendar_month_outlined,
                    size: 18,
                    color: dateFilter?.isActive == true ? cs.primary : null),
                label: Text(dateFilter?.label ?? 'All time'),
                side: dateFilter?.isActive == true
                    ? BorderSide(color: cs.primary)
                    : null,
                onPressed: () => _pickDate(context),
              ),
            ),
        ],
      ),
    );
  }
}
