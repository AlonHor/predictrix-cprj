import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
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

  Future<void> _pickDate(BuildContext context, DateTime? initialDate,
      ValueChanged<DateTime> onDatePicked) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      onDatePicked(picked);
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
                  title: const Text("Date Explanations"),
                  content: const Text(
                      "Validation Date: The date when the assertion should have a clear happened/didn't happen answer. On this day, people can no longer submit predictions.\n\n"
                      "Forecast Deadline: The final date for everyone to cast their votes on what really happened. On this day, votes are locked and ELO is updated based on the outcome."),
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
                onPressed: () => _pickDate(context, _validationDate, (date) {
                  setState(() => _validationDate = date);
                }),
                child: Text(_validationDate == null
                    ? "Pick Validation Date"
                    : "Validation Date: ${_validationDate!.toLocal().toString().split(" ")[0]}"),
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
                onPressed: () => _pickDate(context, _forecastDeadline, (date) {
                  setState(() => _forecastDeadline = date);
                }),
                child: Text(_forecastDeadline == null
                    ? "Pick Forecast Deadline"
                    : "Forecast Deadline: ${_forecastDeadline!.toLocal().toString().split(" ")[0]}"),
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
                            "assr${widget.chatId},${_validationDate!.toIso8601String()},${_forecastDeadline!.toIso8601String()},${_assertionController.text}",
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
