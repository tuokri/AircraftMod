/* Copyright (c) 2024 Tuomo Kriikkula
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

// 3D debug arrow.
class DebugArrow extends Object
    notplaceable;

static function Draw(
    vector Position,
    vector Direction,
    float R,
    float G,
    float B,
    float ArrowHeadLength = 100.0,
    float ArrowHeadAngle = 0.25)
{
    local vector ArrowHead;
    local vector LineEnd;
    local vector Right;
    local vector Left;
    local rotator TempRot;
    local vector TempVec;

    ArrowHead = Position + Direction;
    class'Actor'.static.DrawDebugLine(Position, ArrowHead, R, G, B);

    TempVec.X = 1;
    TempRot.Pitch = (180 * DegToUnrRot) + ArrowHeadAngle;
    Right = QuatRotateVector(QuatProduct(QuatFromAxisAndAngle(Direction, 0.0), QuatFromRotator(TempRot)), TempVec);
    TempRot.Pitch = (180 * DegToUnrRot) - ArrowHeadAngle;
    Left = QuatRotateVector(QuatProduct(QuatFromAxisAndAngle(Direction, 0.0), QuatFromRotator(TempRot)), TempVec);

    LineEnd = ArrowHead + (Right * ArrowHeadLength);
    class'Actor'.static.DrawDebugLine(ArrowHead, LineEnd, R, G, B);
    LineEnd = ArrowHead + (Left * ArrowHeadLength);
    class'Actor'.static.DrawDebugLine(ArrowHead, LineEnd, R, G, B);
}
