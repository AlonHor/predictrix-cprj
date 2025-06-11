import 'package:flutter/material.dart';
import 'package:predictrix/redux/types/assertion.dart';
import 'package:intl/intl.dart';
import 'package:predictrix/screens/prediction_creation_screen.dart';
import 'package:predictrix/utils/navigator.dart';

class AssertionWidget extends StatelessWidget {
  const AssertionWidget({
    super.key,
    required this.assertion,
  });

  final Assertion assertion;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool isPredictionPhase = now.isBefore(assertion.validationDate);
    final bool isVotingPhase = !assertion.completed &&
        now.isAfter(assertion.validationDate) &&
        now.isBefore(assertion.castingForecastDeadline);
    final bool isResultPhase =
        assertion.completed || now.isAfter(assertion.castingForecastDeadline);

    // Using a more compact date format
    final DateFormat dateFormat = DateFormat('dd/MM/yy, \nHH:mm');

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(isPredictionPhase, isVotingPhase,
              isResultPhase, assertion.completed),
          width: 2,
        ),
      ),
      color: Colors.blueGrey[900],
      elevation: 4,
      child: InkWell(
        onTap: () => _showPredictionsDialog(context),
        borderRadius: BorderRadius.circular(12),
        splashFactory: InkRipple.splashFactory,
        highlightColor: Colors.white.withOpacity(0.05),
        splashColor: Colors.white.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.assessment_outlined, // Prediction chart icon
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${assertion.predictions.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildStatusBadge(isPredictionPhase, isVotingPhase,
                      isResultPhase, assertion.completed),
                ],
              ),

              const SizedBox(height: 12),

              // Assertion Text
              Text(
                assertion.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              // Dates - With more compact layout
              Row(
                children: [
                  Expanded(
                    child: _buildCompactDateRow(
                      Icons.access_time,
                      'Prediction:',
                      dateFormat.format(assertion.castingForecastDeadline),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCompactDateRow(
                      Icons.event,
                      'Voting:',
                      dateFormat.format(assertion.validationDate),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action Buttons
              _buildActionButtons(context, isPredictionPhase, isVotingPhase,
                  isResultPhase, assertion.completed),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isPredictionPhase, bool isVotingPhase,
      bool isResultPhase, bool completed) {
    String statusText;
    Color statusColor;

    if (completed) {
      statusText = 'Completed';
      statusColor = Colors.green;
    } else if (isPredictionPhase) {
      statusText = 'Prediction Open';
      statusColor = Colors.blue;
    } else if (isVotingPhase) {
      statusText = 'Voting Open';
      statusColor = Colors.orange[700]!;
    } else {
      statusText = 'Pending Results';
      statusColor = Colors.purple[300]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(bool isPredictionPhase, bool isVotingPhase,
      bool isResultPhase, bool completed) {
    if (completed) {
      return Colors.green;
    } else if (isPredictionPhase) {
      return Colors.blue;
    } else if (isVotingPhase) {
      return Colors.orange[700]!;
    } else {
      return Colors.purple[300]!;
    }
  }

  // New compact date row widget
  Widget _buildCompactDateRow(IconData icon, String label, String dateText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.white60),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                dateText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isPredictionPhase,
      bool isVotingPhase, bool isResultPhase, bool completed) {
    if (completed) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.bar_chart),
        label: const Text('View Results'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          // Logic will be added later
        },
      );
    } else if (isPredictionPhase) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.timeline),
              label: Text(assertion.didPredict ?? false
                  ? 'Already Predicted'
                  : 'Make Prediction'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    assertion.didPredict ?? false ? Colors.grey[600] : Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: assertion.didPredict ?? false
                  ? null // Disable the button if user has already predicted
                  : () {
                      NavigatorUtils.navigateTo(context,
                          PredictionCreationScreen(assertion: assertion));
                    },
            ),
          ),
        ],
      );
    } else if (isVotingPhase) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.how_to_vote),
              label: const Text('Vote'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700]!,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // Logic will be added later
              },
            ),
          ),
        ],
      );
    } else {
      return ElevatedButton.icon(
        icon: const Icon(Icons.lock),
        label: const Text('Prediction Locked'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[700],
          disabledBackgroundColor: Colors.grey[800],
          disabledForegroundColor: Colors.grey[400],
        ),
        onPressed: null,
      );
    }
  }

  void _showPredictionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.blueGrey[800],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Predictions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                assertion.predictions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No predictions yet',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: assertion.predictions.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: Colors.white12),
                          itemBuilder: (context, index) {
                            final prediction = assertion.predictions[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  // Profile photo
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage:
                                        prediction.photoUrl.isNotEmpty
                                            ? NetworkImage(prediction.photoUrl)
                                            : null,
                                    backgroundColor: Colors.blueGrey[600],
                                    child: prediction.photoUrl.isEmpty
                                        ? Text(
                                            prediction.displayName.isNotEmpty
                                                ? prediction.displayName[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),

                                  // Name and prediction
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prediction.displayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: prediction.forecast
                                                    ? Colors.green
                                                        .withOpacity(0.2)
                                                    : Colors.red
                                                        .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: prediction.forecast
                                                      ? Colors.green
                                                      : Colors.red,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                prediction.forecast
                                                    ? 'WILL HAPPEN'
                                                    : 'WON\'T HAPPEN',
                                                style: TextStyle(
                                                  color: prediction.forecast
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Confidence percentage
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey[700],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${(prediction.confidence * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                assertion.predictions.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        );
      },
    );
  }
}
