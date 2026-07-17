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
- 사용자가 프로필 사진을 등록·교체·삭제하고 채팅 아바타에서 크게 볼 수 있게 한다.

## Capabilities

### New Capabilities

- `multi-room-chat`: 그룹 채팅방 생성, 목록, 참여, 나가기, 방 전환과 방별 접근 제어를 정의한다. GitHub #2.
- `image-messaging`: 이미지 선택, 검증, 비공개 업로드, 메시지 연결, 표시와 오류 복구를 정의한다. GitHub #1.
- `profile-images`: 프로필 사진 등록·교체·삭제, 채팅 아바타 표시와 전체 화면 확대를 정의한다. GitHub #4.
- `unread-messages`: 사용자·채팅방별 마지막 읽음 위치와 새 메시지 구분 표시를 정의한다.

### Modified Capabilities

- `public-chat-messaging`: 기존 단일 공용방 메시지 흐름을 선택된 채팅방 단위의 메시지 흐름으로 일반화한다.

## Impact

- Flutter에 채팅방 목록·생성 화면, 방 선택 상태와 이미지 선택·미리보기 UI가 추가된다.
- 채팅 repository가 방 목록/생성/참여/나가기와 이미지 업로드 계약을 제공한다.
- Supabase PostgreSQL에 이미지 첨부 테이블, 방 생성용 RPC와 RLS 정책이 추가된다.
- Supabase Storage에 비공개 이미지 버킷과 참여자 기반 접근 정책이 추가된다.
- 프로필 이미지용 공개 읽기 Storage 버킷과 사용자별 쓰기 정책이 추가되고 `profiles`에 이미지 경로가 저장된다.
- 이미지 Storage 용량과 egress가 증가하므로 파일 크기 제한 및 사용량 모니터링이 필요하다.
- 관련 이슈: https://github.com/kwangna83/mangotalk/issues/1, https://github.com/kwangna83/mangotalk/issues/2, https://github.com/kwangna83/mangotalk/issues/4

## Non-Goals

- 동영상·일반 파일 전송 및 이미지 편집
- 1:1 다이렉트 메시지와 초대 링크
- 방 관리자 위임·강제 퇴장·방 설정 편집
- 푸시 알림과 유해 콘텐츠 자동 판별

## Future Roadmap

추천 기능과 현재 상태는 다음과 같다.

1. [ ] 메시지 답장과 인용 표시
2. [x] 안 읽은 메시지 표시
3. [ ] 메시지 수정·삭제
4. [ ] 이모지 반응
5. [ ] 입력 중·접속 중 표시
6. [ ] 다중 채팅방 생성·전환
7. [ ] 메시지 검색과 날짜 이동
8. [ ] 익명 계정의 이메일 OTP·소셜 계정 전환
9. [ ] 푸시 알림
10. [ ] 사용자 차단·신고와 메시지 전송 빈도 제한
