2026-10-23 — 프레임 지연 최적화 및 설정 축소 (0.23.0 / build 50)

측정 환경: Apple M1 / MacBookAir10,1 / 8 GB RAM / macOS 26.3.
화면: 1440×797 point visible frame, 2× backing scale. 다른 실행 앱은 그대로 둠.
기준 commit: 47a126f. 비교용 앱은 benchmark 진입점만 추가한 동일 코드로 별도 빌드.
기본 측정: 2초 준비 + 캐릭터 수별 10초. 실제 AppKit 창 이동과 displayIfNeeded를 포함.
메인 RunLoop timer callback을 측정하며 compositor-present FPS를 직접 측정한 값은 아님.
모든 캐릭터의 바닥 소품 표시. 계속 걷도록 자동 줍기·행동·휴식·음성과 hover는 제외.

캐릭터 수 | 변경 전 갱신 Hz | 변경 후 갱신 Hz | 변경 전 CPU % | 변경 후 CPU %
1 | 59.30 | 60.01 | 23.31 | 15.16
2 | 59.91 | 60.00 | 40.15 | 19.19
4 | 48.79 | 60.00 | 76.06 | 26.58
6 | 20.45 | 60.01 | 92.83 | 29.51
8 | 16.41 | 59.99 | 94.63 | 30.85

실제 행동 부하 검사: 8명 / 60초 / 자동 줍기·소품 행동 켬 / 휴식·음성 끔 / 커서 바깥.
평균 59.65 Hz, p95 18.48 ms, p99 18.72 ms,
최대 71.91 ms, 25ms 초과 0.47%, CPU 28.89% (한 코어 기준).
지속적인 프레임 저하를 크게 줄였으나 긴 부하 검사에는 단발성 지연이 남음.
현재 구현된 8명까지 확인. 9명 이상 또는 모든 Mac에서의 무드랍을 입증한 수치는 아님.

변경:
- 큰 PNG 시트를 자른 CGImage가 PNG provider를 공유해 display마다 전체 시트를 반복 압축 해제하던 문제 해결.
- 초기 로드 시 raw 픽셀을 소유하는 provider로 전환. 원래 색 공간·palette·alpha·byte layout 유지.
- 이미 숨긴 창 재숨김, 같은 ignoresMouseEvents/좌표 적용, 바뀌지 않은 item 설정 재적용 제거.
- 하치와레/치이카와 보행은 동일한 시트 프레임이면 다시 그리지 않음. idle bob·표정 fade·blink·연속 효과는 유지.
- 이미 적용 중인 확장 캐릭터의 sparse redraw 유지. 이동 물리는 기존 60 Hz와 이동거리 기반 위상 그대로.

검수:
- 원화·음성 등 기존 리소스 131개와 app bundle bytes 동일.
- 원화 및 atlas 197개의 decoded raw pixels와 bitmapInfo 동일.
- Audit/preservation, pixel identity, before/after 및 active-eight JSON에 원시 수치 보관.
- 반복 최적화 중간 결과 after-round1, 실행 sample, 이전 Settings/README도 보존.

UI:
메인은 소환 토글과 캐릭터 버튼만 제공. 캐릭터 선택 후 아이템 전체 토글/목소리 듣기 2개.
아이템 토글은 해당 캐릭터의 보유 소품 및 책상·밥그릇을 한 번에 켜고 끔.
캐릭터 우클릭도 같은 2개. 실제 클릭 명대사·드래그·호버·자동 행동은 유지.
집 디자인 선택은 집 우클릭으로 이동. 공용 집 1개와 고정 위치 유지.
녹음이 없는 3명은 목소리 버튼 disabled. 다른 목소리로 대체하지 않음.

화면 동일성 검사 보강:
provider를 바꾼 CGImage는 TIFF 저장 바이트가 달라지지만 실제 화면 픽셀은 같음.
check-rendered-identity.swift에서 1×/Retina 2× 동일성을 확인하고, 기존 row-major 검사는 TIFF container 대신 양 배율의 composited pixels를 비교하도록 변경.
기존 방식 실패 로그는 self-test-before-render-comparison.log로 보존.

최종 app bundle 검사 810개 통과. CUA에서 소환 목록/2개 상세 옵션/통합 토글/음성 비활성화를 확인.

최종 8명 실행 프로세스 RSS 샘플: 543920 KiB ≈ 531.2 MiB. 고정된 decoded pixel cache 사용.
원래 compressed/lazy provider보다 메모리를 사용해 반복 압축 해제를 제거하는 trade-off이며 앱 종료 시 해제.
