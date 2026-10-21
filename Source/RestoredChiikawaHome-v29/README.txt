치이카와 집 디자인 복원 — 앱 0.16.1 (build 31)
작성일: 2026-10-21

- 치이카와 디자인에 기존 chiikawa-house-v26.png를 다시 연결했습니다.
- 크림색 둥근 외곽, 분홍 문, 꽃·나비 장식과 작은 책상이 있는 이전 그림입니다.
- 이미지를 편집하거나 새로 생성하지 않았습니다. 기존 alpha와 원본 비율을 유지합니다.
- 공용 집 한 채, 기본 하치와레 디자인, 같은 고정 위치·표시 영역·입구 좌표를 유지합니다.
- 어느 디자인이든 두 캐릭터가 함께 입장하고 잠들며, 디자인 변경은 수면 시간을 건드리지 않습니다.
- v28의 분홍 동굴 시안과 기존 실행 리소스 46개도 삭제·수정 없이 보존했습니다.

보관
- References/chiikawa-house-v26.png: 복원에 사용한 기존 이미지 사본.
- Review/shared-home-designs-v29.png: 빈 집과 두 캐릭터가 함께 자는 모습.
- Review/shared-home-sleep-v29.gif: 입장·공용 수면 애니메이션.
- build-log.txt, self-test-app.txt, codesign.txt: release 패키지와 서명·336개 검사 통과 기록.
- resources-preserved.json: 이전 commit의 실행 이미지·음성 46개와 SHA-256 동일.
- 실제 Mac에서 새 앱을 재실행했고, 선택값은 기본 하치와레 집으로 유지했습니다.
- 전체 렌더 이미지도 Source/Project에 보관하고 기존 사본이 바뀌면 Source/Versions에 먼저 보존합니다.
