[CmdletBinding()]
param()

# Original geometric illustrations, generated locally without downloads or user images.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$GraphicsRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../android/app/src/preview/assets/preview'))
[void](New-Item -ItemType Directory -Path $GraphicsRoot -Force)
$GraphicFiles = [Collections.Generic.List[string]]::new()

function Color([string]$Hex) { [Drawing.ColorTranslator]::FromHtml($Hex) }
function Rect($G, $X, $Y, $Width, $Height, [string]$Fill) {
    $Brush = [Drawing.SolidBrush]::new((Color $Fill))
    try { $G.FillRectangle($Brush, [single]$X, [single]$Y, [single]$Width, [single]$Height) } finally { $Brush.Dispose() }
}
function Oval($G, $X, $Y, $Width, $Height, [string]$Fill) {
    $Brush = [Drawing.SolidBrush]::new((Color $Fill))
    try { $G.FillEllipse($Brush, [single]$X, [single]$Y, [single]$Width, [single]$Height) } finally { $Brush.Dispose() }
}
function Line($G, $X1, $Y1, $X2, $Y2, [string]$Fill, $Width = 3) {
    $Pen = [Drawing.Pen]::new((Color $Fill), [single]$Width)
    $Pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
    $Pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
    try { $G.DrawLine($Pen, [single]$X1, [single]$Y1, [single]$X2, [single]$Y2) } finally { $Pen.Dispose() }
}
function Words($G, [string]$Text, $X, $Y, $Size, [string]$Fill, [bool]$Bold = $true) {
    $Style = if ($Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $Font = [Drawing.Font]::new('Segoe UI', [single]$Size, $Style, [Drawing.GraphicsUnit]::Pixel)
    $Brush = [Drawing.SolidBrush]::new((Color $Fill))
    try { $G.DrawString($Text, $Font, $Brush, [single]$X, [single]$Y) } finally { $Font.Dispose(); $Brush.Dispose() }
}
function Poly($G, [object[]]$Coordinates, [string]$Fill) {
    $Points = [Drawing.PointF[]]@($Coordinates | ForEach-Object { [Drawing.PointF]::new([single]$_[0], [single]$_[1]) })
    $Brush = [Drawing.SolidBrush]::new((Color $Fill))
    try { $G.FillPolygon($Brush, $Points) } finally { $Brush.Dispose() }
}
function Canvas([string]$Name, [int]$Width, [int]$Height, [string]$Top, [string]$Bottom, [scriptblock]$Paint) {
    $Bitmap = [Drawing.Bitmap]::new($Width, $Height)
    $G = [Drawing.Graphics]::FromImage($Bitmap)
    $G.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $G.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $Gradient = [Drawing.Drawing2D.LinearGradientBrush]::new([Drawing.Rectangle]::new(0, 0, $Width, $Height), (Color $Top), (Color $Bottom), [single]90)
    try {
        $G.FillRectangle($Gradient, 0, 0, $Width, $Height)
        & $Paint $G $Width $Height
        $Bitmap.Save((Join-Path $GraphicsRoot $Name), [Drawing.Imaging.ImageFormat]::Png)
        $GraphicFiles.Add($Name)
    } finally { $Gradient.Dispose(); $G.Dispose(); $Bitmap.Dispose() }
}
function Vinyl($G, $X, $Y, $Size, [string]$Accent) {
    Oval $G $X $Y $Size $Size '#141923'
    foreach ($Inset in @(0.05, 0.1, 0.16, 0.23)) {
        $Pen = [Drawing.Pen]::new((Color '#343943'), 2)
        try { $G.DrawEllipse($Pen, [single]($X + $Inset * $Size), [single]($Y + $Inset * $Size), [single]($Size * (1 - 2 * $Inset)), [single]($Size * (1 - 2 * $Inset))) } finally { $Pen.Dispose() }
    }
    Oval $G ($X + $Size * 0.35) ($Y + $Size * 0.35) ($Size * 0.3) ($Size * 0.3) $Accent
    Oval $G ($X + $Size * 0.48) ($Y + $Size * 0.48) ($Size * 0.04) ($Size * 0.04) '#F2EBD9'
}
function Guitar($G, $X, $Y, $Scale, [string]$Wood) {
    Oval $G $X ($Y + 155 * $Scale) (160 * $Scale) (170 * $Scale) $Wood
    Oval $G ($X + 20 * $Scale) ($Y + 100 * $Scale) (120 * $Scale) (130 * $Scale) $Wood
    Rect $G ($X + 66 * $Scale) $Y (28 * $Scale) (225 * $Scale) '#644130'
    Oval $G ($X + 54 * $Scale) ($Y + 185 * $Scale) (53 * $Scale) (53 * $Scale) '#241F29'
    Rect $G ($X + 48 * $Scale) ($Y + 266 * $Scale) (68 * $Scale) (12 * $Scale) '#3D2D29'
    for ($StringIndex = 0; $StringIndex -lt 6; $StringIndex++) {
        Line $G ($X + (70 + $StringIndex * 4) * $Scale) $Y ($X + (70 + $StringIndex * 4) * $Scale) ($Y + 272 * $Scale) '#EFD8AD' 1
    }
}
function Stage($G, $Width, $Height, [string]$Accent, [string]$Second) {
    for ($Lamp = 0; $Lamp -lt 5; $Lamp++) {
        $Center = $Width * (0.1 + $Lamp * 0.2)
        Poly $G @(@(($Center - 16), 0), @(($Center + 16), 0), @(($Center + $Width * 0.15), ($Height * 0.75)), @(($Center - $Width * 0.15), ($Height * 0.75))) $(if ($Lamp % 2) { $Second } else { $Accent })
        Oval $G ($Center - 12) 10 24 24 '#FFE8AB'
    }
    Rect $G 0 ($Height * 0.73) $Width ($Height * 0.27) '#171421'
    Oval $G ($Width * 0.39) ($Height * 0.45) ($Width * 0.22) ($Width * 0.22) '#C88648'
    Oval $G ($Width * 0.405) ($Height * 0.475) ($Width * 0.19) ($Width * 0.19) '#252132'
    Line $G ($Width * 0.27) ($Height * 0.35) ($Width * 0.27) ($Height * 0.75) '#CBC9CD' 7
    Line $G ($Width * 0.71) ($Height * 0.3) ($Width * 0.71) ($Height * 0.76) '#CBC9CD' 7
    Oval $G ($Width * 0.19) ($Height * 0.32) ($Width * 0.17) 18 '#D4B76C'
    Oval $G ($Width * 0.64) ($Height * 0.28) ($Width * 0.15) 18 '#D4B76C'
    Guitar $G ($Width * 0.79) ($Height * 0.32) ($Height / 650) '#D59356'
    for ($Audience = 0; $Audience -lt 13; $Audience++) {
        $AX = $Width * $Audience / 12
        Oval $G ($AX - 38) ($Height * 0.89) 76 76 '#090D17'
        Oval $G ($AX - 60) ($Height * 0.96) 120 120 '#090D17'
    }
}
function Studio($G, $Width, $Height, [string]$Accent) {
    Rect $G ($Width * 0.06) ($Height * 0.07) ($Width * 0.88) ($Height * 0.55) '#253637'
    for ($Panel = 0; $Panel -lt 13; $Panel++) { Rect $G ($Width * (0.08 + $Panel * 0.067)) ($Height * 0.09) ($Width * 0.027) ($Height * 0.5) '#668073' }
    Rect $G ($Width * 0.31) ($Height * 0.2) ($Width * 0.38) ($Height * 0.36) '#101722'
    Rect $G ($Width * 0.33) ($Height * 0.23) ($Width * 0.34) ($Height * 0.3) '#173639'
    for ($Track = 0; $Track -lt 5; $Track++) {
        for ($Beat = 0; $Beat -lt 12; $Beat++) {
            $BH = 6 + (($Beat * 17 + $Track * 13) % 28)
            Rect $G ($Width * 0.34 + $Beat * $Width * 0.026) ($Height * (0.26 + $Track * 0.047)) ($Width * 0.011) $BH $Accent
        }
    }
    foreach ($SpeakerX in @(($Width * 0.1), ($Width * 0.74))) {
        Rect $G $SpeakerX ($Height * 0.29) ($Width * 0.15) ($Height * 0.3) '#162125'
        Oval $G ($SpeakerX + $Width * 0.025) ($Height * 0.34) ($Width * 0.1) ($Width * 0.1) '#101417'
        Oval $G ($SpeakerX + $Width * 0.054) ($Height * 0.38) ($Width * 0.044) ($Width * 0.044) '#A9BBA7'
    }
    Poly $G @(@(0, ($Height * 0.72)), @(($Width * 0.2), ($Height * 0.59)), @(($Width * 0.8), ($Height * 0.59)), @($Width, ($Height * 0.72)), @($Width, $Height), @(0, $Height)) '#BC8A5F'
    Rect $G ($Width * 0.16) ($Height * 0.69) ($Width * 0.68) ($Height * 0.23) '#273A3D'
    for ($Fader = 0; $Fader -lt 16; $Fader++) {
        $FX = $Width * (0.19 + $Fader * 0.039)
        Line $G $FX ($Height * 0.72) $FX ($Height * 0.87) '#12272A' 4
        Rect $G ($FX - 7) ($Height * 0.74 + ($Fader * 17 % 49)) 14 8 '#DAE6DA'
    }
}

$AvatarPalettes = @(
    @('#34475B', '#E5B59D', '#292238', '#EEC074'),
    @('#995D6E', '#D89B7D', '#2B222A', '#D5DDBC'),
    @('#212F49', '#E9A864', '#596674', '#82C2BC'),
    @('#D8B592', '#583637', '#DA705D', '#F8E3A3'),
    @('#698885', '#C78F6D', '#26263A', '#E8B1A0'),
    @('#263A39', '#BFA074', '#F0D19E', '#73ACA1')
)
for ($AvatarIndex = 0; $AvatarIndex -lt 6; $AvatarIndex++) {
    $CurrentAvatar = $AvatarIndex
    $Palette = $AvatarPalettes[$AvatarIndex]
    Canvas "avatar-$AvatarIndex.png" 512 512 $Palette[0] '#171E2C' {
        param($G, $Width, $Height)
        if ($CurrentAvatar -eq 2) {
            foreach ($PersonX in @(95, 215, 335)) {
                Oval $G $PersonX 150 94 106 $Palette[1]
                Oval $G ($PersonX - 18) 245 130 220 $Palette[3]
                Oval $G ($PersonX - 4) 126 104 62 $Palette[2]
            }
        } elseif ($CurrentAvatar -eq 3) {
            Rect $G 55 110 402 320 '#653F40'
            for ($Window = 0; $Window -lt 4; $Window++) { Rect $G (85 + 89 * $Window) 185 54 144 '#E9C785' }
            Rect $G 78 111 356 58 '#2B3543'
            Words $G 'SAHNE 34' 137 121 37 '#F5DD9E'
            Rect $G 0 421 512 91 '#394151'
        } elseif ($CurrentAvatar -eq 5) {
            Vinyl $G 105 83 300 '#70BAA7'
            Words $G 'ATÖLYE' 132 395 47 '#F5EAD2'
        } else {
            Oval $G 95 275 332 370 $Palette[3]
            Oval $G 148 95 225 293 $Palette[2]
            Oval $G 172 132 179 208 $Palette[1]
            Oval $G 159 90 190 95 $Palette[2]
            Rect $G 230 316 63 50 $Palette[1]
            Line $G 205 225 217 225 '#352C31' 6
            Line $G 302 225 314 225 '#352C31' 6
            Line $G 242 282 279 282 '#975E60' 4
            if ($CurrentAvatar -eq 4) {
                $Pen = [Drawing.Pen]::new((Color '#EDD2B4'), 18)
                try { $G.DrawArc($Pen, 150, 109, 215, 226, 190, 160) } finally { $Pen.Dispose() }
                Rect $G 140 221 37 81 '#EDD2B4'
                Rect $G 341 221 37 81 '#EDD2B4'
            }
        }
    }
}

Canvas 'photo-landscape.png' 1280 720 '#2C334B' '#966A5F' { param($G,$Width,$Height) Stage $G $Width $Height '#66526B' '#926763' }
Canvas 'photo-no-caption.png' 1280 720 '#3A655D' '#172C31' { param($G,$Width,$Height) Studio $G $Width $Height '#83CEC0' }
Canvas 'photo-long-caption.png' 1280 720 '#6D5546' '#191F28' {
    param($G,$Width,$Height)
    Rect $G 80 50 510 560 '#304147'
    for ($Slat=0; $Slat -lt 9; $Slat++) { Line $G (110+$Slat*57) 60 (110+$Slat*57) 590 '#63796E' 9 }
    Guitar $G 690 82 1.65 '#C89463'
    Vinyl $G 35 470 275 '#C97C62'
    Words $G 'GECE PROVASI' 370 610 51 '#F3DFBF'
}
Canvas 'photo-square.png' 1000 1000 '#E2B876' '#BA7778' {
    param($G,$Width,$Height)
    Oval $G 170 95 710 710 '#EFCAA0'
    Vinyl $G 165 132 680 '#A04C59'
    Words $G 'YENİ BİR SES' 99 855 78 '#382C3F'
}
Canvas 'photo-social.png' 1000 1000 '#497B77' '#23314A' {
    param($G,$Width,$Height)
    Studio $G $Width 850 '#E0B98D'
    Words $G 'birlikte üret.' 113 877 89 '#F0E3C7'
}
Canvas 'photo-portrait.png' 720 1280 '#372D41' '#BD877A' {
    param($G,$Width,$Height)
    Oval $G -180 50 810 810 '#745269'
    Guitar $G 203 243 2.0 '#E0AC70'
    Words $G 'AKUSTİK' 70 987 89 '#F3DEB2'
    Words $G 'pazar oturumu' 83 1100 46 '#F3DEB2' $false
}
Canvas 'photo-video.png' 1280 720 '#183B50' '#486973' { param($G,$Width,$Height) Stage $G $Width $Height '#2B697A' '#426665' }
Canvas 'photo-portrait-video.png' 720 1280 '#8A6757' '#24373C' {
    param($G,$Width,$Height)
    Rect $G 66 40 588 725 '#253E42'
    for ($SoundBar=0; $SoundBar -lt 13; $SoundBar++) { Rect $G (103+$SoundBar*41) (190+($SoundBar*53%160)) 17 (180+($SoundBar*33%180)) '#81BBA3' }
    Oval $G 225 690 285 350 '#BDA278'
    Oval $G 238 700 260 275 '#263C3D'
    Line $G 363 1005 363 1220 '#D7C59F' 14
    Words $G 'ONE TAKE' 82 93 70 '#E8D3AC'
}
Canvas 'poster.png' 1280 720 '#CBA582' '#DEBC8C' {
    param($G,$Width,$Height)
    Oval $G 750 -120 700 700 '#9B4E55'
    Vinyl $G 790 92 430 '#E3B777'
    Words $G 'SAHNE 34 SUNAR' 75 49 27 '#553648'
    Words $G 'GECE' 61 116 147 '#553648'
    Words $G 'FREKANSI' 63 282 113 '#553648'
    Words $G 'ADA DENİZ  /  SELİN AKIN' 78 459 35 '#553648'
    Line $G 80 553 710 553 '#553648' 3
    Words $G '18 EYLÜL  ·  21.00  ·  İSTANBUL' 76 584 32 '#553648'
}
Canvas 'sponsor.png' 1280 720 '#153634' '#254D46' {
    param($G,$Width,$Height)
    for ($Ring=0; $Ring -lt 5; $Ring++) { Oval $G (660+$Ring*30) (80+$Ring*30) (530-$Ring*60) (530-$Ring*60) $(if ($Ring%2) {'#285E55'} else {'#D8B878'}) }
    Words $G 'ATÖLYE SES' 80 100 79 '#F0D9A5'
    Words $G 'Yeni şarkının' 83 252 57 '#EFE7D8'
    Words $G 'ilk odası.' 83 330 57 '#EFE7D8'
    Words $G 'KAYIT  /  MİKS  /  PROVA' 86 563 29 '#CAB88E'
}
Canvas 'announcement-image.png' 1280 720 '#423D69' '#C08292' {
    param($G,$Width,$Height)
    Oval $G 790 -150 600 600 '#DBAD94'
    Oval $G 855 143 415 415 '#777393'
    Words $G 'SoundConnect' 74 54 35 '#EADDD8'
    Words $G 'SESİNİ' 64 164 134 '#F7E5D0'
    Words $G 'BİRLİKTE BÜYÜTELİM.' 75 333 58 '#F7E5D0'
    Words $G 'Yeni buluşmalar. Yeni iş birlikleri.' 80 568 34 '#F0DDE0' $false
}
Canvas 'announcement-video.png' 1280 720 '#0F3548' '#397B83' {
    param($G,$Width,$Height)
    for ($Wave=0; $Wave -lt 18; $Wave++) {
        $WaveHeight = 60 + ($Wave*73%230)
        Rect $G (590+$Wave*34) (335-$WaveHeight/2) 16 $WaveHeight '#79BBB6'
    }
    Words $G 'SoundConnect' 73 58 36 '#C7DED7'
    Words $G 'BURADA' 66 208 92 '#F2DEAF'
    Words $G 'BİR SES VAR.' 68 319 71 '#F2DEAF'
    Words $G 'Topluluğun hikâyesi' 77 570 37 '#D3E4DC' $false
}

$ManifestPath = Join-Path $GraphicsRoot 'manifest.json'
$ManifestNames = @($GraphicFiles.ToArray())
[IO.File]::WriteAllText($ManifestPath, (ConvertTo-Json -InputObject $ManifestNames), [Text.UTF8Encoding]::new($false))
Write-Output "Generated $($GraphicFiles.Count) original PNG fixtures in $GraphicsRoot"
