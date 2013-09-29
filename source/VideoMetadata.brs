'*****************************************************************
'**  Media Browser Roku Client - Video Metadata
'*****************************************************************


'**********************************************************
'** Get Video Details
'**********************************************************

Function getVideoMetadata(videoId As String) As Object
    ' Validate Parameter
    if validateParam(videoId, "roString", "videometadata_details") = false return invalid

    ' URL
    url = GetServerBaseUrl() + "/Users/" + HttpEncode(getGlobalVar("user").Id) + "/Items/" + HttpEncode(videoId)

    ' Prepare Request
    request = HttpRequest(url)
    request.ContentType("json")
    request.AddAuthorization()

    ' Execute Request
    response = request.GetToStringWithTimeout(10)
    if response <> invalid

        ' Fixes bug within BRS Json Parser
        regex         = CreateObject("roRegex", Chr(34) + "(RunTimeTicks|PlaybackPositionTicks|StartPositionTicks)" + Chr(34) + ":(-?[0-9]+),", "i")
        fixedResponse = regex.ReplaceAll(response, Chr(34) + "\1" + Chr(34) + ":" + Chr(34) + "\2" + Chr(34) + ",")

        i = ParseJSON(fixedResponse)

        if i = invalid
            Debug("Error Parsing Video Metadata")
            return invalid
        end if

        if i.Type = invalid
            Debug("No Content Type Set for Video")
            return invalid
        end if
        
        metaData = {}

        ' Set the Content Type
        metaData.ContentType = i.Type

        ' Set the Id
        metaData.Id = i.Id

        ' Set the Title
        metaData.Title = firstOf(i.Name, "Unknown")

        ' Set the Series Title
        if i.SeriesName <> invalid
            metaData.SeriesTitle = i.SeriesName
        end if

        ' Set the Overview
        if i.Overview <> invalid
            metaData.Description = i.Overview
        end if

        ' Set the Official Rating
        if i.OfficialRating <> invalid
            metaData.Rating = i.OfficialRating
        end if

        ' Set the Release Date
        if isInt(i.ProductionYear)
            metaData.ReleaseDate = itostr(i.ProductionYear)
        end if

        ' Set the Star Rating
        if i.CommunityRating <> invalid
            metaData.UserStarRating = Int(i.CommunityRating) * 10
        end if

        ' Set the Run Time
        if i.RunTimeTicks <> "" And i.RunTimeTicks <> invalid
            metaData.Length = Int(((i.RunTimeTicks).ToFloat() / 10000) / 1000)
        end if

        ' Set the Playback Position
        if i.UserData.PlaybackPositionTicks <> "" And i.UserData.PlaybackPositionTicks <> invalid
            metaData.PlaybackPosition = i.UserData.PlaybackPositionTicks
        end if

        if i.Type = "Movie"

            ' Check For People, Grab First 3 If Exists
            if i.People <> invalid And i.People.Count() > 0
                metaData.Actors = CreateObject("roArray", 3, true)

                ' Set Max People to grab Size of people array
                maxPeople = i.People.Count()-1

                ' Check To Max sure there are 3 people
                if maxPeople > 3
                    maxPeople = 2
                end if

                for actorCount = 0 to maxPeople
                    if i.People[actorCount].Name <> "" And i.People[actorCount].Name <> invalid
                        metaData.Actors.Push(i.People[actorCount].Name)
                    end if
                end for
            end if

        else if i.Type = "Episode"

            ' Build Episode Information
            episodeInfo = ""

            ' Add Series Name
            if i.SeriesName <> invalid
                episodeInfo = i.SeriesName
            end if

            ' Add Season Number
            if i.ParentIndexNumber <> invalid
                if episodeInfo <> ""
                    episodeInfo = episodeInfo + " / "
                end if

                episodeInfo = episodeInfo + "Season " + itostr(i.ParentIndexNumber)
            end if

            ' Add Episode Number
            if i.IndexNumber <> invalid
                if episodeInfo <> ""
                    episodeInfo = episodeInfo + " / "
                end if
                
                episodeInfo = episodeInfo + "Episode " + itostr(i.IndexNumber)

                ' Add Double Episode Number
                if i.IndexNumberEnd <> invalid
                    episodeInfo = episodeInfo + "-" + itostr(i.IndexNumberEnd)
                end if
            end if

            ' Use Actors Area for Series / Season / Episode
            metaData.Actors = episodeInfo

        end if

        ' Setup Watched Status In Category Area
        if i.UserData.Played <> invalid And i.UserData.Played = true
            if i.UserData.LastPlayedDate <> invalid
                metaData.Categories = "Watched on " + formatDateStamp(i.UserData.LastPlayedDate)
            else
                metaData.Categories = "Watched"
            end if
        end if

        ' Setup Chapters
        if i.Chapters <> invalid

            metaData.Chapters = CreateObject("roArray", 5, true)
            chapterCount = 0

            for each c in i.Chapters
                chapterData = {}

                ' Set the chapter display title
                chapterData.Title = firstOf(c.Name, "Unknown")
                chapterData.ShortDescriptionLine1 = firstOf(c.Name, "Unknown")

                ' Set chapter time
                if c.StartPositionTicks <> invalid
                    chapterData.ShortDescriptionLine2 = FormatChapterTime(c.StartPositionTicks)
                    chapterData.StartPositionTicks = c.StartPositionTicks
                end if

                ' Get Image Sizes
                sizes = GetImageSizes("flat-episodic-16x9")

                ' Check if Chapter has Image, otherwise use default
                if c.ImageTag <> "" And c.ImageTag <> invalid
                    imageUrl = GetServerBaseUrl() + "/Items/" + HttpEncode(i.Id) + "/Images/Chapter/" + itostr(chapterCount)

                    chapterData.HDPosterUrl = BuildImage(imageUrl, sizes.hdWidth, sizes.hdHeight, c.ImageTag)
                    chapterData.SDPosterUrl = BuildImage(imageUrl, sizes.sdWidth, sizes.sdHeight, c.ImageTag)

                else 
                    chapterData.HDPosterUrl = "pkg://images/items/collection.png"
                    chapterData.SDPosterUrl = "pkg://images/items/collection.png"

                end if

                ' Increment Count
                chapterCount = chapterCount + 1

                metaData.Chapters.push( chapterData )
            end for

        end if

        ' Setup Video Location / Type Information
        if i.VideoType <> invalid
            metaData.VideoType = i.VideoType
        end If

        if i.Path <> invalid
            metaData.VideoPath = i.Path
        end If

        if i.LocationType <> invalid
            metaData.LocationType = i.LocationType
        end If

        ' Set HD Flags
        if i.IsHd <> invalid
            metaData.HDBranded = i.IsHd
            metaData.IsHD = i.IsHd
        end if

        ' Parse Media Info
        metaData = parseVideoMediaInfo(metaData, i)

        ' Get Image Sizes
        if i.Type = "Episode"
            sizes = GetImageSizes("rounded-rect-16x9-generic")
        else
            sizes = GetImageSizes("movie")
        end if
        
        ' Check if Item has Image, otherwise use default
        if i.ImageTags.Primary <> "" And i.ImageTags.Primary <> invalid
            imageUrl = GetServerBaseUrl() + "/Items/" + HttpEncode(i.Id) + "/Images/Primary/0"

            metaData.HDPosterUrl = BuildImage(imageUrl, sizes.hdWidth, sizes.hdHeight, i.ImageTags.Primary)
            metaData.SDPosterUrl = BuildImage(imageUrl, sizes.sdWidth, sizes.sdHeight, i.ImageTags.Primary)

        else 
            metaData.HDPosterUrl = "pkg://images/items/collection.png"
            metaData.SDPosterUrl = "pkg://images/items/collection.png"

        end if

        return metaData
    else
        Debug("Failed to Get Video Metadata")
    end if

    return invalid
