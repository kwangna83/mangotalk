## Context

MangoTalk은 Flutter Web을 GitHub Pages에 배포하고 Flutter 클라이언트가 Supabase Auth·PostgreSQL·Realtime에 직접 연결한다. 현재 앱이 열려 있을 때는 Realtime으로 새 메시지를 받지만 백그라운드 또는 종료 상태의 사용자에게 알리는 경로가 없다.

Firebase Web 앱과 공개 VAPID 키는 준비되었다. Firebase 서버 자격증명은 아직 저장소에 없으며 Supabase secret으로만 등록해야 한다. 개발 PC는 Windows이므로 Web과 Android는 현재 환경에서 검증할 수 있지만 iOS capability와 실제 기기 검증은 macOS/Xcode 및 Apple Developer 설정이 필요하다.

## Goals / Non-Goals

**Goals:**

- Web에서 권한 요청, FCM 토큰 등록, 백그라운드 알림과 알림 클릭 라우팅을 제공한다.
- 발신자 제외, 사용자별 복수 설치, 토큰 갱신과 만료 정리를 지원한다.
- Flutter의 동일한 알림 repository가 Android와 iOS로 확장될 수 있게 한다.
- 메시지 INSERT에서 안전하고 관찰 가능한 서버 발송 경로를 제공한다.
- 서비스 계정 private key와 Supabase 고권한 키가 클라이언트와 Git에 포함되지 않게 한다.

**Non-Goals:**

- 마케팅·예약·관리자 공지 알림
- 알림 빈도 설정, 방별 음소거, 방해 금지 시간
- iOS App Store 서명과 실제 기기 배포 완료
- 메시지 본문 종단간 암호화

## Decisions

### 사용자 승인 게이트를 변경과 배포에 각각 적용

모든 코드·설정·데이터베이스·문서 변경 전에 수정 범위와 영향을 사용자에게 설명하고 명시적 승인을 받는다. 수정 완료 후에는 검증 결과를 먼저 보고하며, 커밋·push·Edge Function 배포·SQL 원격 적용·GitHub Pages 배포를 포함한 외부 상태 변경 전에 별도의 배포 승인을 다시 받는다. 수정 승인은 배포 승인으로 확장 해석하지 않는다.

### FCM을 공통 전송 계층으로 사용

Flutter 공식 플러그인인 `firebase_core`와 `firebase_messaging`을 사용한다. Web에서는 VAPID와 service worker, Android에서는 FCM 네이티브 전달, iOS에서는 FCM의 APNs 연동을 사용한다. 플랫폼별 Web Push와 APNs를 직접 구현하는 대안보다 Flutter 코드와 서버 발송 API를 공유하기 쉽다.

### 공개 Firebase 설정은 빌드 설정, 서버 자격증명은 Supabase secret

Web Firebase config와 VAPID public key는 클라이언트 식별용 공개 값으로 빌드 환경에 주입한다. 서비스 계정 JSON의 client email과 private key 등 서버 자격증명은 Supabase Edge Function secret으로만 저장한다. GitHub Actions에는 private key를 넣지 않는다.

### 사용자별 복수 설치 테이블

`push_subscriptions` 테이블에 `id`, `user_id`, `installation_id`, `platform`, `token`, `enabled`, `last_seen_at`, `created_at`, `updated_at`을 둔다. `(user_id, installation_id)`과 `token`을 고유하게 유지한다. 사용자는 자신의 행만 insert/update/delete할 수 있고 조회는 본인과 서버 역할로 제한한다.

설치 식별자는 앱 로컬 저장소에서 생성한 UUID를 사용한다. FCM 토큰 자체를 설치 ID로 사용하면 토큰 갱신 시 기존 행을 안정적으로 대체하기 어렵기 때문이다.

### 메시지 INSERT webhook에서 Edge Function 호출

