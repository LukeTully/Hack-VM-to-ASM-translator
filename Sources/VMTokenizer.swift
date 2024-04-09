//
//  VMTokenizer.swift
//  HackVMTranslator
//
//  Created by Luke Tully on 2024-04-08.
//

import Foundation

enum ArithmeticCommand: String {
    case add = "+"
    case sub = "-"
    case and = "&"
    case or = "|"
}

enum Comparator: String {
    case eq = "D-M;JEQ"
    case gt = "D-M;JGT"
    case lt = "D-M;JLT"
}

enum UnaryCommand: String {
    case neg = "-"
    case not = "!"
}

enum StackCommand: String {
    case pop
    case push
}

enum DestinationSegment {
    case LCL
    case THIS
    case THAT
    case CONST
    case STATIC
    case ARGUMENT
    case TEMP
}

struct VMInstruction {
    let binaryOperator: ArithmeticCommand?
    let comparator: Comparator?
    let unaryOperator: UnaryCommand?
    let stackCommand: StackCommand?
    let dest: DestinationSegment?
    let index: Int?
}

class VMTokenizer {
    private var assembly: [String] = []
    private var staticPrefix = ""
    private var staticIndex = 0
    private var arithmeticLabels: Set<ArithmeticCommand> = Set()
    private var comparisonLabels: Set<Comparator> = Set()

    private let STACK_PUSH_LABEL = "STACK_PUSH"
    private let WRITE_BOOL_LABEL = "WRITE_BOOL"
    private let WRITE_TRUE_LABEL = "WRITE_TRUE"

    private var stackPushLabelGenerated = false
    private var hasWrittenBoolLabel = false

    private func performPop(from vmInstruction: VMInstruction) -> [String] {
        var result: [String] = []
        result.append(contentsOf:
            convertPop(from: vmInstruction)
        )
        
        if let d = vmInstruction.dest,
            let index = vmInstruction.index {
            result.append(contentsOf:
                writeToSegment(
                    dest: d,
                    index: index
                )
            )
        }

        return result
    }

    private func performPush(from vmInstruction: VMInstruction) -> [String] {
        var result: [String] = []
        result.append(contentsOf:
            convertPush(from: vmInstruction)
        )
        
        if let d = vmInstruction.dest,
            let index = vmInstruction.index {
            result.append(contentsOf:
                readFromSegment(
                    dest: d,
                    segmentIndex: index
                )
            )
        }
        
        return result
    }

    private func performStackOperation(vmInstruction: VMInstruction) -> [String] {
        return [
            convertPop(from: vmInstruction),
            selectSegmentIndex(dest: .TEMP, index: 4),
            ["M=D"],
            convertPop(from: vmInstruction),
            selectSegmentIndex(dest: .TEMP, index: 4),
            convertOperation(from: vmInstruction),
            convertPush(from: vmInstruction),
        ].flatMap { $0 }
    }

    private func convertPop(from vmInstruction: VMInstruction) -> [String] {
        var result: [String] = []
        if vmInstruction.stackCommand == .pop {
            result.append("@SP")
            result.append("AM=M-1")
            result.append("D=M")
        }
        return result
    }

    private func convertPush(from vmInstruction: VMInstruction) -> [String] {
        var result: [String] = []
        if vmInstruction.stackCommand == .push {
            result.append("@SP")
            result.append("AM=M+1")
            result.append("M=D") // D should be already set to a value
        }
        return result
    }

    private func convertBinaryArithmetic(symbol: ArithmeticCommand) -> [String] {
        return [
            "D=M\(symbol)D",
        ]
    }

    private func convertUnaryArithmetic(symbol: UnaryCommand) -> [String] {
        return [
            "D=\(symbol)D",
        ]
    }

    private func getSegmentString(dest: DestinationSegment, constIndex: Int) -> String {
        switch dest {
            case .LCL:
                return "@LCL"
            case .THIS:
                return "@THIS"
            case .THAT:
                return "@THAT"
            case .ARGUMENT:
                return "@ARG"
            case .TEMP:
                return "@TEMP"
            case .CONST:
                return "@\(constIndex)"
            case .STATIC:
                return "@\(staticPrefix).\(staticIndex)"
        }
    }

