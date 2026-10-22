# 쿠리만쥬 구현 자료

2026-10-22. [공식 reference와 출처](References/provenance.json), [six-view model](Generated/kurimanju-tpose-six-views-v39.png), [rig·표정 생성 원본](Generated/), [prompt](Prompts/), [native 8방향 24-frame·13동작 sheet](Final/Native-Reviewed/kurimanju/), [중간 검수](Audit/middle-review.json)를 보관한다.

최종 전체 packaged regression 552개, 독립 기능 검사 99개, native image 검사 212개를 통과했다. 실제 설정 창과 WindowServer 입력도 확인했다. [최종 42항목 검수](Audit/final-audit-v39.json)에 결과를 남겼고 이전 시도도 보관했다.

간식·컵을 독립 소품으로 추가했고 컵을 입으로 올리는 동작을 적용했다. 카메라·기타·공용 훈련봉은 하치와레 시스템을 확장한 팬 앱의 공통 소품이며 공식 소지품이라는 의미는 아니다.

음성은 애니박스 공식 35화·180화에서 화면의 쿠리만쥬 입 동작과 음성 신호 시점이 일치하는 짧은 반응 4개를 발췌했다. [구간·출처·검증 방법](Audio/provenance.json)을 남겼다. 합성이나 voice cloning을 사용하지 않았다. 자막은 짧은 반응 표기이며 비언어 소리의 정확한 받아쓰기라는 의미는 아니다. 클릭 또는 명시적 미리듣기 때만 로컬 재생한다.

전체 원본 영상과 원본 HTML은 Source의 로컬 참고 자료로 보존하고 Git에서는 제외한다. Git에는 짧은 실행 clip, URL·hash·편집 구간·검수 image와 생성 image를 보관한다. 추가 만족 표정 draft는 사지가 붙어 있고 눈 비율이 달라 적용하지 않았으며 삭제하지 않았다.

최종 5명 release의 공통 renderer·입력·수면·음성 재검수는 [전체 최종 검수](../Momonga-v40/Audit/all-five-final-review.json), 최신 실행 sheet는 [PackagedNative](../Momonga-v40/Final/PackagedNative/)에 기록했다. 편집한 음성 clip 사본은 Audio/Clips에도 보관한다.
