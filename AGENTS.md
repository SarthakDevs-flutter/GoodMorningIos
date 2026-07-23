# Means of Grace — AI 작업 가이드

> 새 작업 전 **이 파일을 먼저 읽을 것.**  
> 상세 규칙: `.cursor/rules/means-of-grace-*.mdc`

## 프로젝트

- **앱**: Means of Grace (은혜의 수단) — Flutter iOS 우선
- **기능**: 아침 기도 알람 + 저녁 축복 알람, Circle, Firebase(선택)
- **번들 ID**: `com.bagseonghwa.meansofgrace`
- **사용자 언어**: 한국어 (응답도 한국어)

## 절대 깨지면 안 되는 것 (회귀 방지)

| 영역 | 규칙 |
|------|------|
| 알람 소리 | **ringing** 상태에서만 ON. **listening/STT** 중에는 반드시 OFF |
| `_startListening()` | live/preview 모두 `AlarmSoundService.stop()` 호출 |
| STT 세션 | `_beginListeningSession()` 에서 `ensurePlaying()` 금지 |
| 라이브 알람 | 완료 전 dismiss/cancel 불가 (`isLiveAlarm: true`) |
| 아침 기도 | 단계마다 ~80% 읽기 후 수동으로 다음/Amen |
| 마지막 단계 | 자동 완료 없음 — 사용자가 Amen 탭 |
| iOS 설치 | Release `xcodebuild` + `devicectl` (Personal Team은 debug 홈 실행 불가) |
| Firebase | 미설정 시 `LocalCircleStore`; Firestore 필드 초기화 금지 |

## 앱 구조

```
main.dart → AppLaunchGate → (온보딩 | AuthGate | HomeScreen | 잠금 AlarmScreen)
```

- **홈**: `HomeScreen` — 아침/저녁 알람 카드, Circle, 설정
- **아침 기도**: `lib/screens/alarm_screen.dart`
- **저녁 축복**: `lib/screens/evening_blessing_screen.dart`
- **알람 잠금**: 알람 시간 이후 미완료 시 `AppLaunchGate`가 blocking `AlarmScreen` 표시

## 기도 화면 (현재)

- **입력**: 음성(STT) 전용 — PageView로 단계 스와이프, 하단 마이크 + 진행률
- **키보드 타이핑**: 이전에 iOS에서 글자 미표시 버그로 **제거된 상태** — 재추가 시 별도 브랜치/테스트 필수
- **매칭**: `SpeechMatchUtils` 임계값 **0.80**
- **관련 위젯**: `lib/widgets/prayer_step_nav_bar.dart`

## 알람 시스템

- 스케줄: `AlarmRegistry`, `AlarmScheduleHelper`, `AlarmFireWatchdog`
- 소리: `AlarmSoundService` + iOS `AlarmAudioPlugin.swift`
- 잠금: `AlarmSessionService`, `AlarmPersistenceService`
- 알람 UI가 이미 떠 있으면 (`isBlockingUiVisible`) **중복 push 금지** (`main.dart`)

## 코드 수정 원칙

1. **최소 diff** — 요청과 무관한 리팩터 금지
2. **기존 패턴 따르기** — naming, theme (`AppTheme`), l10n
3. **한 가지 고치면 다른 규칙 깨지지 않게** — 위 표 확인
4. **커밋/PR** — 사용자가 명시적으로 요청할 때만
5. **md 파일** — 사용자 요청 없이 새로 만들지 않음 (이 AGENTS.md는 예외)

## iOS 빌드 & 설치

```bash
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates build

xcrun devicectl device install app --device 00008101-001C1DAE0210001E \
  ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Release-iphoneos/Runner.app
```

## 최근 이슈 (2026-05)

- 키보드 타이핑 + PageView + Material TextField 조합이 iOS에서 UI 깨짐/글자 미표시 유발
- 별도 키보드 Scaffold 분리 시 기도문/메뉴가 사라져 보이는 UX 회귀
- **복구 방향**: 음성 전용 안정 레이아웃 유지 → 타이핑은 나중에 isolated route로 재도전

## 작업 시작 체크리스트

- [ ] 이 파일 + 해당 `.mdc` 규칙 읽음
- [ ] `alarm_screen.dart` / `evening_blessing_screen.dart` 수정 시 소리·STT 규칙 확인
- [ ] `app_launch_gate.dart` / `main.dart` 수정 시 알람 중복 열림 확인
- [ ] 변경 후 `dart analyze` 실행
- [ ] 실기기 테스트 필요 시 Release 빌드 설치
