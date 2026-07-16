# LG Intel Input Switch

Windows hotkeys for switching LG monitor inputs from an Intel GPU path.

This is a small AutoHotkey + PowerShell helper for LG monitors that ignore normal Windows DDC/CI input switching. It sends LG's vendor-specific DDC/CI input command through Intel Graphics Control Library (IGCL).

## English

### Why this exists

Some LG monitors accept ordinary controls like brightness through standard DDC/CI, but input switching can be different:

- Standard Windows `SetVCPFeature` / VCP `0x60` may return success while the monitor does nothing.
- The useful LG path is source address `0x50`, VCP `0xF4`, plus an input value.
- NVIDIA users can often use NvAPI-based helpers such as `winddc input-alt`.
- Intel users need a different path. This project uses Intel IGCL's `ctlI2CAccess` through PowerShell-embedded C#.

The default values in this repo are known LG vendor input values:

| Input | Hex | Decimal | Script command |
| --- | ---: | ---: | --- |
| HDMI 1 | `0x90` | `144` | `hdmi1` |
| HDMI 2 | `0x91` | `145` | `hdmi2` |
| DisplayPort | `0xD0` | `208` | `dp` |
| USB-C / Thunderbolt | `0xD1` | `209` | `usbc` |
| USB-C alternate | `0xD2` | `210` | `usbc2` |

Your monitor may use different values. Verify before assuming the table is universal.

### Files

- `lg-intel-switch.ps1`: command-line switcher using Intel IGCL.
- `Switch-LGInputs.ahk`: AutoHotkey v2 hotkey wrapper.
- `lg-intel-switch.log`: created at runtime by the AutoHotkey wrapper.

### Requirements

- Windows 10/11.
- Intel graphics driver with `ControlLib.dll` available. It is usually installed to `C:\Windows\System32\ControlLib.dll` by Intel graphics drivers.
- AutoHotkey v2 if you want hotkeys.
- PowerShell. No C# compiler project or Visual Studio install is required; PowerShell compiles the embedded C# with `Add-Type`.
- Administrator permission may be required for Intel I2C writes. The AHK wrapper relaunches itself elevated.

### Installing AutoHotkey

The hotkey wrapper requires AutoHotkey v2, not v1.

1. Download AutoHotkey v2 from the official site: https://www.autohotkey.com/v2/
2. Run the installer. The default options are fine for this script.
3. Double-click `Switch-LGInputs.ahk`.
4. Approve the UAC prompt. Intel I2C writes may require administrator permission.

Official install guide: https://www.autohotkey.com/docs/v2/howto/Install.htm

### Usage

Run a scan:

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

There is no universal public table for every LG monitor. The practical workflow is:

1. Confirm normal DDC/CI works. Tools like `winddc display list detailed`, `ClickMonitorDDC`, or `ControlMyMonitor` should be able to read capabilities or adjust brightness.
2. Check whether standard input switching works:

```powershell
winddc --display 1 set input 17
winddc --display 1 set input 18
```

If the command says success but the monitor does not switch, your monitor may need LG's vendor-specific path.

3. Search for values reported by other users. Useful search terms:

```text
LG monitor input-alt
LG monitor DDC 0xF4
LG monitor source address 0x50
LG monitor ddcutil input source
```

4. Try the common LG vendor values listed above.
5. If your values differ, edit the `$inputValues` map near the top of `lg-intel-switch.ps1`.
6. Run the script manually first so you can see return codes:

```powershell
powershell -ExecutionPolicy Bypass -File .\lg-intel-switch.ps1 usbc
```

Return code `0x00000000` means Intel IGCL accepted that transaction. It does not always guarantee the monitor acted on it, so visually confirm the input changed.

### Notes

The script intentionally tries several Intel I2C packet variants because IGCL abstracts low-level transactions differently across HDMI, DisplayPort, USB-C, and driver versions:

- `addr6e-off50`
- `addr6e-off50-override`
- `addr37-off50`
- `addr37-off50-override`
- `addr6e-fullpacket`
- `addr6e-fullpacket-override`

If switching fails, check `lg-intel-switch.log`. A successful Intel call prints `0x00000000`.

### Security Notes

- Read the scripts before running them. `Switch-LGInputs.ahk` intentionally elevates itself with UAC because Intel IGCL I2C writes may require administrator permission.
- Keep `Switch-LGInputs.ahk` and `lg-intel-switch.ps1` in a trusted folder. The AHK wrapper runs the PowerShell script next to it.
- `lg-intel-switch.ps1` accepts only the fixed commands declared in `ValidateSet`: `scan`, `hdmi1`, `hdmi2`, `dp`, `usbc`, and `usbc2`.
- The script does not download code, access the network, modify files except the runtime log, or persist system settings.
- `ExecutionPolicy Bypass` is used only for this one script invocation. It does not change the machine-wide PowerShell execution policy.
- The embedded C# restricts DLL loading to System32 before calling Intel `ControlLib.dll`, reducing the chance of loading an unexpected local DLL.
- The runtime log may include Intel display output handles and result codes, but it should not contain credentials or personal data.

