import 'package:equatable/equatable.dart';

/// Модель статистики для дашборда
class DashboardStats extends Equatable {
  final double totalRevenue;
  final double monthlyRevenue;
  final int inventoryCount;
  final int activeOrdersCount;
  final String period;

  const DashboardStats({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.inventoryCount,
    required this.activeOrdersCount,
    required this.period,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0.0,
      inventoryCount: (json['inventoryCount'] as int?) ?? 0,
      activeOrdersCount: (json['activeOrdersCount'] as int?) ?? 0,
      period: json['period'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRevenue': totalRevenue,
      'monthlyRevenue': monthlyRevenue,
      'inventoryCount': inventoryCount,
      'activeOrdersCount': activeOrdersCount,
      'period': period,
    };
  }

  /// Пустая статистика (когда нет данных)
  factory DashboardStats.empty() {
    return DashboardStats(
      totalRevenue: 0.0,
      monthlyRevenue: 0.0,
      inventoryCount: 0,
      activeOrdersCount: 0,
      period: DateTime.now().toString().substring(0, 7), // YYYY-MM
    );
  }

  @override
  List<Object?> get props => [
        totalRevenue,
        monthlyRevenue,
        inventoryCount,
        activeOrdersCount,
        period,
      ];
}

/// Модель данных графика продаж
class SalesChartData extends Equatable {
  final String period;
  final List<SalesDataPoint> data;

  const SalesChartData({
    required this.period,
    required this.data,
  });

  factory SalesChartData.fromJson(Map<String, dynamic> json) {
    return SalesChartData(
      period: json['period'] as String? ?? '7d',
      data: (json['data'] as List?)
              ?.map((e) => SalesDataPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }

  /// Пустой график
  factory SalesChartData.empty() {
    return const SalesChartData(
      period: '7d',
      data: [],
    );
  }

  @override
  List<Object?> get props => [period, data];
}

/// Точка данных для графика
class SalesDataPoint extends Equatable {
  final String date;
  final double amount;

  const SalesDataPoint({
    required this.date,
    required this.amount,
  });

  factory SalesDataPoint.fromJson(Map<String, dynamic> json) {
    return SalesDataPoint(
      date: json['date'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'amount': amount,
    };
  }

  @override
  List<Object?> get props => [date, amount];
}

/// Модель популярного товара
class PopularItem extends Equatable {
  final int id;
  final String name;
  final int soldCount;
  final String? imageUrl;
  final double price;

  const PopularItem({
    required this.id,
    required this.name,
    required this.soldCount,
    this.imageUrl,
    required this.price,
  });

  factory PopularItem.fromJson(Map<String, dynamic> json) {
    return PopularItem(
      id: json['id'] as int,
      name: json['name'] as String,
      soldCount: json['soldCount'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'soldCount': soldCount,
      'imageUrl': imageUrl,
      'price': price,
    };
  }

  @override
  List<Object?> get props => [id, name, soldCount, imageUrl, price];
}

