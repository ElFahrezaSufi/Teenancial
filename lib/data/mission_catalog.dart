import '../models/mission_model.dart';

class MissionCatalog {
  static const List<MissionItem> all = [
    // Harian
    MissionItem(
      id: 'daily_tx_1',
      title: 'Catat Keuangan Hari Ini',
      description: 'Catat minimal 1 pemasukan atau pengeluaran hari ini.',
      period: MissionPeriod.daily,
      trigger: MissionTrigger.addTransaction,
      targetCount: 1,
      xpReward: 20,
    ),
    MissionItem(
      id: 'daily_save_1',
      title: 'Sisihkan Tabungan',
      description: 'Alokasikan dana ke salah satu target menabung hari ini.',
      period: MissionPeriod.daily,
      trigger: MissionTrigger.saveTarget,
      targetCount: 1,
      xpReward: 25,
    ),
    MissionItem(
      id: 'daily_module_1',
      title: 'Baca Materi Finansial',
      description: 'Selesaikan 1 modul materi di Ruang Belajar hari ini.',
      period: MissionPeriod.daily,
      trigger: MissionTrigger.completeModule,
      targetCount: 1,
      xpReward: 50,
    ),
    MissionItem(
      id: 'daily_quiz_1',
      title: 'Asah Otak Finansial',
      description: 'Lulus 1 kuis di Ruang Belajar hari ini.',
      period: MissionPeriod.daily,
      trigger: MissionTrigger.passQuiz,
      targetCount: 1,
      xpReward: 75,
    ),

    // Mingguan
    MissionItem(
      id: 'weekly_tx_5',
      title: 'Rajin Mencatat',
      description: 'Catat 5 transaksi selama minggu ini.',
      period: MissionPeriod.weekly,
      trigger: MissionTrigger.addTransaction,
      targetCount: 5,
      xpReward: 80,
    ),
    MissionItem(
      id: 'weekly_save_3',
      title: 'Penabung Konsisten',
      description: 'Isi saldo target menabung sebanyak 3 kali minggu ini.',
      period: MissionPeriod.weekly,
      trigger: MissionTrigger.saveTarget,
      targetCount: 3,
      xpReward: 100,
    ),
    MissionItem(
      id: 'weekly_module_2',
      title: 'Belajar Rutin',
      description: 'Selesaikan 2 modul materi di Ruang Belajar minggu ini.',
      period: MissionPeriod.weekly,
      trigger: MissionTrigger.completeModule,
      targetCount: 2,
      xpReward: 120,
    ),

    // Bulanan
    MissionItem(
      id: 'monthly_tx_20',
      title: 'Master Arus Kas',
      description: 'Catat 20 transaksi sepanjang bulan ini.',
      period: MissionPeriod.monthly,
      trigger: MissionTrigger.addTransaction,
      targetCount: 20,
      xpReward: 200,
    ),
    MissionItem(
      id: 'monthly_save_10',
      title: 'Pejuang Target',
      description: 'Isi saldo target menabung sebanyak 10 kali bulan ini.',
      period: MissionPeriod.monthly,
      trigger: MissionTrigger.saveTarget,
      targetCount: 10,
      xpReward: 250,
    ),
    MissionItem(
      id: 'monthly_quiz_3',
      title: 'Cerdas Finansial',
      description: 'Lulus 3 kuis literasi keuangan bulan ini.',
      period: MissionPeriod.monthly,
      trigger: MissionTrigger.passQuiz,
      targetCount: 3,
      xpReward: 300,
    ),

    // Misi Sekali
    MissionItem(
      id: 'onetime_module_1',
      title: 'Langkah Pertama Belajar',
      description: 'Selesaikan modul materi pertamamu di Ruang Belajar.',
      period: MissionPeriod.oneTime,
      trigger: MissionTrigger.completeModule,
      targetCount: 1,
      xpReward: 100,
    ),
    MissionItem(
      id: 'onetime_quiz_1',
      title: 'Lulus Kuis Pertama',
      description: 'Selesaikan dan lulus kuis pertamamu di Ruang Belajar.',
      period: MissionPeriod.oneTime,
      trigger: MissionTrigger.passQuiz,
      targetCount: 1,
      xpReward: 150,
    ),
    MissionItem(
      id: 'onetime_module_3',
      title: 'Pembelajar Tekun',
      description: 'Selesaikan total 3 modul materi di Ruang Belajar.',
      period: MissionPeriod.oneTime,
      trigger: MissionTrigger.completeModule,
      targetCount: 3,
      xpReward: 250,
    ),
    MissionItem(
      id: 'onetime_quiz_3',
      title: 'Ahli Kuis Finansial',
      description: 'Lulus total 3 kuis di Ruang Belajar.',
      period: MissionPeriod.oneTime,
      trigger: MissionTrigger.passQuiz,
      targetCount: 3,
      xpReward: 350,
    ),
  ];

  static List<MissionItem> byPeriod(MissionPeriod period) =>
      all.where((m) => m.period == period).toList();
}
