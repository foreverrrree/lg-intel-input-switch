# LG Intel Input Switch

Windows hotkeys that switch LG monitor inputs from an Intel GPU.

I put this together because some LG monitors just refuse to respond to normal Windows DDC/CI input switching. It's a small AutoHotkey + PowerShell combo that sends LG's own vendor-specific DDC/CI command through the Intel Graphics Control Library (IGCL) instead.

## English

### Why this exists

A lot of LG monitors happily take ordinary DDC/CI commands — brightness, for example — but input switching is a different story:

- The standard Windows call, `SetVCPFeature` on VCP `0x60`, can report success and still do nothing on screen.
- What actually works on LG monitors is source address `0x50`, VCP `0xF4`, plus an input value.
- If you're on NVIDIA, NvAPI-based tools like `winddc input-alt` usually just work.
- On Intel, there isn't an equivalent, so this project talks to Intel IGCL's `ctlI2CAccess` directly, called from C# embedded in PowerShell.

Here are the LG vendor input values this repo ships with by default:

| Input | Hex | Decimal | Script command |
| --- | ---: | ---: | --- |
| HDMI 1 | `0x90` | `144` | `hdmi1` |
| HDMI 2 | `0x91` | `145` | `hdmi2` |
| DisplayPort | `0xD0` | `208` | `dp` |
| USB-C / Thunderbolt | `0xD1` | `209` | `usbc` |
| USB-C alternate | `0xD2` | `210` | `usbc2` |

Your monitor may not match this table exactly — worth confirming before you assume it's universal.

### Files

- `lg-intel-switch.ps1`: command-line switcher using Intel IGCL.
- `Switch-LGInputs.ahk`: AutoHotkey v2 hotkey wrapper.
- `lg-intel-switch.log`: created at runtime by the AutoHotkey wrapper.

### Requirements

- Windows 10/11.
- An Intel graphics driver with `ControlLib.dll` — Intel drivers normally drop this at `C:\Windows\System32\ControlLib.dll`, so you probably already have it.
- AutoHotkey v2, but only if you want hotkeys.
- PowerShell. You don't need Visual Studio or a separate C# compiler — PowerShell compiles the embedded C# on the fly with `Add-Type`.
- Administrator rights, sometimes. Intel I2C writes can require elevation, which is why the AHK wrapper relaunches itself as admin.

### Installing AutoHotkey

Make sure you grab v2 — v1 won't run this script.

1. Download AutoHotkey v2 from the official site: https://www.autohotkey.com/v2/
2. Run the installer — the defaults are fine here.
3. Double-click `Switch-LGInputs.ahk`.
4. Approve the UAC prompt when it pops up; Intel I2C writes may need admin permission.

Official install guide: https://www.autohotkey.com/docs/v2/howto/Install.htm

### Usage

Start with a scan:

```powershell
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 scan
```

Switch inputs manually:

```powershell
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 hdmi1
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 hdmi2
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 dp
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 usbc
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 usbc2
```

For hotkeys, run `Switch-LGInputs.ahk` and approve the UAC prompt.

Default hotkeys:

| Hotkey | Action |
| --- | --- |
| `Ctrl + Alt + H` | HDMI 1 |
| `Ctrl + Alt + 2` | HDMI 2 |
| `Ctrl + Alt + D` | DisplayPort |
| `Ctrl + Alt + U` | USB-C |
| `Ctrl + Alt + Shift + U` | USB-C alternate |

### Finding Values For Your Monitor

There's no single public table that covers every LG model, so you'll likely need to hunt a bit. Here's the workflow that tends to work:

1. First confirm plain DDC/CI works at all. Tools like `winddc display list detailed`, `ClickMonitorDDC`, or `ControlMyMonitor` should be able to read capabilities or nudge the brightness.
2. Then check whether standard input switching does anything:

```powershell
winddc --display 1 set input 17
winddc --display 1 set input 18
```

If it reports success but nothing actually switches, that's the sign you need LG's vendor-specific path instead.

