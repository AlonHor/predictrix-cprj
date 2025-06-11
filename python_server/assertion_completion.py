from db_utils import DbUtils
from queries import GetChatMembersQuery
import json
import math
import datetime
from typing import Any


def calculate_score(confidence: float, forecast: bool, final_answer: bool) -> int:
    """
    Calculate score based on prediction accuracy.

    Formula: (abs(0.5 - confidence) * multiplier * is_correct ? 1 : -1) + multiplier / 2
    """
    multiplier = 1000
    is_correct = forecast == final_answer
    score = (abs(0.5 - confidence) * multiplier *
             (1 if is_correct else -1)) + multiplier // 2
    return int(score)


def check_and_complete_assertion(assertion_data: dict[str, Any]) -> bool:
    """
    Check if assertion should be completed and complete it if necessary.
    Returns True if assertion was completed, False otherwise.
    """
    try:
        chat_id = str(assertion_data.get("ChatId", ""))
        completed = bool(assertion_data.get("Completed", 0))

        # If already completed, nothing to do
        if completed:
            return True

        # Check if we're past validation date
        validation_date: datetime.datetime | None = assertion_data.get(
            "ValidationDate", "")
        if not validation_date:
            return False

        if validation_date.tzinfo is None:
            validation_date = validation_date.replace(
                tzinfo=datetime.timezone.utc)

        try:
            now = datetime.datetime.now(datetime.timezone.utc)
            if now <= validation_date:
                return False  # Not yet time to validate
        except ValueError:
            return False

        # Get chat members count
        members = GetChatMembersQuery().execute(chat_id)
        member_count = len(members)
        majority_threshold = math.ceil(member_count / 2)

        # Parse votes
        votes_json = assertion_data.get("Votes", "{}")
        if isinstance(votes_json, str):
            try:
                votes = json.loads(votes_json)
            except:
                votes = {}
        else:
            votes = votes_json or {}

        # Count votes
        yes_votes = sum(1 for vote in votes.values() if vote)
        no_votes = sum(1 for vote in votes.values() if not vote)

        # Check for clear majority
        final_answer = None
        if yes_votes >= majority_threshold:
            final_answer = True
        elif no_votes >= majority_threshold:
            final_answer = False
        else:
            return False  # No clear majority yet

        # Complete the assertion
        return complete_assertion(assertion_data["Id"], chat_id, final_answer)

    except Exception as e:
        print(f"Error checking assertion completion: {e}")
        return False


def complete_assertion(assertion_id: str, chat_id: str, final_answer: bool) -> bool:
    """
    Complete an assertion and update user stats.
    """
    try:
        # Get predictions data
        pred_row = DbUtils(
            "SELECT Predictions FROM Assertions WHERE Id = %s",
            (assertion_id,)
        ).execute_single()

        if not pred_row:
            return False

        pred_data: dict[str, Any] = dict(pred_row)  # type: ignore
        predictions_json = pred_data.get("Predictions", "{}")

        if isinstance(predictions_json, str):
            try:
                predictions = json.loads(predictions_json)
            except:
                predictions = {}
        else:
            predictions = predictions_json or {}

        # Get current chat stats
        stats_row = DbUtils(
            "SELECT ScoreSumPerUser, PredictionsPerUser FROM Chats WHERE Id = %s",
            (chat_id,)
        ).execute_single()

        if not stats_row:
            return False

        stats_data: dict[str, Any] = dict(stats_row)  # type: ignore

        # Parse current stats
        scores_json = stats_data.get("ScoreSumPerUser", "{}")
        preds_json = stats_data.get("PredictionsPerUser", "{}")

        try:
            score_sums = json.loads(str(scores_json)) if scores_json else {}
            pred_counts = json.loads(str(preds_json)) if preds_json else {}
        except:
            score_sums = {}
            pred_counts = {}

        # Update stats for each user who predicted
        for user_id, prediction in predictions.items():
            if isinstance(prediction, dict):
                confidence = prediction.get("confidence", 0.5)
                forecast = prediction.get("forecast", False)

                # Calculate score
                score = calculate_score(confidence, forecast, final_answer)

                # Update user stats
                current_score = score_sums.get(user_id, 0)
                current_preds = pred_counts.get(user_id, 0)

                score_sums[user_id] = current_score + score
                pred_counts[user_id] = current_preds + 1

        # Update database
        success1 = DbUtils(
            "UPDATE Chats SET ScoreSumPerUser = %s, PredictionsPerUser = %s WHERE Id = %s",
            (json.dumps(score_sums), json.dumps(pred_counts), chat_id)
        ).execute_update()

        success2 = DbUtils(
            "UPDATE Assertions SET Completed = 1, FinalAnswer = %s WHERE Id = %s",
            (1 if final_answer else 0, assertion_id)
        ).execute_update()

        return success1 and success2

    except Exception as e:
        print(f"Error completing assertion: {e}")
        return False
