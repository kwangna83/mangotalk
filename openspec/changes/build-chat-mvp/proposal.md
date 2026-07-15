## Why

사용자가 iOS에서 간단한 실시간 텍스트 대화를 주고받을 수 있는 첫 번째 제품 단위를 만든다. Flutter와 Supabase를 사용해 빠르게 검증하되, 이후 Android, 영구 계정, 1:1·그룹 채팅 및 파일 전송으로 확장할 수 있는 기반을 마련한다.

## What Changes

- Flutter 기반 모바일 앱에서 닉네임을 입력하고 익명 사용자 세션을 시작할 수 있게 한다.
- 모든 사용자가 참여하는 단일 공용 채팅방을 제공한다.
- 텍스트 메시지를 전송하고 Supabase PostgreSQL에 영구 저장한다.
- 새 메시지를 Supabase Realtime으로 실시간 수신한다.
- 채팅방 진입 시 이전 메시지를 페이지 단위로 조회한다.
- 전송 중, 전송 실패, 재시도 상태를 사용자에게 표시한다.
- Mango Orange·Leaf Green·Purple을 사용하는 Material 3 Expressive Community 디자인을 적용한다.
- 메시지 및 사용자 데이터 접근을 Supabase Auth와 Row Level Security 정책으로 제한한다.
- 초기 개발과 소규모 TestFlight 운영은 Supabase Free 플랜으로 시작하고 사용량과 운영 제약을 모니터링한다.
- 소스 코드와 OpenSpec 산출물을 GitHub kwangna83/mangotalk 저장소에서 버전 관리한다.
- 정식 App Store 출시 전 TestFlight를 통해 iOS 베타 빌드를 배포한다.
- 이미지·파일 전송, 푸시 알림, 읽음 상태, 입력 중 표시, 메시지 수정·삭제, 다중 채팅방은 이번 변경에서 제외한다.

## Capabilities

### New Capabilities

- `anonymous-user-access`: 닉네임을 가진 익명 사용자의 세션 생성, 복원 및 기본 프로필 식별을 정의한다.
- `public-chat-messaging`: 단일 공용 채팅방의 메시지 내역 조회, 텍스트 전송, 실시간 수신 및 오류 상태를 정의한다.

### Modified Capabilities

- 없음.

## Impact

- 신규 Flutter 애플리케이션과 iOS 실행 구성이 추가된다.
- 공통 Material 3 테마, 디자인 토큰, 표현적인 채팅 컴포넌트와 접근성 검증이 추가된다.
- Flutter 앱은 `supabase_flutter`를 통해 Supabase Auth, Database 및 Realtime에 연결된다.
- Supabase에 프로필, 채팅방, 참여자 및 메시지 테이블과 관련 인덱스·RLS 정책이 추가된다.
- Free 플랜의 비활성 프로젝트 정지, 용량·Realtime 한도 및 자동 백업 부재에 대한 운영 절차와 Pro 전환 기준이 추가된다.
- GitHub 원격 저장소 https://github.com/kwangna83/mangotalk.git와 main 브랜치를 기준 소스 저장소로 사용한다.
- TestFlight 배포를 위해 Apple Developer Program, App Store Connect 앱 레코드 및 iOS 서명 설정이 필요하다.
- 향후 Android 빌드는 동일한 Flutter 도메인 및 데이터 계층을 재사용한다.
