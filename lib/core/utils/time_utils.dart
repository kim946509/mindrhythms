// === 시간 관련 유틸리티 함수들 ===
class TimeUtils {
  // 시간 문자열을 DateTime으로 변환
  static DateTime? parseTimeString(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // 현재 시간이 주어진 시간 문자열과 일치하는지 확인 (±30분 허용)
  static bool isCurrentTime(String timeString, {int toleranceMinutes = 30}) {
    final targetTime = parseTimeString(timeString);
    if (targetTime == null) return false;
    
    final now = DateTime.now();
    final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    
    final difference = currentTime.difference(targetTime).inMinutes.abs();
    return difference <= toleranceMinutes;
  }
  
  // 시간 문자열을 사용자 친화적 형태로 변환
  static String formatTimeDisplay(String timeString) {
    final time = parseTimeString(timeString);
    if (time == null) return timeString;
    
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    
    if (hour < 12) {
      return '오전 $hour:$minute';
    } else if (hour == 12) {
      return '오후 12:$minute';
    } else {
      return '오후 ${hour - 12}:$minute';
    }
  }
  
  // 가장 가까운 시간 찾기
  static String? findNearestTime(List<String> times) {
    if (times.isEmpty) return null;
    
    final now = DateTime.now();
    String? nearest;
    int minDifference = double.maxFinite.toInt();
    
    for (final timeString in times) {
      final targetTime = parseTimeString(timeString);
      if (targetTime != null) {
        final difference = now.difference(targetTime).inMinutes.abs();
        if (difference < minDifference) {
          minDifference = difference;
          nearest = timeString;
        }
      }
    }
    
    return nearest;
  }
  
  // 시간 목록을 시간순으로 정렬
  static List<String> sortTimeStrings(List<String> times) {
    final timesWithDateTime = times
        .map((timeString) => {
              'original': timeString,
              'dateTime': parseTimeString(timeString),
            })
        .where((item) => item['dateTime'] != null)
        .toList();
    
    timesWithDateTime.sort((a, b) {
      final timeA = a['dateTime'] as DateTime;
      final timeB = b['dateTime'] as DateTime;
      return timeA.compareTo(timeB);
    });
    
    return timesWithDateTime
        .map((item) => item['original'] as String)
        .toList();
  }
  
  // 현재 시간 이후의 시간들만 필터링
  static List<String> getUpcomingTimes(List<String> times) {
    final now = DateTime.now();
    
    return times.where((timeString) {
      final targetTime = parseTimeString(timeString);
      return targetTime != null && targetTime.isAfter(now);
    }).toList();
  }
  
  // 시간 문자열이 유효한지 검증
  static bool isValidTimeString(String timeString) {
    return parseTimeString(timeString) != null;
  }
} 