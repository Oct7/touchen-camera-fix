# TouchEn 때문에 맥 카메라·스크린샷이 안 될 때

맥 내장 카메라가 앱에서 잡히지 않는데 진단 모드에서는 정상이라면, 은행·관공서 사이트용 보안 프로그램 **TouchEn nxWeb**(라온시큐어)의 화면 캡처 방지 기능이 원인일 수 있습니다. 이 기능이 macOS 카메라 서비스를 계속 강제 종료하기 때문입니다.

이 저장소에는 원인 분석과, TouchEn 화면 캡처 방지를 켜고 끄는 데스크톱 앱의 소스가 들어 있습니다.

> English summary: TouchEn nxWeb's anti-screen-capture agent kills (SIGTERM) every non-injectable process whose path contains `SCREEN`, `CAPTURE` or `캡쳐`. This includes the macOS camera service `/usr/libexec/cameracaptured` and the screenshot UI.

> 라온시큐어와 관계없는 비공식 자료입니다. 아래 내용은 Mac 한 대에서 시스템 로그와 실행 파일을 직접 분석해 확인한 것입니다.

## 증상

- 내장 카메라가 FaceTime, Photo Booth, 화상회의 앱 등에서 잡히지 않거나, 잠깐 보였다가 사라집니다.
- 스크린샷(⌘⇧3 / ⌘⇧4 / ⌘⇧5)이 안 되거나 도중에 사라집니다.
- 진단 모드로 부팅하면 카메라가 정상입니다.

## 원인

### 1. 화면 캡처 방지 방식: 프로세스 이름으로 골라서 종료

TouchEn nxWeb을 설치하면 `TouchEN_TEWeb_Agent`(`/Applications/raonsecure/TouchEnnxWeb/`)가 LaunchDaemon(`com.raon.TouchEN_TEWeb_Agent`)으로 등록되어 root 권한으로 항상 실행됩니다. 실행 파일을 분석한 동작은 다음과 같습니다.

```
1초마다 반복:
  보호 값 = nexweb.dat 파일의 5번째 바이트
  보호 값이 0이면: 아무것도 하지 않음
  보호 값이 1이면: 아직 검사하지 않은 모든 프로세스에 대해
      화면 보호용 라이브러리(tewebguard.dylib) 주입을 시도
      주입에 실패하면 실행 파일 경로를 대문자로 바꾼 뒤
          "SCREEN", "CAPTURE", "캡쳐" 중 하나라도 들어 있으면 SIGTERM으로 종료
```

macOS 시스템 프로세스는 SIP로 보호되어 주입이 항상 실패합니다. 그래서 경로에 이 단어가 들어간 시스템 프로세스는 모두 종료 대상이 됩니다.

### 2. 최신 macOS 카메라 서비스 이름이 걸림

최신 macOS에서 내장 카메라는 `/usr/libexec/cameracaptured`가 담당합니다. 이 이름을 대문자로 바꾸면 `CAMERACAPTURED`가 되어 **CAPTURE**가 들어 있습니다. 그래서 보호 값이 1인 동안 다음이 반복됩니다.

1. 카메라 서비스가 시작되면 1초 남짓 만에 TouchEn이 종료시킵니다.
2. launchd가 약 10초 뒤 다시 시작하고, 다시 종료되기를 반복합니다.
3. 앱에서는 카메라가 아예 없거나 잠깐 나타났다가 사라집니다.

이 에이전트는 2017년에 만들어진 인텔(x86_64) 전용 프로그램입니다. Apple Silicon에서는 Rosetta로 실행됩니다. 예전 macOS의 카메라 서비스(`VDCAssistant` 등)에는 이 단어들이 없어서 문제가 드러나지 않았던 것으로 보입니다.

같은 규칙에 걸려 함께 종료되는 것들입니다.

| 프로세스 | 걸리는 단어 | 영향 |
|---|---|---|
| `cameracaptured` | CAPTURE | 내장 카메라 |
| `screencaptureui` | SCREEN, CAPTURE | 스크린샷 |
| `icdd` (`/System/Library/Image Capture/…`) | CAPTURE | 이미지 캡처 (아이폰 사진 가져오기 등) |
| `ScreenTimeSettingsAgent`, `ScreenSharingSubscriber` 등 | SCREEN | 스크린타임, 화면 공유 |
| `ContinuityCaptureAgent` | CAPTURE | 연속성 카메라 |

### 3. 보호 값이 1로 남아 버림

은행 페이지가 보호를 요청하면 `TouchEN_TEWeb.app`이 `nexweb.dat`에 보호 값을 기록합니다. 이 값이 0으로 해제되지 않고 남아 있으면, 은행 사이트를 닫은 뒤에도 보호 모드가 계속됩니다. 그동안 카메라와 스크린샷도 계속 막힙니다. 이 저장소를 만든 Mac에서는 마지막으로 기록된 뒤 약 12일 동안 값이 1로 남아 있었습니다.

### 4. 진단 모드에서는 정상인 이유

진단 모드는 별도 환경으로 부팅됩니다. 그래서 TouchEn 같은 서드파티 프로그램이 실행되지 않습니다.

### 5. 가끔 우연히 카메라가 되는 이유 (추정)