End Function


Function parseVideoMediaInfo(metaData As Object, video As Object) As Object

    ' Setup Video / Audio / Subtitle Streams
    metaData.videoStream     = CreateObject("roAssociativeArray")
    metaData.audioStreams    = CreateObject("roArray", 2, true)
    metaData.subtitleStreams = CreateObject("roArray", 2, true)

    ' Determine Media Compatibility
    compatibleVideo      = false
    compatibleAudio      = false
    foundVideo           = false
    foundDefaultAudio    = false
    firstAudio           = true
    firstAudioChannels   = 0
    defaultAudioChannels = 0
    directPlay           = false

    for each stream in video.MediaStreams

        if stream.Type = "Video" And foundVideo = false
            foundVideo = true
            streamBitrate = Int(stream.BitRate / 1000)

            if (stream.Codec = "h264" Or stream.Codec = "AVC") And stream.Level <= 41 And streamBitrate < 20000
                compatibleVideo = true
            end if

            ' Determine Full 1080p
            if stream.Height = 1080
                metaData.videoStream.FullHD = true
            end if

            ' Determine Frame Rate
            if stream.RealFrameRate <> invalid
                if stream.RealFrameRate >= 29
                    metaData.videoStream.FrameRate = 30
                else
                    metaData.videoStream.FrameRate = 24
                end if

            else if stream.AverageFrameRate <> invalid
                if stream.RealFrameRate >= 29
                    metaData.videoStream.FrameRate = 30
                else
                    metaData.videoStream.FrameRate = 24
                end if

            end if

        else if stream.Type = "Audio" 

            if firstAudio
                firstAudio = false
                firstAudioChannels = firstOf(stream.Channels, 2)

                ' Determine Compatible Audio (Default audio will override)
                if stream.Codec = "aac" Or (stream.Codec = "ac3" And getGlobalVar("audioOutput51")) Or (stream.Codec = "dca" And getGlobalVar("audioOutput51") And getGlobalVar("audioDTS"))
                    compatibleAudio = true
                end if
            end if

            ' Use Default To Determine Surround Sound
            if stream.IsDefault
                foundDefaultAudio = true

                channels = firstOf(stream.Channels, 2)
                defaultAudioChannels = channels
                if channels > 5
                    metaData.AudioFormat = "dolby-digital"
                end if
                
                ' Determine Compatible Audio
                if stream.Codec = "aac" Or (stream.Codec = "ac3" And getGlobalVar("audioOutput51")) Or (stream.Codec = "dca" And getGlobalVar("audioOutput51") And getGlobalVar("audioDTS"))
                    compatibleAudio = true
                else
                    compatibleAudio = false
                end if
            end if

            audioData = {}
            audioData.Title = ""

            ' Set Index
            audioData.Index = stream.Index

            ' Set Language
            if stream.Language <> invalid
                audioData.Title = formatLanguage(stream.Language)
            end if

            ' Set Description
            if stream.Profile <> invalid
                audioData.Title = audioData.Title + ", " + stream.Profile
            else if stream.Codec <> invalid
                audioData.Title = audioData.Title + ", " + stream.Codec
            end if

            ' Set Channels
            if stream.Channels <> invalid
                audioData.Title = audioData.Title + ", Channels: " + itostr(stream.Channels)
            end if

            metaData.audioStreams.push( audioData )

        else if stream.Type = "Subtitle" 

            subtitleData = {}
            subtitleData.Title = ""

            ' Set Index
            subtitleData.Index = stream.Index

            ' Set Language
            if stream.Language <> invalid
                subtitleData.Title = formatLanguage(stream.Language)
            end if

            metaData.subtitleStreams.push( subtitleData )

        end if

    end for

    ' If no default audio was found, use first audio stream
    if Not foundDefaultAudio
        defaultAudioChannels = firstAudioChannels
        if firstAudioChannels > 5
            metaData.AudioFormat = "dolby-digital"
        end if
    end if

    ' Set Video Compatibility And Direct Play
    metaData.CompatVideo = compatibleVideo
    metaData.CompatAudio = compatibleAudio
    metaData.DirectPlay  = directPlay ' Not sure This Is needed

    ' Set the Default Audio Channels
    metaData.DefaultAudioChannels = defaultAudioChannels

    return metaData
