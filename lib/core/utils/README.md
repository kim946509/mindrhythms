# Utils 폴더

## 파일 구성

### `time_utils.dart` - 시간 관리 유틸리티
서버에서 받은 동적 시간 값들을 처리하는 유틸리티 클래스

#### 주요 기능들
- **parseTimeString()**: 시간 문자열 → DateTime 변환
- **isCurrentTime()**: 현재 시간과 비교 (허용 오차 ±30분)
- **formatTimeDisplay()**: 사용자 친화적 시간 표시 (오전/오후)
- **findNearestTime()**: 가장 가까운 시간 찾기
- **sortTimeStrings()**: 시간 목록 정렬
- **getUpcomingTimes()**: 현재 시간 이후 시간들만 필터링
- **isValidTimeString()**: 시간 문자열 유효성 검증

#### 사용 예시
```dart
import '../utils/time_utils.dart';

// 시간 변환 및 검증
TimeUtils.parseTimeString("14:30");           // DateTime 객체
TimeUtils.isValidTimeString("25:70");         // false

// 현재 시간과 비교
TimeUtils.isCurrentTime("14:30");             // 현재 시간이 14:00~15:00 사이면 true
TimeUtils.isCurrentTime("14:30", toleranceMinutes: 15); // ±15분 허용

// 사용자 친화적 표시
TimeUtils.formatTimeDisplay("14:30");         // "오후 2:30"
TimeUtils.formatTimeDisplay("09:15");         // "오전 9:15"

// 시간 목록 처리
final times = ["21:00", "09:30", "14:15"];
TimeUtils.sortTimeStrings(times);             // ["09:30", "14:15", "21:00"]
TimeUtils.findNearestTime(times);             // 가장 가까운 시간
TimeUtils.getUpcomingTimes(times);            // 현재 시간 이후 시간들
```

## 설계 원칙

1. **순수 함수**: 부작용 없는 static 메서드들
2. **에러 처리**: null 반환 및 안전한 타입 변환
3. **확장성**: 새로운 시간 관련 기능을 쉽게 추가 가능
4. **성능**: 효율적인 시간 비교 및 정렬 알고리즘 