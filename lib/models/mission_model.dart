enum MissionPeriod {
  daily('Harian'),
  weekly('Mingguan'),
  monthly('Bulanan'),
  oneTime('Sekali Saja');

  final String label;
  const MissionPeriod(this.label);
}

enum MissionTrigger {
  addTransaction,
  saveTarget,
  completeModule,
  passQuiz,
  createTarget,
}

class MissionItem {
  final String id;
  final String title;
  final String description;
  final MissionPeriod period;
  final MissionTrigger trigger;
  final int targetCount;
  final int xpReward;

  const MissionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.period,
    required this.trigger,
    required this.targetCount,
    required this.xpReward,
  });
}

enum MissionClaimStatus {
  inProgress,
  claimable,
  claimed,
}
