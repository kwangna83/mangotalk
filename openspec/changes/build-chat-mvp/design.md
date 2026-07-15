## Context

현재 프로젝트에는 애플리케이션 코드나 운영 중인 백엔드가 없다. 첫 릴리스는 iOS에서 단일 공용 채팅방의 실시간 텍스트 대화를 검증하는 것이 목적이며, 동일 Flutter 코드베이스로 Android를 지원하고 이후 영구 계정, 1:1·그룹 채팅과 파일 전송을 추가할 가능성이 있다.

클라이언트는 Flutter, 백엔드는 Supabase Auth·PostgreSQL·Realtime을 사용한다. 모바일 클라이언트는 신뢰할 수 없는 환경으로 취급하며, 권한은 UI가 아니라 PostgreSQL RLS에서 최종 강제한다.

## Goals / Non-Goals

**Goals:**

- 익명 사용자와 닉네임 기반으로 진입 장벽이 낮은 채팅 흐름을 제공한다.
- 메시지를 영구 저장하고 실시간으로 전달하며 재연결 시 누락을 복구한다.
- 1:1·그룹 채팅을 같은 `rooms`/`members`/`messages` 모델로 추가할 수 있게 한다.
- Flutter의 플랫폼 독립적인 도메인·데이터 계층을 iOS와 향후 Android에서 재사용한다.
- 모든 직접 데이터 접근을 Auth와 RLS로 제한한다.

**Non-Goals:**

- 이미지·파일 전송, 푸시 알림, 읽음 상태, 입력 중 표시
- 메시지 수정·삭제, 차단·신고·관리자 도구
- 영구 계정 전환 및 소셜 로그인
- 종단간 암호화와 대규모 트래픽 최적화
- 다중 채팅방 UI와 1:1·그룹방 생성 흐름

## Decisions

### Flutter 단일 코드베이스

UI와 앱 로직은 Flutter로 구현한다. iOS 고유 기능이 핵심 요구사항이 아니며 Android 확장이 예상되므로 SwiftUI와 Kotlin 앱을 별도로 유지하는 비용을 피한다. 네이티브 구현은 플랫폼별 완성도가 최우선일 때 유리하지만 현재 MVP의 속도와 확장 방향에는 맞지 않는다.

### Material 3 Expressive Community 시각 언어

MangoTalk의 시각 방향은 세 후보 중 Material 3 Expressive Community로 확정한다. 활기찬 색, 큰 라운드 형태, 명확한 타이포그래피, 사용자 아바타와 부드러운 모션을 사용해 향후 그룹·커뮤니티 채팅으로 확장 가능한 친근한 브랜드를 만든다. 비교 목업은 `docs/design/mangotalk-ui-directions.png`에 보존한다.

Flutter의 `ThemeData(useMaterial3: true)`와 의미 기반 color scheme을 사용하며 화면 위젯에 색상 값을 직접 반복하지 않는다.

- Primary Mango: `#FFB526`
- Secondary Leaf: `#2F7D5B`
- Tertiary Purple: `#7457D9`
- Light Surface: `#FFF9F1`
- Primary Text: `#211A12`
- Incoming Bubble: `#FFFFFF`
- Outgoing Bubble: `#FFB526`
- Composer Surface: `#F1ECFF`

채팅 화면은 Mango 색상의 큰 곡선형 헤더, 원형 아바타, 최대 24px radius의 메시지 버블, capsule 입력창과 강조된 원형 전송 버튼을 사용한다. 장식 도형은 헤더와 빈 배경 영역에만 제한하고 메시지 본문과 겹치지 않는다. 상대 메시지는 아바타·닉네임과 함께 왼쪽, 내 메시지는 오른쪽에 배치한다.

모션은 메시지 등장과 전송 상태 변화에 180~280ms 범위의 짧은 easing을 사용한다. Reduce Motion 설정에서는 이동·크기 변화 대신 단순 fade 또는 즉시 전환한다. Dynamic Type, screen reader 의미 레이블, 최소 44x44pt/48x48dp 터치 영역과 WCAG AA 수준의 본문 대비를 보장한다. iOS에서는 safe area, 키보드, back gesture와 시스템 상태바 관례를 유지하고 Android에서도 동일한 브랜드 토큰을 재사용한다.
### Supabase 관리형 백엔드