3. Search around for values other people have already found. These search terms tend to turn up useful threads:

```text
LG monitor input-alt
LG monitor DDC 0xF4
LG monitor source address 0x50
LG monitor ddcutil input source
```

4. Try the common LG vendor values from the table above first — good odds they just work.
5. If yours are different, edit the `$inputValues` map near the top of `lg-intel-switch.ps1`.
6. Run the script by hand a few times before wiring up hotkeys, so you can actually see the return codes:

```powershell
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 usbc
```

A return code of `0x00000000` just means Intel IGCL accepted the transaction — it doesn't guarantee the monitor actually did anything, so glance at the screen to be sure the input changed.

### Notes

The script deliberately tries a handful of different Intel I2C packet variants, because IGCL abstracts low-level transactions a bit differently depending on HDMI vs. DisplayPort vs. USB-C, and even across driver versions:

- `addr6e-off50`
- `addr6e-off50-override`
- `addr37-off50`
- `addr37-off50-override`
- `addr6e-fullpacket`
- `addr6e-fullpacket-override`

If switching doesn't work, check `lg-intel-switch.log` — a successful Intel call always prints `0x00000000`.

### Security Notes

- Read the scripts before you run them. `Switch-LGInputs.ahk` elevates itself via UAC on purpose, since Intel IGCL I2C writes often need admin permission.
- Keep `Switch-LGInputs.ahk` and `lg-intel-switch.ps1` together in a folder you trust — the AHK wrapper just runs the PowerShell script sitting next to it.
- `lg-intel-switch.ps1` only accepts the fixed commands declared in `ValidateSet`: `scan`, `hdmi1`, `hdmi2`, `dp`, `usbc`, and `usbc2`. Nothing else gets through.
- It doesn't download anything, doesn't touch the network, and doesn't write to disk beyond its own runtime log.
- `ExecutionPolicy Bypass` applies only to this one invocation — it won't change your machine-wide PowerShell policy.
- The embedded C# restricts DLL loading to System32 before it calls Intel's `ControlLib.dll`, which cuts down the risk of an unexpected local DLL getting loaded instead.
- The runtime log can contain Intel display output handles and result codes, but nothing like credentials or personal data.

## 한국어

### 이 프로젝트가 필요한 이유

LG 모니터 중에는 밝기 조절 같은 일반 DDC/CI 명령은 곧잘 받아들이면서도, 유독 입력 전환만큼은 표준 방식으로 안 먹히는 경우가 있습니다.

- Windows 표준 VCP `0x60` 입력 전환 명령을 보내면 성공 응답은 오는데, 정작 화면은 그대로인 경우가 많습니다.
- 실제로 먹히는 건 `source address 0x50`, `VCP 0xF4`에 입력값을 얹어 보내는 LG 전용 조합입니다.
- NVIDIA 쓰신다면 `winddc input-alt` 같은 도구로 대부분 해결됩니다.
- 문제는 Intel입니다. 이런 도구가 마땅치 않아서, 이 프로젝트는 Intel IGCL의 `ctlI2CAccess`를 PowerShell에 내장된 C# 코드로 직접 호출하는 방식을 택했습니다.

기본으로 넣어둔 입력값은 이렇습니다:

| 입력 | Hex | Decimal | 스크립트 명령 |
| --- | ---: | ---: | --- |
| HDMI 1 | `0x90` | `144` | `hdmi1` |
| HDMI 2 | `0x91` | `145` | `hdmi2` |
| DisplayPort | `0xD0` | `208` | `dp` |
| USB-C / Thunderbolt | `0xD1` | `209` | `usbc` |
| USB-C 대체값 | `0xD2` | `210` | `usbc2` |

모든 LG 모니터가 같은 값을 쓰는 건 아니라서, 본인 환경에서 한 번은 확인해 보시는 게 좋습니다.

### 설치

단축키까지 쓰려면 AutoHotkey v2가 필요합니다.

