import 'package:autohub_b2b/models/order_model.dart';

/// Данные для PDF‑счёта / чека (печать через системный диалог, без прямого принтера).
class ReceiptLineData {
  const ReceiptLineData({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

class ReceiptDocumentData {
  const ReceiptDocumentData({
    required this.companyName,
    required this.orderNumber,
    required this.issuedAt,
    required this.lines,
    required this.total,
    this.companySubtitle,
    this.customerName,
    this.paymentInfo,
    this.notes,
    this.vehicleInfo,
    this.statement,
    this.signatures = const [],
    this.currencySymbol = '₸',
    this.logoAssetPath = 'assets/icons/partshub-logo.png',
  });

  final String companyName;
  final String? companySubtitle;
  final String orderNumber;
  final DateTime issuedAt;
  final List<ReceiptLineData> lines;
  final double total;
  final String currencySymbol;
  final String? customerName;
  final String? paymentInfo;
  final String? notes;
  final String? vehicleInfo;

  /// Текст перед подписями: «Работы выполнены в полном объёме…».
  final String? statement;

  /// Подписи внизу документа: «Клиент», «Исполнитель»…
  final List<String> signatures;
  final String logoAssetPath;

  /// Демо‑данные для экрана настроек (iOS).
  static ReceiptDocumentData sample() {
    final now = DateTime.now();
    return ReceiptDocumentData(
      companyName: 'PartsHub Pro',
      companySubtitle: 'Демонстрационный документ',
      orderNumber: 'DEMO-${now.millisecondsSinceEpoch % 100000}',
      issuedAt: now,
      customerName: 'ООО «Пример клиента»',
      paymentInfo: 'Оплата: по счёту',
      lines: const [
        ReceiptLineData(
          name: 'Позиция 1 (пример)',
          quantity: 2,
          unitPrice: 3500,
          lineTotal: 7000,
        ),
        ReceiptLineData(
          name: 'Позиция 2 (пример)',
          quantity: 1,
          unitPrice: 12800,
          lineTotal: 12800,
        ),
      ],
      total: 19800,
      notes: 'Спасибо за заказ!',
    );
  }

  /// Заказ-наряд: работы и запчасти отдельными разделами.
  /// Заказ-наряд: работы и запчасти по заказу автосервиса.
  static ReceiptDocumentData workOrder(OrderModel order, {String? companyName}) =>
      _serviceDocument(order, 'Заказ-наряд', companyName);

  /// Смета до начала работ: клиент подписывает согласие с суммой.
  static ReceiptDocumentData estimate(OrderModel order, {String? companyName}) =>
      _serviceDocument(
        order,
        'Смета',
        companyName,
        statement:
            'Со стоимостью и перечнем работ ознакомлен(а) и согласен(на). '
            'Окончательная сумма может измениться только по согласованию с клиентом.',
        signatures: const ['Клиент', 'Мастер-приёмщик'],
      );

  /// Акт выполненных работ: клиент подтверждает приёмку.
  static ReceiptDocumentData act(OrderModel order, {String? companyName}) =>
      _serviceDocument(
        order,
        'Акт выполненных работ',
        companyName,
        statement:
            'Работы выполнены в полном объёме и в срок. '
            'Автомобиль получен, претензий по объёму и качеству работ не имею.',
        signatures: const ['Клиент', 'Исполнитель'],
      );

  static ReceiptDocumentData _serviceDocument(
    OrderModel order,
    String title,
    String? companyName, {
    String? statement,
    List<String> signatures = const [],
  }) {
    final lines = <ReceiptLineData>[
      ...?order.works?.map(
        (work) => ReceiptLineData(
          name: work.performerName != null
              ? '${work.name} (${work.performerName})'
              : work.name,
          quantity: 1,
          unitPrice: work.subtotal,
          lineTotal: work.subtotal,
        ),
      ),
      ...?order.items?.map((i) {
        final rawName = i.item?['name'] ?? i.item?['title'];
        final name = rawName?.toString().trim();
        return ReceiptLineData(
          name: (name != null && name.isNotEmpty) ? name : 'Товар #${i.itemId}',
          quantity: i.quantity,
          unitPrice: i.priceAtTime,
          lineTotal: i.subtotal,
        );
      }),
    ];

    return ReceiptDocumentData(
      companyName: _company(companyName),
      companySubtitle: title,
      orderNumber: order.orderNumber ?? '#${order.id ?? '—'}',
      issuedAt: order.createdAt,
      customerName: _customerName(order),
      vehicleInfo: _vehicleInfo(order),
      paymentInfo: _paymentLabel(order.paymentStatus),
      notes: order.notes,
      lines: lines,
      total: order.total,
      statement: statement,
      signatures: signatures,
    );
  }

  /// В документе для клиента — название организации, а не платформы.
  static String _company(String? name) =>
      name != null && name.trim().isNotEmpty ? name.trim() : 'PartsHub Pro';

  static String? _vehicleInfo(OrderModel order) {
    final vehicle = order.vehicle;
    if (vehicle == null) return null;
    final brand = vehicle['brand']?.toString() ?? '';
    final model = vehicle['model']?.toString() ?? '';
    final plate = vehicle['plateNumber']?.toString() ?? '';
    final text = '$brand $model ${plate.isNotEmpty ? '· $plate' : ''}'.trim();
    return text.isEmpty ? null : text;
  }

  static String? _customerName(OrderModel order) {
    final cust = order.customer;
    if (cust == null) return null;
    final name =
        cust['name']?.toString() ??
        cust['companyName']?.toString() ??
        cust['title']?.toString();
    return (name != null && name.isNotEmpty) ? name : null;
  }

  static ReceiptDocumentData fromOrder(OrderModel order, {String? companyName}) {
    final items = order.items ?? [];
    final lines = items.map((i) {
      final rawName = i.item?['name'] ?? i.item?['title'];
      final name = rawName?.toString().trim();
      return ReceiptLineData(
        name: (name != null && name.isNotEmpty) ? name : 'Товар #${i.itemId}',
        quantity: i.quantity,
        unitPrice: i.priceAtTime,
        lineTotal: i.subtotal,
      );
    }).toList();

    return ReceiptDocumentData(
      companyName: _company(companyName),
      orderNumber: order.orderNumber ?? '#${order.id ?? '—'}',
      issuedAt: order.createdAt,
      customerName: _customerName(order),
      paymentInfo: _paymentLabel(order.paymentStatus),
      notes: order.notes,
      lines: lines,
      total: order.total,
    );
  }

  static String? _paymentLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Оплачен';
      case 'partially_paid':
        return 'Частичная оплата';
      case 'pending':
        return 'Ожидает оплаты';
      default:
        return status;
    }
  }
}
