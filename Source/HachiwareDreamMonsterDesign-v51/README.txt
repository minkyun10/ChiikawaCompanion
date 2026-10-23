괴물 하치와레 외형 컨펌 초안 — v51
작성: 2026-10-23
상태: 사용자 외형 승인 대기

Review/hachiware-dream-monster-appearance-v51.png
  괴물 하치와레 한 명의 전신 외형 초안. 투명 배경 PNG.
  원작의 큰 귀·소용돌이 눈·볼의 짧은 선·청록 발톱·파란 꼬리를 반영했다.
  몸과 팔다리 비율은 공식 정면 상품을 보조 참고한 생성 해석이다.
  양손은 각각 발톱 4개, 양발은 각각 발톱 3개가 보인다.

기준 자료
  references.json에 공식 원작 2개와 공식 상품 정면·후면의 경로·출처·해시를 기록했다.
  원본 레퍼런스는 Source/HachiwareDreamMonster-v50에 보존되어 있다.

생성 방식
  built-in image_gen 사용. CLI 또는 개인 API key는 사용하지 않았다.
  전체 프롬프트: Prompts/01-appearance-approval.txt
  핵심 요청: 공식 얼굴과 귀·손발·꼬리를 지킨 2D 전신 외형, 한 명만 표시,
  손발이 몸과 연결되고 전부 보이게, 투명 배경, T-pose나 다방향 시트는 제외.
  생성 원본은 수정하지 않고 Review 이미지로 복사했다.
  생성 파일의 원본 사본도 Source/GeneratedOriginals에 보존한다.

검수
  review-status.json: 육안 확인 항목과 승인 상태.
  validation.json: PNG 해상도·alpha·원본과 복사본의 SHA-256 일치 확인.
  매우 약한 alpha 잡음이 아래쪽 가장자리에 있으나 보이는 캐릭터는 잘리지 않았다.
  컨펌용 초안이며 공식 모델 시트 또는 앱 적용용 최종 asset은 아니다.

다음 단계
  사용자가 이 외형을 확정하면 동일한 비율의 T-pose와 정면·후면·측면 시트를 생성한다.
  이번 단계에서는 T-pose를 만들거나 앱의 기존 캐릭터·모션을 변경하지 않았다.
