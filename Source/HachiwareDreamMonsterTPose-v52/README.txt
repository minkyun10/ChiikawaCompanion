괴물 하치와레 — T-pose와 정면·후면·측면 시트 v52
생성: 2026-10-23
외형 기준: 사용자가 't pose 생성'을 요청한 v51 외형

결과물
1. Final/hachiware-dream-monster-front-t-pose-v52.png
   정면 T-pose 마스터. 투명 배경, 양팔 수평, 양손 발톱 각각 4개, 양발 각각 3개.
2. Final/hachiware-dream-monster-three-view-v52.png
   흰 배경의 정면·후면·왼쪽 측면 3방향 시트.
   같은 체형과 색을 유지하며 대략 같은 크기와 발 기준선에 배치했다.
   측면에서는 T-pose의 팔이 화면 앞뒤를 향하므로 어깨 높이에 단축되어 보인다.

생성 기준
- v51의 넓고 둥근 흰 몸, 큰 파란 귀, 소용돌이 눈, 청록색 발톱, 큰 파란 꼬리.
- 먼저 정면 T-pose를 생성하고 그 결과를 다방향 시트의 주 기준으로 사용했다.
- 후면의 파란 머리 무늬와 꼬리 부착 위치는 v50 공식 상품 후면 사진을 보조 참고했다.
- 측면은 확정된 외형을 바탕으로 생성한 해석이며 공식 정투상 자료가 아니다.
- 향후 애니메이션의 비율 기준은 별도 정면 마스터 PNG를 우선한다.

생성 방식과 보관
  built-in image_gen 2회 사용. 생성 이미지의 pixel은 후처리하지 않았다.
  Prompts/01-front-t-pose.txt: 정면 T-pose, 외형 유지, 양팔 수평, 투명 배경.
  Prompts/02-three-view-turnaround.txt: 정면 마스터 기준 정면·후면·측면 시트.
  references.json: 입력 이미지, 역할, SHA-256, 공식 출처.
  validation.json: PNG 열림·해상도·alpha·생성 원본과의 해시 일치·육안 확인 항목.
  generation-status.json: 외형 확정 근거, 생성 상태, 적용 여부.
  모든 생성 원본도 Source/GeneratedOriginals에 별도 보존한다.

적용 범위
  T-pose 및 시트 생성까지 완료했다.
  앱의 캐릭터 교체, 걷기 모션, sprite atlas 또는 rig 제작은 하지 않았다.
