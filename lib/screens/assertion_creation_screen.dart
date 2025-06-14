import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';
import 'package:predictrix/redux/reducers.dart';
import 'package:predictrix/utils/socket_service.dart';

class AssertionCreationScreen extends StatefulWidget {
  final String chatId;

  const AssertionCreationScreen({super.key, required this.chatId});

  @override
  State<AssertionCreationScreen> createState() =>
      _AssertionCreationScreenState();
}

class _AssertionCreationScreenState extends State<AssertionCreationScreen> {
  final TextEditingController _assertionController = TextEditingController();
  final FocusNode _assertionFocusNode = FocusNode();
  DateTime? _validationDate;
  DateTime? _forecastDeadline;

  @override
  void dispose() {
    _assertionController.dispose();
    _assertionFocusNode.dispose();
    super.dispose();
  }

  // Format date time to readable string - without seconds
  String _formatDateTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('dd/MM/yy, HH:mm');
    return formatter.format(dateTime);
  }

  Future<void> _pickDateTime(BuildContext context, DateTime? initialDateTime,
      ValueChanged<DateTime> onDateTimePicked, {DateTime? minDate, DateTime? maxDate}) async {
    final DateTime now = DateTime.now();
    final DateTime minAllowedDate = minDate ?? now;

    // First pick a date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: (initialDateTime != null && initialDateTime.isAfter(minAllowedDate) &&
                   (maxDate == null || initialDateTime.isBefore(maxDate)))
          ? initialDateTime
          : minAllowedDate,
      firstDate: minAllowedDate.isAtSameMomentAs(now) || minAllowedDate.isAfter(now)
          ? DateTime(minAllowedDate.year, minAllowedDate.month, minAllowedDate.day)
          : now,
      lastDate: maxDate ?? DateTime(now.year + 10),
    );

    if (pickedDate != null) {
      // Set default initial time based on constraints
      TimeOfDay initialTime;

      // If we're picking a date that's today and minDate is now, enforce time to be after current time
      final bool isToday = pickedDate.year == now.year &&
          pickedDate.month == now.month &&
          pickedDate.day == now.day;

      if (isToday && minAllowedDate.isAtSameMomentAs(now)) {
        // For today, initial time should be at least current time + 5 minutes
        final now = DateTime.now();
        initialTime = TimeOfDay(hour: now.hour, minute: now.minute + 5);
        // Handle minute overflow
        if (initialTime.minute >= 60) {
          initialTime = TimeOfDay(
              hour: (initialTime.hour + initialTime.minute ~/ 60) % 24,
              minute: initialTime.minute % 60);
        }
      } else if (initialDateTime != null) {
        // Use previous selection if available
        initialTime = TimeOfDay.fromDateTime(initialDateTime);
      } else {
        // Default to current time
        initialTime = TimeOfDay.now();
      }

      // Then pick a time
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: true,
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        // Combine the date and time
        final DateTime pickedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Final validation to ensure the selected datetime meets our requirements
        if (pickedDateTime.isBefore(minAllowedDate)) {
          // Show an error dialog if time selected is invalid
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Invalid Time"),
              content: Text(
                  "Please select a time after ${_formatDateTime(minAllowedDate)}"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Try again with the correct minimum date
                    _pickDateTime(context, null, onDateTimePicked,
                        minDate: minAllowedDate, maxDate: maxDate);
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          return;
        }

        // Check if the picked date is after maxDate
        if (maxDate != null && pickedDateTime.isAfter(maxDate)) {
          // Show an error dialog if time selected is invalid
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Invalid Time"),
              content: Text(
                  "Please select a time before ${_formatDateTime(maxDate)}"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Try again with the correct maximum date
                    _pickDateTime(context, null, onDateTimePicked,
                        minDate: minAllowedDate, maxDate: maxDate);
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          return;
        }

        onDateTimePicked(pickedDateTime);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Pred Challenge"),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: "Help",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("How it works"),
                  content: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("\nA pred challenge has three parts:\n",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text("1. What? - The event you're predicting.\n"),
                        Text("2. When? - The time when the event is settled.\n"),
                        Text("3. Predict by - Deadline for making predictions.\n"),
                        SizedBox(height: 12),
                        Text("After the result is known, members vote on the outcome.\n\nPoints are awarded based on accuracy."),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Got it"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What are we predicting?",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _assertionController,
              focusNode: _assertionFocusNode,
              maxLength: 75,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "e.g., Israel will win this Eurovision",
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Timeline",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Results date selector
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.event),
                onPressed: () => _pickDateTime(
                  context,
                  _validationDate,
                  (date) {
                    setState(() {
                      _validationDate = date;
                      // If forecast deadline exists and is after or equal to the validation date,
                      // reset it so user can pick a valid one
                      if (_forecastDeadline != null &&
                          (_forecastDeadline!.isAfter(date) ||
                           _forecastDeadline!.isAtSameMomentAs(date))) {
                        _forecastDeadline = null;
                      }
                    });
                  },
                ),
                label: _validationDate == null
                    ? const Text("Set results date")
                    : Text("Results on: ${_formatDateTime(_validationDate!)}"),
              ),
            ),

            const SizedBox(height: 12),

            // Predict by date selector (now second)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.timer),
                onPressed: _validationDate == null
                    ? null // Disable button if validation date is not yet picked
                    : () => _pickDateTime(
                        context,
                        _forecastDeadline,
                        (date) {
                          setState(() => _forecastDeadline = date);
                        },
                        // The maximum date for predictions must be before the results date
                        minDate: DateTime.now(),
                        maxDate: _validationDate!.subtract(const Duration(minutes: 1)),
                      ),
                label: _forecastDeadline == null
                    ? const Text("Set predictions deadline")
                    : Text("Predict by: ${_formatDateTime(_forecastDeadline!)}"),
              ),
            ),

            // Timeline explanation
            if (_validationDate != null || _forecastDeadline != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Card(
                  color: Colors.grey.shade800,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_validationDate != null)
                          Text(
                            "Results will be known on ${_formatDateTime(_validationDate!)}",
                            style: TextStyle(color: Colors.grey.shade300),
                          ),
                        if (_forecastDeadline != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Predictions accepted until ${_formatDateTime(_forecastDeadline!)}",
                            style: TextStyle(color: Colors.grey.shade300),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            const Spacer(),

            // Create button
            Center(
              child: Hero(
                tag: 'send-assertion-${widget.chatId}',
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isAnimating = constraints.maxWidth < 250;
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                          elevation: 2,
                        ),
                        onPressed: () {
                          if (_assertionController.text.trim().isEmpty ||
                              _validationDate == null ||
                              _forecastDeadline == null) {
                            ScaffoldMessenger.of(context).showMaterialBanner(
                              MaterialBanner(
                                content: const Text("Please fill all fields."),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        ScaffoldMessenger.of(context)
                                            .hideCurrentMaterialBanner(),
                                    child: const Text("OK"),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          SocketService().send(
                            "assr${widget.chatId},${_validationDate!.toUtc().toIso8601String()},${_forecastDeadline!.toUtc().toIso8601String()},${_assertionController.text}",
                          );

                          // Dispatch action to Redux store
                          StoreProvider.of<AppState>(context).dispatch(
                            SetIsMessageSendingAction(true)
                          );

                          Navigator.of(context).pop();
                        },
                        child: isAnimating
                            ? const SizedBox.shrink()
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Create Challenge',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.send),
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

