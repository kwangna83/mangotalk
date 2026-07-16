# MangoTalk

[현재 시스템 구성도](docs/system-architecture.md)

Flutter와 Supabase로 만드는 간단한 실시간 그룹 채팅 MVP입니다. iOS를 우선 지원하며 Android 프로젝트도 함께 포함합니다.

## 현재 구현

- 익명 로그인과 닉네임 프로필
- 하나의 공용 채팅방
- Supabase Postgres 영구 메시지 저장 및 Realtime 수신
- 50개 단위 cursor 페이지네이션
- 낙관적 전송, 실패 표시와 같은 client message ID 재시도
- Material 3 Expressive Community UI
- profiles/chat_rooms/room_members/messages 스키마와 RLS migration

## Supabase Free 설정

1. Supabase Dashboard에서 `mangotalk-dev` 프로젝트를 생성합니다.
2. Authentication 설정에서 Anonymous Sign-Ins를 활성화합니다.
3. SQL Editor에서 `supabase/migrations/202607150001_initial_chat.sql`을 실행합니다.
4. Project Settings의 API 화면에서 Project URL과 Publishable key를 확인합니다.

Publishable key는 앱에 포함해도 되는 공개 식별 키지만, 데이터 보호는 반드시 RLS 정책으로 수행해야 합니다. `service_role` 키는 앱이나 Git에 절대 넣지 마세요.

## 실행

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

웹에서는 Chrome 실행 또는 정적 배포용 빌드를 사용할 수 있습니다.

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
flutter build web --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

빌드 결과는 `build/web`에 생성됩니다. HTTPS로 배포한 뒤 iPhone Safari의 공유 메뉴에서 **홈 화면에 추가**를 선택하면 standalone 웹 앱으로 실행할 수 있습니다.

로컬 값의 이름은 `.env.example`을 참고하세요. 이 앱은 `.env` 파일을 자동으로 읽지 않으며 빌드 시 `--dart-define`으로 주입합니다. 실제 값이 들어간 파일은 Git에 커밋하지 않습니다.

## 검증

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

현재 Windows에서는 Dart 분석과 테스트를 수행할 수 있습니다. iOS 빌드와 TestFlight 업로드는 macOS, Xcode, Apple Developer Program 계정이 필요합니다.

## 저장 구조

메시지는 기기 내부가 아니라 Supabase Cloud의 Postgres `messages` 테이블에 저장됩니다. 앱 재설치 후에도 같은 익명 세션이 유지된다는 보장은 없으므로, 정식 계정 전환 기능을 추가할 때 기존 익명 사용자를 영구 계정에 연결하는 설계가 필요합니다.

## 환경 분리와 운영

개발은 `mangotalk-dev`, TestFlight는 `mangotalk-testflight`처럼 별도 Supabase 프로젝트를 사용합니다. 각 환경의 URL과 publishable key는 별도 빌드 설정으로 관리합니다. Free 플랜 한도와 비활성 프로젝트 정책은 변경될 수 있으므로 배포 전에 Supabase Dashboard의 Usage와 공식 Pricing 문서를 확인하세요.

스키마 변경 전에는 Dashboard의 database backup/export 절차로 수동 백업을 만들고 복원 가능 여부를 검증합니다. 상시 운영, 자동 백업, 더 높은 사용량 한도가 필요해지면 Pro 전환을 검토합니다.

## GitHub

원격 저장소는 `https://github.com/kwangna83/mangotalk.git`입니다. 커밋 전에 `.env`, 인증서, provisioning profile, `.p8` private key가 추적되지 않는지 반드시 확인합니다.
