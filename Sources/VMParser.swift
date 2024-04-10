//
//  VMParser.swift
//  HackVMTranslator
//
//  Created by Luke Tully on 2024-04-04.
//

import Foundation

class VMParser {
    private var binaryOperator: ArithmeticCommand?
    private var comparator: Comparator?
    private var unaryOperator: UnaryCommand?
    private var stackCommand: StackCommand?
    private var originalInstruction: String?
    
    private var dest: DestinationSegment?
    private var value: Int?

    func getVMInstruction() -> VMInstruction {
        
        return VMInstruction(
            binaryOperator: binaryOperator,
            comparator: comparator,
            unaryOperator: unaryOperator,
            stackCommand: stackCommand,
            dest: dest,
            index: value,
            originalCommand: originalInstruction
        )
    }

    func parse(instruction: String) -> VMInstruction? {
        if !shouldSkip(instruction: instruction) {
            let split: [String] = instruction.components(separatedBy: " ")
            
            if split.count > 0 {
                let baseCommand: String = split[0]
                binaryOperator = arithmeticCommandMap[baseCommand] ?? nil
                comparator = comparatorCommandMap[baseCommand] ?? nil
                unaryOperator = unaryCommandMap[baseCommand] ?? nil
                stackCommand = StackCommand(rawValue: split[0]) ?? nil
                
                
                originalInstruction = instruction
                
                if split.indices.contains(1) {
                    dest = parseDestinationSegment(d: split[1])
                }
                if split.indices.contains(2) {
                    value = parseIndex(indexString: split[2])
                }
            }

            return getVMInstruction()
        }
         
        return nil
    }

    private func shouldSkip (instruction: String) -> Bool {
        /* Determine if the line should be skipped */



        return false
    }

    private func parseDestinationSegment(d: String?) -> DestinationSegment? {
        guard d != nil else {
            return nil
        }
        switch d {
            case "local":
                return .LCL
            case "this":
                return .THIS
            case "that":
                return .THAT
            case "constant":
                return .CONST
            case "static":
                return .STATIC
            case "argument":
                return .ARGUMENT
            case "temp":
                return .TEMP
            default:
                return nil
        }
    }

    private func parseIndex(indexString: String?) -> Int? {
        if let index = indexString {
            return Int(index, radix: 10)
        } else {
            return nil
        }
    }
}
