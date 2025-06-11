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
      ValueChanged<DateTime> onDateTimePicked, {DateTime? minDate}) async {
    final DateTime now = DateTime.now();
    final DateTime minAllowedDate = minDate ?? now;

    // First pick a date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: (initialDateTime != null && initialDateTime.isAfter(minAllowedDate))
          ? initialDateTime
          : minAllowedDate,
      firstDate: minAllowedDate.isAtSameMomentAs(now) || minAllowedDate.isAfter(now)
          ? DateTime(minAllowedDate.year, minAllowedDate.month, minAllowedDate.day)
          : now,
      lastDate: DateTime(now.year + 10),
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
                        minDate: minAllowedDate);
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
        title: const Text("Create Assertion"),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: "What are these dates?",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Help"),
                  content: const Text(
                      "Forecast Deadline: The final date for everyone to cast their predictions.\n\n"
                      "Validation Date: The date when the assertion should have a clear outcome, and voting begins.\n\n"
                      "Voting ends after 24 hours, or when there's a safe majority, whichever comes first.\n\n"
                      "When voting ends, the assertion is considered completed and ELO will be given out."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("OK"),
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
            TextField(
              controller: _assertionController,
              focusNode: _assertionFocusNode,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: "Assertion",
                border: OutlineInputBorder(),
                hintText: "Enter your assertion (max 50 chars)",
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _pickDateTime(
                  context,
                  _forecastDeadline,
                  (date) {
                    setState(() {
                      _forecastDeadline = date;
                      // If validation date exists but is before the new forecast deadline,
                      // reset it so user can pick a new valid one
                      if (_validationDate != null && _validationDate!.isBefore(date)) {
                        _validationDate = null;
                      }
                    });
                  },
                ),
                child: Text(_forecastDeadline == null
                    ? "Pick Forecast Deadline"
                    : "Forecast Deadline: ${_formatDateTime(_forecastDeadline!)}"),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: _forecastDeadline == null
                    ? null // Disable button if forecast deadline is not yet picked
                    : () => _pickDateTime(
                        context,
                        _validationDate,
                        (date) {
                          setState(() => _validationDate = date);
                        },
                        minDate: _forecastDeadline,
                      ),
                child: Text(_validationDate == null
                    ? "Pick Validation Date"
                    : "Validation Date: ${_formatDateTime(_validationDate!)}"),
              ),
            ),
            const Spacer(),
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
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                          side: const BorderSide(color: Colors.black12),
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
                                    'Send Assertion',
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
