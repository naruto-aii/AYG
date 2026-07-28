import 'package:flutter/material.dart';

import '../../theme/app_breakpoints.dart';

bool isDesktopLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
}

bool isWideSummaryLayout(double maxWidth) {
  return maxWidth >= AppBreakpoints.summaryGrid;
}
