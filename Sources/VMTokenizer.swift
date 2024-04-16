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

let arithmeticCommandMap: [String: ArithmeticCommand] = [
    "add": .add,
    "sub": .sub,
    "and": .and,
    "or": .or,
]

enum Comparator: String {
    case eq = "D;JEQ"
    case gt = "D;JGT"
    case lt = "D;JLT"
}

let comparatorCommandMap: [String: Comparator] = [
    "eq": .eq,
    "gt": .gt,
    "lt": .lt,
]
struct ComparisonJumpCommand {
    var positiveJumpCondition: String
    var negativeJumpCondition: String
}

let comparisonMap: [Comparator: ComparisonJumpCommand] = [
    .eq: ComparisonJumpCommand(positiveJumpCondition: "D;JEQ", negativeJumpCondition: "D;JNE"),
    .lt: ComparisonJumpCommand(positiveJumpCondition: "D;JLT", negativeJumpCondition: "D;JGE"),
    .gt: ComparisonJumpCommand(positiveJumpCondition: "D;JGT", negativeJumpCondition: "D;JLE"),
]

enum UnaryCommand: String {
    case neg = "-"
    case not = "!"
}

let unaryCommandMap: [String: UnaryCommand] = [
    "neg": .neg,
    "not": .not,
]

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
    case POINTER
    case TEMP
}

struct VMInstruction {
    let binaryOperator: ArithmeticCommand?
    let comparator: Comparator?
    let unaryOperator: UnaryCommand?
    let stackCommand: StackCommand?
    let dest: DestinationSegment?
    let index: Int?
    let originalCommand: String?
}

class VMTokenizer {
    let staticPrefix: String
    var comparisonLabelIndex: Int = 0
    private var arithmeticLabels: Set<ArithmeticCommand> = Set()
    private var comparisonLabels: Set<Comparator> = Set()

    private let STACK_PUSH_LABEL = "STACK_PUSH"
    private let WRITE_BOOL_LABEL = "WRITE_BOOL"
    private let WRITE_TRUE_LABEL = "WRITE_TRUE"

    private var stackPushLabelGenerated = false
    private var hasWrittenBoolLabel = false

    init(staticPrefix: String) {
        self.staticPrefix = staticPrefix
    }
    
    private func performPop(from vmInstruction: VMInstruction) -> [String] {
        var result: [String] = []

        // Pop off the stack
        result.append(contentsOf: convertPop(from: vmInstruction))

        // Store the stack value in a register
        result.append(
            contentsOf: [
                "@R14",
                "M=D",
            ]
        )

        if let d = vmInstruction.dest,
           let index = vmInstruction.index
        {
            // Calculate the destination index
            result.append(contentsOf: selectSegmentIndex(dest: d, index: index))
            result.append("D=A") // The A register should point to dest offset

            // Store the calculated dest in another register
            result.append(
                contentsOf: [
                    "@R13",
                    "M=D",
                ]
            )

            // Re-read the previous stack value
            result.append(
                contentsOf: [
                    "@R14",
                    "D=M",
                    "@R13",
                    "A=M",
                    "M=D", // Store the previous stack value in the final destination
                ]
            )

//            result.append(contentsOf:
//                writeToSegment(
//                    dest: d,
//                    index: index
//                )
//            )
        }

        return result
    }

    private func performPush(from vmInstruction: VMInstruction) -> [String] {
        var result: [String] = []

        if let d = vmInstruction.dest,
           let index = vmInstruction.index
        {
            result.append(contentsOf:
                readFromSegment(
                    dest: d,
                    segmentIndex: index
                )
            )
            result.append(contentsOf:
                convertPush(from: vmInstruction)
            )
        }

        return result
    }

    private func performStackOperation(vmInstruction: VMInstruction) -> [String] {
        if let binOp = vmInstruction.binaryOperator {
            return convertBinaryArithmetic(symbol: binOp)
        }

        if let comparison = vmInstruction.comparator {
            return generateComparison(expression: comparisonMap[comparison]!)
        }

        if let unaryOperator = vmInstruction.unaryOperator {
            return convertUnaryArithmetic(symbol: unaryOperator)
        }
        
        return []
    }

    private func convertPop(from vmInstruction: VMInstruction) -> [String] {
        var result: [String] = []
        result.append("@SP")
        result.append("AM=M-1")
        result.append("D=M")
//            result.append("M=0")

        return result
    }

    private func convertPush(from vmInstruction: VMInstruction) -> [String] {
        var result: [String] = []
        result.append("@SP")
        result.append("A=M")
        result.append("M=D") // D should be already set to a value
        result.append("@SP")
        result.append("M=M+1")

        return result
    }

