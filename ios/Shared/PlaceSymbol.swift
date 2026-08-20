//
//  PlaceSymbol.swift
//  Shared
//
//  Giving each place the glyph Maps would give it.
//
//  Apple does not vend the artwork it draws on its own map pins, so this is the
//  nearest honest equivalent: MKMapItem hands over a point-of-interest category
//  with every share, and every category has a reasonable SF Symbol. A café gets
//  a cup, a bike shop gets a bicycle, and anything unrecognised falls back to
//  the pin — which is exactly what Maps does with an address or a dropped pin.
//

import MapKit

enum PlaceSymbol {

    /// What an unclassified place gets. Also what everything sent before this
    /// existed gets, since `symbol` decodes as nil for those records.
    static let fallback = "mappin.and.ellipse"

    /// Categories are grouped by what they *are* to a rider, not by Apple's
    /// taxonomy — a brewery and a winery both read as a drink.
    static func name(for category: MKPointOfInterestCategory?) -> String? {
        guard let category else { return nil }
        if #available(iOS 18.0, *), let newer = added18(category) { return newer }
        switch category {
        case .cafe, .bakery:                          return "cup.and.saucer.fill"
        case .restaurant, .foodMarket:                return "fork.knife"
        case .brewery, .winery, .nightlife:           return "wineglass.fill"
        case .store:                                  return "bag.fill"
        case .hotel:                                  return "bed.double.fill"
        case .park, .nationalPark, .campground:       return "tree.fill"
        case .beach:                                  return "beach.umbrella.fill"
        case .marina:                                 return "sailboat.fill"
        case .museum, .aquarium, .zoo:                return "building.columns.fill"
        case .theater, .movieTheater:                 return "theatermasks.fill"
        case .library, .school, .university:          return "book.fill"
        case .stadium, .fitnessCenter:                return "figure.run"
        case .hospital, .pharmacy:                    return "cross.case.fill"
        case .gasStation, .evCharger:                 return "fuelpump.fill"
        case .parking:                                return "parkingsign"
        case .airport:                                return "airplane"
        case .publicTransport:                        return "tram.fill"
        case .bank, .atm:                             return "banknote.fill"
        case .postOffice:                             return "envelope.fill"
        case .restroom:                               return "figure.dress.line.vertical.figure"
        case .laundry:                                return "washer.fill"
        case .amusementPark:                          return "ferriswheel"
        case .fireStation, .police:                   return "shield.fill"
        default:                                      return nil
        }
    }
}

@available(iOS 18.0, *)
private extension PlaceSymbol {
    /// The categories Apple added in iOS 18. Split out rather than guarded
    /// case by case, which the compiler does not allow inside a switch.
    static func added18(_ category: MKPointOfInterestCategory) -> String? {
        switch category {
        case .musicVenue:                                       return "theatermasks.fill"
        case .distillery:                                       return "wineglass.fill"
        case .landmark, .castle, .fortress, .nationalMonument:  return "building.columns.fill"
        case .hiking:                                           return "figure.hiking"
        case .skiing:                                           return "figure.skiing.downhill"
        case .swimming:                                         return "figure.pool.swim"
        case .golf, .miniGolf:                                  return "figure.golf"
        case .tennis, .basketball, .soccer, .baseball,
             .volleyball, .bowling, .skating, .skatePark:       return "sportscourt.fill"
        case .automotiveRepair:                                 return "wrench.and.screwdriver.fill"
        case .mailbox:                                          return "envelope.fill"
        case .spa, .beauty:                                     return "sparkles"
        case .rvPark:                                           return "bus.fill"
        case .animalService:                                    return "pawprint.fill"
        default:                                                return nil
        }
    }
}