1. 공식 사이트에서 AutoHotkey v2를 받습니다: https://www.autohotkey.com/v2/
2. `Switch-LGInputs.ahk`를 더블클릭합니다.
3. UAC 창이 뜨면 승인해 주세요. Intel I2C 쓰기에는 관리자 권한이 필요한 경우가 많습니다.

단축키 없이 PowerShell만 직접 돌려도 됩니다:

```powershell
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 scan
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 hdmi1
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 usbc
```

### 기본 단축키

| 단축키 | 동작 |
| --- | --- |
| `Ctrl + Alt + H` | HDMI 1 |
| `Ctrl + Alt + 2` | HDMI 2 |
| `Ctrl + Alt + D` | DisplayPort |
| `Ctrl + Alt + U` | USB-C |
| `Ctrl + Alt + Shift + U` | USB-C 대체값 |

### 내 모니터 입력값 찾는 법

1. 먼저 DDC/CI 자체가 되는지부터 확인하세요. `winddc display list detailed`, `ClickMonitorDDC`, `ControlMyMonitor` 같은 도구로 밝기 조절이나 capability 조회가 된다면 출발은 나쁘지 않습니다.
2. 그다음 표준 입력 전환이 실제로 되는지 확인합니다.

```powershell
winddc --display 1 set input 17
winddc --display 1 set input 18
```

명령은 성공했다고 뜨는데 화면은 그대로라면, LG 전용 입력 전환 경로가 필요하다는 신호입니다.

3. 아래 검색어로 비슷한 모니터 쓰는 사람들이 찾아낸 값을 뒤져봅니다.

```text
LG monitor input-alt
LG monitor DDC 0xF4
LG monitor source address 0x50
LG monitor ddcutil input source
```

4. 값이 다르면 `lg-intel-switch.ps1` 상단의 `$inputValues`를 고쳐주면 됩니다.
5. 단축키부터 걸지 말고 PowerShell 명령으로 먼저 몇 번 테스트해 보세요. 로그와 반환 코드가 훨씬 잘 보입니다.

`0x00000000`이 떴다고 안심하지 말고, 실제로 모니터 입력이 바뀌었는지는 눈으로 한 번 확인하세요.

### 보안 메모

- 실행하기 전에 스크립트 내용을 한 번 읽어보시길 권합니다.
- `Switch-LGInputs.ahk`는 Intel I2C 쓰기에 관리자 권한이 필요해서 일부러 UAC로 재실행됩니다.
- PowerShell 스크립트는 `scan`, `hdmi1`, `hdmi2`, `dp`, `usbc`, `usbc2` 외의 명령은 받지 않습니다.
- 외부 코드를 내려받지도, 네트워크에 접근하지도, 런타임 로그 외의 파일을 건드리지도 않습니다.
- `ExecutionPolicy Bypass`는 이 한 번의 실행에만 적용되고, 시스템 전체 정책을 바꾸진 않습니다.
- Intel `ControlLib.dll`은 System32 경로에서만 불러오도록 제한해서, 엉뚱한 로컬 DLL이 대신 로드될 위험을 줄였습니다.

## References

- Intel Graphics Control Library: https://github.com/intel/drivers.gpu.control-library
- Windows `winddc`: https://github.com/choplin/winddc
- NVIDIA-oriented LG input switcher that helped document the raw LG command shape: https://github.com/meer-cha/lg-input-switch
- `ddcutil`, useful for investigating VCP capabilities and input values on Linux: https://github.com/rockowitz/ddcutil

## Disclaimer

This sends vendor-specific DDC/CI commands straight to your monitor. It works fine on my LG setup through Intel graphics, but monitor firmware, GPU routing, docks, and USB-C adapters all vary — your mileage may differ. Use at your own risk.

이 스크립트는 모니터에 vendor-specific DDC/CI 명령을 직접 보냅니다. 제 LG + Intel 환경에서는 잘 동작하지만, 모니터 펌웨어나 GPU 연결 경로, 도크, USB-C 어댑터에 따라 결과가 달라질 수 있습니다. 사용은 어디까지나 본인 책임입니다.
