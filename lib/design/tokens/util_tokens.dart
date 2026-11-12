import 'package:flutter/material.dart';
import 'design_colors.dart';

abstract final class UtilTokens {
  static const Color pinBody = DesignColors.statusAttention;
  static const Color pinDot = DesignColors.surface;
  static const Color pinShadow = DesignColors.shadowBase;
  static const double pinShadowAlpha = 0.22;

  static const Color toastSurface = DesignColors.card;
  static const Color toastBorder = DesignColors.divider;
  static const Color toastTitle = DesignColors.textStrong;
  static const Color toastSubtitle = DesignColors.textSecondary;
  static const Color toastSuccess = DesignColors.success;
  static const Color toastError = DesignColors.error;
  static const Color toastWarning = DesignColors.warning;
  static const Color toastInfo = DesignColors.primary;

  static const Color notifApproved = DesignColors.success;
  static const Color notifRejected = DesignColors.error;
  static const Color notifTakedown = DesignColors.statusAttention;
  static const Color notifOther = DesignColors.textSecondary;

  static const Color mapButtonSurface = DesignColors.surface;
  static const Color fieldIcon = DesignColors.primaryLight;
  static const Color fieldLabel = DesignColors.textPrimary;
  static const Color fieldBorder = DesignColors.divider;
}

class DesignHex {
  DesignHex._();

  static String of(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
