import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/pet.dart';

/// A circle with the pet's initial, coloured by the pet's place in the list.
class PetAvatar extends StatelessWidget {
  const PetAvatar({
    required this.pet,
    required this.index,
    required this.size,
    required this.fontSize,
    super.key,
  });

  final Pet pet;

  /// The pet's place in the household's list, which picks its colours.
  final int index;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context).avatar(index);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.fill, shape: BoxShape.circle),
      child: Text(
        pet.name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: colors.initial),
      ),
    );
  }
}
