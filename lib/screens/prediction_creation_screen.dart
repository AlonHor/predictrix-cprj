import 'package:flutter/material.dart';
import 'package:predictrix/redux/types/assertion.dart';
import 'package:predictrix/utils/socket_service.dart';

class PredictionCreationScreen extends StatefulWidget {
  final Assertion assertion;

  const PredictionCreationScreen({
    super.key,
    required this.assertion,
  });

  @override
  State<PredictionCreationScreen> createState() =>
      _PredictionCreationScreenState();
}

class _PredictionCreationScreenState extends State<PredictionCreationScreen> {
  bool? _willHappen;
  double _confidence = 50;

  bool get _canSubmit => _willHappen != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make Prediction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Assertion text display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.assertion.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Prediction heading
            const Center(
              child: Text(
                'What is your prediction?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Will/Won't Happen buttons
            Row(
              children: [
                Expanded(
                  child: _buildPredictionButton(
                    isWillHappen: true,
                    isSelected: _willHappen == true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPredictionButton(
                    isWillHappen: false,
                    isSelected: _willHappen == false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Confidence slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confidence: ${_confidence.toInt()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _willHappen == null ? Colors.grey : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbColor: _willHappen == null ? Colors.grey : Colors.blue,
                    activeTrackColor: _willHappen == null
                        ? Colors.grey[300]
                        : Colors.blue[200],
                    inactiveTrackColor: _willHappen == null
                        ? Colors.grey[200]
                        : Colors.blue[100],
                    overlayColor:
                        (_willHappen == null ? Colors.grey : Colors.blue)
                            .withOpacity(0.3),
                  ),
                  child: Slider(
                    min: 0,
                    max: 100,
                    divisions: 20,
                    // 5% increments
                    value: _confidence,
                    onChanged: _willHappen == null
                        ? null
                        : (value) {
                            setState(() {
                              _confidence = value;
                            });
                          },
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Submit button
            Center(
              child: Hero(
                tag: 'submit-prediction-${widget.assertion.id}',
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                      side: const BorderSide(color: Colors.black12),
                      elevation: 2,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                    onPressed: _canSubmit
                        ? () {
                            SocketService().send(
                              "pred${widget.assertion.id},${_confidence / 100},${_willHappen! ? 'true' : 'false'}",
                            );
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Submit Prediction',
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.send),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionButton({
    required bool isWillHappen,
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 120,
      decoration: BoxDecoration(
        color: isSelected
            ? (isWillHappen ? Colors.green[700] : Colors.red[700])
            : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? (isWillHappen ? Colors.green : Colors.red)
              : Colors.grey[700]!,
          width: 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: (isWillHappen ? Colors.green : Colors.red)
                      .withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _willHappen = isWillHappen;
            });
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isWillHappen ? Icons.check_circle : Icons.cancel,
                size: 36,
                color: isSelected
                    ? Colors.white
                    : (isWillHappen ? Colors.green[300] : Colors.red[300]),
              ),
              const SizedBox(height: 8),
              Text(
                isWillHappen ? 'WILL HAPPEN' : 'WON\'T HAPPEN',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
