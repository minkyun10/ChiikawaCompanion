무기 호버 본체 크기 수정 — v27 / 앱 0.15.1 (build 29)
작성일: 2026-10-21

문제
- 공격 시트는 긴 무기와 몸을 하나의 256 × 256 cell에 담습니다.
- cell 전체를 평소 캐릭터 영역에 맞추던 방식 때문에 공격할 때 몸이 작아졌습니다.

적용
- 하치와레와 치이카와 모두 실제 걷기 front frame 0의 본체 너비를 기준으로 맞춥니다.
- 흰색 연결 영역 중 가장 큰 영역을 측정해 무기와 무기의 흰 돌기를 제외합니다.
- 공격 12프레임 각각 본체 너비·가로 중심·발 바닥선을 걷는 그림에 맞춥니다.
- 본체와 무기를 함께 균일하게 확대하며 원본 PNG 픽셀을 편집하지 않습니다.
- 공격 주기 전체가 들어가는 고정 표시 공간을 별도 투명 panel로 확보합니다.
  이 panel은 일반 앱 뒤의 기존 desktop layer에 있고 mouse event를 통과시킵니다.
- 원래 캐릭터 panel의 132 × 150 크기·위치·이동·마우스 반응 영역은 유지합니다.
- 호버를 벗어나면 다음 tick에서 공격 panel을 숨기고 원래 캐릭터를 표시합니다.
- 공격 12프레임·1.2초 주기와 양쪽 소품 좌표·착용 상태는 유지합니다.

검토 자료
- Review/weapon-hover-size-v27.png: 걷기 / 수정 전 / 수정 후 비교.
- Review/weapon-hover-size-v27.gif: 두 캐릭터의 공격 12프레임 비교.
- Review/body-measurements.json: 원본 본체 너비와 적용 배율.
- Review/app-settings-v27.png: 재실행한 실제 앱 설정 화면.
  실제 desktop에서 공격 중인 장면의 capture는 아니며, 공격 크기는 아래 raster와 controller 검사로 확인했습니다.
- Review/의 나머지 파일은 기존 전체 artwork renderer가 함께 출력한 자료입니다.
- 새 AI 이미지 생성은 없었습니다. 기존 실행 이미지·음성 45개는 모두 이전 commit과 동일합니다.

검증
- self-test-cli.txt: 314개 통과.
- self-test-app.txt: 최종 패키지 321개 통과.
- 새 검사 16개는 두 캐릭터의 실제 132 × 150 표시 크기에서 공격 12프레임을 raster로 측정합니다.
  본체 너비·중심과 발 기준선은 걷기 기준의 2 pixel 이내이며 무기 외곽은 잘리지 않습니다.
  실제 controller의 호버 진입·해제, 원래 panel 위치와 크기, click-through·desktop layer,
  양쪽 소품 좌표 보존을 검사합니다.
- resources-preserved.json: 기존 실행 리소스 45개의 SHA-256 동일.
- build-log.txt: 최종 release 빌드와 앱 패키징 기록.
- codesign.txt: ad-hoc 서명 검증 통과.
- 0.15.1 앱을 실제 Mac에서 재실행하고 설정 화면을 확인했습니다.
- 보안 검사 범위와 결과는 validation.json과 security-*.json에 기록합니다.
