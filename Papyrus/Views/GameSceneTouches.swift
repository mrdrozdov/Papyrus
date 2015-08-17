//
//  GameSceneTouches.swift
//  Papyrus
//
//  Created by Chris Nevin on 13/07/2015.
//  Copyright © 2015 CJNevin. All rights reserved.
//

import SpriteKit

extension GameScene {
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        do { try pickup(atPoint: point(inTouches: touches)) }
        catch { print("Error picking up sprite") }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let point = point(inTouches: touches) else { return }
        heldTile?.resetPosition(point)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        do { try drop(atPoint: point(inTouches: touches)) }
        catch { print("Error dropping sprite") }
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        do { try dropInRack(false, atPoint: heldOrigin ?? point(inTouches: touches)) }
        catch { print("Error dropping in rack") }
    }
    
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
    }
    
}

extension GameScene {
    
    /// - Returns: Point of held tile if available.
    var heldOrigin: CGPoint? {
        return heldTile?.origin
    }
    
    /// - Returns: First point in touches set
    private func point(inTouches touches: Set<UITouch>?) -> CGPoint? {
        return touches?.first?.locationInNode(self)
    }
    
    /// - Parameter point: Point to check for intersection with square sprites
    /// - Returns: `SquareSprite` that best intersects the point passed in
    private func intersectedSquareSprite(point: CGPoint) -> SquareSprite? {
        // Check if we are holding a tile, if not return
        guard let tileSprite = heldTile else { return nil }
        // Function to calculate intersection
        func intersection(item: SquareSprite) -> CGFloat {
            let intersection = CGRectIntersection(item.frame, tileSprite.frame)
            return CGRectGetHeight(intersection) + CGRectGetWidth(intersection)
        }
        // Filter empty squares that intersect our tile
        let s = squareSprites.filter({ $0.isEmpty && $0.intersectsNode(tileSprite) })
        if s.count == 0 { return nil }
        return s.filter({ $0.frame.contains(point) }).first ??
            s.maxElement({ return intersection($0) < intersection($1) })
    }
    
    func calc() {
        let axis = Axis.Horizontal(.Prev)
        var positions = [Position]()
        for sprite in squareSprites where sprite.tileSprite != nil {
            positions.append(Position(axis: axis, iterable: sprite.square.column, fixed: sprite.square.row))
        }
        if let boundary = game.boundary(forPositions: positions) {
            do {
                print(try game.play(boundary, submit: false))
            } catch let err as ValidationError {
                switch err {
                case .InsufficientTiles: print("not enough tiles")
                case .InvalidArrangement: print("invalid arrangement")
                case .NoCenterIntersection: print("no center")
                case .NoIntersection: print("no intersection")
                case .UnfilledSquare: print("skipped square")
                case .UndefinedWord(let word): print("undefined \(word)")
                case .Message(let message): print(message)
                }
            } catch _ {
                
            }
        } else {
            print("No boundary")
        }
        
    }
    
    /// Drop a tile on the board, or if no squares are intersected back to the tile rack.
    /// Throws an error if either 'place' fails.
    private func drop(atPoint point: CGPoint?) throws {
        guard let point = point, sprite = heldTile, origin = heldOrigin else { return }
        guard let emptySquare = intersectedSquareSprite(point) else {
            try dropInRack(atPoint: origin)
            return
        }
        // Drop on board
        emptySquare.animateDropTileSprite(sprite, originalPoint: origin, completion: nil)
        let tile = sprite.tile
        tile.placement = .Board
        calc()
        if tile.value == 0 && tile.letter == "?" {
            actionDelegate?.pickLetter({ (c) -> () in
                sprite.changeLetter(c)
            })
        }
    }
    
    /// Drop currently held tile into the rack.
    /// Throws an error if 'place' method fails.
    private func dropInRack(animated: Bool? = true, atPoint point: CGPoint?) throws {
        guard let point = point, sprite = heldTile else { return }
        animated == true ? sprite.animateDropToRack(point) : sprite.resetPosition(point)
        let tile = sprite.tile
        tile.placement = .Rack
        if tile.value == 0 {
            sprite.changeLetter("?")
        }
    }
    
    /// Pickup a tile from the rack or board.
    /// Throws an error if 'place' method fails.
    private func pickup(atPoint point: CGPoint?) throws {
        guard let point = point else { return }
        if let s = squareSprites.filter({ $0.containsPoint(point) && $0.tileSprite != nil }).first,
            t = s.pickupTileSprite() {
            // Pickup from board
            t.origin = s.origin
            t.tile.placement = .Held
            t.animateGrow()
            addChild(t)
        } else if let t = tileSprites.filter({ $0.containsPoint(point) && !$0.hasActions() }).first {
            // Pickup from rack
            t.origin = t.position
            t.tile.placement = .Held
            t.animatePickupFromRack(point)
        }
    }
}