@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Ultimate YT-DLP Manager v5.7

rem ============================================================================
rem Ultimate YT-DLP Manager v5.7
rem ASCII-only output only
rem AV1-preferred MKV downloads
rem YTSubConverter auto-install
rem ASS subtitle repair:
rem   - scale to 75 percent
rem   - fix overlaps
rem   - keep external ASS fallback
rem Better file detection via yt-dlp after_move:filepath
rem Playlist sync + repair mode for partially downloaded playlists
rem ============================================================================

set "CONFIG_FILE=%~dp0ytdlp_config.ini"
set "min_space_mb=100"
set "subtitle_language=en"
set "auto_switch_drives=NO"
set "avg_download_speed=5"
set "youtube_style_subtitles=YES"
set "ytsubconverter_path="
set "prefer_av1=YES"
set "subtitle_scale_percent=75"
set "subtitle_gap_cs=5"
set "keep_external_ass=YES"

color 0A
cls
call :load_settings
call :check_dependencies
call :main_menu
exit /b 0

:main_menu
cls
echo ================================================================================
echo Ultimate YT-DLP Manager v5.7
echo Config: %CONFIG_FILE%
echo ================================================================================
echo.
echo [1]  Single Video Download
echo [2]  Playlist Download Standard
echo [10] Single Video + YT-Style Subtitles
echo [11] Playlist Repair Existing Files
echo [12] Playlist Download + YT-Style Subtitles
echo [13] Playlist Sync + Repair Existing Folder
echo [S]  Settings
echo [Q]  Quit
echo.
set "menu_choice="
set /p "menu_choice=Select an option: "
call :trim_var menu_choice

if /i "!menu_choice!"=="1"  call :single_video_download & goto :main_menu
if /i "!menu_choice!"=="2"  call :playlist_download & goto :main_menu
if /i "!menu_choice!"=="10" call :styled_subtitle_download & goto :main_menu
if /i "!menu_choice!"=="11" call :playlist_subtitle_repair & goto :main_menu
if /i "!menu_choice!"=="12" call :playlist_download_styled_full & goto :main_menu
if /i "!menu_choice!"=="13" call :playlist_sync_and_repair & goto :main_menu
if /i "!menu_choice!"=="S"  call :settings_menu & goto :main_menu
if /i "!menu_choice!"=="Q"  goto :exit_script

echo.
echo [ERR] Invalid option.
pause
goto :main_menu

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
if /i "!%~1!"=="NO"  ( set "%~1=NO"  & goto :eof )
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
set "%_vn%=!_vv!"
goto :eof

:sanitize_settings
call :trim_var min_space_mb
call :trim_var subtitle_language
call :trim_var auto_switch_drives
call :trim_var avg_download_speed
call :trim_var youtube_style_subtitles
call :trim_var ytsubconverter_path
call :trim_var prefer_av1
call :trim_var subtitle_scale_percent
call :trim_var subtitle_gap_cs
call :trim_var keep_external_ass

call :normalize_yes_no auto_switch_drives NO
call :normalize_yes_no youtube_style_subtitles YES
call :normalize_yes_no prefer_av1 YES
call :normalize_yes_no keep_external_ass YES
call :_validate_numeric min_space_mb 100
call :_validate_numeric avg_download_speed 5
call :_validate_numeric subtitle_scale_percent 75
call :_validate_numeric subtitle_gap_cs 5

if "!subtitle_language!"=="" set "subtitle_language=en"
goto :eof

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
    if /i "!lk!"=="min_space_mb"            set "min_space_mb=!lv!"
    if /i "!lk!"=="subtitle_language"       set "subtitle_language=!lv!"
    if /i "!lk!"=="auto_switch_drives"      set "auto_switch_drives=!lv!"
    if /i "!lk!"=="avg_download_speed"      set "avg_download_speed=!lv!"
    if /i "!lk!"=="youtube_style_subtitles" set "youtube_style_subtitles=!lv!"
    if /i "!lk!"=="ytsubconverter_path"     set "ytsubconverter_path=!lv!"
    if /i "!lk!"=="prefer_av1"              set "prefer_av1=!lv!"
    if /i "!lk!"=="subtitle_scale_percent"  set "subtitle_scale_percent=!lv!"
    if /i "!lk!"=="subtitle_gap_cs"         set "subtitle_gap_cs=!lv!"
    if /i "!lk!"=="keep_external_ass"       set "keep_external_ass=!lv!"
)
call :sanitize_settings
goto :eof

:save_settings
call :sanitize_settings
(
    echo ; Ultimate YT-DLP Manager v5.7
    echo min_space_mb=!min_space_mb!
    echo subtitle_language=!subtitle_language!
    echo auto_switch_drives=!auto_switch_drives!
    echo avg_download_speed=!avg_download_speed!
    echo youtube_style_subtitles=!youtube_style_subtitles!
    echo ytsubconverter_path=!ytsubconverter_path!
    echo prefer_av1=!prefer_av1!
    echo subtitle_scale_percent=!subtitle_scale_percent!
    echo subtitle_gap_cs=!subtitle_gap_cs!
    echo keep_external_ass=!keep_external_ass!
) > "!CONFIG_FILE!"
echo [OK] Settings saved.
goto :eof

