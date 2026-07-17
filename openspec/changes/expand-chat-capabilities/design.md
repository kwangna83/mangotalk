## Context

MVP 데이터 모델은 이미 `chat_rooms`와 `room_members`를 분리하고 `messages`에 `room_id`와 `message_type`을 저장한다. 현재 앱은 고정된 공용방 ID만 사용하며 메시지는 텍스트 본문만 가진다. 이번 변경은 이 모델을 유지하면서 그룹방 생성과 비공개 이미지 첨부를 활성화한다.

## Goals / Non-Goals

**Goals:**

- 방 생성과 생성자 멤버 등록을 원자적으로 수행한다.
- 화면에 선택된 방 하나만 조회·구독하여 방 사이의 메시지를 격리한다.
- 이미지 객체와 메타데이터 모두 방 참여자만 접근하게 한다.
- 업로드 실패와 메시지 저장 실패를 구분하고 안전하게 재시도한다.
- 기존 공용방과 텍스트 메시지에 하위 호환성을 유지한다.

**Non-Goals:**

- 공개 방 탐색 정책을 넘어선 초대·검색·추천 시스템
- 미디어 변환 서버와 CDN 최적화
- 종단간 암호화와 콘텐츠 moderation

## Decisions

### 그룹방 생성은 RPC로 원자화

`create_group_room(p_name, p_client_request_id)` 보안 함수가 방과 생성자의 `admin` 멤버 행을 같은 트랜잭션에서 만든다. 사용자 ID는 입력으로 받지 않고 `auth.uid()`를 사용한다. 클라이언트 요청 ID에 고유 제약을 두어 네트워크 재시도가 중복 방을 만들지 않게 한다.

방 목록은 현재 사용자의 `room_members`를 기준으로 조회한다. 기존 `public` 방은 모든 인증 사용자가 참여할 수 있고, 새 `group` 방은 생성 또는 명시적 참여 정책을 통해서만 접근한다. 초기 버전은 참여 가능한 그룹방 목록을 제공하되, 향후 비공개 초대 모델을 도입할 수 있도록 참여 동작을 repository 뒤에 둔다.

### 선택된 방별 상태와 Realtime 구독

Riverpod에 방 목록과 `selectedRoomId` 상태를 추가한다. 방 전환 시 기존 Realtime 채널을 해제하고 새 방 필터로 구독한 다음 최근 메시지를 조회한다. 비동기 응답에는 방 ID를 함께 검사해 늦게 도착한 이전 방 응답이 현재 화면을 덮어쓰지 않게 한다.

방별 메시지 cursor와 캐시는 방 ID를 key로 분리한다. `message_read_positions`에는 사용자·방별 마지막 읽음 `(created_at, message_id)` cursor를 저장한다. 재입장 시 저장된 위치 이후의 다른 사용자 메시지를 계산해 첫 항목 앞에 구분선을 표시하고, 현재 화면에서 확인한 최신 메시지는 과거 위치로 회귀하지 않는 RPC로 갱신한다.

### 첨부 메타데이터와 비공개 Storage

이미지 원본은 공개 URL이 아닌 Supabase Storage의 private `chat-images` 버킷에 저장한다. 객체 경로는 `{room_id}/{sender_id}/{client_message_id}/{random_file_name}` 구조를 사용한다.

`message_attachments`는 다음 메타데이터를 가진다.

- `id`, `message_id`, `storage_bucket`, `storage_path`
- `mime_type`, `size_bytes`, `width`, `height`, `created_at`
- 메시지당 초기 최대 이미지 수는 1개

`messages.message_type` check constraint는 `text`와 `image`를 허용한다. 이미지 메시지의 `body`는 선택적 캡션을 위해 빈 문자열을 허용하되, 텍스트 메시지는 기존 1~2,000자 제약을 유지하도록 타입별 constraint로 변경한다.

DB와 Storage 정책은 경로의 `room_id`, `sender_id`를 검증한다. 참여자만 객체를 읽고 본인 경로에 업로드할 수 있다. 앱은 짧은 유효기간의 signed URL을 생성하며 영구 URL을 저장하지 않는다.

### 업로드 후 메시지 확정

클라이언트는 이미지를 검증하고 Storage 업로드를 완료한 뒤 이미지 메시지와 첨부 메타데이터를 RPC로 원자 저장한다. 메시지 저장이 실패하면 같은 `client_message_id`로 재시도한다. 참조되지 않은 업로드 객체는 즉시 삭제를 시도하고, 실패한 고아 객체는 별도 정리 작업 대상으로 기록한다.

지원 형식과 초기 제한은 JPEG, PNG, WebP 및 파일당 10MB 이하로 한다. GIF는 애니메이션 처리와 비용 정책을 정하기 전까지 제외한다. 브라우저의 파일 확장자가 아니라 MIME type과 decode 가능 여부를 검증한다.

### 기존 데이터 호환

기존 `text` 메시지와 공용방 ID는 변경하지 않는다. migration은 새 테이블과 정책을 추가하고 기존 check constraint만 타입별 규칙으로 교체한다. 롤백 시 앱에서 신규 진입점을 먼저 비활성화한 후 이미지 행과 Storage 객체를 보존한 채 신규 쓰기를 중단한다.

## Risks / Trade-offs

- [Storage와 DB 저장 사이에 분산 트랜잭션이 없음] → 고유 client ID, 참조 없는 객체 삭제 시도와 주기적 고아 객체 정리를 사용한다.
- [signed URL 만료로 이미지가 깨질 수 있음] → 만료 전에 재발급하고 403 응답 시 한 번 갱신한다.
- [방 전환 경쟁 조건으로 다른 방 메시지가 보일 수 있음] → 모든 비동기 결과와 이벤트의 `room_id`를 현재 선택값과 대조한다.
- [이미지로 Free 플랜 용량·egress가 빠르게 증가] → 10MB 제한, 사용량 모니터링과 향후 리사이즈 작업을 적용한다.
- [클라이언트 MIME 검증 우회] → Storage/DB 정책과 허용 MIME 설정을 서버에서도 강제한다.

## Migration Plan

1. 신규 DB 함수, 제약, 첨부 테이블과 RLS migration을 개발 프로젝트에 적용한다.
2. private Storage 버킷과 정책을 migration으로 생성한다.
3. 기존 공용방/텍스트 회귀 및 권한 거부 테스트를 실행한다.
4. 다중 방 기능을 먼저 배포하고 방별 구독 격리를 검증한다.
5. 이미지 기능을 feature entry point와 함께 배포하고 Storage 사용량을 모니터링한다.

## Open Questions

- 그룹방을 모든 인증 사용자가 발견·참여 가능하게 할지, 초대받은 사용자만 허용할지 제품 정책을 확정해야 한다.
- 이미지 캡션을 첫 버전부터 제공할지 결정해야 한다.
- 원본만 저장할지 썸네일 생성 Edge Function을 함께 도입할지 사용량 검증 후 결정한다.
