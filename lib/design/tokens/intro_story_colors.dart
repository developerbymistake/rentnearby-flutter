import 'package:flutter/painting.dart';

class IntroSkyPalette {
  const IntroSkyPalette(this.t, this.b, this.h1, this.h1b, this.h2, this.h2b, this.g, this.r);

  final Color t, b, h1, h1b, h2, h2b, g, r;
}

abstract final class IntroStoryColors {
  static const List<IntroSkyPalette> palettes = [
    IntroSkyPalette(Color(0xFFFDE3C8), Color(0xFFC9C3F5), Color(0xFF9A92E0), Color(0xFFC9C3F5), Color(0xFF7471D6), Color(0xFF9A92E0), Color(0xFF58A06C), Color(0xFF4A5072)),
    IntroSkyPalette(Color(0xFF8ED0F7), Color(0xFFE6F6FF), Color(0xFFA5CDB8), Color(0xFFD8EEE2), Color(0xFF72B08D), Color(0xFFA5CDB8), Color(0xFF4C9A63), Color(0xFF3B4058)),
    IntroSkyPalette(Color(0xFF6FC3F5), Color(0xFFFFEBC9), Color(0xFF9CC7AE), Color(0xFFE3EFD9), Color(0xFF6AAF86), Color(0xFF9CC7AE), Color(0xFF4A9A5E), Color(0xFF3E4560)),
    IntroSkyPalette(Color(0xFFFF9E6B), Color(0xFFFFD9A8), Color(0xFFD39A86), Color(0xFFF3C5A8), Color(0xFFB06784), Color(0xFFD39A86), Color(0xFF7C8F5A), Color(0xFF46435A)),
    IntroSkyPalette(Color(0xFF0E1330), Color(0xFF3A3F9E), Color(0xFF2F3482), Color(0xFF4A50B0), Color(0xFF232868), Color(0xFF2F3482), Color(0xFF1E5A48), Color(0xFF242840)),
  ];

  static const Color white = Color(0xFFFFFFFF);
  static const Color clear = Color(0x00FFFFFF);
  static const Color clearBlack = Color(0x00000000);
  static const Color white25 = Color(0x40FFFFFF);
  static const Color white28 = Color(0x47FFFFFF);
  static const Color white35 = Color(0x59FFFFFF);
  static const Color white45 = Color(0x73FFFFFF);
  static const Color white60 = Color(0x99FFFFFF);
  static const Color white62 = Color(0x9EFFFFFF);
  static const Color white85 = Color(0xD9FFFFFF);

  static const Color shadow18 = Color(0x2E000000);
  static const Color shadow20 = Color(0x33000000);
  static const Color shadow22 = Color(0x38000000);
  static const Color shadow25 = Color(0x40000000);
  static const Color shadow28 = Color(0x47000000);
  static const Color shadow30 = Color(0x4D000000);
  static const Color shadow32 = Color(0x52000000);

  static const Color curb = Color(0xFFD5D8E2);

  static const Color sunCore = Color(0xFFFFF6D0);
  static const Color sunMid = Color(0xFFFFD98A);
  static const Color sunEdge = Color(0x00FFC878);
  static const Color sunGlow = Color(0xFFFFD68C);
  static const Color moonCore = Color(0xFFFFFFFF);
  static const Color moonMid = Color(0xFFDCE3FF);
  static const Color moonEdge = Color(0xFF9FAAF0);
  static const Color moonGlow = Color(0xFFB4BEFF);

  static const List<Color> sunGlowColors = [Color(0x73FFD68C), Color(0x73FFD68C), Color(0x73FFD68C), Color(0x60FFD68C), Color(0x4DFFD68C), Color(0x38FFD68C), Color(0x27FFD68C), Color(0x18FFD68C), Color(0x0AFFD68C), Color(0x04FFD68C), Color(0x00FFD68C)];
  static const List<double> sunGlowStops = [0, .2857, .2857, .361, .436, .511, .586, .662, .774, .887, 1];
  static const double sunGlowRadius = 133;
  static const List<Color> moonGlowColors = [Color(0x4FB4BEFF), Color(0x4FB4BEFF), Color(0x4FB4BEFF), Color(0x39B4BEFF), Color(0x23B4BEFF), Color(0x12B4BEFF), Color(0x08B4BEFF), Color(0x03B4BEFF), Color(0x00B4BEFF)];
  static const List<double> moonGlowStops = [0, .388, .388, .490, .592, .694, .796, .898, 1];
  static const double moonGlowRadius = 98;