:check_dependencies
cls
echo ================================================================================
echo Dependency Check
echo ================================================================================
where yt-dlp >nul 2>&1
if errorlevel 1 (
    echo [ERR] yt-dlp not found.
    call :install_ytdlp
) else (
    echo [OK] yt-dlp found.
)

where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo [ERR] ffmpeg not found.
    call :install_ffmpeg
) else (
    echo [OK] ffmpeg found.
)

where ffprobe >nul 2>&1
if errorlevel 1 (
    echo [ERR] ffprobe not found. It should come with ffmpeg.
) else (
    echo [OK] ffprobe found.
)

call :check_ytsubconverter
echo.
pause
goto :eof

:check_ytsubconverter
if /i "!youtube_style_subtitles!"=="NO" (
    echo [INFO] YouTube-style subtitles are disabled.
    goto :eof
)
if "!ytsubconverter_path!"=="" (
    echo [INFO] YTSubConverter not configured. The script can install it automatically.
    goto :eof
)
if exist "!ytsubconverter_path!" (
    echo [OK] YTSubConverter found: !ytsubconverter_path!
) else (
    echo [WARN] YTSubConverter path is set but file is missing.
)
goto :eof

:install_ytdlp
echo.
set "inst_choice="
set /p "inst_choice=Install yt-dlp automatically? (Y/N): "
call :trim_var inst_choice
if /i not "!inst_choice!"=="Y" goto :eof
if not exist "%USERPROFILE%\bin" mkdir "%USERPROFILE%\bin" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "try { Invoke-WebRequest -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile '%USERPROFILE%\bin\yt-dlp.exe' -UseBasicParsing } catch { exit 1 }"
call :_setx_safe "%USERPROFILE%\bin"
goto :eof

:install_ffmpeg
echo.
set "ff_choice="
set /p "ff_choice=Install ffmpeg automatically? (Y/N): "
call :trim_var ff_choice
if /i not "!ff_choice!"=="Y" goto :eof
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "try { Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%TEMP%\ffmpeg.zip' -UseBasicParsing } catch { exit 1 }"
if errorlevel 1 goto :eof
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "try { Expand-Archive -Path '%TEMP%\ffmpeg.zip' -DestinationPath '%USERPROFILE%\ffmpeg_tmp' -Force; $d = Get-ChildItem '%USERPROFILE%\ffmpeg_tmp' -Directory | Select-Object -First 1; if ($d) { if (Test-Path '%USERPROFILE%\ffmpeg') { Remove-Item '%USERPROFILE%\ffmpeg' -Recurse -Force }; Move-Item $d.FullName '%USERPROFILE%\ffmpeg'; Remove-Item '%USERPROFILE%\ffmpeg_tmp' -Recurse -Force } } catch { exit 1 }"
call :_setx_safe "%USERPROFILE%\ffmpeg\bin"
goto :eof

:install_ytsubconverter
echo.
set "ytsc_choice="
set /p "ytsc_choice=Install YTSubConverter automatically? (Y/N): "
call :trim_var ytsc_choice
if /i not "!ytsc_choice!"=="Y" goto :eof
set "ytsc_dir=%USERPROFILE%\bin\YTSubConverter"
set "ytsc_exe=!ytsc_dir!\YTSubConverter.exe"
if not exist "!ytsc_dir!" mkdir "!ytsc_dir!" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$url='https://github.com/arcusmaximus/YTSubConverter/releases/download/1.6.3/YTSubConverter.exe'; try { Invoke-WebRequest -Uri $url -OutFile '%USERPROFILE%\bin\YTSubConverter\YTSubConverter.exe' -UseBasicParsing } catch { exit 1 }"
if errorlevel 1 goto :eof
if exist "!ytsc_exe!" (
    set "ytsubconverter_path=!ytsc_exe!"
    call :save_settings
    call :_setx_safe "!ytsc_dir!"
    echo [OK] YTSubConverter installed.
)
goto :eof

:ensure_ytsubconverter
if not "!ytsubconverter_path!"=="" if exist "!ytsubconverter_path!" goto :eof
call :install_ytsubconverter
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

:select_output_path
echo.
set "OUTPATH="
set /p "OUTPATH=Enter output folder path: "
call :trim_var OUTPATH
if "!OUTPATH!"=="" set "OUTPATH=%CD%\YTVIDS"
if not exist "!OUTPATH!" mkdir "!OUTPATH!" >nul 2>&1
echo [OK] Output path: !OUTPATH!
goto :eof

:select_quality
echo.
echo [1] Best Quality
echo [2] 4K / 2160p
echo [3] 1080p
echo [4] 720p
echo [5] 480p
echo.
set "qual_sel="
set /p "qual_sel=Select quality: "
call :trim_var qual_sel
if "!qual_sel!"=="" set "qual_sel=1"

