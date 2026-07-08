@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Ultimate YT-DLP Manager v5.6

rem ============================================================================
rem Ultimate YT-DLP Manager v5.6
rem - Auto-installs yt-dlp, ffmpeg, YTSubConverter
rem - AV1-preferred downloads with MKV output
rem - Keeps external .ass fallback for VLC
rem - Verifies subtitle stream exists in final MKV
rem - Direct playlist download with YouTube-style subtitles
rem - Playlist subtitle repair for existing folders
rem ============================================================================

rem ============================================================================
rem DEFAULT CONFIG
rem ============================================================================
set "CONFIG_FILE=%~dp0ytdlp_config.ini"
set "min_space_mb=100"
set "download_subtitles=YES"
set "subtitle_language=en"
set "auto_switch_drives=NO"
set "avg_download_speed=5"
set "delete_after_convert=ASK"
set "youtube_style_subtitles=YES"
set "ytsubconverter_path="
set "prefer_av1=YES"

color 0A
cls
call :load_settings
call :check_dependencies
call :main_menu
exit /b 0

rem ============================================================================
rem MAIN MENU
rem ============================================================================
:main_menu
cls
echo ================================================================================
echo   Ultimate YT-DLP Manager v5.6
echo   Config: %CONFIG_FILE%
echo ================================================================================
echo.
echo   [1]  Single Video Download
echo   [2]  Playlist Download  (Standard)
echo   [3]  Multiple Playlists
echo   [4]  Download from URL List File
echo   [5]  Audio Only Download
echo   [6]  Smart Download
echo   [7]  Merge Audio + Video Files
echo   [8]  Convert Video Files
echo   [9]  Utilities
echo   [10] YouTube-Style Subtitles Download (Single Video)
echo   [11] Playlist Subtitle Repair (Existing Files)
echo   [12] Playlist Download + YouTube-Style Subtitles
echo   [S]  Settings
echo   [Q]  Quit
echo.
echo ================================================================================
set "menu_choice="
set /p "menu_choice=  Select an option: "
call :trim_var menu_choice

if /i "!menu_choice!"=="1"  ( call :single_video_download & goto :main_menu )
if /i "!menu_choice!"=="2"  ( call :playlist_download & goto :main_menu )
if /i "!menu_choice!"=="3"  ( call :multi_playlist_download & goto :main_menu )
if /i "!menu_choice!"=="4"  ( call :url_list_download & goto :main_menu )
if /i "!menu_choice!"=="5"  ( call :audio_only_download & goto :main_menu )
if /i "!menu_choice!"=="6"  ( call :smart_download & goto :main_menu )
if /i "!menu_choice!"=="7"  ( call :merge_audio_video & goto :main_menu )
if /i "!menu_choice!"=="8"  ( call :convert_video_files & goto :main_menu )
if /i "!menu_choice!"=="9"  ( call :utilities_menu & goto :main_menu )
if /i "!menu_choice!"=="10" ( call :styled_subtitle_download & goto :main_menu )
if /i "!menu_choice!"=="11" ( call :playlist_subtitle_repair & goto :main_menu )
if /i "!menu_choice!"=="12" ( call :playlist_download_styled_full & goto :main_menu )
if /i "!menu_choice!"=="S"  ( call :settings_menu & goto :main_menu )
if /i "!menu_choice!"=="Q"  goto :exit_script

echo.
echo   [!] Invalid option. Press any key...
pause >nul
goto :main_menu

rem ============================================================================
rem HELPERS
rem ============================================================================
:trim_var
setlocal EnableDelayedExpansion
set "_tv=!%~1!"
if not defined _tv (
    endlocal & set "%~1=" & goto :eof
)
for /f "tokens=* delims= " %%A in ("!_tv!") do set "_tv=%%A"
:trim_var_right
if defined _tv if "!_tv:~-1!"==" " (
    set "_tv=!_tv:~0,-1!"
    goto :trim_var_right
)
for /f "delims=" %%A in ("!_tv!") do endlocal & set "%~1=%%~A"
goto :eof

:normalize_yes_no
call :trim_var %~1
if /i "!%~1!"=="YES" ( set "%~1=YES" & goto :eof )
if /i "!%~1!"=="NO"  ( set "%~1=NO" & goto :eof )
set "%~1=%~2"
goto :eof

:normalize_yes_no_ask
call :trim_var %~1
if /i "!%~1!"=="YES" ( set "%~1=YES" & goto :eof )
if /i "!%~1!"=="NO"  ( set "%~1=NO" & goto :eof )
if /i "!%~1!"=="ASK" ( set "%~1=ASK" & goto :eof )
set "%~1=%~2"
goto :eof

:_validate_numeric
set "_vn=%~1"
set "_vd=%~2"
set "_vv=!%_vn%!"
call :trim_var _vv
if "!_vv!"=="" (
    set "%_vn%=!_vd!"
    goto :eof
)
set "_vt=!_vv!"
for /f "delims=0123456789" %%C in ("!_vt!") do set "_vt=NaN"
if "!_vt!"=="NaN" (
    set "%_vn%=!_vd!"
    goto :eof
)
if "!_vv!"=="0" (
    set "%_vn%=!_vd!"
    goto :eof
)
set "%_vn%=!_vv!"
goto :eof

:sanitize_settings
call :trim_var min_space_mb
call :trim_var download_subtitles
call :trim_var subtitle_language
call :trim_var auto_switch_drives
call :trim_var avg_download_speed
call :trim_var delete_after_convert
call :trim_var youtube_style_subtitles
call :trim_var ytsubconverter_path
call :trim_var prefer_av1

call :normalize_yes_no download_subtitles YES
call :normalize_yes_no auto_switch_drives NO
call :normalize_yes_no youtube_style_subtitles YES
call :normalize_yes_no prefer_av1 YES
call :normalize_yes_no_ask delete_after_convert ASK
call :_validate_numeric min_space_mb 100
call :_validate_numeric avg_download_speed 5
if "!subtitle_language!"=="" set "subtitle_language=en"
goto :eof

:file_nonzero
set "%~2=0"
powershell -NoProfile -Command "if ((Test-Path '%~1') -and ((Get-Item '%~1').Length -gt 0)) { exit 0 } else { exit 1 }" >nul 2>&1
if not errorlevel 1 set "%~2=1"
goto :eof

:has_subtitle_stream
set "%~2=0"
where ffprobe >nul 2>&1
if errorlevel 1 goto :eof
for /f "usebackq delims=" %%S in (`ffprobe -v error -select_streams s -show_entries stream^=codec_name -of csv^=p^=0 "%~1" 2^>nul`) do (
    set "%~2=1"
    goto :eof
)
goto :eof

