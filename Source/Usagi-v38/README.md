# 우사기 — 승인 외형 및 구현 자료

2026-10-22 사용자 승인: “합격. 계속 진행해줘”. 기준 외형은 [승인 T-pose sheet](Approval-v2/Generated/usagi-tpose-sheet-for-approval.png)다.

- [사용자 reference 원본](Approval-v2/References/usagi-user-reference.jpeg)
- [승인 외형의 rig·표정 생성 원본과 prompt](Approved-v3/)
- [현재 적용 파츠](Final/Parts/)
- [실제 native renderer로 만든 8방향 24-frame sheet·GIF·동작 sheet](Final/Native/usagi/)
- [공개 성우 샘플 원본·편집 구간·출처](Audio/)
- [중간 검수](Audit/middle-review.json), [최종 42항목 검수](Audit/final-audit-v38.json)

우사기 단계의 최종 packaged regression은 495개, 독립 native asset 검사는 212개를 통과했다. 공부 12 frame의 입 중앙에 분홍 혀가 남고, 8방향 전체 192 frame의 귀·손·발이 canvas 안에 들어오는지 확인했다. 기존 하치와레·치이카와 resource 51개는 byte 단위로 보존했다.

음성은 권다예 성우의 공개 character demo에서 짧은 비언어 반응 4개를 발췌했다. 원 제공자는 특정 anime episode를 명시하지 않으므로 episode 원음이라고 보증하지 않는다. 자막 기호는 앱 반응 label이다. 합성·voice cloning은 사용하지 않았다. 클릭과 명시적인 미리듣기 외의 행동에서는 재생하지 않는다. 10개 text 반응도 같은 무작위 pool에 포함한다.

`Generated`, `Superseded-v1`, `ImplementationDrafts`, 최초 `NativePreviews`에는 수정 전 자료를 이력으로 보존했다. 현재 적용본은 위 `Final`과 `Approved-v3`다. 발·팔 연결과 보간은 native rig 코드에서 한 경로와 반 주기 offset으로 계산하며, identity와 표정은 승인 reference를 바탕으로 생성한 raster 파츠를 사용한다.

공용 집은 하나이고, 기존 위치·크기와 기본 하치와레 디자인을 유지한다. 우사기와 기존 두 친구의 동시 수면·기상, 디자인 교체 시 수면 clock·소품 좌표 보존도 검사했다. 다음 단계는 쿠리만쥬다.

최종 5명 release의 공통 renderer·입력·수면·음성 재검수는 [전체 최종 검수](../Momonga-v40/Audit/all-five-final-review.json), 최신 실행 sheet는 [PackagedNative](../Momonga-v40/Final/PackagedNative/)에 기록했다. 편집한 음성 clip 사본은 Audio/Clips에도 보관한다.
