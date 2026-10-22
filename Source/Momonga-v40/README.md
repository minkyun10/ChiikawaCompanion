# 모몽가 구현 자료

2026-10-22. [공식 reference·출처](References/provenance.json), [six-view model](Generated/momonga-tpose-six-views-v40.png), [생성 원본·수정 시안](Generated/), [prompt](Prompts/), [등록 파츠](Final/Parts/)를 보관한다.

[중간 검수·수정 이력](Audit/middle-review.json), [모몽가 42항목 검수](Audit/final-audit-v40.json), [전체 5명 최종 검수](Audit/all-five-final-review.json)를 구분한다. 최종 실행 그림은 [실제 package에서 추출한 native sheet](Final/PackagedNative/)다. 이 폴더에는 공통 renderer 변경 후 우사기·쿠리만쥬도 다시 확인한 자료가 함께 있다. 이전 Native 폴더와 draft도 삭제하지 않았다.

최종 release 0.20.1 build 44에서 전체 앱 검사 612개, native image 검사 636개(새 캐릭터별 212개)를 통과했다. 기존 하치와레·치이카와 resource 51개도 byte 단위로 보존했다.

8방향 24-frame 걷기, 13개 기본 동작, 독립 아이템·생활 소품, 무기 hover, 클릭, 공용 집 수면과 기상을 연결했다. 모몽가의 큰 꼬리는 별도 파츠로 등록해 몸 크기가 바뀌지 않으며 뒤쪽 방향에서는 등 위로 보인다. 벚꽃은 공식 157화의 꽃 장식을 참고했다. 카메라·기타·공용 훈련봉은 팬 앱의 공통 기능이다.

[음성 provenance](Audio/provenance.json): 애니박스 공식 한국어 25·157화의 짧은 반응 4개를 사용한다. 성우 미소가 하늘다람쥐를 맡은 사실은 성우의 공개 profile에서 확인했다. 관련 없는 성우 demo는 쓰지 않았다. 자막은 짧은 앱 반응 표시이며 ASR timing을 참고했지만 공인 전사로 표기하지 않는다. 클릭·명시적 미리듣기만 로컬 재생하며 clone·합성은 없다. 문구 10개는 text-only 팬 앱 반응이다.

전체 원본 영상·ASR·웹 원문은 Source 안의 로컬 참고 자료로 보존하고 Git에서 제외한다. Git에는 생성 image 전체, 짧은 실행 음성 clip, 출처·hash·구간 및 검수 자료를 저장한다. 편집한 clip 사본도 Audio/Clips에 보관한다.

실행 앱은 빌드 시 준비한 native atlas를 읽고, actual frame이 바뀔 때 새 친구를 다시 그린다. 이동·입력 갱신은 60Hz로 유지한다. UserDefaults에 설정만 보관하며 움직임·대화·음성 이력을 저장하거나 알림을 감시하지 않는다. 메모리의 frame·mask cache는 캐릭터·방향·동작의 고정된 조합 수로 제한된다.
