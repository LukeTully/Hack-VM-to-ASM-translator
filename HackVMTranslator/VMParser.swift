//
//  VMParser.swift
//  HackVMTranslator
//
//  Created by Luke Tully on 2024-04-04.
//

import Foundation

class Parser {
    let binaryOperator: ArithmeticCommand?
    let comparator: Comparator?
    let unaryOperator: UnaryCommand?
    let stackCommand: StackCommand?

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

    init(instruction: String) {
        let split: [String] = instruction.components(separatedBy: " ")

        binaryOperator = ArithmeticCommand(rawValue: split[0]) ?? nil
        comparator = Comparator(rawValue: split[0]) ?? nil
        unaryOperator = UnaryCommand(rawValue: split[0]) ?? nil
        stackCommand = StackCommand(rawValue: split[0]) ?? nil
        dest = parseDestinationSegment(d: split[1])
        value = parseIndex(indexString: split[2])
    }

    private func parseDestinationSegment(d: String?) -> DestinationSegment? {
        guard d != nil else {
            return nil
        }
        switch d {
            case "LCL":
                return .LCL
            case "THIS":
                return .THIS
            case "THAT":
                return .THAT
            case "CONST":
                return .CONST
            case "STATIC":
                return .STATIC
            case "ARGUMENT":
                return .ARGUMENT
            case "TEMP":
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
