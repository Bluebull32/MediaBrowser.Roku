'** Credit: Plex Roku https://github.com/plexinc/roku-client-public

' Debug screen saver on port 8087

Sub RunScreenSaver()
    m.RegistryCache = CreateObject("roAssociativeArray")
    mode = firstOf(RegRead("screensaver"), "random")

    if mode <> "disabled" then
        initGlobals()
        DisplayScreenSaver(mode)
    else
        Debug("Deferring to system screensaver")
    end if
End Sub

Sub DisplayScreenSaver(mode)
    if getGlobalVar("isHD") then
        m.default_screensaver = {url:"pkg:/images/channel/hd-home-tile.png", SourceRect:{w:336,h:210}, TargetRect:{x:0,y:0}}
    else
        m.default_screensaver = {url:"pkg:/images/channel/sd-home-tile.png", SourceRect:{w:248,h:140}, TargetRect:{x:0,y:0}}
    end if

    m.ss_timer = CreateObject("roTimespan")
    m.ss_last_url = invalid

    canvas = CreateScreenSaverCanvas("#FF000000")
    canvas.SetImageFunc(GetScreenSaverImage)
    canvas.SetUpdatePeriodInMS(6000)
    canvas.SetUnderscan(.05)

    if mode = "animated" then
        canvas.SetLocFunc(screensaverLib_SmoothAnimation)
        canvas.SetLocUpdatePeriodInMS(40)
    else if mode = "random" then
        canvas.SetLocFunc(screensaverLib_RandomLocation)
        canvas.SetLocUpdatePeriodInMS(0)
    else
        Debug("Unrecognized screensaver preference: " + tostr(mode))
        return
    end if

    canvas.Go()
End Sub

Function GetScreenSaverImage()
    'savedImage = ReadAsciiFile("tmp:/mediabrowser_screensaver")
   ' if savedImage <> "" then
        'tokens = savedImage.Tokenize("\")
        'width = tokens[0].toint()
       ' height = tokens[1].toint()
        'image = {url:tokens[2], SourceRect:{w:width, h:height}, TargetRect:{x:0,y:0}}
    'else
        'image = m.default_screensaver
    'end if

	image = m.default_screensaver

    ' If we've been on the same screensaver image for a long time, give the
    ' PMS a break and switch to the default image from the package.

    if m.ss_last_url <> image.url then
        m.ss_timer.Mark()
        m.ss_last_url = image.url
    end if

    if left(image.url, 4) <> "pkg:" AND m.ss_timer.TotalSeconds() > 7200 then
        'SaveImagesForScreenSaver(invalid, {})
    end if

    o = CreateObject("roAssociativeArray")
    o.art = image
    o.content_list = [image]

    o.GetHeight = function() :return m.art.SourceRect.h :end function
    o.GetWidth  = function() :return m.art.SourceRect.w :end function
    o.Update = function(x, y)
        m.art.TargetRect.x = x
        m.art.TargetRect.y = y
        return m.content_list
    end function

    return o
End Function

Sub SaveImagesForScreenSaver(item, sizes)

    if item = invalid then
        WriteFileHelper("tmp:/mediabrowser_screensaver", invalid, invalid, invalid)
    else if getGlobalVar("isHD") then
        WriteFileHelper("tmp:/mediabrowser_screensaver", item.HDPosterURL + token, sizes.hdWidth, sizes.hdHeight)
    else
        WriteFileHelper("tmp:/mediabrowser_screensaver", item.SDPosterURL + token, sizes.sdWidth, sizes.sdHeight)
    end if
End Sub

Sub WriteFileHelper(fname, url, width, height)
    Debug("Saving image for screensaver: " + tostr(url))
    if url <> invalid then
        content = width + "\" + height + "\" + url
        if (not WriteAsciiFile(fname + "~", content)) then Debug("WriteAsciiFile() Failed")
        if (not MoveFile(fname + "~",fname)) then Debug("MoveFile() failed")
    else
        DeleteFile(fname)
    end if
End Sub