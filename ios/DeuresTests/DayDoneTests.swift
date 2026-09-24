import Foundation
import Testing
@testable import Deures

struct DayDoneTests {
  let start = URL(string: "https://deures.example.com/")!
  let page = URL(string: "https://deures.example.com/")

  @Test func decodesTheChildAndTheDate() throws {
    let done = try #require(DayDone(jsonData: #"{"child_id":1,"date":"2026-09-14"}"#, pageURL: page, startLocation: start))

    #expect(done.childID == 1)
    #expect(done.date.description == "2026-09-14")
  }

  @Test(arguments: ["2026-9-14", "2026-02-30", "14/09/2026", "", "2026-09-14T00:00:00Z"])
  func rejectsAMalformedDate(date: String) {
    #expect(DayDone(jsonData: #"{"child_id":1,"date":"\#(date)"}"#, pageURL: page, startLocation: start) == nil)
  }

  @Test(arguments: [#"{"date":"2026-09-14"}"#, #"{"child_id":"1","date":"2026-09-14"}"#, #"{"child_id":0,"date":"2026-09-14"}"#, "not json"])
  func rejectsAMissingOrInvalidChild(json: String) {
    #expect(DayDone(jsonData: json, pageURL: page, startLocation: start) == nil)
  }

  @Test(arguments: ["https://elsewhere.example.com/", "http://deures.example.com/", "https://deures.example.com.evil.example/"])
  func ignoresAMessageFromAPageOffTheStartHost(url: String) {
    #expect(DayDone(jsonData: #"{"child_id":1,"date":"2026-09-14"}"#, pageURL: URL(string: url), startLocation: start) == nil)
  }

  @Test func ignoresAMessageWhenThePageHasNoURL() {
    #expect(DayDone(jsonData: #"{"child_id":1,"date":"2026-09-14"}"#, pageURL: nil, startLocation: start) == nil)
  }
}