if /i "!prefer_av1!"=="YES" (
    if "!qual_sel!"=="1" set "FORMAT_SELECTOR=bestvideo[vcodec*=av01]+bestaudio/bestvideo+bestaudio/best"
    if "!qual_sel!"=="2" set "FORMAT_SELECTOR=bestvideo[vcodec*=av01][height<=2160]+bestaudio/bestvideo[height<=2160]+bestaudio/best"
    if "!qual_sel!"=="3" set "FORMAT_SELECTOR=bestvideo[vcodec*=av01][height<=1080]+bestaudio/bestvideo[height<=1080]+bestaudio/best"
    if "!qual_sel!"=="4" set "FORMAT_SELECTOR=bestvideo[vcodec*=av01][height<=720]+bestaudio/bestvideo[height<=720]+bestaudio/best"
    if "!qual_sel!"=="5" set "FORMAT_SELECTOR=bestvideo[vcodec*=av01][height<=480]+bestaudio/bestvideo[height<=480]+bestaudio/best"
) else (
    if "!qual_sel!"=="1" set "FORMAT_SELECTOR=bestvideo+bestaudio/best"
    if "!qual_sel!"=="2" set "FORMAT_SELECTOR=bestvideo[height<=2160]+bestaudio/best"
    if "!qual_sel!"=="3" set "FORMAT_SELECTOR=bestvideo[height<=1080]+bestaudio/best"
    if "!qual_sel!"=="4" set "FORMAT_SELECTOR=bestvideo[height<=720]+bestaudio/best"
    if "!qual_sel!"=="5" set "FORMAT_SELECTOR=bestvideo[height<=480]+bestaudio/best"
)
if "!FORMAT_SELECTOR!"=="" set "FORMAT_SELECTOR=bestvideo+bestaudio/best"
echo [OK] Format selector: !FORMAT_SELECTOR!
goto :eof

:validate_url
set "URL_VALID=0"
if /i "!DOWNLOAD_URL:~0,4!"=="http" set "URL_VALID=1"
if "!URL_VALID!"=="0" echo [ERR] Invalid URL.
goto :eof

:build_sub_lang_query
set "SUB_LANG_QUERY=!subtitle_language!.*,!subtitle_language!,*"
if not "%~1"=="" set "SUB_LANG_QUERY=%~1.*,%~1,*"
goto :eof

:file_nonzero
set "%~2=0"
powershell -NoProfile -Command "if ((Test-Path '%~1') -and ((Get-Item '%~1').Length -gt 0)) { exit 0 } else { exit 1 }" >nul 2>&1
if not errorlevel 1 set "%~2=1"
goto :eof

:has_subtitle_stream
set "%~2=0"
for /f "usebackq delims=" %%S in (`ffprobe -v error -select_streams s -show_entries stream^=codec_name -of csv^=p^=0 "%~1" 2^>nul`) do (
    set "%~2=1"
    goto :eof
)
goto :eof

:single_video_download
cls
echo ================================================================================
echo Single Video Download
echo ================================================================================
echo.
set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=Enter video URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" goto :eof
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )
call :select_quality
call :select_output_path

echo.
echo [INFO] Downloading video...
yt-dlp -f "!FORMAT_SELECTOR!" --merge-output-format mkv --output "!OUTPATH!\%%(title)s.%%(ext)s" "!DOWNLOAD_URL!"
pause
goto :eof

:playlist_download
cls
echo ================================================================================
echo Playlist Download Standard
echo ================================================================================
echo.
set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=Enter playlist URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" goto :eof
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )
call :select_quality
call :select_output_path

echo.
echo [INFO] Downloading playlist...
yt-dlp -f "!FORMAT_SELECTOR!" --merge-output-format mkv --output "!OUTPATH!\%%(playlist_index)s - %%(title)s.%%(ext)s" "!DOWNLOAD_URL!"
pause
goto :eof

:download_single_video_capture
set "CAPTURED_PATH="
for /f "usebackq delims=" %%P in (`yt-dlp -f "!FORMAT_SELECTOR!" --merge-output-format mkv --print after_move:filepath --output "!OUTPATH!\%%(title)s.%%(ext)s" "!DOWNLOAD_URL!"`) do (
    set "CAPTURED_PATH=%%P"
)
goto :eof

:download_playlist_item_capture
set "CAPTURED_PATH="
for /f "usebackq delims=" %%P in (`yt-dlp -f "!FORMAT_SELECTOR!" --merge-output-format mkv --print after_move:filepath --playlist-items "%~2" --output "%~3\%%(playlist_index)s - %%(title)s.%%(ext)s" "%~1"`) do (
    set "CAPTURED_PATH=%%P"
)
goto :eof

:download_subtitles_for_single
set "SUB_CAPTURED="
call :build_sub_lang_query %~2
yt-dlp --skip-download --write-subs --write-auto-subs --sub-langs "!SUB_LANG_QUERY!" --sub-format srv3 --output "%~1\%%(title)s.%%(ext)s" "!DOWNLOAD_URL!" >nul
for %%A in ("%~3") do (
    call :find_subtitle_for_video "%%~fA" "%~2"
    set "SUB_CAPTURED=!FOUND_SUB!"
)
goto :eof

:download_subtitles_for_playlist_item
set "SUB_CAPTURED="
call :build_sub_lang_query %~4
yt-dlp --skip-download --write-subs --write-auto-subs --sub-langs "!SUB_LANG_QUERY!" --sub-format srv3 --playlist-items "%~2" --output "%~3\%%(playlist_index)s - %%(title)s.%%(ext)s" "%~1" >nul
call :find_subtitle_for_video "%~5" "%~4"
set "SUB_CAPTURED=!FOUND_SUB!"
goto :eof

