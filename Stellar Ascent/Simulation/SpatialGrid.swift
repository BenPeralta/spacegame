import Foundation
import simd

class SpatialGrid {
    // Cell size optimized for "neighbor check" range
    // Usually radius of influence / 3 or so, or max collision size
    let cellSize: Float
    
    // Map: CellHash -> List of Entity Indices
    var grid: [Int64: [Int]] = [:]
    
    init(cellSize: Float) {
        self.cellSize = cellSize
    }
    
    // Hash: (cx << 32) ^ cy
    @inline(__always)
    func cellKey(cx: Int, cy: Int) -> Int64 {
        return (Int64(cx) << 32) ^ Int64(cy & 0xffffffff)
    }
    
    @inline(__always)
    func cellCoord(_ pos: SIMD2<Float>) -> (Int, Int) {
        // Safety: prevent crash if position is NaN or Inf
        let x = pos.x.isFinite ? pos.x : 0.0
        let y = pos.y.isFinite ? pos.y : 0.0
        return (Int(floor(x / cellSize)), Int(floor(y / cellSize)))
    }
    
    func insert(entityIndex: Int, pos: SIMD2<Float>) {
        let (cx, cy) = cellCoord(pos)
        let key = cellKey(cx: cx, cy: cy)
        grid[key, default: []].append(entityIndex)
    }
    
    func clear() {
        grid.removeAll(keepingCapacity: true)
    }
    
    // Return entity indices in cells overlapping the query circle
    func query(center: SIMD2<Float>, radius: Float) -> [Int] {
        var results: [Int] = []
        // Optional capacity reservation if we know avg density
        // results.reserveCapacity(50) 
        
        let minX = Int(floor((center.x - radius) / cellSize))
        let maxX = Int(floor((center.x + radius) / cellSize))
        let minY = Int(floor((center.y - radius) / cellSize))
        let maxY = Int(floor((center.y + radius) / cellSize))
        
        for cx in minX...maxX {
            for cy in minY...maxY {
                let key = cellKey(cx: cx, cy: cy)
                if let cellIndices = grid[key] {
                    results.append(contentsOf: cellIndices)
                }
            }
        }
        
        return results
    }
}
