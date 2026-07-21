## 1. Flutter 프로젝트 기반

- [x] 1.1 Git 저장소를 초기화하고 기본 브랜치를 main으로 설정한 뒤 https://github.com/kwangna83/mangotalk.git을 origin으로 등록한다
- [x] 1.2 Flutter 빌드 산출물, 환경 설정, Supabase 비밀키, Apple 서명 파일 및 API private key를 제외하는 .gitignore를 작성한다
- [x] 1.3 현재 저장소에 iOS와 Android를 포함한 Flutter 애플리케이션을 생성하고 기본 실행을 확인한다
- [x] 1.4 supabase_flutter, Riverpod 및 UUID 생성 의존성을 추가하고 앱의 feature/core 디렉터리 구조를 만든다
- [x] 1.5 Supabase URL과 publishable key를 빌드 환경에서 주입하고 누락 시 안전하게 실패하는 설정 계층을 구현한다
- [x] 1.6 presentation, domain, data 계층과 인증·채팅 repository 인터페이스를 정의한다

## 2. Supabase 데이터베이스와 보안

- [x] 2.1 Supabase Free 플랜으로 `mangotalk-dev` 프로젝트를 만들고 익명 인증과 Flutter 접속 정보를 준비한다
- [x] 2.2 `profiles`, `chat_rooms`, `room_members`, `messages` 테이블과 외래키·길이 제약을 생성하는 SQL migration을 작성한다
- [x] 2.3 메시지 cursor 조회 인덱스와 `(sender_id, client_message_id)` 고유 제약을 추가한다
- [x] 2.4 단일 공용 채팅방을 생성하는 seed migration을 작성한다
- [x] 2.5 모든 공개 테이블에 RLS를 활성화하고 본인 프로필 및 공용방 참여 정책을 구현한다
- [x] 2.6 참여자만 메시지를 조회·전송하고 `sender_id = auth.uid()`를 강제하는 RLS 정책을 구현한다
- [ ] 2.7 인증·비인증·타인 위조 요청에 대한 RLS 허용 및 거부 통합 테스트를 작성한다

## 3. 익명 사용자 접근

- [x] 3.1 익명 세션 생성, 세션 복원 및 로그아웃을 제공하는 Supabase 인증 repository를 구현한다
- [x] 3.2 닉네임 정리·길이 검증과 본인 프로필 생성·조회 로직을 구현한다
- [x] 3.3 앱 시작 시 세션 상태에 따라 닉네임 화면 또는 채팅 화면으로 이동하는 상태 흐름을 구현한다
- [x] 3.4 닉네임 입력 화면에 로딩, 유효성 오류, 네트워크 실패 및 재시도 상태를 구현한다
- [ ] 3.5 세션 복원, 만료 처리 및 프로필 생성 실패에 대한 단위·위젯 테스트를 작성한다

## 4. 채팅 데이터 계층

- [x] 4.1 채팅방, 참여자, 메시지 및 로컬 전송 상태 domain 모델을 구현한다
- [x] 4.2 인증 사용자의 공용방 참여 기록을 멱등하게 생성하는 repository 동작을 구현한다
- [x] 4.3 최근 메시지와 이전 메시지를 50개 단위 cursor로 조회하는 repository 동작을 구현한다
- [x] 4.4 클라이언트 메시지 ID로 텍스트 메시지를 멱등 전송하는 repository 동작을 구현한다
- [x] 4.5 Realtime insert 구독, 메시지 ID 기반 중복 제거 및 정렬을 구현한다
- [x] 4.6 연결 복구 후 마지막 확인 cursor 이후 메시지를 조회하는 누락 보완 동작을 구현한다
- [ ] 4.7 pagination, 중복 전송 방지, 실시간 중복 병합 및 재연결 catch-up 단위 테스트를 작성한다

## 5. 채팅 사용자 인터페이스