  static const Color signPole = Color(0xFF6A7289);
  static const Color signBoard = Color(0xFFFFC83A);

  static const Color mountainLitTop = Color(0xFFC9A98F);
  static const Color mountainLitBottom = Color(0xFF8F6E5E);
  static const Color mountainShadeTop = Color(0xFF7A5C6E);
  static const Color mountainShadeBottom = Color(0xFF4F3F5C);
  static const Color mountainRidge35 = Color(0x5946323C);
  static const Color mountainRidge25 = Color(0x4046323C);
  static const Color snowShade = Color(0xFFCFE0F2);
  static const Color pine = Color(0xFF2F7A4C);
  static const Color mountainNight = Color(0xFF0E1330);
  static const Color mountainBaseLeft = Color(0xFF4A9A5E);
  static const Color mountainBaseRight = Color(0xFF3F8F55);
  static const Color trail = Color(0xF2FFF6DC);

  static const Color riverTop = Color(0xFF8BCDF3);
  static const Color riverBottom = Color(0xFF4F8FDC);
  static const Color riverBank = Color(0xFF5FA66C);
  static const Color riverShade = Color(0x591F5E8C);
  static const Color lake = Color(0xFF5D8BE0);

  static const Color fireCore = Color(0xF2FFB05A);
  static const Color fireEdge = Color(0x00FF8A3C);
  static const Color warmCore = Color(0xE6FFD98A);
  static const Color warmEdge = Color(0x00FFD98A);
  static const Color flameBottom = Color(0xFFFF7A1C);
  static const Color flameTop = Color(0xFFFFC24A);
  static const Color flameInner = Color(0xFFFFE27A);
  static const Color stone = Color(0xFF8C8C96);
  static const Color logDark = Color(0xFF5A3A22);
  static const Color logLight = Color(0xFF76502F);
  static const Color spark = Color(0xFFFFD25A);

  static const Color beamCore = Color(0xCCFFF3B0);
  static const Color beamEdge = Color(0x00FFF3B0);
  static const Color puff = Color(0xFFE7DFD2);
  static const Color hub = Color(0xFFD9CFEA);
  static const Color hubDot = Color(0xFF6A5A92);
  static const Color glass20 = Color(0x337EC8F2);

  static const Color footPanda = Color(0xFF3D3763);
  static const Color footFox = Color(0xFFC25B1E);
  static const Color footLion = Color(0xFF8A5A2B);

  static const List<Color> canopy = [Color(0xFFFF5A5F), Color(0xFFFFD25A), Color(0xFF3FA7FF), Color(0xFFFFFFFF), Color(0xFF7B61FF), Color(0xFFFF8A3C)];
  static const Color domeLight = Color(0x73FFFFFF);
  static const Color domeDark = Color(0x2E000000);
  static const Color canopyLine = Color(0x8C28283C);

  static const Color selfieArm = Color(0xFF4B4472);
  static const Color selfieStick = Color(0xFF3A3F55);
  static const Color selfieGrip = Color(0xFF1F2333);
  static const Color phoneBody = Color(0xFF23283C);
  static const Color phoneScreen = Color(0xFF8FD0F7);
  static const Color phoneLens = Color(0xFF6B7390);

  static const List<Color> confetti = [Color(0xFFFF6B6B), Color(0xFFFFD25A), Color(0xFF5C5EDD), Color(0xFF4CC38A)];

  static const Color wood = Color(0xFFB9855A);
  static const Color woodLeg = Color(0xFF8A5F3C);
  static const Color woodLegBack = Color(0xFF7A5236);
  static const Color tableGrassDeep = Color(0xFF2B6A44);
  static const Color landTop = Color(0xFFD6EBC8);
  static const Color landBottom = Color(0xFFBEDFB0);
  static const Color park = Color(0xFFA5D89A);
  static const Color water = Color(0xFF8EC9F0);
  static const Color block = Color(0xFFEFE3CF);
  static const Color mapLine35 = Color(0x5978A06E);
  static const Color route = Color(0xFF5C5EDD);
}
