## 0. 필수 사용자 승인 게이트

> 아래 모든 작업은 파일 또는 원격 상태를 변경하기 전에 수정 범위에 대한 사용자의 명시적 승인을 받아야 한다. 수정과 로컬 검증이 끝난 뒤에는 결과를 보고하고, 커밋·push·SQL 적용·Edge Function 또는 GitHub Pages 배포 전에 별도의 명시적 배포 승인을 받아야 한다. 수정 승인은 배포 승인이 아니다.

## 1. Firebase와 Flutter 기반

- [x] 1.1 `firebase_core`, `firebase_messaging`과 설치 ID 저장 의존성을 추가하고 플랫폼별 초기화 계층을 만든다
- [x] 1.2 Firebase Web 공개 설정과 VAPID key를 빌드 환경으로 주입하며 누락 시 알림 기능만 안전하게 비활성화한다
- [x] 1.3 제공된 Firebase Web 앱을 FlutterFire 초기화에 연결하고 공개 설정 외 자격증명이 번들에 없는지 검사한다
- [x] 1.4 알림 권한·토큰·갱신 이벤트를 추상화하는 notification repository 인터페이스와 FCM 구현을 작성한다

## 2. Supabase 구독 데이터와 보안

- [x] 2.1 사용자별 복수 설치를 저장하는 `push_subscriptions` migration과 token·installation 고유 제약을 작성한다
- [x] 2.2 메시지·구독별 멱등 발송 상태를 저장하는 `push_deliveries` migration을 작성한다
- [x] 2.3 사용자가 자신의 구독만 생성·갱신·삭제할 수 있고 다른 사용자 토큰을 읽을 수 없도록 RLS를 구현한다
- [ ] 2.4 본인 허용·타인 거부·비인증 거부 및 고유 제약에 대한 DB 통합 테스트를 작성한다

## 3. 클라이언트 알림 구독

- [x] 3.1 로그인 사용자가 명시적으로 알림 권한을 요청하고 결과 상태를 확인하는 UI를 구현한다
- [x] 3.2 설치 UUID와 FCM 토큰을 현재 사용자에게 멱등 등록하고 앱 시작 시 최신 상태로 동기화한다
- [x] 3.3 FCM token refresh 시 기존 설치 행을 교체하고 로그아웃 시 현재 설치 구독을 비활성화한다
- [ ] 3.4 권한 허용·거부·미지원·토큰 갱신·로그아웃 흐름의 단위 및 위젯 테스트를 작성한다

## 4. Web 백그라운드 알림

- [x] 4.1 `firebase-messaging-sw.js`를 추가하고 GitHub Pages `/mangotalk/` 경로에서 service worker를 등록한다
- [x] 4.2 백그라운드 메시지에 발신자와 미리보기를 표시하고 notification click payload를 앱 URL로 전달한다
- [ ] 4.3 앱 시작·재개 시 알림 payload의 방 ID를 읽고 세션 복원 후 해당 채팅방으로 이동한다
- [x] 4.4 포그라운드에서 현재 채팅방을 보고 있을 때 중복 시스템 알림을 표시하지 않는다
- [ ] 4.5 Chrome에서 권한 허용·거부, 백그라운드·종료 수신과 클릭 라우팅을 통합 검증한다

## 5. 서버 알림 발송

- [x] 5.1 사용자가 Firebase 서비스 계정 JSON을 생성하고 private key·client email·project ID를 Supabase secret으로 등록한다
- [x] 5.2 메시지 webhook payload를 검증하고 발신자를 제외한 방 참여자의 활성 토큰을 조회하는 Edge Function을 구현한다
- [x] 5.3 Firebase 서비스 계정으로 단기 OAuth access token을 생성하고 FCM HTTP v1 API로 알림을 발송한다
- [x] 5.4 `(message_id, subscription_id)` 기준으로 중복 발송을 방지하고 FCM invalid-token 응답 시 구독을 비활성화한다
- [ ] 5.5 Edge Function 단위 테스트와 인증되지 않은 호출·변조 payload 거부 테스트를 작성한다
- [x] 5.6 Edge Function을 `mangotalk-dev`에 배포하고 `messages` INSERT Database Webhook을 연결한다

## 6. 배포와 검증

- [x] 6.1 GitHub Actions Web 빌드에 Firebase 공개 설정과 VAPID key를 secret이 아닌 환경 설정으로 주입한다
- [ ] 6.2 두 익명 사용자와 두 브라우저로 발신자 제외, 다른 사용자 알림, 중복 방지와 만료 토큰 정리를 검증한다
- [ ] 6.3 포맷, 정적 분석, Flutter 테스트, Edge Function 테스트와 release Web 빌드를 실행한다
- [ ] 6.4 알림 설정, 서비스 계정 secret 등록·교체, webhook, 장애 확인과 롤백 절차를 README에 문서화한다
- [ ] 6.5 GitHub Pages에 배포하고 HTTPS service worker·FCM token·백그라운드 알림을 실제 사이트에서 검증한다

## 7. 모바일 확장

- [ ] 7.1 Android Firebase 앱과 `google-services.json`, 알림 권한 및 notification channel을 구성해 실제 기기에서 검증한다
- [ ] 7.2 macOS/Xcode에서 iOS Push Notifications capability와 Background Modes를 활성화한다
- [ ] 7.3 Apple Developer에서 APNs key를 만들고 Firebase에 등록한 뒤 iOS 실제 기기에서 검증한다
- [ ] 7.4 Android·iOS 설정 파일과 APNs private key가 Git 비밀값 정책을 준수하는지 검사한다
