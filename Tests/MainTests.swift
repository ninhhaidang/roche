import Foundation

@main
struct AllTestsRunner {
    static func main() async {
        do {
            print("--- Running SubprocessRunner Tests ---")
            try await runSubprocessRunnerTests()

            print("\n--- Running CleanEngine Tests ---")
            try await runCleanEngineTests()

            print("\n--- Running CleanListParser Tests ---")
            runCleanListParserTests()

            print("\n--- Running CleanEngine Selection Tests ---")
            try await runCleanEngineSelectionTests()

            print("\n--- Running TrashManager Tests ---")
            try await runTrashManagerTests()

            print("\n--- Running CleanEngine Execution Tests ---")
            try await runCleanEngineExecutionTests()
            print("\n--- Running MoleExecutableFinder Tests ---")
            try await runMoleExecutableFinderTests()
            print("\n--- Running CleanEngine Purge & Installer Tests ---")
            try await runCleanEnginePurgeInstallerTests()
            print("\n--- Running PTYProcessRunner Tests ---")
            try await runPTYProcessRunnerTests()
            print("\n--- Running UninstallEngine Tests ---")
            try await runUninstallEngineTests()
            print("\n--- Running OptimizeEngine Tests ---")
            try await runOptimizeEngineTests()
            print("\n--- Running OptimizeEngine Streaming Tests ---")
            try await runOptimizeEngineStreamingTests()

            print("\n===============================")
            print("ALL SUITES PASSED SUCCESSFULLY!")
            print("===============================")
        } catch {
            print("\nTest failed with error: \(error)")
            exit(1)
        }
    }
}