:validate_url
set "URL_VALID=0"
set "_url_prefix=!DOWNLOAD_URL:~0,4!"
if /i "!_url_prefix!"=="http" set "URL_VALID=1"
if "!URL_VALID!"=="0" (
    echo   [ERR] Invalid URL: "!DOWNLOAD_URL!"
    echo   [ERR] URL must begin with http:// or https://
)
goto :eof

rem ============================================================================
rem CONFIG
rem ============================================================================
:load_settings
if not exist "!CONFIG_FILE!" (
    call :sanitize_settings
    goto :eof
)
for /f "usebackq eol=; tokens=1,* delims==" %%A in ("!CONFIG_FILE!") do (
    set "lk=%%A"
    set "lv=%%B"
    call :trim_var lk
    call :trim_var lv
    if /i "!lk!"=="min_space_mb"             set "min_space_mb=!lv!"
    if /i "!lk!"=="download_subtitles"       set "download_subtitles=!lv!"
    if /i "!lk!"=="subtitle_language"        set "subtitle_language=!lv!"
    if /i "!lk!"=="auto_switch_drives"       set "auto_switch_drives=!lv!"
    if /i "!lk!"=="avg_download_speed"       set "avg_download_speed=!lv!"
    if /i "!lk!"=="delete_after_convert"     set "delete_after_convert=!lv!"
    if /i "!lk!"=="youtube_style_subtitles"  set "youtube_style_subtitles=!lv!"
    if /i "!lk!"=="ytsubconverter_path"      set "ytsubconverter_path=!lv!"
    if /i "!lk!"=="prefer_av1"               set "prefer_av1=!lv!"
)
call :sanitize_settings
goto :eof

:save_settings
call :sanitize_settings
(
    echo ; Ultimate YT-DLP Manager v5.6 - Config File
    echo min_space_mb=!min_space_mb!
    echo download_subtitles=!download_subtitles!
    echo subtitle_language=!subtitle_language!
    echo auto_switch_drives=!auto_switch_drives!
    echo avg_download_speed=!avg_download_speed!
    echo delete_after_convert=!delete_after_convert!
    echo youtube_style_subtitles=!youtube_style_subtitles!
    echo ytsubconverter_path=!ytsubconverter_path!
    echo prefer_av1=!prefer_av1!
) > "!CONFIG_FILE!"
echo   [OK] Settings saved to: !CONFIG_FILE!
goto :eof

rem ============================================================================
rem DEPENDENCIES
rem ============================================================================
:check_dependencies
cls
echo ================================================================================
echo   Dependency Check
echo ================================================================================
set "_dep_missing=0"

where yt-dlp >nul 2>&1
if errorlevel 1 (
    echo   [!!] yt-dlp NOT found.
    set "_dep_missing=1"
    call :install_ytdlp
) else (
    echo   [OK] yt-dlp found in PATH.
)

where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo   [!!] ffmpeg NOT found.
    set "_dep_missing=1"
    call :install_ffmpeg
) else (
    echo   [OK] ffmpeg found in PATH.
)

call :check_ytsubconverter
echo.
if "!_dep_missing!"=="1" (
    echo   Press any key to continue to the main menu...
    pause >nul
)
goto :eof

:check_ytsubconverter
if /i "!youtube_style_subtitles!"=="NO" (
    echo   [INFO] YouTube-style subtitles are disabled in Settings.
    goto :eof
)
if "!ytsubconverter_path!"=="" (
    echo   [INFO] YTSubConverter: not configured.
    echo   [INFO] The script can install it automatically when needed.
    goto :eof
)
if exist "!ytsubconverter_path!" (
    echo   [OK] YTSubConverter found: !ytsubconverter_path!
) else (
    echo   [WARN] YTSubConverter path is set but file is missing.
)
goto :eof

:ensure_ytsubconverter
if not "!ytsubconverter_path!"=="" if exist "!ytsubconverter_path!" goto :eof
echo.
echo   [INFO] YTSubConverter is required for YouTube-style subtitles.
call :install_ytsubconverter
goto :eof

:install_ytsubconverter
set "ytsc_choice="
set /p "ytsc_choice=  Install YTSubConverter automatically? (Y/N): "
call :trim_var ytsc_choice
if /i not "!ytsc_choice!"=="Y" (
    echo   [SKIP] YTSubConverter install skipped.
    goto :eof
)
set "ytsc_dir=%USERPROFILE%\bin\YTSubConverter"
set "ytsc_exe=!ytsc_dir!\YTSubConverter.exe"
if not exist "!ytsc_dir!" mkdir "!ytsc_dir!" >nul 2>&1
echo   [..] Downloading YTSubConverter.exe...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$url='https://github.com/arcusmaximus/YTSubConverter/releases/download/1.6.3/YTSubConverter.exe'; try { Invoke-WebRequest -Uri $url -OutFile '%USERPROFILE%\bin\YTSubConverter\YTSubConverter.exe' -UseBasicParsing; Write-Host '[OK] Downloaded.' } catch { Write-Host '[ERR] ' + $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo   [ERR] Failed to download YTSubConverter.
    goto :eof
)
if not exist "!ytsc_exe!" (
    echo   [ERR] Download did not produce the expected file.
    goto :eof
)
set "ytsubconverter_path=!ytsc_exe!"
call :save_settings
call :_setx_safe "!ytsc_dir!"
echo   [OK] YTSubConverter installed: !ytsubconverter_path!
goto :eof

:_setx_safe
set "_new_entry=%~1"
set "cur_path="
for /f "usebackq tokens=2*" %%A in (`reg query "HKCU\Environment" /v PATH 2^>nul`) do set "cur_path=%%B"
if "!cur_path!"=="" set "cur_path=%PATH%"
echo !cur_path! | findstr /i /c:"!_new_entry!" >nul 2>&1
if not errorlevel 1 goto :eof
set "_new_path=!cur_path!;!_new_entry!"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment',$true).SetValue('PATH','!_new_path!',[Microsoft.Win32.RegistryValueKind]::ExpandString) } catch { exit 1 }"
goto :eof

:install_ytdlp
echo.
set "inst_choice="
set /p "inst_choice=  Install yt-dlp automatically? (Y/N): "
call :trim_var inst_choice
if /i not "!inst_choice!"=="Y" goto :eof
set "ytdlp_dir=%USERPROFILE%\bin"
if not exist "!ytdlp_dir!" mkdir "!ytdlp_dir!" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Invoke-WebRequest -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile '%USERPROFILE%\bin\yt-dlp.exe' -UseBasicParsing } catch { exit 1 }"
call :_setx_safe "!ytdlp_dir!"
goto :eof

