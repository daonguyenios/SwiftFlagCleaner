import Testing
import SwiftParser
@testable import SwiftFlagCleaner

private func cleanSource(_ source: String) -> String {
    let syntaxTree = Parser.parse(source: source)
    let cleanedSource = SwiftCleanerRewriter(flag: "FEATURE_FLAG")
        .rewrite(syntaxTree.root)

    return cleanedSource.description
}

struct SwiftCleanerRewriterTests {
  @Test func ifEnabledFlag() async throws {
    let source =
      """
      #if FEATURE_FLAG
      let enabledPart = "Enabled Part"
      #endif
      """

    let expectedCleanedSource =
      """
      let enabledPart = "Enabled Part"
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func notIfEnabledFlag() async throws {
    let source =
      """
      #if !FEATURE_FLAG
      let enabledPart = "Enabled Part"
      #endif
      """

    let expectedCleanedSource =
      """
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func elseEnabledFlag() async throws {
    let source =
      """
      #if !FEATURE_FLAG
      let disabledPart = "Disabled Part"
      #else
      let enabledPart = "Enabled Part"
      #endif
      """

    let expectedCleanedSource =
      """
      let enabledPart = "Enabled Part"
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func hasIndentation() async throws {
    let source =
      """
      #if !FEATURE_FLAG
          let disabledPart = "Disabled Part"
      #else
          let enabledPart = "Enabled Part"
      #endif
      """

    let expectedCleanedSource =
      """
          let enabledPart = "Enabled Part"
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func hasNewlines() async throws {
    let source =
      """
      #if !FEATURE_FLAG

          let disabledPart = "Disabled Part"
      #else

          let enabledPart = "Enabled Part"
      #endif
      """

    let expectedCleanedSource =
      """

          let enabledPart = "Enabled Part"
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func hasComments() async throws {
    let source =
      """
      // Top comment
      #if !FEATURE_FLAG // Disabled
          /*
            Internal comment
          */
          let disabledPart = "Disabled Part"
      #else // FEATURE_FLAG
          /*
                Internal comment
          */
          let enabledPart = "Enabled Part"
      #endif // FEATURE_FLAG
      /// Bottom comment
      """

    let expectedCleanedSource =
      """
      // Top comment
          /*
                Internal comment
          */
          let enabledPart = "Enabled Part"
      /// Bottom comment
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func keepNewlinesAbove() async throws {
    let source =
      """
      #import Module

      #if FEATURE_FLAG
      let enabledPart = "Enabled Part"
      #endif
      """

    let expectedCleanedSource =
      """
      #import Module

      let enabledPart = "Enabled Part"
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func keepNewlinesBelow() async throws {
    let source =
      """
      #if FEATURE_FLAG
      let enabledPart = "Enabled Part"
      #endif

      let foo = "foo"
      """

    let expectedCleanedSource =
      """
      let enabledPart = "Enabled Part"

      let foo = "foo"
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func multipleEnabledFlags() async throws {
    let source =
      """
      #if FEATURE_FLAG
      let enabledPart = "Enabled Part"
      #endif

      #if FEATURE_FLAG
      let enabledPart2 = "Enabled Part"
      #endif

      #if FEATURE_FLAG
      let enabledPart3 = "Enabled Part"
      #endif
      """

    let expectedCleanedSource =
      """
      let enabledPart = "Enabled Part"

      let enabledPart2 = "Enabled Part"

      let enabledPart3 = "Enabled Part"
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }

  @Test func nestedFlags() async throws {
    let source =
      """
      #if GLOBAL_FLAG
      let top = "top"
      #if FEATURE_FLAG
      let enabledPart = "Enabled Part"
      #else
      let disabledPart = "Disabled Part"
      #endif
      let bottom = "bottom"
      #else
      let top2 = "top"
      #if FEATURE_FLAG
      let enabledPart2 = "Enabled Part"
      #else
      let disabledPart2 = "Disabled Part"
      #endif
      let bottom2 = "bottom"
      #endif
      """

    let expectedCleanedSource =
      """
      #if GLOBAL_FLAG
      let top = "top"
      let enabledPart = "Enabled Part"
      let bottom = "bottom"
      #else
      let top2 = "top"
      let enabledPart2 = "Enabled Part"
      let bottom2 = "bottom"
      #endif
      """

    #expect(cleanSource(source) == expectedCleanedSource)
  }
}