에이전트는 프로세스마다 한 번만 검사하고, 통과한 프로세스는 기억해 두었다가 다시 보지 않습니다. 카메라 서비스가 막 생성되어 아직 실행 파일로 바뀌기 전(`xpcproxy` 상태)에 검사되면, 단어에 걸리지 않아 통과로 기록되고 그 뒤로는 종료되지 않습니다. 실제로 약 100번 재시작되는 동안 2번 이렇게 살아남았습니다. 이렇게 살아남아도 카메라 서비스가 다시 시작되면(재부팅, 잠자기 해제 등) 다시 막힙니다.

## 확인 방법

```sh
# 1) 보호 값 확인: 5번째 바이트가 01이면 보호 모드
xxd /Applications/raonsecure/TouchEnnxWeb/nexweb.dat

# 2) TouchEn이 종료시킨 프로세스 목록
#    zsh에서는 log가 내장 명령이므로 /usr/bin/log로 실행해야 합니다.
/usr/bin/log show --last 10m --style compact \
  --predicate 'process == "launchd" AND eventMessage CONTAINS "sent by TouchEN"'

# 3) 카메라 서비스가 짧게 실행되고 종료되기를 반복하는지
/usr/bin/log show --last 10m --style compact \
  --predicate 'process == "launchd" AND subsystem CONTAINS "com.apple.cameracaptured" AND eventMessage CONTAINS "exited due to"'
```

2)에서 `exited due to SIGTERM | sent by TouchEN_TEWeb_Agent`가 반복되고, 3)에서 `ran for 700ms`처럼 짧은 실행이 약 10초 간격으로 반복되면 이 문제입니다. 카메라 서비스는 SIGTERM을 받으면 스스로 정상 종료(`exit(0)`)하기 때문에, 3)에는 누가 종료시켰는지가 남지 않습니다.

검증한 내용은 다음과 같습니다.

- 같은 실행 파일을 경로에 `Capture`가 들어간 폴더와 들어가지 않은 폴더에 하나씩 두고 실행했습니다. 보호 값이 1이면 `Capture` 폴더 쪽만 SIGTERM으로 종료되었고, 0이면 둘 다 정상적으로 끝났습니다.
- 보호 값이 1인 상태에서 카메라 서비스를 재시작하자 14번 연속으로 1초 안에 종료되었습니다. 같은 시간에 스크린샷 서비스는 TouchEn에 의해 109번 종료되었습니다.
- 보호 값을 0으로 바꾸자 종료가 바로 멈췄습니다.

## 해결

### 바로 풀기 (관리자 권한 불필요)

보호 값만 0으로 되돌립니다. 은행 사이트를 다시 열면 다시 1이 될 수 있습니다.

```sh
printf '\000' | dd of=/Applications/raonsecure/TouchEnnxWeb/nexweb.dat bs=1 seek=4 count=1 conv=notrunc
```

### 켜기·끄기 앱

이 저장소의 앱은 TouchEn 화면 캡처 방지 에이전트 자체를 끄고 켭니다. 실행하면 현재 상태를 보여 주고, 켜져 있으면 [끄기], 꺼져 있으면 [켜기] 버튼을 띄웁니다.

- **끄기:** 에이전트를 멈추고, 재부팅해도 다시 켜지지 않게 합니다(`launchctl disable` + `bootout`). 은행 사이트를 열어도 카메라와 스크린샷이 막히지 않습니다.
- **켜기:** 보호 값을 0으로 맞춘 뒤 에이전트를 다시 켭니다(`launchctl enable` + `bootstrap`). 값이 1로 남아 있으면 켜자마자 카메라가 종료되기 때문입니다. 은행 페이지를 열면 TouchEn이 알아서 보호를 켭니다.
- 실행할 때마다 macOS 관리자 비밀번호 창이 뜹니다.
- 키보드 보안(TouchEn nxKey) 등 다른 구성 요소는 건드리지 않습니다.

## 빌드

macOS 기본 도구인 `osacompile`만 있으면 됩니다.

```sh
git clone https://github.com/Oct7/touchen-camera-fix.git
cd touchen-camera-fix
./build.sh              # build/TouchEn 켜기·끄기.app 생성
./build.sh ~/Desktop    # 데스크톱에 바로 생성
```

스크립트 없이 직접 빌드하려면 다음과 같이 합니다.

```sh
osacompile -o "build/TouchEn 켜기·끄기.app" src/touchen-toggle.applescript
```

> 앱을 두는 경로에 `SCREEN`, `CAPTURE`, `캡쳐`(대소문자 무관)가 들어가면, TouchEn이 켜져 있을 때 이 앱도 종료됩니다.

## 주의

- 끄면 은행·관공서 사이트의 화면 캡처 방지가 동작하지 않습니다. 사이트에 따라 보안 프로그램이 동작하지 않는다는 안내가 나올 수 있습니다.
- 확인한 환경은 macOS 27.2, Apple Silicon(M4 Pro), TouchEn nxWeb 에이전트(2017년 빌드)입니다. 다른 버전에서는 경로나 동작이 다를 수 있습니다.
- 사용에 따른 책임은 사용자에게 있습니다.
