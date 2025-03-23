// lib/widgets/adaptive_profile_card.dart

import 'package:flutter/material.dart';
import '../models/player.dart';
import '../config/app_config.dart';

class AdaptiveProfileCard extends StatelessWidget {
  final Player profile;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectMode;

  const AdaptiveProfileCard({
    Key? key,
    required this.profile,
    required this.isSelected,
    this.onTap,
    this.onLongPress,
    this.isSelectMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Otteniamo le dimensioni effettive dello spazio disponibile
    final size = MediaQuery.of(context).size;
    final availableWidth = size.width;

    // Calcoliamo le dimensioni in base allo spazio disponibile
    final isCompact = availableWidth < 360;
    final isMedium = availableWidth < 600;

    // Calcoliamo le dimensioni dell'avatar in modo dinamico
    final avatarSize = isCompact ? 20.0 : (isMedium ? 25.0 : 30.0);
    final fontSize = isCompact ? 12.0 : (isMedium ? 14.0 : AppConfig.title);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Otteniamo le dimensioni effettive della card
        final cardWidth = constraints.maxWidth;
        final cardHeight = constraints.maxHeight;

        // Adattiamo il contenuto in base allo spazio disponibile
        final bool showExtendedInfo = cardHeight > 120 && !isCompact;

        return Card(
          elevation: isSelected ? 8 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? Colors.yellow : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Contenuto principale centrato
                Center(  // Aggiungi un Center qui per forzare il centraggio
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 4 : 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,  // Importante!
                      children: [
                        // Avatar
                        Hero(
                          tag: 'profile_avatar_${profile.id}',
                          child: CircleAvatar(
                            radius: avatarSize,
                            backgroundColor: Colors.blue.shade800,
                            child: Text(
                              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '',
                              style: TextStyle(
                                fontSize: avatarSize * 0.8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 2 : 4),
                        // Nome
                        Center(  // Aggiungi un altro Center qui specificamente per il testo
                          child: Text(
                            isCompact ? profile.name[0].toUpperCase() : profile.name,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'OpenDyslexic',
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        // Altre informazioni se necessario...
                      ],
                    ),
                  ),
                ),

                // Checkbox per la selezione
                if (isSelectMode)
                  Positioned(
                    right: isCompact ? 2 : 4,
                    top: isCompact ? 2 : 4,
                    child: Container(
                      width: avatarSize * 0.8,
                      height: avatarSize * 0.8,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.yellow : Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.check : Icons.check_box_outline_blank,
                        color: isSelected ? Colors.black : Colors.grey,
                        size: avatarSize * 0.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}