:find_subtitle_for_video
set "FOUND_SUB="
set "FPS_VIDEO=%~1"
set "FPS_LANG=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$video=$env:FPS_VIDEO; $lang=$env:FPS_LANG; $dir=[IO.Path]::GetDirectoryName($video); $stem=[IO.Path]::GetFileNameWithoutExtension($video); $files=Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Extension -eq '.srv3' -and ($_.BaseName -eq $stem -or $_.BaseName -like ($stem + '.*')) }; if($lang -ne '') { $pref=$files | Where-Object { $_.Name -like ($stem + '.' + $lang + '*.srv3') } | Select-Object -First 1; if($pref){ $pref.FullName; exit 0 } }; $f=$files | Select-Object -First 1; if($f){ $f.FullName }" > "%TEMP%\_found_sub.txt"
set /p "FOUND_SUB="<"%TEMP%\_found_sub.txt"
del "%TEMP%\_found_sub.txt" >nul 2>&1
goto :eof

:find_existing_video
set "FOUND_VIDEO="
set "FE_DIR=%~1"
set "FE_INDEX=%~2"
set "FE_TITLE=%~3"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$dir=$env:FE_DIR; $idx=$env:FE_INDEX; $title=$env:FE_TITLE; $stem=$idx + ' - ' + $title; $exts=@('.mkv','.mp4','.webm'); $f=Get-ChildItem -LiteralPath $dir -File | Where-Object { $exts -contains $_.Extension.ToLower() -and ($_.BaseName -eq $stem -or $_.BaseName -like ($idx + ' - *')) } | Sort-Object @{Expression={if($_.BaseName -eq $stem){0}else{1}}}, Name | Select-Object -First 1; if($f){ $f.FullName }" > "%TEMP%\_found_video.txt"
set /p "FOUND_VIDEO="<"%TEMP%\_found_video.txt"
del "%TEMP%\_found_video.txt" >nul 2>&1
goto :eof

:convert_srv3_to_ass
set "CSA_IN=%~1"
set "CSA_OUT=%~2"
if not exist "!CSA_IN!" goto :eof
"!ytsubconverter_path!" "!CSA_IN!" --visual
if exist "!CSA_OUT!" goto :eof
goto :eof

:repair_ass_file
set "RAF_PATH=%~1"
set "RAF_SCALE=%~2"
set "RAF_GAP=%~3"
if not exist "!RAF_PATH!" goto :eof
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$path=$env:RAF_PATH; $scale=[double]$env:RAF_SCALE/100.0; $gapCs=[int]$env:RAF_GAP; $enc=[System.Text.UTF8Encoding]::new($false); $lines=[System.Collections.Generic.List[string]]::new(); Get-Content -LiteralPath $path | ForEach-Object { [void]$lines.Add($_) }; function Parse-AssTime([string]$t){ if($t -match '^(?<h>\d+):(?<m>\d{2}):(?<s>\d{2})\.(?<c>\d{2})$'){ return ([TimeSpan]::FromHours([int]$Matches.h)+[TimeSpan]::FromMinutes([int]$Matches.m)+[TimeSpan]::FromSeconds([int]$Matches.s)+[TimeSpan]::FromMilliseconds(([int]$Matches.c)*10)) } return $null }; function Format-AssTime([TimeSpan]$ts){ if($ts.TotalMilliseconds -lt 0){ $ts=[TimeSpan]::Zero }; $cs=[int][Math]::Floor($ts.Milliseconds/10); return ('{0}:{1:00}:{2:00}.{3:00}' -f [int]$ts.TotalHours,$ts.Minutes,$ts.Seconds,$cs) }; $dlg=@(); for($i=0;$i -lt $lines.Count;$i++){ $line=$lines[$i]; if($line -like 'Style:*'){ $body=$line.Substring(6).Trim(); $parts=$body.Split(','); if($parts.Count -ge 3){ $n=0.0; if([double]::TryParse($parts[2],[ref]$n)){ $parts[2]=([Math]::Round($n*$scale,2)).ToString([Globalization.CultureInfo]::InvariantCulture); $lines[$i]='Style: ' + ($parts -join ',') } } } elseif($line -like 'Dialogue:*'){ $body=$line.Substring(9).Trim(); $parts=$body.Split(',',10); if($parts.Count -eq 10){ $start=Parse-AssTime $parts[1]; $end=Parse-AssTime $parts[2]; $parts[9]=[regex]::Replace($parts[9],'\\fs(\d+(?:\.\d+)?)',{ param($m) '\fs' + ([Math]::Round(([double]$m.Groups[1].Value*$scale),2)).ToString([Globalization.CultureInfo]::InvariantCulture) }); $dlg += [pscustomobject]@{ Index=$i; Parts=$parts; Start=$start; End=$end } } } }; for($j=0;$j -lt $dlg.Count-1;$j++){ if($null -ne $dlg[$j].Start -and $null -ne $dlg[$j].End -and $null -ne $dlg[$j+1].Start){ if($dlg[$j].End -gt $dlg[$j+1].Start){ $newEnd=$dlg[$j+1].Start - [TimeSpan]::FromMilliseconds($gapCs*10); if($newEnd -le $dlg[$j].Start){ $newEnd=$dlg[$j].Start + [TimeSpan]::FromMilliseconds(10) }; $dlg[$j].Parts[2]=Format-AssTime $newEnd; $dlg[$j].End=$newEnd } } }; foreach($d in $dlg){ $lines[$d.Index]='Dialogue: ' + ($d.Parts -join ',') }; [System.IO.File]::WriteAllLines($path,$lines,$enc)"
goto :eof

