# mindrhythms

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## **최종 정리된 폴더 구조**

```
lib/
├── core/                                     # 🎯 모든 추상화의 중심
│   ├── base/
│   │   ├── base_controller.dart              # 컨트롤러 기본 추상 클래스
│   │   ├── base_component.dart               # 컴포넌트 기본 추상 클래스
│   │   ├── base_model.dart                   # 상속구조 모델 기본 클래스
│   │   └── base_service.dart                 # 서비스 기본 추상 클래스
│   │
│   ├── abstractions/                         # 🔑 핵심 인터페이스들
│   │   ├── api_repository.dart               # API 통신 핵심 인터페이스
│   │   ├── storage_repository.dart           # 로컬 저장소 핵심 인터페이스
│   │   ├── screen_navigation.dart            # 화면 전환 핵심 인터페이스
│   │   └── component_renderer.dart           # 컴포넌트 렌더링 핵심 인터페이스
│   │
│   ├── constants/
│   │   ├── app_screens.dart                  # 6개 화면 타입
│   │   ├── component_types.dart              # header, body, footer
│   │   ├── survey_types.dart                 # 설문 관련 상수
│   │   └── api_endpoints.dart                # API 엔드포인트
│   │
│   └── utils/                                # 🛠️ 실제 비즈니스 로직
│       ├── screen_resolver.dart              # 상속구조 데이터 → 화면 결정
│       ├── component_factory.dart            # 실행 중 데이터 → 컴포넌트 생성
│       ├── data_parser.dart                  # 서버 데이터 파싱
│       └── survey_validator.dart             # 설문 유효성 검사
│
├── models/
│   └── app_data_model.dart                   # 📦 상속구조 통합 모델 (4개 인터페이스 모두 포함)
│
├── controllers/
│   └── app_controller.dart                   # 🎮 공통화된 메인 컨트롤러 (모든 상태 관리)
│
├── views/
│   ├── app_view.dart                         # 📱 메인 앱 뷰
│   │
│   ├── components/                           # 🧩 6개 화면 × 3개 영역 = 18개 컴포넌트
│   │   ├── headers/                          # splash, login, survey_list, survey_status, survey_before, survey_start
│   │   ├── bodies/                           # splash, login, survey_list, survey_status, survey_before, survey_start
│   │   ├── footers/                          # splash, login, survey_list, survey_status, survey_before, survey_start
│   │   └── common/                           # loading, error, question, layout_wrapper
│   │
│   └── services/                             # 🔧 core abstractions 상속받은 구현체들
│       ├── api_service.dart                  # API 통신 구현체
│       ├── storage_service.dart              # 로컬 저장소 구현체
│       └── survey_service.dart               # 설문 관련 서비스 구현체
│
└── main.dart
```

## **핵심 변경사항**

### **1. Mixin 제거** ✅
- 작은 프로젝트에 불필요한 복잡성 제거
- 단순하고 명확한 상속 구조로 변경

### **2. Controller 공통화** ✅
- `app_controller.dart` 하나로 모든 상태 관리
- `survey_controller.dart` 제거하여 단순화

### **3. Model 상속구조 통합** ✅
- 개별 모델들 (`login_model.dart`, `notification_model.dart` 등) 제거
- `app_data_model.dart` 하나로 4개 인터페이스 모두 포함하는 상속구조

### **4. Core Abstractions 중심** ✅
- 모든 구현체가 `core/abstractions/` 인터페이스를 상속받아 동작
- `core/base/` 추상 클래스들이 기본 구조 제공
- `core/utils/`에서 실제 비즈니스 로직 처리

### **5. 실행 중 동적 변경 지원** ✅
- `component_factory.dart`: 데이터 값 기준으로 컴포넌트 동적 생성
- `screen_resolver.dart`: 상속구조 데이터 분석으로 화면 자동 결정
- `base_component.dart`: 실행 중 값 기준으로 컴포넌트 변경 지원

## **동작 원리**

1. **Core가 모든 것을 관리**: `abstractions/`가 핵심 인터페이스 정의
2. **상속구조 데이터 모델**: 하나의 모델이 4개 인터페이스 상속구조 지원
3. **공통화된 컨트롤러**: 하나의 컨트롤러가 모든 상태 관리
4. **동적 컴포넌트**: 실행 중 데이터 값으로 적절한 컴포넌트 선택
5. **단순한 구조**: 과도한 추상화 없이 필요한 만큼만 구조화

이제 훨씬 깔끔하고 관리하기 쉬운 구조가 되었습니다! 🎉