    private func convertBinaryArithmetic(symbol: ArithmeticCommand) -> [String] {
        return [
            "@SP", // Pop off the stack
            "AM=M-1",
            "D=M",
            "@R15", // Store the value in R15
            "M=D",
            "@SP", // Pop another
            "AM=M-1",
            "D=M",
            "@R15",
            "D=D\(symbol.rawValue)M",
            "@SP",
            "A=M", // Navigate back to stack top
            "M=D", // Store the binary arithmetic result
            "@SP",
            "M=M+1", // Increment stack pointer once more
        ]
    }

    private func convertUnaryArithmetic(symbol: UnaryCommand) -> [String] {
        return [
            "@SP", // Decrement stack by 1
            "AM=M-1",
            "M=\(symbol.rawValue)M", // Replace top of stack with unaried value
            "@SP", // Re-increment stack pointer
            "M=M+1",
        ]
    }

    private func getSegmentString(dest: DestinationSegment, constIndex: Int) -> String {
        let THIS_LABEL = "@THIS"
        let THAT_LABEL = "@THAT"

        switch dest {
            case .LCL:
                return "@LCL"
            case .THIS:
                return THIS_LABEL
            case .THAT:
                return THAT_LABEL
            case .ARGUMENT:
                return "@ARG"
            case .POINTER:
                if constIndex == 1 {
                    return THAT_LABEL
                }
                return THIS_LABEL // TODO: This should be one of many conditions that are checked earlier for validity
            case .TEMP:
                return "@\(5 + constIndex)"
            case .CONST:
                return "@\(constIndex)"
            case .STATIC:
                return "@\(staticPrefix).\(constIndex)"
        }
    }

    private func readFromSegment(dest: DestinationSegment, segmentIndex: Int) -> [String] {
        // The last instruction here should have set the D register to the value stored at the segment base + index
        var results: [String] = []
        let indexInstructions = selectSegmentIndex(dest: dest, index: segmentIndex)
        results.append(contentsOf: indexInstructions)
        if dest != .CONST {
            results.append("D=M")
        }
        return results
    }

    private func selectSegmentIndex(dest: DestinationSegment, index: Int) -> [String] {
        var results: [String] = []
        results.append(getSegmentString(dest: dest, constIndex: index))

        if dest == .TEMP ||
            dest == .POINTER ||
            dest == .STATIC
        {
            return results
        }

        if dest != .CONST {
            results.append("D=M")
            results.append("@\(index)")
            results.append("A=D+A")
        } else {
            results.append("AD=A")
        }

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
            result.append(
                contentsOf: [
                    "(\(WRITE_BOOL_LABEL))",
                    "@R15",
                    "@\(WRITE_TRUE_LABEL)",
                ]
            )
        }

        // Handle jump
        result.append(jump.rawValue)
        return result.compactMap { $0 }
    }

    private func generateComparison(expression: ComparisonJumpCommand) -> [String] {
        var results: [String] = [
            [
                "@SP", // Pop off the stack
                "AM=M-1",
                "D=M",
                "@R15",
                "M=D",
                "@SP",
                "AM=M-1",
                "D=M",
                "@R15",
                "D=D-M", // Compares lower stack item to higher stack item
                "@PUSH_TRUE_\(comparisonLabelIndex)",
                expression.positiveJumpCondition,
                "@PUSH_FALSE_\(comparisonLabelIndex)",
                expression.negativeJumpCondition,
                "(PUSH_TRUE_\(comparisonLabelIndex))",
                "@SP",
                "A=M",
                "M=-1",
                "@SP",
                "M=M+1",
                "@JUMP_BACK_\(comparisonLabelIndex)",
                "0;JEQ",
                "(PUSH_FALSE_\(comparisonLabelIndex))",
                "@SP",
                "A=M",
                "M=0",
                "@SP",
                "M=M+1",
                "(JUMP_BACK_\(comparisonLabelIndex))",
            ]
        ].flatMap { $0 }
        
        comparisonLabelIndex += 1
        return results
    }


    func translate(from vmInstruction: VMInstruction) -> [String] {
        var translatedInstructionList: [String] = []
        if let pushOrPop = vmInstruction.stackCommand {
            switch pushOrPop {
                case .pop:
                    translatedInstructionList.append(contentsOf: performPop(from: vmInstruction))
                case .push:
                    translatedInstructionList.append(contentsOf: performPush(from: vmInstruction))
            }
        } else {
            translatedInstructionList.append(contentsOf: performStackOperation(vmInstruction: vmInstruction))
        }

        // Append a comment that denotes the original VM command
        if translatedInstructionList.indices.contains(0) {
            if let og = vmInstruction.originalCommand {
                translatedInstructionList[0].append(" // \(og)")
            }
        }

        return translatedInstructionList
    }

    func finish() -> [String] {
        /* Once each line has been translated, write any symbols or loops that need to end the program */
        var result: [String] = []
        result.append(contentsOf: [
            "@END",
            "0;JMP",
            "(END)",
            "@END",
            "0;JMP",
            "(\(WRITE_TRUE_LABEL))",
            "D=1",
        ])
        result.append(contentsOf: writeToStack())
        return result.compactMap { $0 }
    }
}
