// The Swift Programming Language
// https://docs.swift.org/swift-book

//print("Hello, world!")

import ArgumentParser
import Foundation

@main
@available(macOS 12.0.0, *)
struct Translator: AsyncParsableCommand {
   @Argument var filePath: String
    
    static let configuration = CommandConfiguration(abstract: "Convert VM commands into Hack ASM")
    
    mutating func run() async throws {
        let vm = VMTranslator()
        let testFilePath = "/Users/luke/development/nand2tetris/projects/07/MemoryAccess/CustomTest/CustomTest2.vm"
        
        let results = try? await vm.parseLinesWithPath(filePath: filePath)
        guard let validResults = results else {
            return
        }
        for result in validResults {
            print(result)
        }
    }
}


struct VMTranslator {
    @available(macOS 12.0.0, *)
    func parseLinesWithPath(filePath: String) async throws -> [String] {
        
        let url = URL(fileURLWithPath: filePath)
        
        var lineCount = 0

        let tokenizer = VMTokenizer()
        let parser = VMParser()
        
        do {
            // Read each line of the data as it becomes available.
            for try await line in url.lines
            {
                lineCount += 1

                if let parsedLine = parser.parse(instruction: line) {
                    tokenizer.translate(from: parsedLine)
                } else {
                    print("found nil \(line)")
                    continue
                }
                // print("\(lineCount): \(line)")
            }
            return tokenizer.finish()
        } catch {
             print ("Error: \(error)")
        }
        
        
        return []
    }
}


struct TestTranslator {
    
}