- [ ] 5.1 Material 3, Mango·Leaf·Purple 의미 색상, 타이포그래피, 간격, radius와 모션 duration 디자인 토큰을 구현한다
- [x] 5.2 Mango 곡선형 헤더, 공용방 제목, 사용자 아바타와 콘텐츠를 방해하지 않는 장식 요소를 구현한다
- [x] 5.3 채팅 화면에 초기 로딩, 빈 상태, 최근 메시지 목록과 발신자 닉네임을 표시한다
- [ ] 5.4 수신·발신 메시지 버블, 시간과 전송 상태를 Material 3 Expressive 스타일로 구현한다
- [x] 5.5 위로 스크롤할 때 이전 메시지를 불러오고 기존 스크롤 위치를 유지한다
- [x] 5.6 1자 이상 2,000자 이하 메시지만 전송 가능한 capsule 입력창과 강조된 전송 버튼을 구현한다
- [x] 5.7 메시지별 전송 중·성공·실패 표시와 동일 클라이언트 메시지 ID를 사용하는 재시도 UI를 구현한다
- [x] 5.8 새 메시지 실시간 반영과 사용자의 현재 스크롤 위치를 고려한 자동 스크롤 동작을 구현한다
- [ ] 5.9 180~280ms 메시지 모션과 Reduce Motion 대체 동작을 구현한다
- [ ] 5.10 Dynamic Type, screen reader 레이블, 최소 터치 영역과 색상 대비를 검증한다
- [ ] 5.11 채팅 내역·전송·실패·재시도·이전 내역·접근성 흐름의 위젯 테스트를 작성한다

## 6. 검증과 iOS 준비

- [ ] 6.1 두 사용자 세션으로 실시간 송수신, 재연결 복구 및 중복 방지를 통합 검증한다
- [ ] 6.2 앱 재실행 시 익명 세션과 기존 메시지가 복원되는지 iOS 시뮬레이터에서 검증한다
- [ ] 6.3 Dart 포맷, 정적 분석, 단위·위젯·통합 테스트를 실행하고 오류를 해결한다
- [ ] 6.4 iOS debug 빌드를 생성하고 Supabase 설정 및 실행 절차를 README에 문서화한다
## 7. GitHub와 TestFlight 배포

- [x] 7.1 Git 상태와 추적 파일을 검토하고 환경 비밀값·인증서·private key가 커밋 대상에 없는지 검사한다
- [x] 7.2 OpenSpec 산출물, Flutter 코드, Supabase migration 및 README를 의미 있는 단위로 커밋한다
- [x] 7.3 origin이 https://github.com/kwangna83/mangotalk.git인지 확인하고 main 브랜치를 push한다
- [ ] 7.4 Apple Developer Program과 App Store Connect에 앱 ID, 앱 레코드 및 iOS 서명 설정을 준비한다
- [ ] 7.5 macOS와 Xcode에서 버전·빌드 번호를 설정하고 배포용 iOS archive를 App Store Connect에 업로드한다
- [ ] 7.6 TestFlight 베타 설명, 피드백 이메일, 테스트 항목 및 심사 정보를 작성한다
- [ ] 7.7 첫 외부 테스트 빌드의 Beta App Review를 요청하고 승인 상태를 확인한다
- [ ] 7.8 이메일 또는 공개 링크로 테스터를 초대하고 실제 기기 설치와 Supabase 연결을 검증한다
- [ ] 7.9 TestFlight 빌드의 90일 만료와 후속 빌드 업로드 절차를 README에 문서화한다
## 8. Supabase Free 운영

- [ ] 8.1 TestFlight 배포 전에 두 번째 Free 프로젝트 `mangotalk-testflight`를 만들고 검증된 migration을 적용한다
- [ ] 8.2 개발용과 TestFlight용 Supabase URL·publishable key를 분리하여 Git에 포함되지 않는 환경 설정으로 관리한다
- [ ] 8.3 Free 플랜의 DB, Storage, egress, Realtime, Edge Function 및 비활성 정지 한도를 README에 문서화한다
- [ ] 8.4 schema 변경과 TestFlight 배포 전 DB 수동 export 및 복구 절차를 작성하고 한 번 검증한다
- [ ] 8.5 Supabase Dashboard에서 사용량을 정기 점검하고 Free 한도의 80% 도달 여부를 기록한다
- [ ] 8.6 비활성 정지를 허용할 수 없거나 자동 백업·상시 운영이 필요해질 때 Pro로 전환하는 판단 기준을 검토한다


