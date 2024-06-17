// The Swift Programming Language
// https://docs.swift.org/swift-book

// print("Hello, world!")

import ArgumentParser
import Foundation

@main
@available(macOS 13.0.0, *)
struct Translator: AsyncParsableCommand {
    @Argument var sourceFilePath = "/Users/luke/development/nand2tetris/projects/08/ProgramFlow/BasicLoop/BasicLoop.vm"
    @Argument var outputFilePath: String?
    @Flag var bootstrap = false

    static let configuration = CommandConfiguration(abstract: "Convert VM commands into Hack ASM")

    mutating func run() async throws {
        let vm = VMTranslator(
            fileToRead: sourceFilePath,
            fileToWrite: outputFilePath,
            shouldBootstrap: bootstrap
        )

        do {
            try await vm.parseLines()
        } catch {
            print("\(error.localizedDescription)")
        }
    }
}

@available(macOS 13.0.0, *)
struct VMTranslator {
    let readable: URL
    let writable: URL
    let shouldBootstrap: Bool

    init(
        fileToRead: String,
        fileToWrite: String?,
        shouldBootstrap: Bool
    ) {
        readable = URL(fileURLWithPath: fileToRead)
        self.shouldBootstrap = shouldBootstrap

        if let f = fileToWrite {
            writable = URL(fileURLWithPath: f)
        } else {
            /*
                Create a new file based on the capitalized name of the source instruction file
                ~/Documents/Example.vm -> ~/Documents/Example.asm
             */
            let filename = extractFileNameFromURL(path: readable)
            let pathToContainingDirectory = readable.deletingLastPathComponent()
            let finalURL = pathToContainingDirectory.appending(component: "\(filename).asm")
            writable = finalURL
        }
    }

    func parseLines() async throws {
        var lineCount = 0

        let tokenizer = VMTokenizer(staticPrefix: extractFileNameFromURL(path: writable))
        let parser = VMParser()

        // Write some empty data to overwrite or create the destination file
        try "".write(to: writable, atomically: true, encoding: .utf8)

        if let fileForWriting = FileHandle(forWritingAtPath: writable.path) {
            defer {
                fileForWriting.closeFile()
            }
            do {
                // Set the stage by initializing the ram pointers
                if shouldBootstrap {
                    writeLines(
                        instructions: tokenizer.bootstrapVMTranslator(),
                        fileHandle: fileForWriting
                    )
                }

                // At the moment it doesn't seem like the order of writing functions will matter
                var functionList: Set<VMInstruction> = []

                // Read each line of the data as it becomes available.
                for try await line in readable.lines {
                    lineCount += 1

                    if let parsedLine = parser.parse(instruction: line) {
                        /* Hold onto functionDefs for later to append before the final loop */
                        if parsedLine.functionDef != nil {
                            functionList.insert(parsedLine)
                            continue
                        }

                        writeLines(
                            instructions: tokenizer.translate(from: parsedLine),
                            fileHandle: fileForWriting
                        )
                    }
                }

                let convertedFunctionDefs: [String] = functionList.flatMap {
                    tokenizer.translate(from: $0)
                }

                return writeLines(
                    instructions: tokenizer.finish(remainingInstructions: convertedFunctionDefs),
                    fileHandle: fileForWriting
                )
            } catch {
                print("Error: \(error)")
            }
        }
    }

    private func writeLines(instructions: [String], fileHandle: FileHandle) {
        for line in instructions {
            fileHandle.seekToEndOfFile()
            if let data = "\(line)\n".data(using: .utf8) {
                fileHandle.write(data)
            }
        }
    }
}

func extractFileNameFromURL(path: URL) -> String {
    return path.deletingPathExtension().lastPathComponent
}

struct TestTranslator {}