:install_ffmpeg
echo.
set "ff_choice="
set /p "ff_choice=  Install ffmpeg automatically? (Y/N): "
call :trim_var ff_choice
if /i not "!ff_choice!"=="Y" goto :eof
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%TEMP%\ffmpeg.zip' -UseBasicParsing } catch { exit 1 }"
if errorlevel 1 goto :eof
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Expand-Archive -Path '%TEMP%\ffmpeg.zip' -DestinationPath '%USERPROFILE%\ffmpeg_tmp' -Force; $d = Get-ChildItem '%USERPROFILE%\ffmpeg_tmp' -Directory | Select-Object -First 1; if ($d) { if (Test-Path '%USERPROFILE%\ffmpeg') { Remove-Item '%USERPROFILE%\ffmpeg' -Recurse -Force }; Move-Item $d.FullName '%USERPROFILE%\ffmpeg'; Remove-Item '%USERPROFILE%\ffmpeg_tmp' -Recurse -Force } } catch { exit 1 }"
set "ff_bin=%USERPROFILE%\ffmpeg\bin"
call :_setx_safe "!ff_bin!"
goto :eof

rem ============================================================================
rem DRIVE / OUTPUT
rem ============================================================================
:scan_drives
set "drive_count=0"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' } | ForEach-Object { $f=[math]::Round($_.Free/1GB,2); $u=[math]::Round($_.Used/1GB,2); Write-Output ($_.Root + '|' + $f + '|' + $u) }" > "%TEMP%\_ytdlp_drives.tmp" 2>nul
for /f "usebackq tokens=1,2,3 delims=|" %%A in ("%TEMP%\_ytdlp_drives.tmp") do (
    set /a "drive_count+=1"
    set "drive_letter[!drive_count!]=%%A"
    set "drive_free[!drive_count!]=%%B"
    set "drive_used[!drive_count!]=%%C"
)
del "%TEMP%\_ytdlp_drives.tmp" >nul 2>&1
echo.
echo   ════════════════════════════════════════════════════════════════════════════════
echo    #    Drive    Free (GB)    Used (GB)
echo   ════════════════════════════════════════════════════════════════════════════════
for /l %%i in (1,1,!drive_count!) do echo    [%%i]  !drive_letter[%%i]!      !drive_free[%%i]! GB free     !drive_used[%%i]! GB used
echo    [C]  Enter a custom path
echo   ════════════════════════════════════════════════════════════════════════════════
goto :eof

:select_output_path
call :scan_drives
echo.
set "OUTPATH="
set "drive_sel="
set /p "drive_sel=  Select drive [number] or [C] for custom path: "
call :trim_var drive_sel
if /i "!drive_sel!"=="C" (
    set /p "OUTPATH=  Enter full path: "
    call :trim_var OUTPATH
) else (
    set "valid_sel=0"
    for /l %%i in (1,1,!drive_count!) do if "!drive_sel!"=="%%i" (
        set "valid_sel=1"
        set "OUTPATH=!drive_letter[%%i]!"
    )
    if "!valid_sel!"=="0" set "OUTPATH=%CD%"
)
if "!OUTPATH!"=="" set "OUTPATH=%CD%"
if "!OUTPATH:~-1!"=="\" set "OUTPATH=!OUTPATH:~0,-1!"
if "!OUTPATH:~2!"=="" set "OUTPATH=!OUTPATH!\YTVIDS"
if not exist "!OUTPATH!" mkdir "!OUTPATH!" >nul 2>&1
echo   [>>] Output path: !OUTPATH!
goto :eof

rem ============================================================================
rem QUALITY / AV1
rem ============================================================================
:select_quality
cls
echo ================================================================================
echo   Quality Selection
echo ================================================================================
echo.
echo   [1]  Best Quality
echo   [2]  4K / 2160p
echo   [3]  1080p
echo   [4]  720p
echo   [5]  480p
echo.
echo   AV1 preference: !prefer_av1!
echo.
set "qual_sel="
set /p "qual_sel=  Select quality: "
call :trim_var qual_sel
if "!qual_sel!"=="" set "qual_sel=1"

if /i "!prefer_av1!"=="YES" (
    if "!qual_sel!"=="1" set "QUALITY_FLAG=-f ""bestvideo[vcodec*=av01]+bestaudio/bestvideo+bestaudio/best"""
    if "!qual_sel!"=="2" set "QUALITY_FLAG=-f ""bestvideo[vcodec*=av01][height<=2160]+bestaudio/bestvideo[height<=2160]+bestaudio/best"""
    if "!qual_sel!"=="3" set "QUALITY_FLAG=-f ""bestvideo[vcodec*=av01][height<=1080]+bestaudio/bestvideo[height<=1080]+bestaudio/best"""
    if "!qual_sel!"=="4" set "QUALITY_FLAG=-f ""bestvideo[vcodec*=av01][height<=720]+bestaudio/bestvideo[height<=720]+bestaudio/best"""
    if "!qual_sel!"=="5" set "QUALITY_FLAG=-f ""bestvideo[vcodec*=av01][height<=480]+bestaudio/bestvideo[height<=480]+bestaudio/best"""
) else (
    if "!qual_sel!"=="1" set "QUALITY_FLAG=-f bestvideo+bestaudio/best"
    if "!qual_sel!"=="2" set "QUALITY_FLAG=-f bestvideo[height<=2160]+bestaudio/best"
    if "!qual_sel!"=="3" set "QUALITY_FLAG=-f bestvideo[height<=1080]+bestaudio/best"
    if "!qual_sel!"=="4" set "QUALITY_FLAG=-f bestvideo[height<=720]+bestaudio/best"
    if "!qual_sel!"=="5" set "QUALITY_FLAG=-f bestvideo[height<=480]+bestaudio/best"
)
if "!QUALITY_FLAG!"=="" set "QUALITY_FLAG=-f bestvideo+bestaudio/best"
echo   [OK] Quality flag: !QUALITY_FLAG!
goto :eof