Supabase Database Webhook이 `messages` INSERT를 `send-message-push` Edge Function에 전달한다. Function은 service role로 방 참여자와 활성 토큰을 조회하되 `sender_id`를 제외하고 FCM HTTP v1 API로 발송한다. Flutter 클라이언트가 직접 발송하면 다른 사용자의 토큰 노출과 임의 알림 발송을 막기 어려워 채택하지 않는다.

### OAuth 서비스 계정 토큰을 Function에서 생성

Edge Function은 Supabase secret에 저장된 Firebase project ID, client email, private key로 짧은 수명의 OAuth access token을 만들고 FCM HTTP v1 API를 호출한다. 장기 private key는 응답이나 로그에 기록하지 않는다.

### 포그라운드는 인앱 Realtime, 백그라운드는 시스템 알림

Web service worker는 백그라운드 메시지를 표시하고 `notificationclick`에서 `/mangotalk/?room=<id>`를 연다. 포그라운드에서는 현재 방 여부를 판단해 이미 Realtime으로 보이는 메시지에 중복 시스템 알림을 만들지 않는다.

### 멱등 발송 기록

`push_deliveries`에 `(message_id, subscription_id)` 고유 제약과 상태를 기록한다. webhook 재시도 시 기존 성공 건은 건너뛰고, 영구적인 invalid-token 응답은 구독을 비활성화한다.

## Risks / Trade-offs

- [사용자가 알림 권한을 거부하면 시스템 알림을 보낼 수 없음] → 채팅은 정상 유지하고 설정에서 재활성화하는 안내를 제공한다.
- [브라우저와 iOS가 백그라운드 전달을 제한할 수 있음] → 전달을 보장으로 표현하지 않고 FCM 응답과 발송 상태를 기록한다.
- [익명 계정은 앱 데이터 삭제 후 복구할 수 없음] → 토큰은 현재 auth user에만 연결하고 로그아웃 및 invalid-token 시 정리한다.
- [메시지 미리보기가 잠금 화면에 노출될 수 있음] → MVP는 짧은 미리보기를 기본으로 하되 후속 변경에서 내용 숨김 설정을 추가한다.
- [Free 플랜 Edge Function·egress 한도 사용] → 발신자 제외, 활성 토큰 필터링, 일괄 FCM 호출과 사용량 모니터링을 적용한다.
- [서비스 계정 private key 유출] → Supabase secret에만 저장하고 노출 시 Firebase에서 즉시 폐기·교체한다.

## Migration Plan

1. Firebase 공개 Web 설정을 로컬 및 GitHub Pages 빌드 환경에 추가한다.
2. `push_subscriptions`와 `push_deliveries` migration 및 RLS를 적용한다.
3. Flutter 알림 repository, 권한 UI, 토큰 등록과 로그아웃 정리를 구현한다.
4. Web service worker와 알림 클릭 라우팅을 구현한다.
5. 사용자가 Firebase 서비스 계정 JSON을 생성하고 값들을 Supabase secret으로 등록한다.
6. Edge Function을 배포하고 메시지 INSERT webhook을 연결한다.
7. 두 브라우저 사용자로 발신자 제외, 백그라운드 수신, 클릭 라우팅과 만료 토큰 처리를 검증한다.
8. 검증 후 Android 설정을 추가하고, macOS 준비 시 APNs와 iOS capability를 연결한다.

롤백 시 Database Webhook을 먼저 비활성화하고 Edge Function과 클라이언트 알림 UI를 비활성화한다. 토큰 테이블은 개인정보 삭제 정책에 따라 제거할 수 있으며 기존 채팅 기능에는 영향을 주지 않는다.

## Open Questions

- 잠금 화면에서 메시지 본문을 기본 표시할지 발신자만 표시할지 향후 사용자 설정으로 제공해야 한다.
- 공용방 외 다중 채팅방이 활성화될 때 방별 음소거와 알림 빈도 정책을 별도 변경으로 정의해야 한다.
- iOS 구현 시 APNs 키와 Firebase 프로젝트 연결 및 실제 기기 테스트 일정을 정해야 한다.
