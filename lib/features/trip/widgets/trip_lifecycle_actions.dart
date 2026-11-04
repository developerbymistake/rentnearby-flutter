import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/dio_error_mapper.dart';
import '../controllers/trip_plan_controller.dart';
import '../data/trip_repository.dart';
import '../data/trip_today_cache.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';

class TripLifecycleActions {
  static const _repo = TripRepository();
  static bool _busy = false;

  static Future<bool> markComplete(BuildContext context) async {
    final c = TripPlanController.to;
    final id = c.trip.value?.id;
    if (id == null) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          TripStrings.markCompleteQ,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: const Text(TripStrings.markCompleteBody, style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(TripStrings.cancelAction,
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TripColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStrings.markComplete, style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (ok != true || _busy) return false;
    _busy = true;
    try {
      final result = await _repo.complete(id);
      c.trip.value = result;
      TripTodayCache.saveTrip(result);
      AppToast.success(TripStrings.tripCompleted);
      return true;
    } catch (e) {
      if (DioErrorMapper.errorType(e) == TripErrorTypes.tripNotEnded) {
        AppToast.error(TripStrings.tripNotEnded);
      } else if (DioErrorMapper.isNetworkError(e)) {
        AppToast.error(TripStrings.noNetwork);
      } else {
        AppToast.error(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad));
      }
      return false;
    } finally {
      _busy = false;
    }
  }

  static Future<bool> toggleMute(BuildContext context) async {
    final c = TripPlanController.to;
    final trip = c.trip.value;
    if (trip == null || _busy) return false;
    _busy = true;
    try {
      final result = await _repo.mute(trip.id, muted: !trip.isMuted);
      c.trip.value = result;
      TripTodayCache.saveTrip(result);
      AppToast.success(result.isMuted ? TripStrings.remindersMuted : TripStrings.remindersOn);
      return true;
    } catch (e) {
      AppToast.error(DioErrorMapper.isNetworkError(e)
          ? TripStrings.noNetwork
          : DioErrorMapper.toMessage(e, TripStrings.couldNotLoad));
      return false;
    } finally {
      _busy = false;
    }
  }

  static Future<void>? openSummary(String tripId) => TripNavigation.openSummary(tripId);
}