:styled_mux_video
set "SMV_SOURCE=%~1"
set "SMV_ASS=%~2"
set "SMV_LANG=%~3"
set "SMV_FINAL=%~4"
set "SMV_DELETE_SOURCE=%~5"
set "%~6=0"

if not exist "!SMV_SOURCE!" goto :eof
if not exist "!SMV_ASS!" goto :eof

if /i "!SMV_SOURCE!"=="!SMV_FINAL!" (
    set "SMV_TEMP=!SMV_FINAL!.tmp.mkv"
) else (
    set "SMV_TEMP=!SMV_FINAL!"
)
if exist "!SMV_TEMP!" del "!SMV_TEMP!" >nul 2>&1

ffmpeg -y ^
 -i "!SMV_SOURCE!" ^
 -i "!SMV_ASS!" ^
 -map 0 ^
 -map 1:0 ^
 -c:v copy ^
 -c:a copy ^
 -c:s ass ^
 -metadata:s:s:0 language=!SMV_LANG! ^
 -metadata:s:s:0 title="YouTube Style" ^
 -disposition:s:0 default ^
 "!SMV_TEMP!" ^
 -loglevel warning

if errorlevel 1 (
    if exist "!SMV_TEMP!" del "!SMV_TEMP!" >nul 2>&1
    goto :eof
)

call :file_nonzero "!SMV_TEMP!" SMV_NONZERO
if "!SMV_NONZERO!"=="0" (
    if exist "!SMV_TEMP!" del "!SMV_TEMP!" >nul 2>&1
    goto :eof
)

if /i not "!SMV_TEMP!"=="!SMV_FINAL!" (
    if exist "!SMV_FINAL!" del "!SMV_FINAL!" >nul 2>&1
    move /y "!SMV_TEMP!" "!SMV_FINAL!" >nul
    if errorlevel 1 goto :eof
)

call :has_subtitle_stream "!SMV_FINAL!" SMV_HAS_SUBS
if "!SMV_HAS_SUBS!"=="0" goto :eof

if /i "!SMV_DELETE_SOURCE!"=="YES" if /i not "!SMV_SOURCE!"=="!SMV_FINAL!" del "!SMV_SOURCE!" >nul 2>&1
set "%~6=1"
goto :eof

:styled_subtitle_download
cls
echo ================================================================================
echo Single Video + YT-Style Subtitles
echo ================================================================================
echo.
if /i "!youtube_style_subtitles!"=="NO" ( echo [ERR] Disabled in Settings. & pause & goto :eof )
call :ensure_ytsubconverter
if "!ytsubconverter_path!"=="" ( echo [ERR] YTSubConverter unavailable. & pause & goto :eof )

set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=Enter video URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" goto :eof
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )

set "local_lang="
set /p "local_lang=Language [default !subtitle_language!]: "
call :trim_var local_lang
if "!local_lang!"=="" set "local_lang=!subtitle_language!"

call :select_quality
call :select_output_path

echo.
echo [1/4] Downloading video...
call :download_single_video_capture
if "!CAPTURED_PATH!"=="" (
    echo [ERR] Could not resolve final downloaded file.
    pause
    goto :eof
)
if not exist "!CAPTURED_PATH!" (
    echo [ERR] Downloaded file not found.
    pause
    goto :eof
)
set "VIDEO_FILE=!CAPTURED_PATH!"
echo [OK] Video: !VIDEO_FILE!

echo.
echo [2/4] Downloading subtitles...
call :download_subtitles_for_single "!OUTPATH!" "!local_lang!" "!VIDEO_FILE!"
if "!SUB_CAPTURED!"=="" (
    echo [ERR] No subtitles were downloaded for this video.
    pause
    goto :eof
)
echo [OK] Subtitle source: !SUB_CAPTURED!

echo.
echo [3/4] Converting and repairing ASS...
for %%A in ("!SUB_CAPTURED!") do set "ASS_FILE=%%~dpnA.ass"
call :convert_srv3_to_ass "!SUB_CAPTURED!" "!ASS_FILE!"
if not exist "!ASS_FILE!" (
    echo [ERR] ASS conversion failed.
    pause
    goto :eof
)
call :repair_ass_file "!ASS_FILE!" "!subtitle_scale_percent!" "!subtitle_gap_cs!"
echo [OK] ASS repaired.

echo.
echo [4/4] Embedding and verifying...
call :styled_mux_video "!VIDEO_FILE!" "!ASS_FILE!" "!local_lang!" "!VIDEO_FILE!" "NO" MUX_OK
if "!MUX_OK!"=="0" (
    echo [ERR] Subtitle mux verification failed.
    echo [INFO] External ASS kept: !ASS_FILE!
    pause
    goto :eof
)

