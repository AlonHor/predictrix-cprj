import 'package:flutter/material.dart';
import 'package:predictrix/redux/types/assertion.dart';
import 'package:intl/intl.dart';
import 'package:predictrix/screens/prediction_creation_screen.dart';
import 'package:predictrix/utils/navigator.dart';
import 'package:predictrix/utils/socket_service.dart';

class AssertionWidget extends StatelessWidget {
  const AssertionWidget({
    super.key,
    required this.assertion,
  });

  final Assertion assertion;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final bool isPredictionPhase =
        now.isBefore(assertion.castingForecastDeadline);
    final bool isVotingPhase =
        !assertion.completed && now.isAfter(assertion.validationDate);
    final bool isResultPhase = assertion.completed;

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
        onTap: () {
          if (assertion.completed) {
            _showResultsDialog(context);
          } else if (isVotingPhase) {
            _showVotesDialog(context);
          } else {
            _showPredictionsDialog(context);
          }
        },
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
              Text(
                assertion.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactDateRow(
                      Icons.access_time,
                      'Pred Until:',
                      dateFormat
                          .format(assertion.castingForecastDeadline.toLocal()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCompactDateRow(
                      Icons.event,
                      'Results By:',
                      dateFormat.format(assertion.validationDate.toLocal()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
      statusText = 'Prediction Closed';
      statusColor = Colors.grey[600]!;
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
      return Colors.grey[600]!;
    }
  }

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
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart),
              label: const Text('View Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _showResultsDialog(context);
              },
            ),
          ),
        ],
      );
    } else if (isPredictionPhase) {
      // Prediction open phase - can make predictions if not already predicted
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
                backgroundColor: assertion.didPredict ?? false
                    ? Colors.grey[600]
                    : Colors.blue,
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
      // Voting phase - can vote on whether it happened or not
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
                _showVotingDialog(context);
              },
            ),
          ),
        ],
      );
    } else {
      // Prediction closed phase - cannot predict or vote
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock_clock),
              label: const Text('Awaiting Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                disabledBackgroundColor: Colors.grey[800],
                disabledForegroundColor: Colors.grey[400],
              ),
              onPressed: null,
            ),
          ),
        ],
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

  // Adding new method for handling the voting dialog
  void _showVotingDialog(BuildContext context) {
    bool? selectedVote;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Did this happen?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      assertion.text,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildVoteOption(
                            context,
                            true,
                            selectedVote,
                            (value) => setState(() => selectedVote = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildVoteOption(
                            context,
                            false,
                            selectedVote,
                            (value) => setState(() => selectedVote = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700]!,
                              disabledBackgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: selectedVote == null
                                ? null
                                : () {
                                    final voteString =
                                        selectedVote! ? "true" : "false";
                                    SocketService().send(
                                        "vote${assertion.id},$voteString");
                                    Navigator.of(context).pop();
                                  },
                            child: const Text('SUBMIT VOTE'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showResultsDialog(BuildContext context) {
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
                        'Results',
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

                // Final answer section
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: assertion.finalAnswer
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: assertion.finalAnswer ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        assertion.finalAnswer
                            ? Icons.check_circle
                            : Icons.cancel,
                        color:
                            assertion.finalAnswer ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          assertion.finalAnswer ? 'HAPPENED' : 'DIDN\'T HAPPEN',
                          style: TextStyle(
                            color: assertion.finalAnswer
                                ? Colors.green
                                : Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white24),

                // User predictions section
                const Padding(
                  padding: EdgeInsets.only(left: 20, top: 8, bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        'User Predictions',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                assertion.predictions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No predictions were made',
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
                            // Check if prediction was correct
                            final bool wasCorrect =
                                prediction.forecast == assertion.finalAnswer;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  // Profile photo
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: prediction
                                                .photoUrl.isNotEmpty
                                            ? NetworkImage(prediction.photoUrl)
                                            : null,
                                        backgroundColor: Colors.blueGrey[600],
                                        child: prediction.photoUrl.isEmpty
                                            ? Text(
                                                prediction
                                                        .displayName.isNotEmpty
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
                                      // Accuracy indicator
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: wasCorrect
                                                ? Colors.green
                                                : Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Icon(
                                            wasCorrect
                                                ? Icons.check
                                                : Icons.close,
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),

                                  // Name and prediction
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              prediction.displayName,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                                decoration: wasCorrect
                                                    ? TextDecoration.none
                                                    : TextDecoration
                                                        .lineThrough,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              wasCorrect
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              color: wasCorrect
                                                  ? Colors.green[300]
                                                  : Colors.red[300],
                                              size: 16,
                                            ),
                                          ],
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
                                      color: wasCorrect
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: wasCorrect
                                            ? Colors.green.withOpacity(0.5)
                                            : Colors.red.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${(prediction.confidence * 100).toInt()}%',
                                      style: TextStyle(
                                        color: wasCorrect
                                            ? Colors.green[300]
                                            : Colors.red[300],
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

                Padding(
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVotesDialog(BuildContext context) {
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
                // Header with title
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Current Votes',
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

                // Voting status section
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[700]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange[700]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.how_to_vote,
                        color: Colors.orange[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Voting in progress',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white24),

                // Vote counts summary
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      // Count for "Happened"
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${assertion.votes.where((vote) => vote.vote).length}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Happened',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Count for "Didn't Happen"
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${assertion.votes.where((vote) => !vote.vote).length}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Didn\'t Happen',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white24),

                // User votes section
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        assertion.votes.isEmpty ? 'No Votes Yet' : 'All Votes',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                assertion.votes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No one has voted yet',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: assertion.votes.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: Colors.white12),
                          itemBuilder: (context, index) {
                            final vote = assertion.votes[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  // Profile photo
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: vote.photoUrl.isNotEmpty
                                        ? NetworkImage(vote.photoUrl)
                                        : null,
                                    backgroundColor: Colors.blueGrey[600],
                                    child: vote.photoUrl.isEmpty
                                        ? Text(
                                            vote.displayName.isNotEmpty
                                                ? vote.displayName[0]
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

                                  // Name
                                  Expanded(
                                    child: Text(
                                      vote.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Vote
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: vote.vote
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: vote.vote
                                            ? Colors.green
                                            : Colors.red,
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      vote.vote
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          vote.vote ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                Padding(
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoteOption(BuildContext context, bool isHappened,
      bool? selectedVote, Function(bool) onSelect) {
    final isSelected = selectedVote == isHappened;

    return InkWell(
      onTap: () => onSelect(isHappened),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isHappened
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2))
              : Colors.blueGrey[700],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isHappened ? Colors.green : Colors.red)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isHappened ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: isHappened ? Colors.green : Colors.red,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              isHappened ? 'HAPPENED' : 'NOPE...',
              style: TextStyle(
                color: isHappened ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
