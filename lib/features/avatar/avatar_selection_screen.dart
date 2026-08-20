import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'avatar_controller.dart';
import 'avatar_data.dart';

/// Screen for selecting and customizing avatar
class AvatarSelectionScreen extends ConsumerStatefulWidget {
  const AvatarSelectionScreen({super.key});

  @override
  ConsumerState<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends ConsumerState<AvatarSelectionScreen> {
  AvatarGender? _selectedGender;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(avatarConfigProvider);
    final filteredAvatars = _selectedGender != null
        ? AvatarPresets.byGender(_selectedGender!)
        : AvatarPresets.allHumans;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Choose Your Avatar'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Gender filter
          _buildGenderFilter(),

          // Preview area
          _buildPreview(config),

          // Avatar grid
          Expanded(
            child: _buildAvatarGrid(filteredAvatars, config),
          ),

          // Animation toggles
          _buildAnimationToggles(config),
        ],
      ),
    );
  }

  Widget _buildGenderFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GenderChip(
            label: 'All',
            isSelected: _selectedGender == null,
            onTap: () => setState(() => _selectedGender = null),
          ),
          const SizedBox(width: 8),
          _GenderChip(
            label: 'Female',
            icon: Icons.female,
            color: Colors.pink,
            isSelected: _selectedGender == AvatarGender.female,
            onTap: () => setState(() => _selectedGender = AvatarGender.female),
          ),
          const SizedBox(width: 8),
          _GenderChip(
            label: 'Male',
            icon: Icons.male,
            color: Colors.blue,
            isSelected: _selectedGender == AvatarGender.male,
            onTap: () => setState(() => _selectedGender = AvatarGender.male),
          ),
          const SizedBox(width: 8),
          _GenderChip(
            label: 'Neutral',
            icon: Icons.person,
            color: Colors.purple,
            isSelected: _selectedGender == AvatarGender.neutral,
            onTap: () => setState(() => _selectedGender = AvatarGender.neutral),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(AvatarConfig config) {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Avatar preview
          _AvatarPreview(character: config.character),

          // Expression indicator
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                config.character.displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarGrid(List<AvatarCharacter> avatars, AvatarConfig currentConfig) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = currentConfig.character == avatar;

        return _AvatarCard(
          character: avatar,
          isSelected: isSelected,
          onTap: () {
            ref.read(avatarConfigProvider.notifier).selectCharacter(avatar);
          },
        );
      },
    );
  }

  Widget _buildAnimationToggles(AvatarConfig config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animation Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _ToggleTile(
            icon: Icons.record_voice_over,
            label: 'Lip Sync',
            value: config.enableLipSync,
            onChanged: (v) => ref.read(avatarConfigProvider.notifier).toggleLipSync(v),
          ),
          _ToggleTile(
            icon: Icons.visibility,
            label: 'Eye Blinking',
            value: config.enableBlinking,
            onChanged: (v) => ref.read(avatarConfigProvider.notifier).toggleBlinking(v),
          ),
          _ToggleTile(
            icon: Icons.air,
            label: 'Breathing Animation',
            value: config.enableBreathing,
            onChanged: (v) => ref.read(avatarConfigProvider.notifier).toggleBreathing(v),
          ),
        ],
      ),
    );
  }
}

/// Gender selection chip
class _GenderChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    this.icon,
    this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? (color ?? AppColors.primary) : AppColors.surface,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: isSelected ? Colors.white : color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar preview widget
class _AvatarPreview extends StatelessWidget {
  final AvatarCharacter character;

  const _AvatarPreview({required this.character});

  @override
  Widget build(BuildContext context) {
    // For now, use a placeholder gradient avatar
    // In production, this would load actual 3D models or Lottie animations
    return Hero(
      tag: 'avatar_${character.name}',
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              character.gender.color.withValues(alpha: 0.8),
              character.gender.color.withValues(alpha: 0.4),
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: character.gender.color,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: character.gender.color.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            character.gender.icon,
            size: 60,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Avatar selection card
class _AvatarCard extends StatelessWidget {
  final AvatarCharacter character;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarCard({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.surface : AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? character.gender.color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      character.gender.color.withValues(alpha: 0.8),
                      character.gender.color.withValues(alpha: 0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  character.gender.icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              // Name
              Text(
                character.displayName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // Description
              Text(
                character.description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Selected indicator
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: character.gender.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Selected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle tile for animation settings
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(
        label,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
