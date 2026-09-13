[CmdletBinding()]
param([Parameter(Mandatory)][string]$Ffmpeg)

$ErrorActionPreference = 'Stop'
$PreviewAssets = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../android/app/src/preview/assets/preview'))
$PreviewPoster = Join-Path $PreviewAssets 'announcement-video.png'
if (-not (Test-Path -LiteralPath $PreviewPoster)) {
    throw 'Run generate_graphics.ps1 first to create the original preview artwork.'
}
$PreviewAudio = Join-Path $PreviewAssets 'audio.wav'
$PreviewVideo = Join-Path $PreviewAssets 'video.mp4'
& $Ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'aevalsrc=0.035*(sin(2*PI*220*t)+sin(2*PI*277.18*t)+sin(2*PI*329.63*t))*exp(-2*mod(t\,1)):s=44100:d=8' -af 'afade=t=in:d=0.15,afade=t=out:st=7:d=1' -ac 1 $PreviewAudio
if ($LASTEXITCODE -ne 0) { throw 'Preview audio generation failed.' }
& $Ffmpeg -hide_banner -loglevel error -y -loop 1 -i $PreviewPoster -i $PreviewAudio -vf "scale=720:900,zoompan=z='min(zoom+0.0008,1.12)':d=200:s=576x720:fps=25,format=yuv420p" -t 8 -c:v libx264 -preset fast -crf 25 -c:a aac -b:a 96k -movflags +faststart $PreviewVideo
if ($LASTEXITCODE -ne 0) { throw 'Preview video generation failed.' }
Get-Item -LiteralPath $PreviewAudio, $PreviewVideo | Select-Object Name, Length
