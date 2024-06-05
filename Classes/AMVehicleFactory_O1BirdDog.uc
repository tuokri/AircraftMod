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

// Bird Dog aircraft factory.
class AMVehicleFactory_O1BirdDog extends ROTransportVehicleFactory;

DefaultProperties
{
    Begin Object Name=SVehicleMesh
        SkeletalMesh=SkeletalMesh'BirdDog.Mesh.BirdDog_Rig_Master'
        Translation=(X=0.0,Y=0.0,Z=0.0)
    End Object

    Components.Remove(Sprite)

    Begin Object Name=CollisionCylinder
        CollisionHeight=+100.0
        CollisionRadius=+400.0
        Translation=(X=0.0,Y=0.0,Z=0.0)
        Rotation=(Pitch=0,Roll=0,Yaw=32767)
    End Object

    VehicleClass=class'AMAircraft_O1BirdDog_Content'
    DrawScale=1.0

    bTransportHeloFactory=true
}
