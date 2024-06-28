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
    private var controlFlowCommand: ControlFlowCommand?
    private var functionDef: FunctionDefinition?
    private var conditionalJumpLabel: String?
    private var unconditionalJumpLabel: String?
    private var callFunction: CallSignature?
    private var isReturnStatement: Bool?
    private var putLabelValue: String?

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
            originalCommand: originalInstruction,
            controlFlowCommand: controlFlowCommand,
            conditionalJumpLabel: conditionalJumpLabel,
            unconditionalJumpLabel: unconditionalJumpLabel,
            callFunction: callFunction,
            isReturnStatement: isReturnStatement,
            putLabelValue: putLabelValue,
            functionDef: functionDef
        )
    }

    func parse(instruction: String) -> VMInstruction? {
        if !shouldSkip(instruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let split: [String] = instruction.components(separatedBy: .whitespaces)

            if !split.isEmpty {
                let baseCommand: String = split[0].trimmingCharacters(in: .whitespacesAndNewlines)

                // TODO: This pattern is really clumsy

                binaryOperator = arithmeticCommandMap[baseCommand] ?? nil
                comparator = comparatorCommandMap[baseCommand] ?? nil
                unaryOperator = unaryCommandMap[baseCommand] ?? nil
                stackCommand = StackCommand(rawValue: baseCommand) ?? nil
                controlFlowCommand = ControlFlowCommand(rawValue: baseCommand) ?? nil   // controlFlowMap[baseCommand] ?? nil
                originalInstruction = instruction

                let second = split.indices.contains(1) ? split[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                let third = split.indices.contains(2) ? split[2].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                if let validControlFlowCommand = controlFlowCommand {
                    switch validControlFlowCommand {
                        case .functionReturn:
                            isReturnStatement = true
                        case .ifGoto:
                            conditionalJumpLabel = second
                        case .goto:
                            unconditionalJumpLabel = second
                        case .functionDef:
                            functionDef = FunctionDefinition(
                                labelName: second!,
                                nLocalVars: Int(third ?? "", radix: 10) ?? 0
                            )
                        case .callFunction:
                            callFunction = CallSignature(
                                labelName: second!,
                                nArgs: Int(third ?? "0", radix: 10) ?? 0
                            )
                        case .putLabel:
                            putLabelValue = second
                    }
                } else {
                    dest = parseDestinationSegment(d: second)
                    value = parseIndex(indexString: third)
                }
            }

            return getVMInstruction()
        }

        return nil
    }

    private func shouldSkip(instruction: String) -> Bool {
        /* Determine if the line should be skipped */
        if instruction.hasPrefix("//") {
            print("Skipped line \(instruction)")
            return true
        }
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
            case "pointer":
                return .POINTER
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