del "!SUB_CAPTURED!" >nul 2>&1
if /i "!keep_external_ass!"=="NO" del "!ASS_FILE!" >nul 2>&1
echo [OK] Finished successfully.
pause
goto :eof

:playlist_download_styled_full
cls
echo ================================================================================
echo Playlist Download + YT-Style Subtitles
echo ================================================================================
echo.
if /i "!youtube_style_subtitles!"=="NO" ( echo [ERR] Disabled in Settings. & pause & goto :eof )
call :ensure_ytsubconverter
if "!ytsubconverter_path!"=="" ( echo [ERR] YTSubConverter unavailable. & pause & goto :eof )

set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=Enter playlist URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" goto :eof
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )

set "local_lang="
set /p "local_lang=Language [default !subtitle_language!]: "
call :trim_var local_lang
if "!local_lang!"=="" set "local_lang=!subtitle_language!"

call :select_quality
call :select_output_path

echo.
echo [1/3] Downloading playlist videos...
yt-dlp -f "!FORMAT_SELECTOR!" --merge-output-format mkv --output "!OUTPATH!\%%(playlist_index)s - %%(title)s.%%(ext)s" "!DOWNLOAD_URL!"

echo.
echo [2/3] Downloading playlist subtitles...
call :build_sub_lang_query !local_lang!
yt-dlp --skip-download --write-subs --write-auto-subs --sub-langs "!SUB_LANG_QUERY!" --sub-format srv3 --output "!OUTPATH!\%%(playlist_index)s - %%(title)s.%%(ext)s" "!DOWNLOAD_URL!"

echo.
echo [3/3] Repairing subtitles and embedding...
set "pl_ok=0"
set "pl_fail=0"
for /f "usebackq delims=" %%S in (`dir /b /a-d "!OUTPATH!\*.srv3" 2^>nul`) do (
    set "CUR_SUB=!OUTPATH!\%%S"
    for %%A in ("!CUR_SUB!") do (
        set "SUB_BASE1=%%~nA"
        set "ASS_FILE=%%~dpnA.ass"
    )
    for %%B in ("!SUB_BASE1!") do set "STEM=%%~nB"

    set "VIDEO_FILE="
    if exist "!OUTPATH!\!STEM!.mkv" set "VIDEO_FILE=!OUTPATH!\!STEM!.mkv"
    if "!VIDEO_FILE!"=="" if exist "!OUTPATH!\!STEM!.mp4" set "VIDEO_FILE=!OUTPATH!\!STEM!.mp4"
    if "!VIDEO_FILE!"=="" if exist "!OUTPATH!\!STEM!.webm" set "VIDEO_FILE=!OUTPATH!\!STEM!.webm"

    if "!VIDEO_FILE!"=="" (
        echo [WARN] Matching video not found for %%S
        set /a pl_fail+=1
    ) else (
        call :convert_srv3_to_ass "!CUR_SUB!" "!ASS_FILE!"
        if exist "!ASS_FILE!" (
            call :repair_ass_file "!ASS_FILE!" "!subtitle_scale_percent!" "!subtitle_gap_cs!"
            call :styled_mux_video "!VIDEO_FILE!" "!ASS_FILE!" "!local_lang!" "!VIDEO_FILE!" "NO" ONE_OK
            if "!ONE_OK!"=="1" (
                echo [OK] Repaired: !VIDEO_FILE!
                del "!CUR_SUB!" >nul 2>&1
                set /a pl_ok+=1
            ) else (
                echo [ERR] Failed: !VIDEO_FILE!
                set /a pl_fail+=1
            )
            if /i "!keep_external_ass!"=="NO" del "!ASS_FILE!" >nul 2>&1
        ) else (
            echo [ERR] ASS conversion failed for %%S
            set /a pl_fail+=1
        )
    )
)
echo.
echo [OK] Finished.
echo Repaired: !pl_ok!
echo Failed:   !pl_fail!
pause
goto :eof

:playlist_subtitle_repair
cls
echo ================================================================================
echo Playlist Repair Existing Files
echo ================================================================================
echo.
if /i "!youtube_style_subtitles!"=="NO" ( echo [ERR] Disabled in Settings. & pause & goto :eof )
call :ensure_ytsubconverter
if "!ytsubconverter_path!"=="" ( echo [ERR] YTSubConverter unavailable. & pause & goto :eof )

set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=Enter playlist URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" goto :eof
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )

set "repair_dir="
set /p "repair_dir=Enter folder containing playlist files: "
call :trim_var repair_dir
if not exist "!repair_dir!" ( echo [ERR] Folder not found. & pause & goto :eof )

set "local_lang="
set /p "local_lang=Language [default !subtitle_language!]: "
call :trim_var local_lang
if "!local_lang!"=="" set "local_lang=!subtitle_language!"

set "replace_non_mkv=YES"
set "rep_choice="
set /p "rep_choice=Replace MP4/WEBM with MKV after repair? (Y/N, default Y): "
call :trim_var rep_choice
if /i "!rep_choice!"=="N" set "replace_non_mkv=NO"

