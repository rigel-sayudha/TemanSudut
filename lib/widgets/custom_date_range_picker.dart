import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const CustomDateRangePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTime? initialStartDate,
    DateTime? initialEndDate,
  }) {
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomDateRangePicker(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
      ),
    );
  }

  @override
  _CustomDateRangePickerState createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime _currentMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _currentMonth = DateTime(
      _startDate?.year ?? _today.year,
      _startDate?.month ?? _today.month,
    );
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      if (_startDate == null) {
        _startDate = date;
        _endDate = null;
      } else if (_startDate != null && _endDate == null) {
        if (date.isBefore(_startDate!)) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      } else {
        _startDate = date;
        _endDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Pilih Rentang Tanggal',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildHeader(),
          const SizedBox(height: 16),
          _buildDaysOfWeek(),
          Expanded(child: _buildCalendarGrid()),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: _prevMonth,
          ),
          Text(
            DateFormat('MMMM yyyy', 'id').format(_currentMonth),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    // 1 = Monday, 7 = Sunday
    final firstDayWeekday = firstDayOfMonth.weekday;

    int totalSlots = firstDayWeekday - 1 + daysInMonth;
    int rows = (totalSlots / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        if (index < firstDayWeekday - 1 || index >= totalSlots) {
          return const SizedBox.shrink();
        }

        final day = index - (firstDayWeekday - 1) + 1;
        final date = DateTime(_currentMonth.year, _currentMonth.month, day);

        return _buildDayCell(date);
      },
    );
  }

  Widget _buildDayCell(DateTime date) {
    bool isSelected = false;
    bool isStart = false;
    bool isEnd = false;
    bool isInRange = false;
    bool isToday = DateUtils.isSameDay(date, _today);

    if (_startDate != null && DateUtils.isSameDay(date, _startDate)) {
      isSelected = true;
      isStart = true;
      if (_endDate == null) {
        isEnd = true;
      }
    }
    if (_endDate != null && DateUtils.isSameDay(date, _endDate)) {
      isSelected = true;
      isEnd = true;
    }
    if (_startDate != null && _endDate != null) {
      if (date.isAfter(_startDate!) && date.isBefore(_endDate!)) {
        isInRange = true;
      }
    }

    Widget content = Center(
      child: Text(
        '${date.day}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: isSelected || isToday
              ? FontWeight.w600
              : FontWeight.normal,
          color: isSelected
              ? Colors.white
              : (isToday ? const Color(0xFF5D4037) : Colors.black87),
        ),
      ),
    );

    return GestureDetector(
      onTap: () => _onDaySelected(date),
      child: Stack(
        children: [
          // Range background
          if (isInRange || (isSelected && _endDate != null))
            Container(
              margin: EdgeInsets.only(
                left: isStart ? 24 : 0,
                right: isEnd ? 24 : 0,
                top: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF5D4037).withOpacity(0.15),
              ),
            ),

          // Selection circle
          if (isSelected)
            Container(
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF5D4037),
                shape: BoxShape.circle,
              ),
            ),

          // Border for today if not selected
          if (isToday && !isSelected)
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF5D4037), width: 1.5),
                shape: BoxShape.circle,
              ),
            ),

          content,
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    String selectedText = 'Pilih Tanggal';
    if (_startDate != null) {
      if (_endDate != null) {
        selectedText =
            '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}';
      } else {
        selectedText = DateFormat('dd MMM yyyy').format(_startDate!);
      }
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tanggal Terpilih',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5D4037),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed:
                (_startDate != null && _endDate != null) ||
                    (_startDate != null && _endDate == null)
                ? () {
                    Navigator.pop(
                      context,
                      DateTimeRange(
                        start: _startDate!,
                        end: _endDate ?? _startDate!,
                      ),
                    );
                  }
                : null,
            child: Text(
              'Terapkan',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