rem ============================================================================
rem ESTIMATION / SPACE
rem ============================================================================
:estimate_download
set "EST_SIZE_MB=0"
if "!IS_PLAYLIST!"=="" set "IS_PLAYLIST=0"
echo.
echo   [..] Estimating download size...
if "!IS_PLAYLIST!"=="1" (
    set "total_mb=0"
    for /f "usebackq delims=" %%S in (`yt-dlp --flat-playlist --print "%%(filesize,filesize_approx)s" "!DOWNLOAD_URL!" 2^>nul`) do (
        set "sz=%%S"
        if not "!sz!"=="NA" if not "!sz!"=="" (
            for /f "tokens=1 delims=." %%N in ("!sz!") do set "sz_int=%%N"
            set /a "total_mb+=!sz_int!/1048576" 2>nul
        )
    )
    set "EST_SIZE_MB=!total_mb!"
) else (
    for /f "usebackq delims=" %%S in (`yt-dlp --print "%%(filesize,filesize_approx)s" "!DOWNLOAD_URL!" 2^>nul`) do (
        if "!EST_SIZE_MB!"=="0" (
            if not "%%S"=="NA" if not "%%S"=="" (
                for /f "tokens=1 delims=." %%N in ("%%S") do set /a "EST_SIZE_MB=%%N/1048576" 2>nul
            )
        )
    )
)
if "!EST_SIZE_MB!"=="0" (
    echo   [WARN] Could not estimate size.
    goto :eof
)
set /a "est_total_sec=!EST_SIZE_MB!/!avg_download_speed!"
set /a "est_hours=!est_total_sec!/3600"
set /a "est_rem=!est_total_sec!%%3600"
set /a "est_min=!est_rem!/60"
set /a "est_sec=!est_rem!%%60"
echo   Estimated size : ~!EST_SIZE_MB! MB
echo   Estimated time : !est_hours!h !est_min!m !est_sec!s
goto :eof

:find_alternate_drive
set "ALT_DRIVE="
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' } | ForEach-Object { $f=[math]::Round($_.Free/1MB,0); Write-Output ($_.Root + '|' + $f) }" > "%TEMP%\_ytdlp_alt.tmp" 2>nul
set "_cur_root=!OUTPATH:~0,2!\"
for /f "usebackq tokens=1,2 delims=|" %%A in ("%TEMP%\_ytdlp_alt.tmp") do (
    if "!ALT_DRIVE!"=="" if /i not "%%A"=="!_cur_root!" (
        set /a "cand_rem=%%B-!EST_SIZE_MB!"
        if !cand_rem! GEQ !min_space_mb! set "ALT_DRIVE=%%AYTVIDS"
    )
)
del "%TEMP%\_ytdlp_alt.tmp" >nul 2>&1
goto :eof

:check_space_and_maybe_switch
set "SPACE_OK=1"
set "check_drive_letter=!OUTPATH:~0,1!"
set "free_mb="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive -Name '!check_drive_letter!' -ErrorAction SilentlyContinue).Free/1MB,0)" 2^>nul`) do set "free_mb=%%F"
if "!free_mb!"=="" goto :eof
set /a "space_remain=!free_mb!-!EST_SIZE_MB!"
if !space_remain! GEQ !min_space_mb! goto :eof
if /i "!auto_switch_drives!"=="YES" (
    call :find_alternate_drive
    if "!ALT_DRIVE!"=="" (
        set "SPACE_OK=0"
    ) else (
        set "OUTPATH=!ALT_DRIVE!"
        if not exist "!OUTPATH!" mkdir "!OUTPATH!" >nul 2>&1
    )
) else (
    set "SPACE_OK=0"
)
goto :eof

rem ============================================================================
rem STANDARD DOWNLOADS
rem ============================================================================
:single_video_download
cls
echo ================================================================================
echo   Single Video Download
echo ================================================================================
echo.
set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=  Enter video URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" ( pause & goto :eof )
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )
set "IS_PLAYLIST=0"
call :select_quality
call :select_output_path
call :estimate_download
set "conf="
set /p "conf=  Proceed with download? (Y/N): "
call :trim_var conf
if /i not "!conf!"=="Y" goto :eof
call :check_space_and_maybe_switch
if "!SPACE_OK!"=="0" ( echo   [ERR] Insufficient space. & pause & goto :eof )
set "SUBTITLE_FLAGS="
set "MERGE_FORMAT=mkv"
if /i "!download_subtitles!"=="YES" set "SUBTITLE_FLAGS=--write-subs --write-auto-subs --sub-langs !subtitle_language! --convert-subs srt --embed-subs"
yt-dlp !QUALITY_FLAG! --no-playlist --merge-output-format !MERGE_FORMAT! --output "!OUTPATH!\%%(title)s.%%(ext)s" --retries 10 --fragment-retries 10 !SUBTITLE_FLAGS! "!DOWNLOAD_URL!"
pause
goto :eof

:playlist_download
cls
echo ================================================================================
echo   Playlist Download (Standard)
echo ================================================================================
echo.
set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=  Enter playlist URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" ( pause & goto :eof )
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )
set "IS_PLAYLIST=1"
call :select_quality
call :select_output_path
call :estimate_download
set "conf="
set /p "conf=  Proceed with download? (Y/N): "
call :trim_var conf
if /i not "!conf!"=="Y" goto :eof
call :check_space_and_maybe_switch
if "!SPACE_OK!"=="0" ( echo   [ERR] Insufficient space. & pause & goto :eof )
set "SUBTITLE_FLAGS="
set "MERGE_FORMAT=mkv"
if /i "!download_subtitles!"=="YES" set "SUBTITLE_FLAGS=--write-subs --write-auto-subs --sub-langs !subtitle_language! --convert-subs srt --embed-subs"
set "archive_file=!OUTPATH!\yt_archive.txt"
yt-dlp !QUALITY_FLAG! --merge-output-format !MERGE_FORMAT! --output "!OUTPATH!\%%(playlist_index)s - %%(title)s.%%(ext)s" --download-archive "!archive_file!" --retries 10 --fragment-retries 10 !SUBTITLE_FLAGS! "!DOWNLOAD_URL!"
pause
goto :eof

:multi_playlist_download
cls
echo ================================================================================
echo   Multiple Playlists Download
echo ================================================================================
echo.
echo   Enter one URL per line. Type DONE when finished.
set "pl_count=0"
:_mpl_input
set "pl_url="
set /p "pl_url=  URL (or DONE): "
call :trim_var pl_url
if /i "!pl_url!"=="DONE" goto :_mpl_start
if "!pl_url!"=="" goto :_mpl_input
set /a "pl_count+=1"
set "pl_url_!pl_count!=!pl_url!"
goto :_mpl_input

