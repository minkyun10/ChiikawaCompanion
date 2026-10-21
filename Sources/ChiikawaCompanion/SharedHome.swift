import AppKit

extension DesktopController {
    var homeOccupants: [HomeOccupant] {
        actors.compactMap { actor in
            guard state.isVisible(actor.friend), let routine = homeRoutines[actor.friend], routine.isInside else { return nil }
            return HomeOccupant(friend: actor.friend, routine: routine)
        }
    }

    /// A skin is presentation only: it cannot choose who may enter the house.
    func activateSharedHome(now: Date = Date()) {
        let sleepers = homeOccupants.map(\.friend)
        if sleepers.isEmpty {
            for actor in actors where state.isVisible(actor.friend) { sendHome(actor.friend, now: now) }
        } else {
            for friend in sleepers { wakeFriend(friend, now: now) }
        }
    }

    func sendHome(_ friend: Friend, now: Date = Date()) {
        switch friend {
        case .hachiware: goHome(now: now)
        case .chiikawa: goChiikawaHome(now: now)
        default: break
        }
    }

    func wakeFriend(_ friend: Friend, now: Date = Date()) {
        switch friend {
        case .hachiware: wakeFromHome(now: now)
        case .chiikawa: wakeChiikawa(now: now)
        default: break
        }
    }
}