    private func readFromSegment(dest: DestinationSegment, segmentIndex: Int) -> [String] {
        // The last instruction here should have set the D register to the value stored at the segment base + index
        var results: [String] = []
        let indexInstructions = selectSegmentIndex(dest: dest, index: segmentIndex)
        results.append(contentsOf: indexInstructions)
        results.append("A=D+A")
        results.append("D=M")
        return results
    }

    private func selectSegmentIndex(dest: DestinationSegment, index: Int) -> [String] {
        // TODO: This isn't complete. I need to select the base address of the segment using the dest, based on the template instructions in vscode
        let seg = getSegmentString(dest: dest, constIndex: index)
        var results: [String] = []
        results.append("@\(index)")
        results.append("D=A")
        results.append("A=D+A")
        return results
    }

    private func writeToSegment(dest: DestinationSegment, index: Int) -> [String] {
        // The last instruction here should have set the D register to the value stored at the segment base + index
        let seg = getSegmentString(dest: dest, constIndex: index)
        var results: [String] = []
        results.append(contentsOf: selectSegmentIndex(dest: dest, index: index))
        results.append("D=M")
        return results
    }

    private func writeToStack() -> [String] {
        /* Writes the value stored in the D register to the stack */
        if stackPushLabelGenerated {
            return [
                "@\(STACK_PUSH_LABEL)",
                "0;JMP",
            ]
        } else {
            stackPushLabelGenerated = true
            return [
                "(\(STACK_PUSH_LABEL))",
                "@SP",
                "AM=M+1",
                "M=D",
            ]
        }
    }

    private func generateArithmeticFunction(expression: ArithmeticCommand) -> [String] {
        let labelName = "\(expression.rawValue)"
        if arithmeticLabels.contains(expression) {
            return [
                "@\(labelName)",
                "0;JMP",
            ]
        } else {
            return [
                "(\(labelName)",
                "D=M\(expression.rawValue)D",
            ]
        }
    }

    private func writeBool(jump: Comparator) -> [String] {
        var result: [String] = []
        if hasWrittenBoolLabel {
            // Jump to the writeBool label if it already exists
            result.append(
                contentsOf: [
                    "@\(WRITE_BOOL_LABEL)",
                    "0;JMP",
                ]
            )
        } else {
            result.append("(\(WRITE_BOOL_LABEL))")
            result.append(contentsOf: selectSegmentIndex(dest: .TEMP, index: 4))
            result.append(contentsOf: [
                "@\(WRITE_TRUE_LABEL)",
            ]
            )
        }

        // Handle jump
        result.append(jump.rawValue)
        return result.compactMap { $0 }
    }

    private func generateComparison(expression: Comparator) -> [String] {
        var result: [String] = []
        result.append(contentsOf: selectSegmentIndex(dest: .TEMP, index: 3))
        result.append(contentsOf: writeBool(jump: expression))
        result.append(expression.rawValue)
        return result.compactMap { $0 }
    }

    private func convertOperation(from vmInstruction: VMInstruction) -> [String] {
        if let binOp = vmInstruction.binaryOperator {
            return convertBinaryArithmetic(symbol: binOp)
        }

        if let comparison = vmInstruction.comparator {
            return generateComparison(expression: comparison)
        }

        if let unaryOperator = vmInstruction.unaryOperator {
            return convertUnaryArithmetic(symbol: unaryOperator)
        }

        return []
    }

    func translate(from vmInstruction: VMInstruction) {
        if let pushOrPop = vmInstruction.stackCommand {
            switch pushOrPop {
                case .pop:
                    assembly.append(contentsOf: performPop(from: vmInstruction))
                case .push:
                    assembly.append(contentsOf: performPush(from: vmInstruction))
            }
        }
        assembly.append(contentsOf: performStackOperation(vmInstruction: vmInstruction))
    }

    func finish() -> [String] {
        /* Once each line has been translated, write any symbols or loops that need to end the program */
        var result: [String] = []
        result.append(contentsOf: assembly)
        result.append(contentsOf: [
            "@END",
            "0;JMP",
            "(END)",
            "@END",
            "0;JMP",
            "(\(WRITE_TRUE_LABEL)",
            "D=1",
        ])
        result.append(contentsOf: writeToStack())
        return result.compactMap { $0 }
    }
}
