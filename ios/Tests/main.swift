//
//  Checks for the share extension's URL parsing.
//
//  Deliberately not an XCTest target — this needs no simulator and no project
//  surgery. It lives outside SendPin/ and SendPinShare/ so the file-system
//  synchronized groups don't sweep it into a build.
//
//      ios/Tests/run.sh
//
//  Parsing is the part that fails quietly: a wrong coordinate still looks like
//  a successful send, right up until the Karoo routes you somewhere else.
//

import Foundation

var failures = 0

func expect(_ raw: String, lat: Double?, lng: Double?, name: String?, _ label: String) {
    let d = URL(string: raw).flatMap { Destination(mapsURL: $0) }
    let gotLat = d?.latitude, gotLng = d?.longitude, gotName = d?.name
    let ok = gotLat == lat && gotLng == lng && gotName == name
    if !ok {
        failures += 1
        print("FAIL  \(label)")
        print("      url:      \(raw)")
        print("      expected: \(String(describing: lat)), \(String(describing: lng)), \(String(describing: name))")
        print("      got:      \(String(describing: gotLat)), \(String(describing: gotLng)), \(String(describing: gotName))")
    } else {
        print("ok    \(label)")
    }
}

// Classic Apple Maps share: coordinates in ll, name in q.
expect("https://maps.apple.com/?ll=37.7749,-122.4194&q=Blue%20Bottle%20Coffee",
       lat: 37.7749, lng: -122.4194, name: "Blue Bottle Coffee", "apple ll+q")

// Newer place link: coordinate + name, plus a lot of noise.
expect("https://maps.apple.com/place?address=1%20Test%20St&auid=1234567890123456789&coordinate=51.5074,-0.1278&name=The%20Cafe&place-id=I123",
       lat: 51.5074, lng: -0.1278, name: "The Cafe", "apple place")

// Dropped pin: q holds coordinates, so there is no name.
expect("https://maps.apple.com/?q=37.7749,-122.4194",
       lat: 37.7749, lng: -122.4194, name: nil, "apple dropped pin")

// Search result carrying a span. The span must never be mistaken for a place.
expect("https://maps.apple.com/?ll=45.4642,9.1900&spn=0.01,0.01&q=Duomo",
       lat: 45.4642, lng: 9.1900, name: "Duomo", "apple ll with span")

// Span but no real coordinate: must refuse rather than invent a location.
expect("https://maps.apple.com/?spn=0.01,0.01&q=coffee",
       lat: nil, lng: nil, name: nil, "span only, no coordinate")

// Directions link.
expect("https://maps.apple.com/?daddr=48.8584,2.2945&dirflg=w",
       lat: 48.8584, lng: 2.2945, name: nil, "apple daddr")

// Google Maps desktop URL: coordinates live in the path.
expect("https://www.google.com/maps/place/Somewhere/@35.6595,139.7005,17z/data=!3m1",
       lat: 35.6595, lng: 139.7005, name: nil, "google path")

// Short links carry nothing parseable — must fail cleanly.
expect("https://maps.app.goo.gl/aBcDeF123", lat: nil, lng: nil, name: nil, "google short link")
expect("https://maps.apple.com/p/abc123", lat: nil, lng: nil, name: nil, "apple short link")

// Not a map at all.
expect("https://example.com/article", lat: nil, lng: nil, name: nil, "unrelated url")

// Out-of-range numbers are not coordinates.
expect("https://maps.apple.com/?q=199.5,-500.25", lat: nil, lng: nil, name: nil, "out of range")

// Southern/western hemisphere, through to the waypoint that actually gets sent.
// Asserts on Waypoint rather than a URL: the share extension advertises the
// waypoint directly, so this is the last form the value takes before it leaves
// the phone.
if let d = URL(string: "https://maps.apple.com/?ll=-33.8688,151.2093&q=Opera%20House")
    .flatMap({ Destination(mapsURL: $0) }) {
    let w = d.waypoint
    let good = w.lat == -33.8688 && w.lng == 151.2093 && w.name == "Opera House"
    print(good ? "ok    southern hemisphere → waypoint" : "FAIL  southern hemisphere → waypoint -> \(w)")
    if !good { failures += 1 }
} else {
    print("FAIL  southern hemisphere → waypoint (did not parse)"); failures += 1
}

print(failures == 0 ? "\nall passed" : "\n\(failures) failed")
exit(failures == 0 ? 0 : 1)
