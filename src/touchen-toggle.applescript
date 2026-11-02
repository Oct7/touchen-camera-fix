-- TouchEn 켜기·끄기
-- TouchEn nxWeb 화면 캡처 방지 데몬(com.raon.TouchEN_TEWeb_Agent)을 끄고 켭니다.
-- 이 데몬은 보호 값(nexweb.dat 5번째 바이트)이 1이면 경로에 SCREEN/CAPTURE/캡쳐가 들어간
-- 프로세스(카메라 서비스 cameracaptured, 스크린샷 screencaptureui 등)를 강제 종료합니다.

property serviceLabel : "com.raon.TouchEN_TEWeb_Agent"
property plistPath : "/Library/LaunchDaemons/com.raon.TouchEN_TEWeb_Agent.plist"
property flagPath : "/Applications/raonsecure/TouchEnnxWeb/nexweb.dat"
property appTitle : "TouchEn 켜기·끄기"

on isRunning()
	try
		do shell script "/bin/launchctl print system/" & serviceLabel & " | /usr/bin/grep -q 'state = running'"
		return true
	on error
		return false
	end try
end isRunning

-- 끄기: 재부팅해도 다시 켜지지 않도록 disable 후 내림
on offCommand()
	return "/bin/launchctl disable system/" & serviceLabel & "; /bin/launchctl bootout system/" & serviceLabel & " 2>/dev/null; true"
end offCommand

-- 켜기: 보호 값이 1로 남아 있으면 켜자마자 카메라가 죽으므로 0으로 맞춘 뒤 켬
-- (은행 페이지를 열면 TouchEn이 알아서 1로 바꿈)
on onCommand()
	return "printf '\\000' | /bin/dd of=" & quoted form of flagPath & " bs=1 seek=4 count=1 conv=notrunc 2>/dev/null; /bin/launchctl enable system/" & serviceLabel & "; /bin/launchctl bootstrap system " & quoted form of plistPath & " 2>/dev/null || /bin/launchctl kickstart system/" & serviceLabel & "; true"
end onCommand

on run
	set wasRunning to isRunning()
	if wasRunning then
		set msg to "TouchEn 화면 캡처 방지가 켜져 있습니다." & return & return & "끄면 카메라와 스크린샷이 TouchEn 때문에 막히지 않습니다. 대신 은행·관공서 사이트의 화면 캡처 방지가 동작하지 않습니다."
		set actionLabel to "끄기"
		set cmd to offCommand()
	else
		set msg to "TouchEn 화면 캡처 방지가 꺼져 있습니다." & return & return & "켜 두면 은행·관공서 사이트를 쓰는 동안 카메라와 스크린샷이 막힐 수 있습니다."
		set actionLabel to "켜기"
		set cmd to onCommand()
	end if

	display dialog msg buttons {"취소", actionLabel} default button actionLabel cancel button "취소" with title appTitle

	do shell script cmd with administrator privileges

	-- 상태가 바뀔 때까지 최대 15초 확인 (TouchEn이 처음 실행에 실패하면 launchd가 10초 뒤 재시도함)
	set nowRunning to wasRunning
	repeat 15 times
		set nowRunning to isRunning()
		if nowRunning is not wasRunning then exit repeat
		delay 1
	end repeat

	if nowRunning is not wasRunning then
		if nowRunning then
			set resultMsg to "TouchEn을 켰습니다."
		else
			set resultMsg to "TouchEn을 껐습니다."
		end if
	else
		if nowRunning then
			set resultMsg to "상태가 바뀌지 않았습니다. (현재: 켜짐)"
		else
			set resultMsg to "상태가 바뀌지 않았습니다. (현재: 꺼짐)"
		end if
	end if
	display dialog resultMsg buttons {"확인"} default button "확인" with title appTitle
end run