Flutter 앱은 `supabase_flutter`를 통해 Auth, PostgreSQL 및 Realtime에 접근한다. 직접 REST/WebSocket 서버를 구축하는 대안보다 초기 운영 요소가 적고, 관계형 모델과 RLS가 방 참여 관계를 표현하기 쉽다. Supabase 의존성은 repository 인터페이스 뒤에 격리하여 향후 백엔드 교체 영향을 제한한다.

```text
Flutter UI
    │
State / Use cases
    │
Repository interfaces
    │
Supabase repositories
    ├── Auth
    ├── PostgreSQL
    └── Realtime
```

상태 관리는 Riverpod을 사용한다. 화면 위젯이 Supabase SDK를 직접 호출하지 않고, 인증 및 채팅 상태를 provider/notifier와 repository를 통해 다루게 하여 테스트와 플랫폼 재사용성을 높인다.

### Supabase Free 플랜 운영

개발과 초기 TestFlight 검증은 Supabase Cloud Free 플랜으로 시작한다. 별도의 상시 API 서버는 운영하지 않으며 Flutter가 publishable key와 사용자 JWT를 이용해 RLS로 보호된 Supabase API에 직접 접근한다.

2026-07-15 기준 계획 한도는 프로젝트당 DB 500MB, Storage 1GB, 월 egress 5GB, 월 Realtime 메시지 200만 건, Realtime 동시 연결 200개, 월 Edge Function 50만 회이며 Free 조직은 활성 프로젝트 2개까지 사용할 수 있다. 실제 구축 및 배포 시점에는 공식 요금표를 다시 확인한다.

두 프로젝트는 다음과 같이 사용한다.

- `mangotalk-dev`: 개발과 통합 테스트
- `mangotalk-testflight`: 외부 TestFlight 테스트 데이터

Free 프로젝트는 낮은 활동량이 일정 기간 지속되면 일시 정지될 수 있고 자동 백업이 제공되지 않는다. 중요한 schema 변경과 TestFlight 배포 전에 DB를 수동 export하고 복구 절차를 검증한다. Dashboard에서 DB, Storage, egress, Realtime 메시지와 동시 연결 사용량을 정기 확인한다.

다음 중 하나가 충족되면 Pro 전환을 검토한다.

- 항상 접속 가능해야 해서 비활성 정지를 허용할 수 없는 경우
- 자동 백업과 더 긴 로그 보존이 필요한 경우
- DB, Storage, egress, Realtime 메시지 또는 동시 연결이 Free 한도의 80%에 도달한 경우
- TestFlight 범위를 넘어 실제 사용자에게 지속적으로 서비스하는 경우
### 확장 가능한 채팅 데이터 모델

MVP에서도 채팅방과 참여자를 분리한다. 공용방 전용 `messages` 구조로 단순화하면 이후 1:1·그룹 채팅 도입 시 메시지와 권한 모델을 다시 작성해야 하기 때문이다.

```text
auth.users
    │ 1:1
profiles

chat_rooms 1 ─── N room_members N ─── 1 auth.users
     │
     └────── 1 ─── N messages N ─── 1 auth.users
```

- `profiles`: `id`(auth.users PK/FK), `nickname`, `created_at`, `updated_at`
- `chat_rooms`: `id`, `type`(`public`/`direct`/`group`), `name`, `created_by`, `created_at`
- `room_members`: `room_id`, `user_id`, `role`, `joined_at`; `(room_id, user_id)` 복합 PK
- `messages`: `id`, `room_id`, `sender_id`, `client_message_id`, `message_type`, `body`, `created_at`

MVP는 하나의 `public` 방을 마이그레이션에서 생성한다. 사용자는 공용방 진입 시 자신의 참여 행을 생성할 수 있다. 향후 `direct`와 `group` 방은 같은 테이블을 사용하고 방 생성 정책만 추가한다. 파일 기능은 Storage의 비공개 객체와 연결되는 `message_attachments` 테이블을 별도 변경으로 추가한다.

### 서버 기준 정렬과 멱등 전송

