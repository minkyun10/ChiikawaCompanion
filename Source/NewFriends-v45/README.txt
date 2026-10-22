랏코 · 시사 · 카니 — 공식 자료 기반 신규 친구 (2026-10-22)

References/Official: 공식 anime-chiikawa.jp 캐릭터 소개 및 공식 chiikawamarket.jp 상품 이미지.
sources.json에 URL·확인일·SHA256을 기록. 웹 원문은 로컬 보존, Git 제외.
랏코는 딸기 파르페 먹기, 시사는 라멘 서빙, 카니(古本屋)는 책 읽기.
캐릭터당 소품은 keepsake 1개. 무기·기타·카메라·털뭉치·책상·밥 소품은 추가하지 않음.
공통 보행·클릭·호버·드래그·독립 소품 좌표·드래그 드롭·귀가·수면·기상은 기존 시스템 공유.
한국어 캐릭터 녹음은 확보되지 않아 클릭 창작 반응 문구 10개만 표시. 실제 명대사 전사가 아님.

Generated: image_gen으로 만든 전체 시안. rakko-draft.png도 빠짐없이 보존.
rakko-sheet.png / shisa-sheet.png / kani-sheet.png: 정면·측면·후면·양 대각선·T-pose·팔·발·소품.
rakko-right.png: 비대칭 흉터를 유지하기 위한 별도 오른쪽 방향 원화.
Prompts: 모든 생성·수정 prompt 원문.
Parts: native AppKit crop으로 각 component 분리. 각 rig-registration.json에 source crop과 hash.
캐릭터 원화는 합성용으로 팔다리가 분리되어 있으며 앱에서는 기존 연결형 native 손발을 사용.
ExtractRig.swift / ExtractRightRig.swift: 추출 재현 script. T-pose는 보관, 나머지는 runtime resource.
NewFriendFace.swift는 등록된 눈·입 영역만 변경하고 원래 몸·흉터·갈기·머리띠·볼을 보존.
보행 8방향 × 24프레임, 허용 반응 7종 × 12프레임. 양발 위상은 반 주기 차이.
집은 기존 단일 공용 집이며 새 친구 전용 집은 만들지 않음.
Audit: 빌드 및 기능·외형 검수 기록. Final: 적용된 atlas와 미리보기.

최종 자동 검수: build 49 / 0.22.0 app bundle, 770개 통과. 기존 resource 104개와 expansion atlas 46개 동일.
실패한 초기 검사도 Audit에 보존: 고정된 5인 명단 가정, 모든 expansion에 음성이 있다는 기존 검사 가정을 8인·무음 지원 기준으로 수정.

실행 검수 추가 발견: Finder 방식으로 실행하면 optional expression이 없을 때 Bundle.module로 넘어가 개발 checkout을 탐색하며 멈춤.
launch-sample.txt에서 RosterNativeRig → assetURL → NSBundle → filesystem open 대기를 확인.
패키지 앱의 PNG/Voice lookup을 Bundle.main 내부로 제한하고 새 친구의 불필요한 전신 표정 lookup을 제거함.
compile/CLI test와 Finder launch의 환경 차이가 있었으므로 실제 재실행도 별도 검수.
launch-fix-build.log는 원화·atlas 변경 없이 실행 파일만 재컴파일/재서명한 기록.