set "playlist_map=%TEMP%\ytdlp_playlist_map_%RANDOM%.txt"
yt-dlp --flat-playlist --print "%%(playlist_index)s|%%(title)s" "!DOWNLOAD_URL!" > "!playlist_map!"
if not exist "!playlist_map!" ( echo [ERR] Could not read playlist metadata. & pause & goto :eof )

set "pr_ok=0"
set "pr_skip=0"
set "pr_fail=0"

for /f "usebackq tokens=1,* delims=|" %%A in ("!playlist_map!") do (
    set "ITEM_INDEX=%%A"
    set "ITEM_TITLE=%%B"
    call :find_existing_video "!repair_dir!" "!ITEM_INDEX!" "!ITEM_TITLE!"
    if "!FOUND_VIDEO!"=="" (
        echo [SKIP] Missing local video: !ITEM_INDEX! - !ITEM_TITLE!
        set /a pr_skip+=1
    ) else (
        set "VIDEO_FILE=!FOUND_VIDEO!"
        call :download_subtitles_for_playlist_item "!DOWNLOAD_URL!" "!ITEM_INDEX!" "!repair_dir!" "!local_lang!" "!VIDEO_FILE!"
        if "!SUB_CAPTURED!"=="" (
            echo [SKIP] No subtitles found: !VIDEO_FILE!
            set /a pr_skip+=1
        ) else (
            for %%S in ("!SUB_CAPTURED!") do set "ASS_FILE=%%~dpnS.ass"
            call :convert_srv3_to_ass "!SUB_CAPTURED!" "!ASS_FILE!"
            if not exist "!ASS_FILE!" (
                echo [ERR] ASS conversion failed: !VIDEO_FILE!
                set /a pr_fail+=1
            ) else (
                call :repair_ass_file "!ASS_FILE!" "!subtitle_scale_percent!" "!subtitle_gap_cs!"
                set "FINAL_FILE=!VIDEO_FILE!"
                for %%E in ("!VIDEO_FILE!") do set "CUR_EXT=%%~xE"
                if /i "!CUR_EXT!"==".mp4" if /i "!replace_non_mkv!"=="YES" set "FINAL_FILE=%%~dpnE.mkv"
                if /i "!CUR_EXT!"==".webm" if /i "!replace_non_mkv!"=="YES" set "FINAL_FILE=%%~dpnE.mkv"
                call :styled_mux_video "!VIDEO_FILE!" "!ASS_FILE!" "!local_lang!" "!FINAL_FILE!" "!replace_non_mkv!" MUX_OK
                if "!MUX_OK!"=="1" (
                    echo [OK] Repaired: !FINAL_FILE!
                    del "!SUB_CAPTURED!" >nul 2>&1
                    if /i "!keep_external_ass!"=="NO" del "!ASS_FILE!" >nul 2>&1
                    set /a pr_ok+=1
                ) else (
                    echo [ERR] Mux verification failed: !VIDEO_FILE!
                    set /a pr_fail+=1
                )
            )
        )
    )
)
del "!playlist_map!" >nul 2>&1
echo.
echo [OK] Finished.
echo Repaired: !pr_ok!
echo Skipped:  !pr_skip!
echo Failed:   !pr_fail!
pause
goto :eof

:playlist_sync_and_repair
cls
echo ================================================================================
echo Playlist Sync + Repair Existing Folder
echo ================================================================================
echo.
if /i "!youtube_style_subtitles!"=="NO" ( echo [ERR] Disabled in Settings. & pause & goto :eof )
call :ensure_ytsubconverter
if "!ytsubconverter_path!"=="" ( echo [ERR] YTSubConverter unavailable. & pause & goto :eof )

set "DOWNLOAD_URL="
set /p "DOWNLOAD_URL=Enter playlist URL: "
call :trim_var DOWNLOAD_URL
if "!DOWNLOAD_URL!"=="" goto :eof
call :validate_url
if "!URL_VALID!"=="0" ( pause & goto :eof )

set "repair_dir="
set /p "repair_dir=Enter existing playlist folder: "
call :trim_var repair_dir
if "!repair_dir!"=="" set "repair_dir=%CD%\YTVIDS"
if not exist "!repair_dir!" mkdir "!repair_dir!" >nul 2>&1

set "local_lang="
set /p "local_lang=Language [default !subtitle_language!]: "
call :trim_var local_lang
if "!local_lang!"=="" set "local_lang=!subtitle_language!"

call :select_quality

set "playlist_map=%TEMP%\ytdlp_playlist_map_%RANDOM%.txt"
yt-dlp --flat-playlist --print "%%(playlist_index)s|%%(title)s" "!DOWNLOAD_URL!" > "!playlist_map!"
if not exist "!playlist_map!" ( echo [ERR] Could not read playlist metadata. & pause & goto :eof )

set "sync_ok=0"
set "sync_skip=0"
set "sync_fail=0"

