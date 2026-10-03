// Backend şemalarıyla eşleşen veri modelleri.

const kCategories = [
  'Yemek',
  'Ulaşım',
  'Faturalar',
  'Eğlence',
  'Sağlık',
  'Eğitim',
  'Alışveriş',
  'Diğer',
];

class TransactionModel {
  final int id;
  final double amount;
  final String type; // income | expense
  final String category;
  final bool autoCategorized;
  final bool isRecurring;
  final String note;
  final String occurredOn;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.autoCategorized,
    required this.isRecurring,
    required this.note,
    required this.occurredOn,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> j) => TransactionModel(
        id: j['id'],
        amount: (j['amount'] as num).toDouble(),
        type: j['type'],
        category: j['category'],
        autoCategorized: j['auto_categorized'] ?? false,
        isRecurring: j['is_recurring'] ?? false,
        note: j['note'] ?? '',
        occurredOn: j['occurred_on'] ?? '',
      );
}

/// Ana sayfa özeti (backend /transactions/summary). Tutarlar TL.
class SummaryModel {
  final double balance;
  final double totalIncome;
  final double totalExpense;
  final double monthExpense;
  final List<({String category, double total})> monthByCategory;

  SummaryModel({
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
    required this.monthExpense,
    required this.monthByCategory,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> j) => SummaryModel(
        balance: (j['balance'] as num).toDouble(),
        totalIncome: (j['total_income'] as num).toDouble(),
        totalExpense: (j['total_expense'] as num).toDouble(),
        monthExpense: (j['month_expense'] as num).toDouble(),
        monthByCategory: (j['month_by_category'] as List)
            .map((e) => (
                  category: e['category'] as String,
                  total: (e['total'] as num).toDouble()
                ))
            .toList(),
      );
}

class BudgetModel {
  final int id;
  final String category;
  final double monthlyLimit;
  final double spent;

  BudgetModel({
    required this.id,
    required this.category,
    required this.monthlyLimit,
    required this.spent,
  });

  double get ratio => monthlyLimit == 0 ? 0 : (spent / monthlyLimit);

  factory BudgetModel.fromJson(Map<String, dynamic> j) => BudgetModel(
        id: j['id'],
        category: j['category'],
        monthlyLimit: (j['monthly_limit'] as num).toDouble(),
        spent: (j['spent'] as num?)?.toDouble() ?? 0,
      );
}

class CategorySuggestion {
  final String category;
  final double confidence;
  final String model;
  CategorySuggestion(this.category, this.confidence, this.model);

  factory CategorySuggestion.fromJson(Map<String, dynamic> j) =>
      CategorySuggestion(
          j['category'], (j['confidence'] as num).toDouble(), j['model']);
}

class ForecastModel {
  final double currentMonthSpent;
  final double projectedMonthEnd;
  final double nextMonthPrediction;
  final String method; // trend | last_month | run_rate
  final String velocity; // Yüksek | Normal | Düşük
  final List<({String month, double total})> history;

  ForecastModel({
    required this.currentMonthSpent,
    required this.projectedMonthEnd,
    required this.nextMonthPrediction,
    required this.method,
    required this.velocity,
    required this.history,
  });

  factory ForecastModel.fromJson(Map<String, dynamic> j) => ForecastModel(
        currentMonthSpent: (j['current_month_spent'] as num).toDouble(),
        projectedMonthEnd: (j['projected_month_end'] as num).toDouble(),
        nextMonthPrediction: (j['next_month_prediction'] as num).toDouble(),
        method: j['method'],
        velocity: j['velocity'],
        history: (j['history'] as List)
            .map((e) => (
                  month: e['month'] as String,
                  total: (e['total'] as num).toDouble()
                ))
            .toList(),
      );
}

class GoalModel {
  final int id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String? deadline;
  final double progress; // 0..1

  GoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.progress,
  });

  double get remaining => (targetAmount - currentAmount).clamp(0, targetAmount);

  factory GoalModel.fromJson(Map<String, dynamic> j) => GoalModel(
        id: j['id'],
        title: j['title'],
        targetAmount: (j['target_amount'] as num).toDouble(),
        currentAmount: (j['current_amount'] as num).toDouble(),
        deadline: j['deadline'],
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
      );
}

class InsightModel {
  final String icon;
  final String tone; // good | warn | neutral
  final String title;
  final String text;

  InsightModel({
    required this.icon,
    required this.tone,
    required this.title,
    required this.text,
  });

  factory InsightModel.fromJson(Map<String, dynamic> j) => InsightModel(
        icon: j['icon'] ?? 'info',
        tone: j['tone'] ?? 'neutral',
        title: j['title'] ?? '',
        text: j['text'] ?? '',
      );
}

class AnomalyModel {
  final double amount;
  final String category;
  final String note;
  final String occurredOn;
  final String severity; // high | medium
  final String reason;

  AnomalyModel({
    required this.amount,
    required this.category,
    required this.note,
    required this.occurredOn,
    required this.severity,
    required this.reason,
  });

  factory AnomalyModel.fromJson(Map<String, dynamic> j) => AnomalyModel(
        amount: (j['amount'] as num).toDouble(),
        category: j['category'],
        note: j['note'] ?? '',
        occurredOn: j['occurred_on'] ?? '',
        severity: j['severity'] ?? 'medium',
        reason: j['reason'] ?? '',
      );
}
