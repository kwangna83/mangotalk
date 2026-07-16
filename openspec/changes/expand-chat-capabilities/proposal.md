## Why

현재 MangoTalk은 단일 공용방의 텍스트 대화만 지원한다. 실제 그룹 대화를 검증하려면 대화 주제별로 방을 나누고 사진을 공유할 수 있어야 한다. 기존 `chat_rooms`, `room_members`, `messages.message_type` 확장 지점을 활용해 기능을 추가하되, 방 참여 권한과 비공개 이미지 접근은 데이터베이스와 Storage 정책에서 강제한다.

## What Changes

- 사용자가 여러 그룹 채팅방을 생성하고 참여·나가기·전환할 수 있게 한다.
- 사용자가 참여 중인 방 목록과 방별 메시지 내역을 제공한다.
- 선택한 방에 대해서만 메시지를 조회하고 Realtime 이벤트를 수신한다.
- 채팅 메시지에 이미지를 첨부하고 업로드 진행·실패·재시도 상태를 표시한다.
- 이미지 객체는 Supabase Storage 비공개 버킷에 저장하고 참여자에게만 signed URL을 제공한다.
- 이미지 메타데이터, 방 생성 함수, 관련 인덱스와 DB/Storage RLS 정책을 migration으로 추가한다.
- 기존 공용방, 텍스트 메시지 및 익명 사용자 세션은 그대로 유지한다.

## Capabilities

### New Capabilities

- `multi-room-chat`: 그룹 채팅방 생성, 목록, 참여, 나가기, 방 전환과 방별 접근 제어를 정의한다. GitHub #2.
- `image-messaging`: 이미지 선택, 검증, 비공개 업로드, 메시지 연결, 표시와 오류 복구를 정의한다. GitHub #1.

### Modified Capabilities

- `public-chat-messaging`: 기존 단일 공용방 메시지 흐름을 선택된 채팅방 단위의 메시지 흐름으로 일반화한다.

## Impact

- Flutter에 채팅방 목록·생성 화면, 방 선택 상태와 이미지 선택·미리보기 UI가 추가된다.
- 채팅 repository가 방 목록/생성/참여/나가기와 이미지 업로드 계약을 제공한다.
- Supabase PostgreSQL에 이미지 첨부 테이블, 방 생성용 RPC와 RLS 정책이 추가된다.
- Supabase Storage에 비공개 이미지 버킷과 참여자 기반 접근 정책이 추가된다.
- 이미지 Storage 용량과 egress가 증가하므로 파일 크기 제한 및 사용량 모니터링이 필요하다.
- 관련 이슈: https://github.com/kwangna83/mangotalk/issues/1, https://github.com/kwangna83/mangotalk/issues/2

## Non-Goals

- 동영상·일반 파일 전송 및 이미지 편집
- 1:1 다이렉트 메시지와 초대 링크
- 방 관리자 위임·강제 퇴장·방 설정 편집
- 읽음 상태, 푸시 알림과 유해 콘텐츠 자동 판별