메시지 순서는 서버가 생성한 `created_at`과 `id`의 복합 순서로 결정한다. 기기 시각은 정렬 기준으로 사용하지 않는다. `(sender_id, client_message_id)`에 고유 제약을 두어 응답 유실 후 재시도가 같은 메시지를 중복 생성하지 않게 한다.

최근 메시지는 50개를 cursor 방식으로 조회하고 UI에서는 오래된 것부터 표시한다. offset 페이지네이션은 메시지가 계속 추가될 때 중복 또는 누락이 발생할 수 있어 사용하지 않는다.

### 초기 조회와 실시간 구독의 결합

채팅 repository는 초기 내역 조회와 Realtime insert 구독을 결합한다. 메모리 목록은 메시지 `id`로 중복을 제거하고 복합 정렬키로 정렬한다. 연결 복구 시 마지막 확인 정렬키 이후의 메시지를 다시 조회하여 오프라인 동안의 누락을 보완한다.

전송 메시지는 로컬에서 `sending` 상태로 즉시 보이고, DB 응답 또는 동일 ID의 Realtime 이벤트가 오면 `sent`로 합쳐진다. 실패 시 본문과 `client_message_id`를 보존하여 안전하게 재시도한다.

### 데이터베이스가 강제하는 권한

Flutter 앱에는 publishable key만 포함하며 secret/service-role key를 포함하지 않는다. 공개 스키마의 모든 테이블에 RLS를 활성화한다.

- `profiles`: 본인 행만 insert/update; 인증 사용자는 채팅 표시를 위해 필요한 프로필을 조회
- `chat_rooms`: 인증 사용자는 공용방 조회 가능
- `room_members`: 공용방에 본인 참여 행만 생성 가능; 참여자만 같은 방 참여 목록 조회
- `messages`: 참여자만 select/insert; insert의 `sender_id = auth.uid()` 강제
- DB check constraint로 닉네임과 메시지 길이를 클라이언트 검증과 별도로 강제

관리자 작업이나 비밀 키가 필요한 기능은 향후 Edge Function 또는 신뢰할 수 있는 서버에서 실행한다.

### 환경과 마이그레이션 관리

Supabase URL과 publishable key는 빌드 환경 설정으로 주입하며 저장소에 운영 비밀을 커밋하지 않는다. 테이블, 인덱스, seed 및 RLS는 재현 가능한 Supabase SQL migration으로 관리한다. 개발과 운영 Supabase 프로젝트는 분리한다.

### GitHub 소스 관리

프로젝트의 기준 원격 저장소는 https://github.com/kwangna83/mangotalk.git이며 기본 브랜치는 main으로 사용한다. OpenSpec 산출물, Flutter 코드, Supabase migration 및 재현 가능한 프로젝트 설정을 함께 커밋한다.

.gitignore에는 Flutter 빌드 산출물, IDE 로컬 파일, 서명 파일, 환경별 설정 및 비밀값을 포함한다. Supabase secret/service-role key, Apple 인증서와 provisioning profile, App Store Connect API private key는 Git에 커밋하지 않는다. 구현 단계별로 검증 가능한 크기의 커밋을 만들고, 전체 테스트와 비밀값 점검을 통과한 상태만 원격에 push한다.

### TestFlight 베타 배포

MVP는 공개 App Store 출시 대신 TestFlight 외부 테스트를 목표로 한다. macOS의 Xcode에서 배포용 iOS archive를 생성하고 App Store Connect에 업로드한다. 앱 설명, 피드백 이메일, 테스트 항목과 로그인·백엔드 접근에 필요한 검토 정보를 제공한 뒤 첫 외부 빌드의 TestFlight Beta App Review를 요청한다.

테스터는 이메일 또는 공개 초대 링크로 참여하며 TestFlight 앱에서 설치한다. 각 빌드는 90일 테스트 기간을 가지므로 지속 테스트가 필요하면 새 버전과 빌드 번호로 다시 업로드한다. TestFlight는 베타 배포 수단이며 영구적인 비공개 설치나 정식 출시를 대체하지 않는다.
## Risks / Trade-offs

