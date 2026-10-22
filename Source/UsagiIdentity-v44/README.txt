우사기 외형 고정 · 공식 자료 기반 표정과 손동작
작성·확인: 2026-10-22

사용자 기준
  승인된 T pose 자체는 유지하고 표정마다 달라 보이는 외형을 수정한다.
  신규 외부 레퍼런스는 공식 홈페이지 자료만 사용한다.
  기존 소품 소유 규칙과 클릭 전용 음성, 공용 집, 보행은 유지한다.

고정 정본
  ../Usagi-v38/Approval-v2/Generated/usagi-tpose-sheet-for-approval.png
  실행 body: Sources/ChiikawaCompanion/Resources/usagi-rig-*-v38.png
  T pose와 방향별 body PNG 자체는 변경하지 않는다.

확인한 공식 출처 (verified: 2026-10-22)
  https://chiikawa-info.jp/ : 공식 종합 정보 사이트가 anime-chiikawa.jp와 chiikawamarket.jp를 연결한다.
  https://www.anime-chiikawa.jp/chara.html : 작은 눈·입, 높은 둥근 눈썹선, 분홍 볼과 짧은 손.
  https://www.anime-chiikawa.jp/episode.html : 홈페이지가 공개하는 회차 정지 이미지.
    001: 푸딩 / 020: 우사기의 손 / 055: 우사기의 무기 / 091: 작은 옆 입 모양.
  https://chiikawamarket.jp/products/4903320168053 : 공식 판매 2D 스티커의 환호 입과 짧게 든 팔.
  https://chiikawamarket.jp/products/4571609409229 : 공식 촬영용 캐릭터의 얼굴, 보조 검토만 사용.
  References/Official/sources.json: 원본 URL, 홈페이지 URL, SHA-256, 확인 날짜.
  조사 중 내려받았으나 우사기를 직접 보여주지 않는 회차도 조사 이력으로 보존한다.
  팬 위키·팬아트·비공식 쇼핑몰 자료는 새 표정의 근거로 사용하지 않았다.

관찰과 구현의 구분
  공식 이미지에서 확인: 환호/무기 장면에서도 둥근 높은 눈썹, 작은 뜬 눈과 omega 형태의 윗입을 유지한다.
  기존 앱 문제: 표정마다 전신 PNG를 교체했고 공격에는 원래 눈썹 대신 각진 화난 눈썹을 사용했다.
  구현 결정: 전신 PNG 교체를 제거하고 승인 body 위의 눈·입 내부만 바꾼다.
  기존 눈·눈썹·볼과 omega 윗입을 우선 재사용한다. 수면/기상에는 작은 눈꺼풀만 적용한다.
  손은 기존 보행의 짧고 둥근 paw 형상을 사용하고, 소품을 잡는 동작만 제한된 길이의 팔을 쓴다.
  움직임은 공식 정지 이미지에서 영감을 받아 구현한 12프레임 보간이다.
  공식 영상의 원본 프레임이나 공식 동작 타이밍을 복제한 자료라고 주장하지 않는다.

자료
  Generated/: 내장 image_gen으로 만든 투명 표정 부품 2개 원본. 초안도 보관.
  Prompts/: 두 생성 요청의 전체 프롬프트. CLI나 외부 생성 API는 사용하지 않았다.
  ExtractFaceParts.swift: 투명 부품을 분리하는 native 원본. 생성 alpha와 RGB를 유지한다.
  Parts/: 18개 분리 부품과 등록 좌표. 실행에는 입 4개·눈꺼풀 4개만 사용한다.
  Before/: 이전 전체 body 표정과 동작 preview.
  Review-v1/: 첫 native 조립 검토본. 최종 결과는 build/roster/usagi에서 생성하며 전체 archive에도 보존한다.
  Audit/: 빌드·회귀검사·원본보존 검증.

최종 검수
  app 0.21.0 (48), app bundle 전체 기능 검사 608개 통과.
  8개 동작의 표정 변경 영역 밖 픽셀과 외곽 실루엣 보존을 실제 native render에서 확인.
  승인 T pose, 기존 resource 96개, 보행·다른 친구 atlas 38개 byte 동일.
  우사기 동작 atlas 8개 갱신. 이전 전신 표정 5개는 Before에 보존하고 bundle에서 제외.
  Final/identity-preview.png: 최종 동작 비교.
  Final/identity-motion.gif: 12개 phase를 나란히 비교하는 동기화 미리보기. 실제 동작별 재생 시간은 앱 설정된 cycle을 따른다.
  최초 검사에서 얼굴 안쪽의 alpha까지 동일해야 한다고 검사한 부분은, 눈·입 부품 합성을 허용하되 얼굴 밖 픽셀과 전체 실루엣은 보존하도록 정정했다. 초기 실패 로그도 보존한다.
  새 앱 실행과 설정 창 닫기 확인. 자동 음성 재생 없이 바탕화면에서 실행 중.
