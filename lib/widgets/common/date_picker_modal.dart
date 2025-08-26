import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../utils/calendar_constants.dart';

class DatePickerModal extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const DatePickerModal({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  ConsumerState<DatePickerModal> createState() => _DatePickerModalState();
}

class _DatePickerModalState extends ConsumerState<DatePickerModal> {
  late DateTime _selectedDate;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _monthController = FixedExtentScrollController(
      initialItem: _selectedDate.month - 1,
    );
    
    final currentYear = DateTime.now().year;
    final yearIndex = _selectedDate.year - (currentYear - CalendarConstants.yearsToLoad);
    _yearController = FixedExtentScrollController(
      initialItem: yearIndex.clamp(0, CalendarConstants.yearsToLoad * 2),
    );
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentYear = DateTime.now().year;

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(context, isDark),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildMonthPicker(isDark),
                ),
                Expanded(
                  child: _buildYearPicker(currentYear, isDark),
                ),
              ],
            ),
          ),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Jump to Date',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(bool isDark) {
    return CupertinoPicker(
      scrollController: _monthController,
      itemExtent: 40,
      onSelectedItemChanged: (index) {
        setState(() {
          _selectedDate = DateTime(_selectedDate.year, index + 1, 1);
        });
      },
      children: _months.map((month) {
        return Center(
          child: Text(
            month,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYearPicker(int currentYear, bool isDark) {
    final startYear = currentYear - CalendarConstants.yearsToLoad;
    final endYear = currentYear + CalendarConstants.yearsToLoad;

    return CupertinoPicker(
      scrollController: _yearController,
      itemExtent: 40,
      onSelectedItemChanged: (index) {
        setState(() {
          _selectedDate = DateTime(startYear + index, _selectedDate.month, 1);
        });
      },
      children: List.generate(endYear - startYear + 1, (index) {
        final year = startYear + index;
        return Center(
          child: Text(
            year.toString(),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: year == currentYear ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final today = DateTime.now();
                widget.onDateSelected(today);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.today),
              label: const Text('Today'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                widget.onDateSelected(_selectedDate);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Go to ${DateFormat.yMMM().format(_selectedDate)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showDatePickerModal(
  BuildContext context,
  DateTime initialDate,
  Function(DateTime) onDateSelected,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DatePickerModal(
      initialDate: initialDate,
      onDateSelected: onDateSelected,
    ),
  );
}