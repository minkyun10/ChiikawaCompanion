HachiwareExclusiveItems-v41 — 2026-10-22 / app 0.20.2 build 45

사용자 요청: 털뭉치와 기타는 하치와레 전용으로 설정하고 다른 캐릭터에서 제거.

치이카와에는 기존부터 두 소품과 관련 동작이 없습니다.
우사기·쿠리만쥬·모몽가의 화면 소품, 설정, 메뉴, 드래그 payload,
줍기·연주·토하기 자동 행동과 실행용 atlas에서 해당 항목을 제거했습니다.
하치와레의 기타·털뭉치와 상호작용은 유지합니다.

이전 rosterOptionsV38의 guitar·furball만 걸러서 다시 저장합니다.
다른 소품의 켜짐·꺼짐과 자동 줍기·생활 동작·휴식·음성 설정은 유지합니다.
기타를 알 수 없는 enum으로 처리해 전체 설정을 초기화하지 않도록 문자열로 migration합니다.
털뭉치는 하치와레도 사용하는 공통 ActivitySpot 값이므로 새 친구의 허용 목록에서 제외합니다.

이전 생성 이미지·기타/토하기 sheet는 Source의 과거 제작 폴더에 모두 보존합니다.
이번에 imagegen으로 새 캐릭터 그림을 생성하지 않았습니다. 빌드로 갱신한 preview는 Source/Project에 복사하며
같은 경로의 이전 그림은 Source/Versions에 보존합니다.

Audit/verify-preservation.py는 직전 완료 commit cfcc834를 기준으로
실행에서 유지하는 atlas와 원본 resource가 바뀌지 않았는지,
제외한 atlas가 실행 bundle에는 없고 이전 Source 자료에는 남아 있는지 확인합니다.
Audit/self-test.log는 실제 서명된 app bundle의 전체 기능 검사 결과입니다.
전체 628개 검사 통과. 유지 atlas 57개·원본 resource 106개는 직전 버전과 byte 단위로 동일합니다.
실제 실행 앱의 설정에서 세 친구는 카메라·무기·캐릭터 소품 및 책상·밥만 표시하며,
하치와레의 기타·털뭉치 설정과 기타 자동 착용이 유지되는 것도 확인했습니다.