for /f "usebackq tokens=1,* delims=|" %%A in ("!playlist_map!") do (
    set "ITEM_INDEX=%%A"
    set "ITEM_TITLE=%%B"
    call :find_existing_video "!repair_dir!" "!ITEM_INDEX!" "!ITEM_TITLE!"
    if "!FOUND_VIDEO!"=="" (
        echo [INFO] Missing video. Downloading: !ITEM_INDEX! - !ITEM_TITLE!
        call :download_playlist_item_capture "!DOWNLOAD_URL!" "!ITEM_INDEX!" "!repair_dir!"
        if "!CAPTURED_PATH!"=="" (
            echo [ERR] Download failed: !ITEM_INDEX! - !ITEM_TITLE!
            set /a sync_fail+=1
            set "VIDEO_FILE="
        ) else (
            set "VIDEO_FILE=!CAPTURED_PATH!"
        )
    ) else (
        set "VIDEO_FILE=!FOUND_VIDEO!"
        echo [INFO] Found existing video: !VIDEO_FILE!
    )

    if not "!VIDEO_FILE!"=="" (
        call :download_subtitles_for_playlist_item "!DOWNLOAD_URL!" "!ITEM_INDEX!" "!repair_dir!" "!local_lang!" "!VIDEO_FILE!"
        if "!SUB_CAPTURED!"=="" (
            call :has_subtitle_stream "!VIDEO_FILE!" HAS_SUBS_ALREADY
            if "!HAS_SUBS_ALREADY!"=="1" (
                echo [OK] Existing subtitle stream kept: !VIDEO_FILE!
                set /a sync_skip+=1
            ) else (
                echo [WARN] No subtitles available: !VIDEO_FILE!
                set /a sync_skip+=1
            )
        ) else (
            for %%S in ("!SUB_CAPTURED!") do set "ASS_FILE=%%~dpnS.ass"
            call :convert_srv3_to_ass "!SUB_CAPTURED!" "!ASS_FILE!"
            if not exist "!ASS_FILE!" (
                echo [ERR] ASS conversion failed: !VIDEO_FILE!
                set /a sync_fail+=1
            ) else (
                call :repair_ass_file "!ASS_FILE!" "!subtitle_scale_percent!" "!subtitle_gap_cs!"
                set "FINAL_FILE=!VIDEO_FILE!"
                for %%E in ("!VIDEO_FILE!") do (
                    if /i "%%~xE"==".mp4" set "FINAL_FILE=%%~dpnE.mkv"
                    if /i "%%~xE"==".webm" set "FINAL_FILE=%%~dpnE.mkv"
                )
                call :styled_mux_video "!VIDEO_FILE!" "!ASS_FILE!" "!local_lang!" "!FINAL_FILE!" "YES" MUX_OK
                if "!MUX_OK!"=="1" (
                    echo [OK] Synced and repaired: !FINAL_FILE!
                    del "!SUB_CAPTURED!" >nul 2>&1
                    if /i "!keep_external_ass!"=="NO" del "!ASS_FILE!" >nul 2>&1
                    set /a sync_ok+=1
                ) else (
                    echo [ERR] Mux verify failed: !VIDEO_FILE!
                    set /a sync_fail+=1
                )
            )
        )
    )
)
del "!playlist_map!" >nul 2>&1
echo.
echo [OK] Finished.
echo Updated: !sync_ok!
echo Skipped: !sync_skip!
echo Failed:  !sync_fail!
pause
goto :eof

:settings_menu
cls
call :sanitize_settings
echo ================================================================================
echo Settings
echo ================================================================================
echo.
echo [1]  subtitle_language      = !subtitle_language!
echo [2]  youtube_style_subtitles= !youtube_style_subtitles!
echo [3]  ytsubconverter_path    = !ytsubconverter_path!
echo [4]  prefer_av1             = !prefer_av1!
echo [5]  subtitle_scale_percent = !subtitle_scale_percent!
echo [6]  subtitle_gap_cs        = !subtitle_gap_cs!
echo [7]  keep_external_ass      = !keep_external_ass!
echo [8]  Install/Reinstall YTSubConverter
echo [S]  Save settings
echo [B]  Back
echo.
set "set_sel="
set /p "set_sel=Select: "
call :trim_var set_sel

if "!set_sel!"=="1" ( set /p "subtitle_language=Language code: " & goto :settings_menu )
if "!set_sel!"=="2" ( set /p "youtube_style_subtitles=YES or NO: " & call :normalize_yes_no youtube_style_subtitles YES & goto :settings_menu )
if "!set_sel!"=="3" ( set /p "ytsubconverter_path=Full path: " & goto :settings_menu )
if "!set_sel!"=="4" ( set /p "prefer_av1=YES or NO: " & call :normalize_yes_no prefer_av1 YES & goto :settings_menu )
if "!set_sel!"=="5" ( set /p "subtitle_scale_percent=Percent, e.g. 75: " & call :_validate_numeric subtitle_scale_percent 75 & goto :settings_menu )
if "!set_sel!"=="6" ( set /p "subtitle_gap_cs=Gap in centiseconds, e.g. 5: " & call :_validate_numeric subtitle_gap_cs 5 & goto :settings_menu )
if "!set_sel!"=="7" ( set /p "keep_external_ass=YES or NO: " & call :normalize_yes_no keep_external_ass YES & goto :settings_menu )
if "!set_sel!"=="8" ( call :install_ytsubconverter & pause & goto :settings_menu )
if /i "!set_sel!"=="S" ( call :save_settings & pause & goto :settings_menu )
if /i "!set_sel!"=="B" goto :eof
goto :settings_menu

:exit_script
cls
echo.
echo Goodbye.
echo.
endlocal
exit /b 0