// VIBRO Listening Page — Real-time voice detection status
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum ListeningState { idle, listening, paused, error }

class ListeningPage extends StatefulWidget {
  const ListeningPage({super.key});

  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage> {
  ListeningState _state = ListeningState.idle;

  void _toggleListening() {
    setState(() {
      if (_state == ListeningState.listening) {
        _state = ListeningState.paused;
      } else {
        _state = ListeningState.listening;
      }
    });
  }

  String get _statusLabel {
    switch (_state) {
      case ListeningState.idle:
        return 'Ready';
      case ListeningState.listening:
        return 'Listening';
      case ListeningState.paused:
        return 'Paused';
      case ListeningState.error:
        return 'Error';
    }
  }

  Color get _statusColor {
    switch (_state) {
      case ListeningState.idle:
        return AppColors.textSecondary;
      case ListeningState.listening:
        return AppColors.success;
      case ListeningState.paused:
        return AppColors.warning;
      case ListeningState.error:
        return AppColors.error;
    }
  }

  IconData get _statusIcon {
    switch (_state) {
      case ListeningState.idle:
        return Icons.mic_off_rounded;
      case ListeningState.listening:
        return Icons.mic_rounded;
      case ListeningState.paused:
        return Icons.pause_rounded;
      case ListeningState.error:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Listening',
          style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status circle
              GestureDetector(
                onTap: _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: _state == ListeningState.listening
                        ? AppColors.primaryNavy
                        : AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _state == ListeningState.listening
                          ? AppColors.primaryNavy
                          : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _statusIcon,
                      size: 48,
                      color: _state == ListeningState.listening
                          ? AppColors.white
                          : AppColors.primaryNavy,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Status label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel,
                    style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(
                      fontSize: 18,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                _state == ListeningState.listening
                    ? 'Detecting voices in real-time'
                    : 'Tap to start listening',
                style: AppTypography.bodyMedium(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 40),

              // Device Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('ESP32', 'Not Connected', AppColors.error),
                    const Divider(color: AppColors.divider, height: 24),
                    _buildInfoRow('Microphone', 'Available', AppColors.success),
                    const Divider(color: AppColors.divider, height: 24),
                    _buildInfoRow('Model', 'Default', AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
