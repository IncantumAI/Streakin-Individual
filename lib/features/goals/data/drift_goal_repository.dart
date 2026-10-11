import 'package:streakin/core/time/local_date.dart';
import 'package:streakin/features/goals/data/goal_dao.dart';
import 'package:streakin/features/goals/domain/goal.dart';
import 'package:streakin/features/goals/domain/goal_repository.dart';

class DriftGoalRepository implements GoalRepository {
  DriftGoalRepository(this._dao);
  final GoalDao _dao;

  @override
  Stream<Goal?> watchActive() => _dao.watchActive();

  @override
  Future<Goal?> getActive() => _dao.getActive();

  @override
  Future<Goal?> getById(String id) => _dao.getById(id);

  @override
  Future<List<Goal>> getArchived({int limit = 20, int offset = 0}) =>
      _dao.getArchived(limit: limit, offset: offset);

  @override
  Future<void> saveGoal(Goal goal) => _dao.saveGoal(goal);

  @override
  Future<void> saveGoalHabitLink(GoalHabitLink link) =>
      _dao.saveGoalHabitLink(link);

  @override
  Future<List<GoalHabitLink>> getLinksForGoal(String goalId) =>
      _dao.getLinksForGoal(goalId);

  @override
  Future<void> saveGoalSummary(GoalSummary summary) =>
      _dao.saveGoalSummary(summary);

  @override
  Future<GoalSummary?> getSummary(String goalId) => _dao.getSummary(goalId);

  @override
  Future<GoalLocalState?> getLocalState(String goalId) =>
      _dao.getLocalState(goalId);

  @override
  Future<void> saveLocalState(GoalLocalState state) =>
      _dao.saveLocalState(state);

  @override
  Future<void> setHeroPromptDismissed(LocalDate until) =>
      _dao.setHeroPromptDismissed(until);

  @override
  Future<LocalDate?> getHeroPromptDismissedUntil() =>
      _dao.getHeroPromptDismissedUntil();
}
