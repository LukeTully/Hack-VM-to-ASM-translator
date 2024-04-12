// The Swift Programming Language
// https://docs.swift.org/swift-book

// print("Hello, world!")

import ArgumentParser
import Foundation

@main
@available(macOS 13.0.0, *)
struct Translator: AsyncParsableCommand {
    @Argument var sourceFilePath: String = "/Users/luke/development/nand2tetris/projects/07/MemoryAccess/CustomTest/CustomTest2.vm"
    @Argument var outputFilePath: String?
    
    static let configuration = CommandConfiguration(abstract: "Convert VM commands into Hack ASM")

    mutating func run() async throws {
        
        let vm = VMTranslator(fileToRead: sourceFilePath, fileToWrite: outputFilePath)
        
        do {
            try await vm.parseLines()
        }
        catch {
            print("\(error.localizedDescription)")
        }
    }
}
@available(macOS 13.0.0, *)
struct VMTranslator {
    let readable: URL
    let writable: URL
    
    init(fileToRead: String, fileToWrite: String?) {
        self.readable = URL(fileURLWithPath: fileToRead)
        
        if let f = fileToWrite {
            self.writable = URL(fileURLWithPath: f)
        } else {
            /*
                Create a new file based on the capitalized name of the source instruction file
                ~/Documents/Example.vm -> ~/Documents/Example.asm
             */
            let filename = extractFileNameFromURL(path: self.readable)
            let pathToContainingDirectory = self.readable.deletingLastPathComponent()
            let finalURL = pathToContainingDirectory.appending(component: "\(filename).asm")
            self.writable = finalURL
        }
    }
    
    func parseLines() async throws {
        var lineCount = 0
        
        let tokenizer = VMTokenizer(staticPrefix: extractFileNameFromURL(path: writable))
        let parser = VMParser()
        
        // Write some empty data to overwrite or create the destination file
        try "".write(to: self.writable, atomically: true, encoding: .utf8)
        
        if let fileForWriting = FileHandle(forWritingAtPath: self.writable.path) {
            defer {
                fileForWriting.closeFile()
            }
            do {
                // Read each line of the data as it becomes available.
                for try await line in readable.lines {
                    lineCount += 1
                    
                    if let parsedLine = parser.parse(instruction: line) {
                        writeLines(instructions: tokenizer.translate(from: parsedLine), fileHandle: fileForWriting)
                    } else {
                        print("found nil \(line)")
                        continue
                    }
                }
                return writeLines(
                    instructions: tokenizer.finish(),
                    fileHandle: fileForWriting
                )
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    private func writeLines (instructions: [String], fileHandle: FileHandle) {
        for line in instructions {
            fileHandle.seekToEndOfFile()
            if let data = "\(line)\n".data(using: .utf8) {
                fileHandle.write(data)
            }
        }
    }
}

func extractFileNameFromURL (path: URL) -> String {
    return path.deletingPathExtension().lastPathComponent
}

struct TestTranslator {}
