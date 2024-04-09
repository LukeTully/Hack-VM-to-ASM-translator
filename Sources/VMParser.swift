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

    private var dest: DestinationSegment?
    private var value: Int?

    func getVMInstruction() -> VMInstruction {
        
        return VMInstruction(
            binaryOperator: binaryOperator,
            comparator: comparator,
            unaryOperator: unaryOperator,
            stackCommand: stackCommand,
            dest: dest,
            index: value
        )
    }

    func parse(instruction: String) -> VMInstruction? {
        if !shouldSkip(instruction: instruction) {
            let split: [String] = instruction.components(separatedBy: " ")

            binaryOperator = ArithmeticCommand(rawValue: split[0]) ?? nil
            comparator = Comparator(rawValue: split[0]) ?? nil
            unaryOperator = UnaryCommand(rawValue: split[0]) ?? nil
            stackCommand = StackCommand(rawValue: split[0]) ?? nil
            dest = parseDestinationSegment(d: split[1])
            value = parseIndex(indexString: split[2])

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
