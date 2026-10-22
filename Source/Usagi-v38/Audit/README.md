# 하치와레 기준 검수 준비

검증일: 2026-10-22. 기준 commit: `a4544bd701e721656af1b57265fab73bddc532df`.

## 기준 snapshot과 현재 결과

아래 baseline 파일과 integration 표는 수정 전 commit `a4544bd`의 431개 검사 및 구조를 기록한 snapshot이다. 현재 구현 상태와 혼동하지 않는다.

2026-10-22 사용자가 [T-pose sheet](../Approval-v2/Generated/usagi-tpose-sheet-for-approval.png)를 “합격. 계속 진행해줘”로 승인한 뒤 구현을 진행했다. [우사기 최종 검수](final-audit-v38.json), [쿠리만쥬 최종 검수](../../Kurimanju-v39/Audit/final-audit-v39.json)에 각 단계의 결과를 남겼다. 모몽가 및 전체 회귀 검수는 `../../Momonga-v40/Audit`에 기록한다. 초기 미완성 초안은 ImplementationDrafts에 보존하며 production source와 구분한다.

## 확인한 근거

- `baseline-build.log`: 기존 production source의 release build, artwork render 및 app packaging 결과.
- `baseline-self-test.log`: 실제 app bundle에서 실행한 431개 검사 통과. 테스트 음성 출력은 대체 callback을 사용한다.
- `baseline-signature.log`: 실제 app bundle의 strict signature 검증.
- `baseline-preservation.json`: production source와 기준 commit 비교, resource 파일별 hash 및 packaged copy 비교.
- `hachiware-baseline-evidence.json`: 42개 항목의 acceptance criteria, 코드 정의 위치, 관련 기존 검사 위치 및 보관 자료.
- `baseline-evidence.py`: 위 evidence index 재생성. 관련 검사 위치는 탐색 색인이며, 항목 전체가 검증됐다는 판정이 아니다.
- `baseline-features.json`: 새 캐릭터의 항목별 결과는 전부 `pending`이다.

## 기준을 그대로 복사하면 생기는 차이

1. 하치와레는 좌우 24 frame, 상하·대각선 source pose는 12 frame이다. 새 캐릭터의 목표는 모든 방향에서 양발 전체 24 frame이다. 기존 431개 검사 통과로 새 24-frame 구현을 증명할 수 없다.
2. 하치와레는 실제 음성 4개와 text-only 대사 10개를 사용한다. 새 캐릭터의 실제 녹음 확보는 별도 asset 의존성이며, 무관한 대사나 모방 음성으로 대체한 뒤 동일 성우라고 표기하지 않는다.
3. 하치와레는 기존 수면 이미지에서 집 밖으로 복귀하고, 치이카와는 별도 기상 frame도 있다. 새 캐릭터의 입장·수면·기상은 자체 artwork와 동작을 검수해야 한다.
4. 우사기의 긴 귀를 포함하는 canvas 변경은 화면 경계, pointer mask, 공격 registration을 함께 검토해야 한다. 흰 몸과 정사각 canvas에 맞춘 기존 측정만으로 노란 몸의 우사기 크기를 판정할 수 없다.
5. T-pose의 외형 일치, 발·팔의 자연스러운 연결, 공격 표정은 pixel 검사만으로 통과 처리하지 않는다. 실제 render와 주기 재생을 확인한다.

## baseline에서 확인한 integration 지점

아래 표는 기준 시점의 확인 결과와 당시 수정 계획이다. 실제 구현과 결과는 캐릭터별 최종 검수 문서를 따른다.

| 경계 | 현재 코드 | 필요한 검수 |
|---|---|---|
| roster·설정 | `Model.swift`의 active roster는 하치와레·치이카와 2명 | 새 캐릭터 추가 migration, 기존 숨김·산책 선택 유지 |
| 매 tick 처리 | `Desktop.swift`는 치이카와를 분리한 뒤 나머지를 하치와레로 처리 | 새 캐릭터마다 독립 controller·소품·action clock 사용 |
| 부르기 | `DesktopChiikawa.swift`의 `callFriend`가 두 캐릭터만 분기 | 우사기 부르기가 치이카와 동작을 중단하지 않는지 확인 |
| 공용 집 | `SharedHome.swift`의 입장·기상 command가 두 캐릭터만 분기 | 집 한 개·위치 고정·디자인 독립, 5명 동시 rest clock 유지 |
| 표시·pointer | view와 canonical pointer body는 132×150 | 귀를 자르거나 hover 사각을 축소하지 않는지 확인 |
| 공격 크기 | `AttackBodyMetrics`는 흰 영역을 측정, `destination`은 정사각 기준 | 우사기 색·높이와 무관한 명시적 body/feet registration 검증 |
| settings UI | 공용 집의 캐릭터별 row가 하치와레 외에는 치이카와 controls 사용 | 각 친구에게 자기 controls·상태·음성 player 연결 |
| context·status menu | 두 캐릭터의 하루 동작과 callback만 연결 | 표시·산책·소품·행동·집·음성의 실제 메뉴 경로 확인 |
| 기존 테스트 | 일부 loop가 하치와레 외의 actor를 치이카와로 간주 | 기존 두 명 검증 유지, 새 세 명의 실제 callback·render·5명 간섭 검증 추가 |

## 재검수 순서

우사기 → 쿠리만쥬 → 모몽가 순서를 유지한다. 각 캐릭터에서 identity 승인, 중간 motion/behavior 검수, 42개 항목 비교, 개발 가능한 누락 보완, 최종 재검수를 진행한다. 마지막에는 다섯 캐릭터의 동시 실행에서 소품 좌표·음성·공격 hover·수면·설정이 서로 간섭하지 않는지 확인한다. 최종 완료는 코드·실제 render·packaged resource·native 동작 및 Git 반영 근거를 모두 확인한 뒤 판정한다.
