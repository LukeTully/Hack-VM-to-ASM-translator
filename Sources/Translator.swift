// The Swift Programming Language
// https://docs.swift.org/swift-book

// print("Hello, world!")

import ArgumentParser
import Foundation

@main
@available(macOS 13.0.0, *)
struct Translator: AsyncParsableCommand {
    @Argument var sourceFilePath = "/Users/luke/development/nand2tetris/projects/08/FunctionCalls/NestedCall"
    @Argument var outputFilePath: String?
    @Flag var bootstrap = false
    @Flag var initialize = false
    @Option(name: .customLong("stack-pointer")) var stackPointer = "271"
    
    static let configuration = CommandConfiguration(abstract: "Convert VM commands into Hack ASM")

    mutating func run() async throws {
        let vm = VMTranslator(
            pathToRead: sourceFilePath,
            fileToWrite: outputFilePath,
            shouldBootstrap: bootstrap,
            callSysInit: initialize,
            stackPointerBaseAddress: stackPointer
        )

        do {
            try await vm.parse()
        } catch {
            print("\(error.localizedDescription)")
        }
    }
}

/* The names for these classes are terrible */
@available(macOS 13.0.0, *)
class VMTranslator {
    let readable: URL
    let writable: URL
    let shouldBootstrap: Bool
    let callSysInit: Bool
    let stackPointerBaseAddress: String
    var hasBootStrapped: Bool
    var hasWrittenEnd: Bool
    // At the moment it doesn't seem like the order of writing functions will matter
    var functionList: Set<VMInstruction> = []

    init(
        pathToRead: String,
        fileToWrite: String?,
        shouldBootstrap: Bool,
        callSysInit: Bool,
        stackPointerBaseAddress: String
    ) {
        readable = URL(fileURLWithPath: pathToRead)
        self.shouldBootstrap = shouldBootstrap
        self.hasBootStrapped = false
        self.hasWrittenEnd = false
        self.callSysInit = callSysInit
        self.stackPointerBaseAddress = stackPointerBaseAddress

        /* Determine the name for the final file */
        if readable.hasDirectoryPath {
            let filename = readable.lastPathComponent
            writable = readable.appending(component: "\(filename).asm")
            print(writable.absoluteString)
        } else {
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
    }

    func parse() async throws {
        // Write some empty data to overwrite or create the destination file
        try "".write(to: writable, atomically: true, encoding: .utf8)

        if readable.hasDirectoryPath {
            try await parseDirectory()
        } else {
            try await parseLines(
                currentFile: readable,
                shouldTerminate: true
            )
        }
    }

    private func parseDirectory() async throws {
        /* If given a directory path as input, merge all translated functions from all files into one */
        let fileManager = FileManager()
        let tokenizer = VMTokenizer(staticPrefix: readable.lastPathComponent)

        do {
            let contentsOfDirectory = try fileManager.contentsOfDirectory(at: readable, includingPropertiesForKeys: [], options: .skipsSubdirectoryDescendants)
            for f in contentsOfDirectory {
                if f.isFileURL, f.pathExtension == "vm" {
                    try await parseLines(currentFile: f, tokenizer: tokenizer)
                    print("Finished writing asm from \(f.absoluteString)")
                }
            }
            terminateProgram(tokenizer: tokenizer)
        } catch {
            print("\(error)")
        }
        
    }

    func parseLines(
        currentFile: URL,
        tokenizer: VMTokenizer? = nil,
        shouldTerminate: Bool = false
    )
    async throws {
        var lineCount = 0
        let tokenizer = tokenizer ?? VMTokenizer(staticPrefix: extractFileNameFromURL(path: writable))

        if let fileForWriting = FileHandle(forWritingAtPath: writable.path) {
            defer {
                fileForWriting.closeFile()
            }
            do {
                // Set the stage by initializing the ram pointers
                if !hasBootStrapped && shouldBootstrap {
                    writeLines(
                        instructions: tokenizer.bootstrapVMTranslator(
                            callInit: callSysInit,
                            stackPointerBase: stackPointerBaseAddress
                        ),
                        fileHandle: fileForWriting
                    )
                    hasBootStrapped = true
                }

                tokenizer.setStaticPrefix(prefix: extractFileNameFromURL(path: currentFile))

                var parser = VMParser()

                // Read each line of the data as it becomes available.
                for try await line in currentFile.lines {
                    parser = VMParser()
                    lineCount += 1

                    if let parsedLine = parser.parse(instruction: line) {
                        /* Hold onto functionDefs for later to append before the final loop */
//                        if parsedLine.functionDef != nil {
//                            functionList.insert(parsedLine)
//                            continue
//                        }

                        writeLines(
                            instructions: tokenizer.translate(from: parsedLine),
                            fileHandle: fileForWriting
                        )
                    }
                }
                
                /* This will be called if we're just parsing one file, but I should modify the flow, this is clumsy */
                if shouldTerminate {
                    terminateProgram(tokenizer: tokenizer)
                }

            } catch {
                print("Error: \(error)")
            }
        }
    }

    private func terminateProgram(tokenizer: VMTokenizer) {
//        let convertedFunctionDefs: [String] = functionList.flatMap {
//            tokenizer.translate(from: $0)
//        }

        if !hasWrittenEnd {
            if let fileForWriting = FileHandle(forWritingAtPath: writable.path) {
                defer {
                    fileForWriting.closeFile()
                }
                writeLines(
                    instructions: tokenizer.finish(remainingInstructions: []),
                    fileHandle: fileForWriting
                )
                hasWrittenEnd = true
            }
        }
    }

    private func writeLines(
        instructions: [String],
        fileHandle: FileHandle
    ) {
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
