## Why

사용자가 MangoTalk을 열어 두지 않은 동안 새 메시지를 놓치지 않도록 Web Push 알림을 제공한다. 현재의 Flutter Web·Supabase 구조에서 시작하되 Android와 iOS로 같은 알림 흐름을 확장할 수 있어야 한다.

## What Changes

- 사용자가 명시적으로 알림 권한을 요청하고 브라우저 또는 기기의 FCM 등록 토큰을 계정에 연결할 수 있게 한다.
- 새 메시지가 저장되면 발신자를 제외한 대상 참여자에게 백그라운드 푸시 알림을 보낸다.
- 알림에 발신자 닉네임과 메시지 미리보기를 표시하고 선택하면 대상 채팅방을 연다.
- 토큰 갱신, 권한 거부, 로그아웃 및 만료 토큰 정리를 처리한다.
- Firebase Cloud Messaging과 Supabase Database Webhook·Edge Function을 사용해 알림을 전달한다.
- Firebase 서버 자격증명은 Supabase secret으로만 관리하고 저장소나 Flutter 번들에 포함하지 않는다.
- Web을 우선 지원하고 Android와 iOS가 같은 토큰·라우팅 모델을 재사용할 수 있게 한다.

## Capabilities

### New Capabilities

- `push-notifications`: 알림 권한, 기기 토큰 등록, 새 메시지 알림 전달, 발신자 제외, 알림 선택 라우팅 및 토큰 수명주기를 정의한다.

### Modified Capabilities

- 없음.

## Impact

- Flutter 앱에 Firebase 초기화와 Messaging 의존성 및 알림 상태 계층이 추가된다.
- Web 배포물에 Firebase Messaging service worker와 공개 Firebase/VAPID 빌드 설정이 추가된다.
- Supabase에 사용자별 복수 기기 토큰 테이블, RLS, 알림 발송 Edge Function과 메시지 INSERT webhook이 추가된다.
- GitHub Pages 배포 워크플로에 공개 Firebase Web 설정 주입이 추가된다.
- iOS 실기기 배포에는 Apple Push Notifications capability, APNs 키, macOS/Xcode 설정이 추가로 필요하다.
