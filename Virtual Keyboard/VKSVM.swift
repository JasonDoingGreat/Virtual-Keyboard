//
//  VKSVM.swift
//  Virtual Keyboard
//
//  Created by Zezhou Li on 1/4/17.
//  Copyright © 2017 Zezhou Li. All rights reserved.
//

import Foundation

extension Array where Element: Collection {
    func getColumn(column: Element.Index) -> [Element.Iterator.Element] {
        return self.map { $0[column] }
    }
}

class VKSVM: NSObject {
    
    // Struct of SVM Model
    private struct SVMmodel {
        var b: Float = 0.0
        var alphas = [Float]()
        var w = [Float]()
    }
    
    // FFT Parameters
    private let maxDB: Float = 64.0
    private let minDB: Float = -32.0
    private var headroom: Float = 0.0
    
    // SVM Parameters
    private var paraNumbers: Int = 0
    private var E = [Float]()
    private var passes: Int = 0
    private var eta: Float = 0
    private var L: Float = 0
    private var H: Float = 0
    private var tol: Float = 0.001
    private var max_passes: Int = 5
    private var m: Int = 0
    private var n: Int = 0
    private var model: SVMmodel!

    override init() {
        super.init()
        model = SVMmodel()
    }
    
    private func MatrixDotProduct(_ matrixA: [Float], _ matrixB: [Float]) -> [Float] {
        var result = [Float](repeating: 0.0, count: matrixA.count)
        for i in 0..<matrixA.count {
            result[i] = matrixA[i] * matrixB[i]
        }
        return result
    }
    
    private func MatrixMultiply(_ matrixA:[[Float]], _ matrixB:[[Float]]) -> [[Float]] {
        if matrixA[0].count != matrixB.count {
            print("Illegal matrix dimensions!")
            return [[]]
        }
        
        let size1 = matrixA.count
        let size2 = matrixB[0].count
        
        var result: [[Float]] = [[Float]](repeating: [Float](repeating: 0, count: size2), count: size1)
        
        for i in 0..<result.count {
            for j in 0..<matrixB.count {
                for k in 0..<matrixB[0].count {
                    result[i][k] += matrixA[i][j] * matrixB[j][k]
                }
            }
        }
        return result
    }
    
    private func MatrixTranspose(_ matrix:[[Float]]) -> [[Float]] {
        var result = [[Float]](
            repeating: [Float]( repeating: 0, count: matrix.count),
            count: matrix[0].count
        )
        
        for  i in 0..<matrix.count {
            for j in 0..<matrix[0].count {
                result[j][i] = matrix[i][j]
            }
        }
        return result
    }
    
    func SVMTrain(_ X: [[Float]],
                  _ Y: [Float],
                  _ C: Float,
                  _ KF: String,
                  _ Tol: Float,
                  _ maxpasses: Int) {
        
        tol = Tol
        max_passes = maxpasses
        
        m = X.count
        n = X[0].count
        E = Array(repeating: 0.0, count: m)
        passes = 0
        model.alphas = Array(repeating: 0.0, count: m)
        var alpha_i_old: Float = 0.0
        var alpha_j_old: Float = 0.0
        var multi = [Float]()
        var multi2 = [Float]()
        var randomNum: Float = 0.0
        var j: Int = 0
        var b1: Float = 0.0
        var b2: Float = 0.0
        let K = MatrixMultiply(X, MatrixTranspose(X))
        
        print(Y)
        
        var dots = 12
        while passes < max_passes {
            var num_changed_alphas = 0
            
            for i in 0..<m {
                multi = MatrixDotProduct(MatrixDotProduct(model.alphas, Y), K.getColumn(column: i))
                E[i] = model.b + multi.reduce(0, +) - Y[i]
                
                if (Y[i]*E[i] < -tol && model.alphas[i] < C) || (Y[i]*E[i] > tol && model.alphas[i] > 0) {
                    randomNum = Float(arc4random()) / Float(UINT32_MAX)
                    j = Int(floor(Float(m) * randomNum))
                    while j == i {
                        randomNum = Float(arc4random()) / Float(UINT32_MAX)
                        j = Int(floor(Float(m) * randomNum))
                    }
                    
                    multi2 = MatrixDotProduct(MatrixDotProduct(model.alphas, Y), K.getColumn(column: j))
                    E[j] = model.b + multi2.reduce(0, +) - Y[j]
                    
                    alpha_i_old = model.alphas[i]
                    alpha_j_old = model.alphas[j]
                    
                    if Y[i] == Y[j] {
                        L = max(0, model.alphas[j] + model.alphas[i] - C)
                        H = min(C, model.alphas[j] + model.alphas[i])
                    } else {
                        L = max(0, model.alphas[j] - model.alphas[i])
                        H = min(C, C + model.alphas[j] - model.alphas[i])
                    }
                    
                    if L == H {
                        continue
                    }
                    
                    eta = 2 * K[i][j] - K[i][i] - K[j][j]
                    if eta >= 0 {
                        continue
                    }
                    
                    model.alphas[j] -= (Y[j] * (E[i] - E[j])) / eta
                    
                    model.alphas[j] = min(H, model.alphas[j])
                    model.alphas[j] = max(L, model.alphas[j])
                    
                    if abs(model.alphas[j] - alpha_j_old) < tol {
                        model.alphas[j] = alpha_j_old
                        continue
                    }
                    
                    model.alphas[i] = model.alphas[i] + Y[i]*Y[j]*(alpha_j_old - model.alphas[j])
                    
                    b1 = model.b - E[i] - Y[i] * (model.alphas[i] - alpha_i_old) * K[i][j] - Y[j] * (model.alphas[j] - alpha_j_old) * K[i][j]
                    b2 = model.b - E[j] - Y[i] * (model.alphas[i] - alpha_i_old) * K[i][j] - Y[j] * (model.alphas[j] - alpha_j_old) * K[j][j]
                    
                    
                    if 0 < model.alphas[i] && model.alphas[i] < C  {
                        model.b = b1
                    } else {
                        if 0 < model.alphas[j] && model.alphas[j] < C {
                            model.b = b2
                        } else {
                            model.b = (b1 + b2)/2
                        }
                    }
                    
                    num_changed_alphas = num_changed_alphas + 1
                    
                }
            }
            
            if num_changed_alphas == 0 {
                passes = passes + 1
            } else {
                passes = 0
            }
            
            print(".", terminator:"")
            dots += 1
            if dots > 78 {
                dots = 0
                print("\n")
            }

        }
        print("Done!\n")
        
        var temp = [Float](repeating: 0.0, count: Y.count)
        for i in 0..<Y.count {
            temp[i] = model.alphas[i] * Y[i]
        }
        let temp2 = MatrixMultiply([temp], X)
        model.w = temp2[0]
    }
    
    func printModel() {
        print(model.w)
        print(model.b)
    }
    
    
}
