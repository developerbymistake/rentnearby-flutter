import 'package:flutter/widgets.dart';

import '../../expenses/data/expense_write_gateway.dart';

abstract final class PendingRowExtras {
  static Widget? of(BuildContext context, PendingExpense pending) => null;
}
