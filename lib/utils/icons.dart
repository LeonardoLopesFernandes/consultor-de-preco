import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ícones convertidos de VectorDrawable (assets/icons/*.svg).
class AppIcons {
  static const String arrowBack = 'assets/icons/ic_arrow_back.svg';
  static const String camera = 'assets/icons/ic_camera.svg';
  static const String cameraWhite = 'assets/icons/ic_camera_white.svg';
  static const String delete = 'assets/icons/ic_delete.svg';
  static const String exit = 'assets/icons/ic_exit.svg';
  static const String favorite = 'assets/icons/ic_favorite.svg';
  static const String favoriteBorder = 'assets/icons/ic_favorite_border.svg';
  static const String flashOff = 'assets/icons/ic_flash_off.svg';
  static const String flashOn = 'assets/icons/ic_flash_on.svg';
  static const String float = 'assets/icons/ic_float.svg';
  static const String floatOff = 'assets/icons/ic_float_off.svg';
  static const String history = 'assets/icons/ic_history.svg';
  static const String home = 'assets/icons/ic_home.svg';
  static const String imageSearch = 'assets/icons/ic_image_search.svg';
  static const String menu = 'assets/icons/ic_menu.svg';
  static const String mic = 'assets/icons/ic_mic.svg';
  static const String openLink = 'assets/icons/ic_open_link.svg';
  static const String productPlaceholder = 'assets/icons/ic_product_placeholder.svg';
  static const String search = 'assets/icons/ic_search.svg';
  static const String searchText = 'assets/icons/ic_search_text.svg';
  static const String share = 'assets/icons/ic_share.svg';
  static const String theme = 'assets/icons/ic_theme.svg';
  static const String zoom = 'assets/icons/ic_zoom.svg';

  static Widget asset(
    String path, {
    double size = 24,
    Color? color,
    BoxFit fit = BoxFit.contain,
  }) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      fit: fit,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcIn : BlendMode.srcIn,
    );
  }
}