- [익명 사용자가 로그아웃 또는 앱 데이터 삭제 후 계정을 복구할 수 없음] → MVP에서 명시하고, 영구 계정 연결을 후속 변경으로 설계한다.
- [Realtime 연결 중단으로 이벤트 누락 가능] → 재연결 후 cursor 기반 catch-up 조회를 수행한다.
- [클라이언트 검증 우회] → 길이 제약, 외래키, 고유키와 RLS를 DB에서도 강제한다.
- [RLS 정책 오류로 정보 노출 또는 기능 차단 가능] → 허용·거부 시나리오를 로컬 Supabase 통합 테스트로 검증한다.
- [Supabase SDK가 앱 전반에 퍼지면 공급자 교체가 어려움] → SDK 타입을 data 계층에만 두고 domain 모델과 repository 인터페이스를 유지한다.
- [표현적인 장식과 모션이 메시지 가독성을 해칠 수 있음] → 장식은 콘텐츠 밖에 두고 semantic color, Reduce Motion 및 접근성 테스트를 적용한다.
- [공용 채팅방 악용과 스팸] → MVP에는 입력 길이 제한만 적용하고, 출시 전 rate limit·신고·차단 정책을 별도 변경으로 추가한다.
- [사용량 증가에 따른 비용과 Realtime 한도] → 인덱스와 페이지네이션을 적용하고 실제 사용량을 관찰한 뒤 보존 정책과 확장 방식을 결정한다.
- [Free 프로젝트가 비활성 상태로 일시 정지될 수 있음] → TestFlight 기간에는 상태를 정기 확인하고 상시 가용성이 필요해지면 Pro로 전환한다.
- [Free 플랜에 자동 백업이 없음] → schema 변경과 배포 전에 수동 export를 만들고 복구 절차를 문서화한다.
- [Free 한도를 갑자기 소진할 수 있음] → 사용량을 정기 기록하고 80% 도달 전에 데이터 보존·최적화 또는 Pro 전환을 결정한다.
- [GitHub에 비밀값 또는 서명 자산이 노출될 수 있음] → .gitignore, 커밋 전 secret scan 및 환경 주입 방식을 사용하고 노출 시 즉시 키를 폐기·교체한다.
- [TestFlight 빌드가 90일 후 만료됨] → 만료 전에 새 빌드를 업로드하고 베타 릴리스 기록을 README에 유지한다.
- [Windows 환경만으로 iOS archive를 만들 수 없음] → 최종 빌드와 TestFlight 업로드는 macOS와 Xcode가 준비된 환경에서 수행한다.
## Migration Plan

1. Supabase Free 플랜으로 `mangotalk-dev` 프로젝트를 준비하고 익명 로그인을 활성화한다.
2. 스키마, 인덱스, seed 공용방 및 RLS migration을 적용한다.
3. RLS 허용·거부 및 메시지 멱등성 통합 테스트를 실행한다.
4. Flutter 환경에 개발용 URL과 publishable key를 주입하고 iOS에서 전체 흐름을 검증한다.
5. 테스트와 비밀값 점검 후 GitHub kwangna83/mangotalk의 main 브랜치에 push한다.
6. TestFlight 배포 전 두 번째 Free 프로젝트 `mangotalk-testflight`를 만들고 동일 migration을 적용한다.
7. macOS/Xcode에서 iOS archive를 만들고 App Store Connect에 업로드한다.
8. TestFlight 외부 테스트 심사를 통과한 빌드를 초대된 테스터에게 배포한다.

신규 시스템이므로 데이터 마이그레이션은 없다. 배포 전 롤백은 Flutter 배포를 중단하고 신규 migration을 되돌리거나 개발 프로젝트를 재생성하는 방식으로 수행한다.

## Open Questions

- 실제 배포 전 데이터 보존 기간과 메시지 삭제 정책을 결정해야 한다.
- 영구 계정 전환 시 익명 사용자의 기존 프로필과 메시지 소유권을 유지하는 연결 흐름을 별도 설계해야 한다.
- 운영 출시 전에 Apple 로그인, 푸시 알림 및 악용 방지 중 무엇을 우선할지 결정해야 한다.
- Free 플랜 한도와 가격은 변경될 수 있으므로 TestFlight 배포 직전에 최신 공식 요금을 다시 확인해야 한다.
