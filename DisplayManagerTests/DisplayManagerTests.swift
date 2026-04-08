//
//  DisplayManagerTests.swift
//  DisplayManagerTests
//
//  Created by Divyansh Singh on 05/07/25.
//

import Testing
@testable import DisplayManager

struct DisplayManagerTests {
    @Test func parseDisplayTypesParsesMultipleBlocks() async throws {
        let input = """
        Persistent screen id: abcdef12-3456-7890-abcd-ef1234567890
        Type: Built-in Retina Display
        Persistent screen id: 11111111-2222-3333-4444-555555555555
        Type: DELL U2720Q
        """

        let parsed = parseDisplayTypes(from: input)
        #expect(parsed["abcdef12-3456-7890-abcd-ef1234567890"] == "Built-in Retina Display")
        #expect(parsed["11111111-2222-3333-4444-555555555555"] == "DELL U2720Q")
    }

    @Test func parseDisplayTypesReturnsEmptyForInvalidInput() async throws {
        let parsed = parseDisplayTypes(from: "unexpected output")
        #expect(parsed.isEmpty)
    }
}