:_mpl_start
if !pl_count!==0 ( pause & goto :eof )
call :select_quality
call :select_output_path
set "SUBTITLE_FLAGS="
set "MERGE_FORMAT=mkv"
if /i "!download_subtitles!"=="YES" set "SUBTITLE_FLAGS=--write-subs --write-auto-subs --sub-langs !subtitle_language! --convert-subs srt --embed-subs"
for /l %%i in (1,1,!pl_count!) do (
    set "DOWNLOAD_URL=!pl_url_%%i!"
    set "archive_file=!OUTPATH!\yt_archive_%%i.txt"
    yt-dlp !QUALITY_FLAG! --merge-output-format !MERGE_FORMAT! --output "!OUTPATH!\%%i - %%(playlist_index)s - %%(title)s.%%(ext)s" --download-archive "!archive_file!" --retries 10 --fragment-retries 10 !SUBTITLE_FLAGS! "!DOWNLOAD_URL!"
)
pause
goto :eof

:url_list_download
cls
echo ================================================================================
echo   Download from URL List File
echo ================================================================================
echo.
set "url_file="
set /p "url_file=  Enter path to .txt file: "
call :trim_var url_file
if not exist "!url_file!" ( echo   [ERR] File not found. & pause & goto :eof )
call :select_quality
call :select_output_path
set "SUBTITLE_FLAGS="
set "MERGE_FORMAT=mkv"
if /i "!download_subtitles!"=="YES" set "SUBTITLE_FLAGS=--write-subs --write-auto-subs --sub-langs !subtitle_language! --convert-subs srt --embed-subs"
for /f "usebackq eol=# tokens=* delims=" %%L in ("!url_file!") do (
    set "DOWNLOAD_URL=%%L"
    call :trim_var DOWNLOAD_URL
    if not "!DOWNLOAD_URL!"=="" yt-dlp !QUALITY_FLAG! --merge-output-format !MERGE_FORMAT! --output "!OUTPATH!\%%(title)s.%%(ext)s" --retries 10 --fragment-retries 10 !SUBTITLE_FLAGS! "!DOWNLOAD_URL!"
)
pause
goto :eof

:audio_only_download
cls
echo ================================================================================
echo   Audio Only Download
echo ================================================================================
echo.
set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=  Enter URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" ( pause & goto :eof )
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )
echo   [1] MP3  [2] M4A  [3] OPUS
set "aud_sel="
set /p "aud_sel=  Format: "
call :trim_var aud_sel
if "!aud_sel!"=="1" set "AUD_FLAGS=-x --audio-format mp3 --audio-quality 320k"
if "!aud_sel!"=="2" set "AUD_FLAGS=-x --audio-format m4a --audio-quality 0"
if "!aud_sel!"=="3" set "AUD_FLAGS=-x --audio-format opus --audio-quality 0"
if "!AUD_FLAGS!"=="" set "AUD_FLAGS=-x --audio-format mp3 --audio-quality 320k"
call :select_output_path
yt-dlp !AUD_FLAGS! --no-playlist --output "!OUTPATH!\%%(title)s.%%(ext)s" "!DOWNLOAD_URL!"
pause
goto :eof

:smart_download
set "_prev_switch=!auto_switch_drives!"
set "auto_switch_drives=YES"
call :single_video_download
set "auto_switch_drives=!_prev_switch!"
goto :eof

rem ============================================================================
rem MERGE / CONVERT
rem ============================================================================
:merge_audio_video
cls
echo ================================================================================
echo   Merge Audio + Video Files
echo ================================================================================
echo.
set "merge_dir="
set /p "merge_dir=  Enter folder containing files: "
call :trim_var merge_dir
if "!merge_dir:~-1!"=="\" set "merge_dir=!merge_dir:~0,-1!"
if not exist "!merge_dir!" ( pause & goto :eof )
for /f "usebackq delims=" %%F in (`dir /b /a-d "!merge_dir!\*.mp4" 2^>nul`) do (
    set "_mb=%%~nF"
    if exist "!merge_dir!\!_mb!.m4a" (
        ffmpeg -y -i "!merge_dir!\%%F" -i "!merge_dir!\!_mb!.m4a" -map 0:v:0 -map 1:a:0 -c copy "!merge_dir!\!_mb!_merged.mp4" -loglevel warning
    )
)
pause
goto :eof

:convert_video_files
cls
echo ================================================================================
echo   Video Converter
echo ================================================================================
echo.
set "conv_dir="
set /p "conv_dir=  Enter folder path: "
call :trim_var conv_dir
if "!conv_dir:~-1!"=="\" set "conv_dir=!conv_dir:~0,-1!"
if not exist "!conv_dir!" ( pause & goto :eof )
echo   [1] WEBM   [2] MKV   [3] AVI   [4] FLV   [5] MOV
set "fmt_sel="
set /p "fmt_sel=  > "
call :trim_var fmt_sel
if "!fmt_sel!"=="1" set "SRC_EXT=webm"
if "!fmt_sel!"=="2" set "SRC_EXT=mkv"
if "!fmt_sel!"=="3" set "SRC_EXT=avi"
if "!fmt_sel!"=="4" set "SRC_EXT=flv"
if "!fmt_sel!"=="5" set "SRC_EXT=mov"
if "!SRC_EXT!"=="" ( pause & goto :eof )
echo   [1] Fast copy   [2] High Quality   [3] Balanced
set "enc_sel="
set /p "enc_sel=  > "
call :trim_var enc_sel
if "!enc_sel!"=="1" set "ENC_FLAGS=-c copy"
if "!enc_sel!"=="2" set "ENC_FLAGS=-c:v libx264 -crf 18 -preset slow -c:a aac -b:a 256k"
if "!enc_sel!"=="3" set "ENC_FLAGS=-c:v libx264 -crf 23 -preset medium -c:a aac -b:a 192k"
if "!ENC_FLAGS!"=="" ( pause & goto :eof )
for /f "usebackq delims=" %%F in (`dir /b /a-d "!conv_dir!\*.!SRC_EXT!" 2^>nul`) do (
    ffmpeg -y -i "!conv_dir!\%%F" !ENC_FLAGS! "!conv_dir!\%%~nF.mp4" -loglevel warning -stats
)
pause
goto :eof

