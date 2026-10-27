String money(double v) => '₱${v.toStringAsFixed(2)}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// '2026-12-05' -> '5 Dec'
String shortDate(String ymd) => '${int.parse(ymd.substring(8, 10))} ${_months[int.parse(ymd.substring(5, 7)) - 1]}';

/// '2026-12' -> 'Dec 2026'
String monthLabel(String ym) => '${_months[int.parse(ym.substring(5, 7)) - 1]} ${ym.substring(0, 4)}';
