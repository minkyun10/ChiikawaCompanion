공용 집 한 채 — v28 / 앱 0.16.0 (build 30)
작성일: 2026-10-21

적용
- 화면의 집은 DesktopHome 한 개입니다. 별도 치이카와 집 window와 geometry를 제거했습니다.
- 기본 디자인은 하치와레 집입니다. 함께 쉬는 집 → 집 디자인에서 치이카와로 바꿀 수 있습니다.
- 두 디자인 모두 기존 하치와레 집의 360 × 214pt 크기와 화면 중앙 하단, Dock 위의 위치를 사용합니다.
- 시점·외곽·동굴 개구부·바닥·입구 좌표·수면 공간을 공유하며 디자인 변경은 색과 질감만 바꿉니다.
- 빈 집을 클릭하면 보이는 친구들이 함께 귀가합니다. 각 캐릭터의 개별 귀가·깨우기도 유지합니다.
- 어느 디자인이든 하치와레와 치이카와가 들어가 잠들며, 동시에 자면 각자 수면 그림을 나란히 표시합니다.
- 잠자는 중 디자인을 바꿔도 집 좌표·수면 시작 시각·입장 상태와 바닥 소품 좌표는 유지합니다.
- 잠든 집을 클릭하면 안의 친구들을 깨웁니다. 각자 20초 쉬면 스스로 일어납니다.
- 캐릭터 한 명을 숨겨도 공용 집과 다른 친구의 잠은 유지합니다. 전체 숨김은 집도 함께 숨깁니다.
- 기존의 캐릭터별 집 표시 설정은 제거하고 homeStyle 하나만 저장합니다.
- 향후 캐릭터를 추가해도 집 window는 추가하지 않습니다. HomeGeometry와 homeRoutines를 공유합니다.
  새 캐릭터의 입장·수면 그림은 공용 집 renderer에 연결하고 디자인 선택지는 HomeStyle로 확장합니다.

이미지
- 내장 image_gen의 precise-object-edit로 치이카와 테마의 투명 PNG 한 장을 만들었습니다.
- 하치와레 동굴을 기하 기준으로, 이전 치이카와 집은 색상 참고로만 사용했습니다.
- Generated/chiikawa-shared-home-original-v28.png: 생성 원본과 원래 alpha 그대로.
- Prompts/chiikawa-shared-home.txt: 실제 사용한 전체 프롬프트.
- References/: 두 입력 그림 사본. generation.json에 도구·경로·해시를 기록했습니다.
- 실행 chiikawa-shared-home-v28.png는 보관 원본과 byte 단위로 같습니다.
- 기존 하치와레 집과 이전 치이카와 둥근 집 시안도 보존했습니다.
- Review/shared-home-designs-v28.png: 각 디자인의 빈 집과 두 친구 수면 비교.
- Review/shared-home-sleep-v28.gif: 공용 입장과 함께 자는 호흡 동작.
- Review/app-shared-home-settings-v28.png: 실제 Mac에서 선택 UI 확인 후 기본 하치와레로 복원한 화면.
- 나머지 Review/는 전체 artwork renderer가 함께 출력한 검토 자료입니다.

검증
- CLI 329개, 최종 패키지 336개 검사 통과.
- 새 15개 검사는 기본값·이전 설정 이관·선택 저장·같은 window 재사용·크기/입구/위치 보존,
  한 캐릭터만 표시·두 친구 동시 입장/수면·수면 중 디자인 변경·소품 보존·기상·전체 숨김을 확인합니다.
- 기존 실행 이미지·녹음 45개는 54fa8bf와 동일합니다. resources-preserved.json에 SHA-256을 기록했습니다.
- build-log.txt와 codesign.txt: release 패키징과 ad-hoc 서명 확인.
- 실제 0.16.0 앱을 재실행하고 선택 UI에서 치이카와를 선택한 뒤 하치와레로 되돌렸습니다.
  설정 창을 닫고 새 앱을 실행 상태로 두었습니다.
- 보안 검사와 최종 상태는 security-*.json과 validation.json을 봅니다.
