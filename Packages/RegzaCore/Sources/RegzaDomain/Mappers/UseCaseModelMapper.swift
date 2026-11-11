import Foundation

/// Repository の Data と、UseCase が公開する SharedModel の境界。
package enum UseCaseModelMapper {
    package static func connection(_ data: ConnectionData) -> ConnectionItem {
        ConnectionItem(host: data.host, user: data.user, password: data.password)
    }

    package static func connectionData(_ item: ConnectionItem) -> ConnectionData {
        ConnectionData(host: item.host, user: item.user, password: item.password)
    }

    package static func channel(_ data: ChannelData) -> ChannelItem {
        ChannelItem(
            code: data.code, name: data.name, numberText: data.formattedNumber, programName: nil,
            isNowPlaying: false, hasPrograms: false, canStartOver: false,
            isSubchannel: !data.isRepresentative && data.band != .cs,
            band: data.band, isRepresentative: data.isRepresentative, remoteNumber: data.remoteNumber
        )
    }

    package static func nowPlaying(_ data: NowPlayingData) -> NowPlayingItem {
        NowPlayingItem(
            kind: NowPlayingKind(rawValue: data.kind.rawValue) ?? .unknown,
            channelName: data.channelName,
            channelCode: data.channelCode,
            title: data.title,
            description: data.description,
            chapterName: data.chapterName,
            genre: data.genre,
            position: data.position,
            duration: data.duration,
            isAdvancing: data.isAdvancing,
            updatedAt: data.updatedAt,
            nextProgramStart: data.nextProgramStart,
            nextProgramDuration: data.nextProgramDuration,
            nextTitle: data.nextTitle,
            shortChannel: data.shortChannel,
            captionText: data.captionText,
            headlineText: data.headlineText,
            statusText: data.statusText
        )
    }

    package static func program(_ data: ProgramData, isReserved: Bool, now: Date) -> ProgramItem {
        let minutes = Int(data.end.timeIntervalSince(data.start) / 60)
        return ProgramItem(
            id: data.id, channelCode: data.channelCode, name: data.name, description: data.description,
            start: data.start, end: data.end, startText: DisplayText.time(data.start),
            timeText: "\(DisplayText.range(data.start, data.end)) · \(minutes)分",
            genreName: data.genreName, genre: data.genres.first ?? -1, isOnAir: data.isOnAir(at: now),
            isReserved: isReserved
        )
    }

    package static func programTexts(_ data: ProgramData) -> [ProgramTextItem] {
        data.extended.map { ProgramTextItem(title: $0.title, text: $0.text) }
    }

    package static func reservation(_ data: ReservationData, channelName: String? = nil, now: Date) -> ReservationItem {
        let scheduled = data.isScheduled(now: now)
        return ReservationItem(
            id: data.id, title: data.title, timeText: DisplayText.range(data.start, data.end),
            repeatLabel: data.repeatLabel, isSeries: data.isSeries, channelName: channelName,
            isRecording: scheduled && data.start <= now, isScheduled: scheduled
        )
    }
}
