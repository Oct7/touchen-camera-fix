# TouchEn 때문에 맥 카메라·스크린샷이 안 될 때

맥 카메라가 앱에서 안 잡히는데 진단 모드에서는 정상이라면 TouchEn nxWeb(라온시큐어)이 원인일 수 있습니다.

## 원인

TouchEn nxWeb의 `TouchEN_TEWeb_Agent`(root 데몬)는 보호 값이 1이면 실행 경로에 `SCREEN`·`CAPTURE`·`캡쳐`가 들어간 프로세스를 1초마다 찾아 종료합니다.

- 카메라 서비스 `/usr/libexec/cameracaptured`(CAMERA**CAPTURE**D)가 뜨자마자 종료되어 카메라가 잡히지 않습니다.
- 스크린샷(`screencaptureui`)과 이미지 캡처(`icdd`)도 같이 종료됩니다.
- 보호 값(`/Applications/raonsecure/TouchEnnxWeb/nexweb.dat`의 5번째 바이트)은 은행 페이지를 열면 1이 됩니다. 해제되지 않고 남으면 사이트를 닫아도 계속 막힙니다.
- 진단 모드에서는 TouchEn이 실행되지 않아서 정상입니다.

## 확인

```sh
xxd /Applications/raonsecure/TouchEnnxWeb/nexweb.dat   # 5번째 바이트가 01이면 보호 중
/usr/bin/log show --last 10m --style compact \
  --predicate 'process == "launchd" AND eventMessage CONTAINS "sent by TouchEN"'
```

## 해결

바로 풀기 (관리자 권한 불필요, 은행 사이트를 열면 다시 켜질 수 있음):

```sh
printf '\000' | dd of=/Applications/raonsecure/TouchEnnxWeb/nexweb.dat bs=1 seek=4 count=1 conv=notrunc
```

또는 이 저장소의 **TouchEn 켜기·끄기** 앱으로 TouchEn 에이전트를 끄거나 켭니다.

- 관리자 비밀번호가 필요합니다.
- 끈 상태는 재부팅 후에도 유지됩니다.
- 끄면 은행·관공서 사이트의 화면 캡처 방지가 동작하지 않습니다.

## 빌드

```sh
./build.sh             # build/에 생성
./build.sh ~/Desktop   # 데스크톱에 생성
```

앱 경로에 `SCREEN`·`CAPTURE`·`캡쳐`가 들어가면 TouchEn이 켜져 있을 때 앱도 종료됩니다.

---

라온시큐어와 무관한 비공식 자료입니다. macOS 27.2, Apple Silicon에서 확인했습니다.