rem ============================================================================
rem UTILITIES / SETTINGS
rem ============================================================================
:utilities_menu
cls
echo ================================================================================
echo   Utilities
echo ================================================================================
echo.
echo   [1] Check for yt-dlp updates
echo   [2] View system info
echo   [B] Back
set "util_sel="
set /p "util_sel=  > "
call :trim_var util_sel
if "!util_sel!"=="1" ( yt-dlp -U & pause & goto :utilities_menu )
if "!util_sel!"=="2" (
    echo.
    for /f "tokens=*" %%V in (`yt-dlp --version 2^>nul`) do echo yt-dlp : %%V
    for /f "tokens=1,2,3" %%A in (`ffmpeg -version 2^>&1 ^| findstr "ffmpeg version"`) do echo ffmpeg : %%A %%B %%C
    if exist "!ytsubconverter_path!" ( echo YTSubConverter : !ytsubconverter_path! ) else ( echo YTSubConverter : not installed )
    echo AV1 preference : !prefer_av1!
    pause
    goto :utilities_menu
)
goto :eof

:settings_menu
cls
call :sanitize_settings
echo ================================================================================
echo   Settings
echo ================================================================================
echo.
echo   [1]  min_space_mb            = !min_space_mb!
echo   [2]  download_subtitles      = !download_subtitles!
echo   [3]  subtitle_language       = !subtitle_language!
echo   [4]  auto_switch_drives      = !auto_switch_drives!
echo   [5]  avg_download_speed      = !avg_download_speed! MB/s
echo   [6]  delete_after_convert    = !delete_after_convert!
echo   [7]  youtube_style_subtitles = !youtube_style_subtitles!
echo   [8]  ytsubconverter_path     = !ytsubconverter_path!
echo   [9]  Install / Reinstall YTSubConverter
echo   [10] prefer_av1              = !prefer_av1!
echo   [S]  Save settings to INI
echo   [B]  Back
echo.
set "set_sel="
set /p "set_sel=  Select: "
call :trim_var set_sel

if "!set_sel!"=="1"  ( set /p "min_space_mb=  New min_space_mb: " & call :_validate_numeric min_space_mb 100 & goto :settings_menu )
if "!set_sel!"=="2"  ( set /p "download_subtitles=  YES or NO: " & call :normalize_yes_no download_subtitles YES & goto :settings_menu )
if "!set_sel!"=="3"  ( set /p "subtitle_language=  Language code: " & call :trim_var subtitle_language & if "!subtitle_language!"=="" set "subtitle_language=en" & goto :settings_menu )
if "!set_sel!"=="4"  ( set /p "auto_switch_drives=  YES or NO: " & call :normalize_yes_no auto_switch_drives NO & goto :settings_menu )
if "!set_sel!"=="5"  ( set /p "avg_download_speed=  Speed in MB/s: " & call :_validate_numeric avg_download_speed 5 & goto :settings_menu )
if "!set_sel!"=="6"  ( set /p "delete_after_convert=  ASK, YES, or NO: " & call :normalize_yes_no_ask delete_after_convert ASK & goto :settings_menu )
if "!set_sel!"=="7"  ( set /p "youtube_style_subtitles=  YES or NO: " & call :normalize_yes_no youtube_style_subtitles YES & goto :settings_menu )
if "!set_sel!"=="8"  ( set /p "ytsubconverter_path=  Full path to YTSubConverter.exe: " & call :trim_var ytsubconverter_path & goto :settings_menu )
if "!set_sel!"=="9"  ( call :install_ytsubconverter & pause & goto :settings_menu )
if "!set_sel!"=="10" ( set /p "prefer_av1=  YES or NO: " & call :normalize_yes_no prefer_av1 YES & goto :settings_menu )
if /i "!set_sel!"=="S" ( call :save_settings & pause & goto :settings_menu )
if /i "!set_sel!"=="B" goto :eof
goto :settings_menu

rem ============================================================================
rem STYLED SUBTITLE CORE
rem ============================================================================
:convert_srv3_to_ass
set "srv3_in=%~1"
set "ass_out=%~2"
if not exist "!srv3_in!" goto :eof
"!ytsubconverter_path!" "!srv3_in!" --visual
goto :eof

:styled_mux_video
set "source_video=%~1"
set "ass_file=%~2"
set "sub_lang=%~3"
set "final_out=%~4"
set "delete_source=%~5"
set "%~6=0"

if not exist "!source_video!" goto :eof
if not exist "!ass_file!" goto :eof

if /i "!source_video!"=="!final_out!" (
    set "temp_out=!final_out!.tmp.mkv"
) else (
    set "temp_out=!final_out!"
)
if exist "!temp_out!" del "!temp_out!" >nul 2>&1

ffmpeg -y ^
    -i "!source_video!" ^
    -i "!ass_file!" ^
    -map 0 ^
    -map 1:0 ^
    -c:v copy ^
    -c:a copy ^
    -c:s ass ^
    -metadata:s:s:0 language=!sub_lang! ^
    -metadata:s:s:0 title="YouTube Style" ^
    -disposition:s:0 default ^
    "!temp_out!" ^
    -loglevel warning

if errorlevel 1 (
    if exist "!temp_out!" del "!temp_out!" >nul 2>&1
    goto :eof
)

call :file_nonzero "!temp_out!" mux_nonzero
if "!mux_nonzero!"=="0" (
    if exist "!temp_out!" del "!temp_out!" >nul 2>&1
    goto :eof
)

call :has_subtitle_stream "!temp_out!" mux_has_subs
if exist "!final_out!" if /i not "!temp_out!"=="!final_out!" del "!final_out!" >nul 2>&1

if /i "!temp_out!"=="!final_out!" (
    if "!mux_has_subs!"=="0" goto :eof
) else (
    move /y "!temp_out!" "!final_out!" >nul
    if errorlevel 1 goto :eof
    call :has_subtitle_stream "!final_out!" mux_has_subs
    if "!mux_has_subs!"=="0" goto :eof
)

if /i "!delete_source!"=="YES" if /i not "!source_video!"=="!final_out!" del "!source_video!" >nul 2>&1
set "%~6=1"
goto :eof

rem ============================================================================
rem SINGLE VIDEO STYLED
rem ============================================================================
:styled_subtitle_download
cls
echo ================================================================================
echo   YouTube-Style Subtitles Download (Single Video)
echo ================================================================================
echo.
if /i "!youtube_style_subtitles!"=="NO" ( echo   [ERR] Disabled in Settings. & pause & goto :eof )
call :ensure_ytsubconverter
if "!ytsubconverter_path!"=="" ( echo   [ERR] YTSubConverter unavailable. & pause & goto :eof )
if not exist "!ytsubconverter_path!" ( echo   [ERR] YTSubConverter missing. & pause & goto :eof )

set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=  Enter video URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" ( pause & goto :eof )
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )

