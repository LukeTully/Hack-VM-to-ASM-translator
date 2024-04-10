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
    case eq = "D-M;JEQ"
    case gt = "D-M;JGT"
    case lt = "D-M;JLT"
}

let comparatorCommandMap: [String: Comparator] = [
    "eq": .eq,
    "gt": .gt,
    "lt": .lt,
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
            let index = vmInstruction.index {
            
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
                    "M=D" // Store the previous stack value in the final destination
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
            let index = vmInstruction.index {
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
        return [
            convertPop(from: vmInstruction),
            ["@R15"],
            ["M=D"],
            convertPop(from: vmInstruction),
            ["@R15"],
            convertOperation(from: vmInstruction),
            convertPush(from: vmInstruction),
        ].flatMap { $0 }
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
            "D=D\(symbol.rawValue)M",
        ]
    }

    private func convertUnaryArithmetic(symbol: UnaryCommand) -> [String] {
        return [
            "D=\(symbol.rawValue)D",
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
                return "@\(5 + constIndex)"
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
        if dest != .CONST {
            results.append("D=M")
        }
        return results
    }

    private func selectSegmentIndex(dest: DestinationSegment, index: Int) -> [String] {
        var results: [String] = []
        results.append(getSegmentString(dest: dest, constIndex: index))
        
        if dest == .TEMP {
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

    private func generateComparison(expression: Comparator) -> [String] {
        var result: [String] = []
        result.append("@R13")
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
        
        assembly.append(contentsOf: translatedInstructionList)
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
            "(\(WRITE_TRUE_LABEL))",
            "D=1",
        ])
        result.append(contentsOf: writeToStack())
        return result.compactMap { $0 }
    }
}