End Function



Function setupVideoPlayback(metadata As Object, options = invalid As Object) As Object

    ' Setup Video Playback
    videoType     = LCase(metadata.VideoType)
    locationType  = LCase(metadata.LocationType)
    rokuVersion   = getGlobalVar("rokuVersion")
    audioOutput51 = getGlobalVar("audioOutput51")
    supportsSurroundSound = getGlobalVar("surroundSound")

    ' Set Playback Options
    if options <> invalid
        audioStream    = firstOf(options.audio, false)
        subtitleStream = firstOf(options.subtitle, false)
    else
        audioStream    = false
        subtitleStream = false
    end if

    streamParams = {}

    '''''''''''''''''''''''''''''''
    videoBitrate = "3200"
    '''''''''''''''''''''''''''''''

    if videoType = "videofile"
        extension = getFileExtension(metaData.VideoPath)

        if locationType = "remote"
            action = "transcode"

        else if locationType = "filesystem"

            if metadata.CompatVideo And ( (extension = "mp4" Or extension = "mpv") Or (extension = "mkv" And (rokuVersion[0] > 5 Or (rokuVersion[0] = 5 And rokuVersion[1] >= 1) ) ) )
                if Not audioOutput51 And metaData.DefaultAudioChannels > 2 Or (audioStream Or subtitleStream)
                    action = "streamcopy"
                else
                    if metadata.CompatAudio
                        action = "direct"
                    else
                        action = "streamcopy"
                    end if
                end if

            else
                if metadata.CompatVideo
                    action = "streamcopy"
                else
                    action = "transcode"
                end if
            end if

        end if

    else
        action = "transcode"
    end if



    Print "Action: " + action

    ' Direct Stream
    if action = "direct"
        streamParams.url = GetServerBaseUrl() + "/Videos/" + metadata.Id + "/stream." + extension + "?static=true"
        streamParams.bitrate = 0
        streamParams.quality = true
        streamParams.contentid = "x-direct"

        if extension = "mkv"
            metaData.videoStream.StreamFormat = "mkv"
        else
            metaData.videoStream.StreamFormat = "mp4"
        end if
        metaData.videoStream.Stream = streamParams

    ' Stream Copy
    else if action = "streamcopy"
        streamParams.url = GetServerBaseUrl() + "/Videos/" + metadata.Id + "/stream.m3u8?VideoCodec=copy&VideoBitRate=3200000&MaxWidth=1920&MaxHeight=1080&Profile=high&Level=4.0&AudioCodec=aac&AudioBitRate=128000&AudioChannels=2&AudioSampleRate=44100&TimeStampOffsetMs=0"
        streamParams.bitrate = 0
        streamParams.quality = true
        streamParams.contentid = "x-streamcopy"

        metaData.videoStream.StreamFormat = "hls"
        metaData.videoStream.Stream = streamParams

    ' Transcode
    else
        streamParams.url = GetServerBaseUrl() + "/Videos/" + metadata.Id + "/stream.m3u8?VideoCodec=h264&VideoBitRate=3200000&MaxWidth=1920&MaxHeight=1080&Profile=high&Level=4.0&AudioCodec=aac&AudioBitRate=128000&AudioChannels=2&AudioSampleRate=44100&TimeStampOffsetMs=0"
        streamParams.bitrate = 3200
        streamParams.quality = true
        streamParams.contentid = "x-transcode"

        metaData.videoStream.StreamFormat = "hls"
        metaData.videoStream.Stream = streamParams

    end if

    return metaData