echo.
set "yt_sub_lang="
set /p "yt_sub_lang=  Language [default !subtitle_language!]: "
call :trim_var yt_sub_lang
if "!yt_sub_lang!"=="" set "yt_sub_lang=!subtitle_language!"

set "IS_PLAYLIST=0"
call :select_quality
call :select_output_path
call :estimate_download

echo.
set "conf="
set /p "conf=  Proceed? (Y/N): "
call :trim_var conf
if /i not "!conf!"=="Y" goto :eof

echo.
echo   [1/4] Downloading video as MKV...
yt-dlp !QUALITY_FLAG! --no-playlist --merge-output-format mkv --output "!OUTPATH!\%%(title)s.%%(ext)s" "!DOWNLOAD_URL!"
if errorlevel 1 ( echo   [ERR] Video download failed. & pause & goto :eof )

set "video_file="
for /f "usebackq delims=" %%F in (`yt-dlp --no-playlist --print filename --output "%%(title)s.mkv" "!DOWNLOAD_URL!" 2^>nul`) do if "!video_file!"=="" set "video_file=!OUTPATH!\%%F"
if not exist "!video_file!" (
    for %%E in (mkv mp4 webm) do if "!video_file!"=="" (
        for /f "delims=" %%X in ('dir /b /a-d "!OUTPATH!\*.%%E" 2^>nul ^| sort /r') do if "!video_file!"=="" set "video_file=!OUTPATH!\%%X"
    )
)
if not exist "!video_file!" ( echo   [ERR] Could not find downloaded video. & pause & goto :eof )

echo   [2/4] Downloading srv3 subtitles...
yt-dlp --no-playlist --skip-download --write-subs --write-auto-subs --sub-langs "!yt_sub_lang!" --sub-format srv3 --output "!OUTPATH!\%%(title)s.%%(ext)s" "!DOWNLOAD_URL!" 2>nul

set "srv3_file="
for %%A in ("!video_file!") do (
    if exist "%%~dpnA.!yt_sub_lang!.srv3" set "srv3_file=%%~dpnA.!yt_sub_lang!.srv3"
    if not exist "%%~dpnA.!yt_sub_lang!.srv3" if exist "%%~dpnA.srv3" set "srv3_file=%%~dpnA.srv3"
)
if "!srv3_file!"=="" ( echo   [ERR] No srv3 subtitle file created. & pause & goto :eof )

echo   [3/4] Converting to styled ASS...
for %%A in ("!srv3_file!") do set "ass_file=%%~dpnA.ass"
call :convert_srv3_to_ass "!srv3_file!" "!ass_file!"
if not exist "!ass_file!" ( echo   [ERR] ASS conversion failed. & pause & goto :eof )

echo   [4/4] Embedding ASS into MKV and verifying subtitle stream...
call :styled_mux_video "!video_file!" "!ass_file!" "!yt_sub_lang!" "!video_file!" "NO" mux_ok
if "!mux_ok!"=="0" (
    echo   [ERR] Subtitle mux/verification failed.
    echo   [INFO] External ASS kept for manual VLC loading: !ass_file!
    pause
    goto :eof
)

del "!srv3_file!" >nul 2>&1
echo.
echo   [OK] Done.
echo   [OK] Embedded subtitle verified in: !video_file!
echo   [OK] External ASS fallback kept: !ass_file!
pause
goto :eof

rem ============================================================================
rem EXISTING PLAYLIST REPAIR
rem ============================================================================
:playlist_subtitle_repair
cls
echo ================================================================================
echo   Playlist Subtitle Repair (Existing Files)
echo ================================================================================
echo.
if /i "!youtube_style_subtitles!"=="NO" ( echo   [ERR] Disabled in Settings. & pause & goto :eof )
call :ensure_ytsubconverter
if "!ytsubconverter_path!"=="" ( echo   [ERR] YTSubConverter unavailable. & pause & goto :eof )

set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=  Enter playlist URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" ( pause & goto :eof )
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )

set "repair_dir="
set /p "repair_dir=  Enter folder containing the downloaded playlist files: "
call :trim_var repair_dir
if "!repair_dir:~-1!"=="\" set "repair_dir=!repair_dir:~0,-1!"
if not exist "!repair_dir!" ( pause & goto :eof )

set "yt_sub_lang="
set /p "yt_sub_lang=  Language [default !subtitle_language!]: "
call :trim_var yt_sub_lang
if "!yt_sub_lang!"=="" set "yt_sub_lang=!subtitle_language!"

set "replace_local="
set /p "replace_local=  Replace original files with MKV versions after success? (Y/N): "
call :trim_var replace_local
if /i "!replace_local!"=="Y" ( set "replace_local=YES" ) else ( set "replace_local=NO" )

set "overwrite_existing="
set /p "overwrite_existing=  Overwrite existing target MKVs if found? (Y/N): "
call :trim_var overwrite_existing
if /i "!overwrite_existing!"=="Y" ( set "overwrite_existing=YES" ) else ( set "overwrite_existing=NO" )

set "temp_sub_dir=%TEMP%\ytdlp_subrepair_%RANDOM%_%RANDOM%"
mkdir "!temp_sub_dir!" >nul 2>&1
if errorlevel 1 ( echo   [ERR] Could not create temp folder. & pause & goto :eof )

echo.
echo   [1/3] Downloading playlist srv3 subtitles...
yt-dlp --skip-download --write-subs --write-auto-subs --sub-langs "!yt_sub_lang!" --sub-format srv3 --output "!temp_sub_dir!\%%(playlist_index)s - %%(title)s.%%(ext)s" --ignore-errors "!DOWNLOAD_URL!"
set "srv_count=0"
for /f "usebackq delims=" %%S in (`dir /b /a-d "!temp_sub_dir!\*.srv3" 2^>nul`) do set /a "srv_count+=1"
if "!srv_count!"=="0" (
    echo   [ERR] No srv3 subtitles downloaded.
    rd /s /q "!temp_sub_dir!" >nul 2>&1
    pause
    goto :eof
)

echo   [2/3] Converting and muxing...
set "repair_ok=0"
set "repair_skip=0"
set "repair_fail=0"