## 한국어

### 이 프로젝트가 필요한 이유

일부 LG 모니터는 밝기 조절 같은 일반 DDC/CI 명령은 잘 받지만, 입력 전환은 표준 방식으로 동작하지 않을 수 있습니다.

- Windows 표준 VCP `0x60` 입력 전환 명령은 성공처럼 보여도 실제 화면 입력이 바뀌지 않을 수 있습니다.
- LG 입력 전환에는 `source address 0x50`, `VCP 0xF4`, 입력값 조합이 필요한 경우가 있습니다.
- NVIDIA 경로에서는 `winddc input-alt` 같은 도구가 동작할 수 있습니다.
- Intel 경로에서는 별도 방식이 필요해서, 이 프로젝트는 Intel IGCL의 `ctlI2CAccess`를 PowerShell 안의 C# 코드로 호출합니다.

기본 입력값:

| 입력 | Hex | Decimal | 스크립트 명령 |
| --- | ---: | ---: | --- |
| HDMI 1 | `0x90` | `144` | `hdmi1` |
| HDMI 2 | `0x91` | `145` | `hdmi2` |
| DisplayPort | `0xD0` | `208` | `dp` |
| USB-C / Thunderbolt | `0xD1` | `209` | `usbc` |
| USB-C 대체값 | `0xD2` | `210` | `usbc2` |

모든 LG 모니터에서 같은 값이 보장되는 것은 아니니, 본인 환경에서 확인해 주세요.

### 설치

단축키를 쓰려면 AutoHotkey v2가 필요합니다.

1. 공식 사이트에서 AutoHotkey v2를 설치합니다: https://www.autohotkey.com/v2/
2. `Switch-LGInputs.ahk`를 더블클릭합니다.
3. UAC 관리자 권한 요청이 뜨면 승인합니다. Intel I2C 쓰기에는 관리자 권한이 필요할 수 있습니다.

PowerShell만 직접 실행할 수도 있습니다:

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

1. 먼저 DDC/CI 자체가 되는지 확인합니다. `winddc display list detailed`, `ClickMonitorDDC`, `ControlMyMonitor` 같은 도구로 밝기나 capability가 읽히면 출발점은 좋습니다.
2. 표준 입력 전환이 되는지 확인합니다.

```powershell
winddc --display 1 set input 17
winddc --display 1 set input 18
```

명령은 성공하는데 실제 입력이 바뀌지 않으면 LG 전용 입력 전환 경로가 필요할 수 있습니다.

3. 아래 검색어로 같은 계열 사용자의 값을 찾아봅니다.

```text
LG monitor input-alt
LG monitor DDC 0xF4
LG monitor source address 0x50
LG monitor ddcutil input source
```

4. 값이 다르면 `lg-intel-switch.ps1` 상단의 `$inputValues`를 수정합니다.
5. 단축키보다 PowerShell 명령으로 먼저 테스트하면 로그와 반환 코드를 보기 쉽습니다.

성공처럼 보이는 `0x00000000`이 떠도 실제 모니터가 바뀌었는지는 눈으로 확인해야 합니다.

### 보안 메모

- 실행 전에 스크립트를 읽어보는 것을 권장합니다.
- AHK 파일은 Intel I2C 쓰기 권한 때문에 UAC 관리자 권한으로 다시 실행됩니다.
- PowerShell 스크립트는 `scan`, `hdmi1`, `hdmi2`, `dp`, `usbc`, `usbc2` 명령만 받습니다.
- 외부 다운로드, 네트워크 접근, 시스템 설정 영구 변경은 하지 않습니다.
- `ExecutionPolicy Bypass`는 해당 실행 한 번에만 적용되며 시스템 정책을 바꾸지 않습니다.
- Intel `ControlLib.dll`은 System32에서만 로드하도록 제한했습니다.

## References

- Intel Graphics Control Library: https://github.com/intel/drivers.gpu.control-library
- Windows `winddc`: https://github.com/choplin/winddc
- NVIDIA-oriented LG input switcher that helped document the raw LG command shape: https://github.com/meer-cha/lg-input-switch
- `ddcutil`, useful for investigating VCP capabilities and input values on Linux: https://github.com/rockowitz/ddcutil

## Disclaimer

This sends vendor-specific DDC/CI commands to the monitor. It worked for my LG setup through Intel graphics, but monitor firmware, GPU routing, docks, and USB-C adapters can change behavior. Use at your own risk.

이 스크립트는 모니터에 vendor-specific DDC/CI 명령을 보냅니다. 모니터 펌웨어, GPU 연결 경로, 도크, USB-C 어댑터에 따라 동작이 달라질 수 있습니다. 사용은 본인 책임입니다.