End Function


Function getVideoBitrateSettings(bitrate As Dynamic) As Object
    if bitrate = invalid then bitrate = 3200

    ' Get Bitrate Settings
    if bitrate = 664
        settings = {
            videobitrate: "664000"
            maxwidth: "640"
            maxheight: "360"
            profile: "high"
            level: "4.0"
        }

    else if bitrate = 996
        settings = {
            videobitrate: "996000"
            maxwidth: "1280"
            maxheight: "720"
            profile: "high"
            level: "4.0"
        }

    else if bitrate = 1320
        settings = {
            videobitrate: "1320000"
            maxwidth: "1280"
            maxheight: "720"
            profile: "high"
            level: "4.0"
        }

    else if bitrate = 2600
        settings = {
            videobitrate: "2600000"
            maxwidth: "1920"
            maxheight: "1080"
            profile: "high"
            level: "4.0"
        }

    else if bitrate = 3200
        settings = {
            videobitrate: "3200000"
            maxwidth: "1920"
            maxheight: "1080"
            profile: "high"
            level: "4.0"
        }

    else if bitrate = 4500
        settings = {
            videobitrate: "4500000"
            maxwidth: "1920"
            maxheight: "1080"
            profile: "high"
            level: "4.0"
        }

    else if bitrate = 5800
        settings = {
            videobitrate: "5800000"
            maxwidth: "1920"
            maxheight: "1080"
            profile: "high"
            level: "4.0"
        }

    else if bitrate = 7200
        settings = {
            videobitrate: "7200000"
            maxwidth: "1920"
            maxheight: "1080"
            profile: "high"
            level: "4.0"
        }

    else if bitrate = 8600
        settings = {
            videobitrate: "8600000"
            maxwidth: "1920"
            maxheight: "1080"
            profile: "high"
            level: "4.0"
        }

    end if
    
    return settings
End Function