for /f "usebackq delims=" %%S in (`dir /b /a-d "!temp_sub_dir!\*.srv3" 2^>nul`) do (
    set "srv3_full=!temp_sub_dir!\%%S"
    for %%A in ("!srv3_full!") do (
        set "sub_level1=%%~nA"
        set "ass_full=%%~dpnA.ass"
    )
    for %%B in ("!sub_level1!") do set "video_stem=%%~nB"

    set "source_video="
    for %%E in (mkv mp4 webm) do if "!source_video!"=="" (
        if exist "!repair_dir!\!video_stem!.%%E" set "source_video=!repair_dir!\!video_stem!.%%E"
    )

    if "!source_video!"=="" (
        echo   [SKIP] No matching local video: !video_stem!
        set /a "repair_skip+=1"
    ) else (
        call :convert_srv3_to_ass "!srv3_full!" "!ass_full!"
        if not exist "!ass_full!" (
            echo   [ERR] ASS conversion failed: %%S
            set /a "repair_fail+=1"
        ) else (
            if /i "!replace_local!"=="YES" (
                set "final_out=!repair_dir!\!video_stem!.mkv"
            ) else (
                set "final_out=!repair_dir!\!video_stem!_styled.mkv"
            )

            set "skip_item=0"
            if exist "!final_out!" if /i "!overwrite_existing!"=="NO" set "skip_item=1"

            if "!skip_item!"=="1" (
                echo   [SKIP] Target already exists: !final_out!
                set /a "repair_skip+=1"
            ) else (
                call :styled_mux_video "!source_video!" "!ass_full!" "!yt_sub_lang!" "!final_out!" "!replace_local!" item_ok
                if "!item_ok!"=="1" (
                    echo   [OK] Updated: !final_out!
                    copy /y "!ass_full!" "!repair_dir!\!video_stem!.ass" >nul 2>&1
                    set /a "repair_ok+=1"
                ) else (
                    echo   [ERR] Mux verify failed: !video_stem!
                    copy /y "!ass_full!" "!repair_dir!\!video_stem!.ass" >nul 2>&1
                    set /a "repair_fail+=1"
                )
            )
        )
    )
    if exist "!ass_full!" del "!ass_full!" >nul 2>&1
    if exist "!srv3_full!" del "!srv3_full!" >nul 2>&1
)

echo   [3/3] Cleaning up...
rd /s /q "!temp_sub_dir!" >nul 2>&1
echo.
echo   Updated : !repair_ok!
echo   Skipped : !repair_skip!
echo   Failed  : !repair_fail!
pause
goto :eof

rem ============================================================================
rem NEW: DIRECT PLAYLIST DOWNLOAD WITH YT-STYLE SUBS
rem ============================================================================
:playlist_download_styled_full
cls
echo ================================================================================
echo   Playlist Download + YouTube-Style Subtitles
echo ================================================================================
echo.
if /i "!youtube_style_subtitles!"=="NO" ( echo   [ERR] Disabled in Settings. & pause & goto :eof )
call :ensure_ytsubconverter
if "!ytsubconverter_path!"=="" ( echo   [ERR] YTSubConverter unavailable. & pause & goto :eof )

set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=  Enter playlist URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" ( pause & goto :eof )
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )

set "IS_PLAYLIST=1"
call :select_quality
call :select_output_path
call :estimate_download

set "yt_sub_lang="
set /p "yt_sub_lang=  Language [default !subtitle_language!]: "
call :trim_var yt_sub_lang
if "!yt_sub_lang!"=="" set "yt_sub_lang=!subtitle_language!"

echo.
set "conf="
set /p "conf=  Download playlist as AV1-preferred MKV with YouTube-style subtitles? (Y/N): "
call :trim_var conf
if /i not "!conf!"=="Y" goto :eof

echo.
echo   [1/3] Downloading playlist videos as MKV...
set "archive_file=!OUTPATH!\yt_archive.txt"
yt-dlp !QUALITY_FLAG! --merge-output-format mkv --output "!OUTPATH!\%%(playlist_index)s - %%(title)s.%%(ext)s" --download-archive "!archive_file!" --retries 10 --fragment-retries 10 "!DOWNLOAD_URL!"
if errorlevel 1 echo   [WARN] Some video downloads reported errors.

echo.
echo   [2/3] Downloading srv3 subtitles for playlist...
yt-dlp --skip-download --write-subs --write-auto-subs --sub-langs "!yt_sub_lang!" --sub-format srv3 --output "!OUTPATH!\%%(playlist_index)s - %%(title)s.%%(ext)s" --ignore-errors "!DOWNLOAD_URL!"
if errorlevel 1 echo   [WARN] Some subtitle downloads reported errors.

echo.
echo   [3/3] Converting and embedding styled subtitles...
set "dl_ok=0"
set "dl_skip=0"
set "dl_fail=0"

for /f "usebackq delims=" %%S in (`dir /b /a-d "!OUTPATH!\*.srv3" 2^>nul`) do (
    set "srv3_full=!OUTPATH!\%%S"
    for %%A in ("!srv3_full!") do (
        set "sub_level1=%%~nA"
        set "ass_full=%%~dpnA.ass"
    )
    for %%B in ("!sub_level1!") do set "video_stem=%%~nB"

    set "source_video="
    for %%E in (mkv mp4 webm) do if "!source_video!"=="" (
        if exist "!OUTPATH!\!video_stem!.%%E" set "source_video=!OUTPATH!\!video_stem!.%%E"
    )

    if "!source_video!"=="" (
        echo   [SKIP] No matching video found for: !video_stem!
        set /a "dl_skip+=1"
    ) else (
        call :convert_srv3_to_ass "!srv3_full!" "!ass_full!"
        if not exist "!ass_full!" (
            echo   [ERR] ASS conversion failed: %%S
            set /a "dl_fail+=1"
        ) else (
            call :styled_mux_video "!source_video!" "!ass_full!" "!yt_sub_lang!" "!source_video!" "NO" dl_item_ok
            if "!dl_item_ok!"=="1" (
                echo   [OK] Styled subtitle verified: !source_video!
                del "!srv3_full!" >nul 2>&1
                set /a "dl_ok+=1"
            ) else (
                echo   [ERR] Subtitle mux verify failed: !source_video!
                set /a "dl_fail+=1"
            )
        )
    )
)

echo.
echo   Downloaded + styled : !dl_ok!
echo   Skipped             : !dl_skip!
echo   Failed              : !dl_fail!
echo.
echo   [INFO] External .ass files were kept beside the MKV files for VLC fallback.
pause
goto :eof

rem ============================================================================
rem EXIT / CLEANUP
rem ============================================================================
:exit_script
call :cleanup
cls
echo.
echo   Ultimate YT-DLP Manager v5.6 - Goodbye.
echo.
endlocal
exit /b 0

:cleanup
del "%TEMP%\_ytdlp_drives.tmp" >nul 2>&1
del "%TEMP%\_ytdlp_alt.tmp" >nul 2>&1
goto :eof