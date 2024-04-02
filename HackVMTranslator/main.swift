//
//  main.swift
//  HackVMTranslator
//
//  Created by Luke Tully on 2024-03-25.
//

import Foundation

print("Hello, World!")

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
    case pop = "pop"
    case push = "push"
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

class Tokenizer {
    private var assembly: [String] = []
    private var staticPrefix: String = ""
    private var staticIndex: Int = 0
    private var arithmeticLabels: Set<ArithmeticCommand> = Set()
    private var comparisonLabels: Set<Comparator> = Set()
    
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
    
    private func convertBinaryArithmetic (symbol: ArithmeticCommand) -> [String]{
        return [
            "D=M\(symbol)D"
        ]
    }
    private func convertUnaryArithmetic (symbol: UnaryCommand) -> [String] {
        return [
            "D=\(symbol)D"
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
                return "@\(self.staticPrefix).\(self.staticIndex)"
        }
    }
    private func readFromSegment(dest: DestinationSegment, segmentIndex: Int) -> [String] {
        // The last instruction here should have set the D register to the value stored at the segment base + index
        let seg = getSegmentString(dest: dest, constIndex: segmentIndex)
        var results: [String] = []
        let indexInstructions = selectSegmentIndex(dest: dest, index: segmentIndex)
        results.append(contentsOf: indexInstructions)
        results.append("A=D+A")
        results.append("D=M")
        return results
    }
    
    private func selectSegmentIndex (dest: DestinationSegment, index: Int) -> [String] {
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
    
    private var stackPushLabelGenerated = false
    private let STACK_PUSH_LABEL = "STACK_PUSH"
    private func writeToStack () -> [String] {
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
    
    private func performStackOperation (vmInstruction: VMInstruction) -> [String] {
        return [
            convertPop(from: vmInstruction),
            selectSegmentIndex(dest: .TEMP, index: 4),
            ["M=D"],
            convertPop(from: vmInstruction),
            selectSegmentIndex(dest: .TEMP, index: 4),
            convertOperation(from: vmInstruction),
            convertPush(from: vmInstruction) // TODO: Conver to accept string params like push local 5
        ].flatMap({ $0 })
    }
    
    private func generateArithmeticFunction (expression: ArithmeticCommand) -> [String] {
        let labelName = "\(expression.rawValue)"
        if arithmeticLabels.contains(expression) {
            return [
                "@\(labelName)",
                "0;JMP"
            ]
        } else {
            return [
                "(\(labelName)",
                "D=M\(expression.rawValue)D",
                
            ]
        }
    }
    
    
    private let WRITE_BOOL_LABEL = "WRITE_BOOL"
    private let WRITE_TRUE_LABEL = "WRITE_TRUE"
    
    private var hasWrittenBoolLabel = false
    private func writeBool (jump: Comparator) -> [String] {
        var result: [String] = []
        if hasWrittenBoolLabel {
            // Jump to the writeBool label if it already exists
            result.append(contentsOf: [
                "@\(WRITE_BOOL_LABEL)",
                "0;JMP"
            ])
        } else {
            result.append("(\(WRITE_BOOL_LABEL))")
            result.append(contentsOf: selectSegmentIndex(dest: .TEMP, index: 4))
            result.append(contentsOf: [
                "@\(WRITE_TRUE_LABEL)",
                ]
            )
        }
        
        // Handle jump
    }
    
    private func generateComparison (expression: Comparator) -> [String] {
        var result: [String] = []
        result.append(contentsOf: selectSegmentIndex(dest: .TEMP, index: 3))
        result.append(contentsOf: writeBool(jump: expression))
        result.append(expression.rawValue)
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
        
        return [] // Placeholder
    }
    
    func translate (from vmInstruction: VMInstruction) {
        self.segmentIndex = vmInstruction.index
//        switch vmInstruction.command {
//            case .pop:
//                assembly.append(contentsOf: convertPop(from: vmInstruction))
//            case .push:
//                assembly.append(contentsOf: convertPush(from: vmInstruction))
//            default:
//                assembly.append(contentsOf: convertArithmetic(from: vmInstruction))
//        }
    }
}

struct Parser {
    let binaryOperator: ArithmeticCommand?
    let comparator: Comparator?
    let unaryOperator: UnaryCommand?
    let stackCommand: StackCommand?
    
    private var dest: DestinationSegment?
    private var value: Int?
    

    init(instruction: String) {
        let instruction = splitInstruction(instruction: instruction)
        // command = instruction.command
    
        dest = instruction.dest
        value = instruction.index
    }
    
    private func parseDestinationSegment (dest: String?) -> DestinationSegment? {
        guard dest != nil else {
            return nil
        }
        switch dest {
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
    
    private func parseIndex (indexString: String?) -> Int? {
        if let index = indexString {
            return Int(index, radix: 10)
        } else {
            return nil
        }
    }
    
    private func splitInstruction(instruction: String) -> VMInstruction {
        let split: [String] = instruction.components(separatedBy: " ")
        
        var dest: String? = split[1]
        var index: Int? = parseIndex(indexString: split[2])
        
        return VMInstruction(
            binaryOperator: ArithmeticCommand(rawValue: split[0]) ?? nil,
            comparator: Comparator(rawValue: split[0]) ?? nil,
            unaryOperator: UnaryCommand(rawValue: split[0]) ?? nil,
            stackCommand: StackCommand(rawValue: split[0]) ?? nil,
            dest: let dest =  ? parseDestinationSegment(dest: split[1]) : nil,
            index:  ?? nil
        )
    }
}
