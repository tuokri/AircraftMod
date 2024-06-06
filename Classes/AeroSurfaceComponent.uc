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

// Individual surface component that applies lift, drag and torque to the
// owning aircraft. Can have optional control surfaces (flaps).
class AeroSurfaceComponent extends PrimitiveComponent;

const HALFPI = 1.57079632679;
const UU_TO_METERS = 0.02;

enum EInputType
{
    EIT_None,
    EIT_Yaw,
    EIT_Roll,
    EIT_Pitch,
    EIT_Flap,
};

var(AeroSurface) float LiftSlope;
var(AeroSurface) float AspectRatio;
var(AeroSurface) float FlapFraction;
var(AeroSurface) float ZeroLiftAOA;
var(AeroSurface) float StallAngleHigh;
var(AeroSurface) float StallAngleLow;
var(AeroSurface) float Chord;
var(AeroSurface) float Span;
var(AeroSurface) float SkinFriction;
var(AeroSurface) bool bIsControlSurface;
var(AeroSurface) EInputType InputType;
var(AeroSurface) name AttachmentTargetName;
var(AeroSurface) bool bAttachToSocket;
var(AeroSurface) float InputMultiplier;
var(AeroSurface) name FlapSkelControllerNameUp;
var(AeroSurface) name FlapSkelControllerNameDown;
var(AeroSurface) name SurfaceName;

// DEBUG ONLY.
var(AeroSurfaceDebug) vector CachedDragDirection;
var(AeroSurfaceDebug) vector CachedLiftDirection;
var(AeroSurfaceDebug) vector CachedAirVelocity;
var(AeroSurfaceDebug) vector CachedForwardVector;
var(AeroSurfaceDebug) float MaxTorque;
var(AeroSurfaceDebug) float MaxForce;
var(AeroSurfaceDebug) vector CachedLift;
var(AeroSurfaceDebug) vector CachedDrag;
var(AeroSurfaceDebug) vector CachedTorque;
var(AeroSurfaceDebug) vector CachedForce;
var(AeroSurfaceDebug) float CachedLiftCoeff;
var(AeroSurfaceDebug) float CachedDragCoeff;
var(AeroSurfaceDebug) float CachedTangentialCoeff;
var(AeroSurfaceDebug) float CachedDynamicPressure;
var(AeroSurfaceDebug) bool bIsAtStall;

var float FlapAngle;

/*
simulated function vector TransformDirection(matrix TM, vector Direction)
{
    return TransformVectorNoScale(TM, Direction);
}

simulated function vector TransformVectorNoScale(matrix TM, vector Direction)
{
    return QuatRotateVector(QuatFromRotator(MatrixGetRotator(TM)), Direction);
}

simulated function vector InverseTransformDirection(matrix TM, vector Direction)
{
    return InverseTransformVectorNoScale(TM, Direction);
}

simulated function vector InverseTransformVectorNoScale(matrix TM, vector Direction)
{
    return VectorQuaternionInverseRotateVector(QuatFromRotator(MatrixGetRotator(TM)), Direction);
}

simulated function vector VectorQuaternionInverseRotateVector(Quat Q, vector Vec)
{
    return QuatRotateVector(VectorQuaternionInverse(Q), Vec);
}

simulated function Quat VectorQuaternionInverse(Quat Q)
{
    Q.X = -Q.X;
    Q.Y = -Q.Y;
    Q.Z = -Q.Z;
    return Q;
}
*/

simulated function SetFlapAngle(float Angle)
{
    // FlapAngle = FClamp(Angle, DegToRad * -50, DegToRad * 50);
    FlapAngle = FClamp(Angle, -0.8726646259971648, 0.8726646259971648);

    // `log(name $ ": FlapAngle (rad) = " $ FlapAngle,, 'AircraftPhysics');
    // `log(name $ ": FlapAngle (deg) = " $ FlapAngle * RadToDeg,, 'AircraftPhysics');
}

simulated function CalculateForces(
    vector WorldAirVelocity,
    float AirDensity,
    vector RelativePosition,
    out vector OutForce,
    out vector OutTorque)
{
    // local matrix RotMatrix;
    local vector Lift;
    local vector Drag;
    local vector Torque;
    local vector AirVelocity;
    local vector DragDirection;
    local vector LiftDirection;
    local vector ForwardVector;
    local vector AerodynamicCoefficients;
    local vector LocalForce;
    local vector LocalTorque;
    local float CorrectedLiftSlope;
    local float Theta;
    local float FlapEffectiveness;
    local float DeltaLift;
    local float ZeroLiftAOABase;
    local float LocalZeroLiftAOA;
    local float StallAngleHighBase;
    local float StallAngleLowBase;
    local float ClMaxHigh;
    local float ClMaxLow;
    local float LocalStallAngleHigh;
    local float LocalStallAngleLow;
    local float Area;
    local float DynamicPressure;
    local float LocalAngleOfAttack;

    local vector _Discard_Y, _Discard_Z;

    // TODO: something is fucking this up? LifDirection goes from
    // up to down suddenly for some reason?

    // TODO: some fuckery going on here in the original Unity project?
    //  - The forward vector is not really forward but points to the left
    //    on the reference Cessna aircraft? Why are the aero surfaces rotated 90 deg?
    // GetAxes(GetRotation(), ForwardVector, Y, Z); <-- this should be correct according to all intuition!?
    GetAxes(Owner.Rotation, _Discard_Y, ForwardVector, _Discard_Z); // <-- but let's do this instead...
    ForwardVector = -ForwardVector; // Yeah...

    // Accounting for aspect ratio effect on lift coefficient.
    CorrectedLiftSlope = (LiftSlope * AspectRatio
        / (AspectRatio + 2 * (AspectRatio + 4) / (AspectRatio + 2)));

    // Calculating flap deflection influence on zero lift angle of attack
    // and angles at which stall happens.
    Theta = ACos(2 * FlapFraction - 1);
    FlapEffectiveness = 1 - (Theta - Sin(Theta)) / PI;
    DeltaLift = (CorrectedLiftSlope * FlapEffectiveness
        * FlapEffectivenessCorrection(FlapAngle) * FlapAngle);

    ZeroLiftAOABase = ZeroLiftAOA * DegToRad;
    LocalZeroLiftAOA = ZeroLiftAOABase - DeltaLift / CorrectedLiftSlope;

    StallAngleHighBase = StallAngleHigh * DegToRad;
    StallAngleLowBase = StallAngleLow * DegToRad;

    ClMaxHigh = (CorrectedLiftSlope * (StallAngleHighBase - ZeroLiftAOABase)
        + DeltaLift * LiftCoefficientMaxFraction(FlapFraction));
    ClMaxLow = (CorrectedLiftSlope * (StallAngleLowBase - ZeroLiftAOABase)
        + DeltaLift * LiftCoefficientMaxFraction(FlapFraction));

    LocalStallAngleHigh = LocalZeroLiftAOA + ClMaxHigh / CorrectedLiftSlope;
    LocalStallAngleLow = LocalZeroLiftAOA + ClMaxLow / CorrectedLiftSlope;

    // Calculating air velocity relative to the surface's coordinate system.
    AirVelocity = InverseTransformNormal(LocalToWorld, WorldAirVelocity);
    // Ignore the component perpendicular to surface since it only causes skin friction.
    AirVelocity.Y = 0; // TODO: In unity the Z component is discarded? And in Unreal Y?
    DragDirection = TransformNormal(LocalToWorld /*RotMatrix*/, Normal(AirVelocity));
    LiftDirection = Normal(DragDirection cross ForwardVector);
    DragDirection = Normal(DragDirection);

    // `log("###### LiftDirection SIZE :" @ VSize(LiftDirection));
    // `log("###### DragDirection SIZE :" @ VSize(DragDirection));
    // `log("###### AirVelocity SIZE   :" @ VSize(AirVelocity));

    // DEBUG ONLY.
    CachedAirVelocity = AirVelocity;
    CachedDragDirection = DragDirection;
    CachedLiftDirection = LiftDirection;
    CachedForwardVector = ForwardVector;

    Area = Chord * Span;
    // TODO: are things breaking due to meters/UUs conversions?
    DynamicPressure = 0.5 * AirDensity * VSizeSq((AirVelocity * UU_TO_METERS));
    CachedDynamicPressure = DynamicPressure;
    LocalAngleOfAttack = ATan2(AirVelocity.Y, -AirVelocity.X);

    AerodynamicCoefficients = CalculateCoefficients(
        LocalAngleOfAttack, CorrectedLiftSlope,
        LocalZeroLiftAOA, LocalStallAngleHigh, LocalStallAngleLow);

    CachedLiftCoeff = AerodynamicCoefficients.X;
    CachedDragCoeff = AerodynamicCoefficients.Y;
    CachedTangentialCoeff = AerodynamicCoefficients.Z;

    // `log(
    //     name
    //     $ ": FlapAngle = " $ FlapAngle
    //     $ ", Area = " $ Area
    //     $ ", LiftCoeff = " $ CachedLiftCoeff
    //     $ ", DragCoeff = " $ CachedDragCoeff
    //     $ ", TangentialCoeff = " $ CachedTangentialCoeff
    //     $ ", DynamicPressure = " $ DynamicPressure,, 'AircraftPhysics');

    Lift = LiftDirection * AerodynamicCoefficients.X * DynamicPressure * Area;
    // Lift = ClampLength(Lift, MaxForce); // TODO: need for safety?
    CachedLift = Lift;

    Drag = DragDirection * AerodynamicCoefficients.Y * DynamicPressure * Area;
    // Drag = ClampLength(Drag, MaxForce); // TODO: need for safety?
    CachedDrag = Drag;

    // TODO: where to do the unit conversions for torque?
    Torque = (-ForwardVector * AerodynamicCoefficients.Z * DynamicPressure * Area * Chord) * UU_TO_METERS;
    // Torque = ClampLength(Torque, MaxTorque); // TODO: need for safety?

    LocalForce = Lift + Drag;
    // LocalForce = ClampLength(LocalForce, MaxForce);
    CachedForce = LocalForce;

    // TODO: where to do the unit conversions for torque?
    LocalTorque = ((RelativePosition cross LocalForce) * UU_TO_METERS) + Torque;
    // LocalTorque = ClampLength(LocalTorque, MaxTorque);
    CachedTorque = LocalTorque;

    OutForce += LocalForce;
    OutTorque += LocalTorque;

    bIsAtStall = !(LocalAngleOfAttack < LocalStallAngleHigh && LocalAngleOfAttack > LocalStallAngleLow);
    // `log(
    //     name
    //     $ ": Lift = " $ Lift
    //     $ ", Drag = " $ Drag
    //     $ ", Force = " $ LocalForce
    //     $ ", Torque = " $ LocalTorque
    //     $ ", AirVelocity = " $ AirVelocity
    //     $ ", WorldAirVelocity = " $ WorldAirVelocity
    //     $ ", RelativePosition = " $ RelativePosition
    //     $ ", IsAtStall = " $ bIsAtStall,, 'AircraftPhysics');
}

simulated function vector CalculateCoefficients(float InAngleOfAttack, float CorrectedLiftSlope,
    float InZeroLiftAOA, float InStallAngleHigh, float InStallAngleLow)
{
    local vector AerodynamicCoefficients;
    local vector AerodynamicCoefficientsLow;
    local vector AerodynamicCoefficientsStall;
    local float PaddingAngleHigh;
    local float PaddingAngleLow;
    local float PaddedStallAngleHigh;
    local float PaddedStallAngleLow;
    local float LerpParam;

    // Low angles of attack mode and stall mode curves are stitched together by a line segment.
    PaddingAngleHigh = DegToRad * Lerp(15, 5, (RadToDeg * FlapAngle + 50) / 100);
    PaddingAngleLow = DegToRad * Lerp(15, 5, (-RadToDeg * FlapAngle + 50) / 100);
    PaddedStallAngleHigh = InStallAngleHigh + PaddingAngleHigh;
    PaddedStallAngleLow = InStallAngleLow - PaddingAngleLow;

    if (PaddedStallAngleHigh == 0
        || PaddedStallAngleLow == 0
        || PaddingAngleLow == 0
        || PaddingAngleHigh == 0)
    {
        `log("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! "
            $ "WARNING: ZERO VALUE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!",, 'AircraftPhysics');
    }

    if (InAngleOfAttack < InStallAngleHigh && InAngleOfAttack > InStallAngleLow)
    {
        // Low angle of attack mode.
        AerodynamicCoefficients = CalculateCoefficientsAtLowAOA(InAngleOfAttack,
            CorrectedLiftSlope, InZeroLiftAOA);
    }
    else
    {
        if (InAngleOfAttack > PaddedStallAngleHigh || InAngleOfAttack < PaddedStallAngleLow)
        {
            // Stall mode.
            AerodynamicCoefficients = CalculateCoefficientsAtStall(InAngleOfAttack,
                CorrectedLiftSlope, InZeroLiftAOA, InStallAngleHigh, InStallAngleLow);
        }
        else
        {
            // Linear stitching in-between stall and low angles of attack modes.
            if (InAngleOfAttack > InStallAngleHigh)
            {
                AerodynamicCoefficientsLow = CalculateCoefficientsAtLowAOA(InStallAngleHigh,
                    CorrectedLiftSlope, InZeroLiftAOA);
                AerodynamicCoefficientsStall = CalculateCoefficientsAtStall(PaddedStallAngleHigh,
                    CorrectedLiftSlope, InZeroLiftAOA, InStallAngleHigh, InStallAngleLow);
                LerpParam = (InAngleOfAttack - InStallAngleHigh) / (PaddedStallAngleHigh - InStallAngleHigh);
            }
            else
            {
                AerodynamicCoefficientsLow = CalculateCoefficientsAtLowAOA(InStallAngleLow,
                    CorrectedLiftSlope, InZeroLiftAOA);
                AerodynamicCoefficientsStall = CalculateCoefficientsAtStall(PaddedStallAngleLow,
                    CorrectedLiftSlope, InZeroLiftAOA, InStallAngleHigh, InStallAngleLow);
                LerpParam = (InAngleOfAttack - InStallAngleLow) / (PaddedStallAngleLow - InStallAngleLow);
            }

            AerodynamicCoefficients = VLerp(AerodynamicCoefficientsLow, AerodynamicCoefficientsStall, LerpParam);
        }
    }

    return AerodynamicCoefficients;
}

simulated function vector CalculateCoefficientsAtStall(float InAngleOfAttack,
    float CorrectedLiftSlope, float InZeroLiftAOA, float InStallAngleHigh, float InStallAngleLow)
{
    local vector Coefficients;
    local float LiftCoefficientLowAOA;
    local float InducedAngle;
    local float EffectiveAngle;
    local float NormalCoefficient;
    local float TangentialCoefficient;
    local float LiftCoefficient;
    local float DragCoefficient;
    local float TorqueCoefficient;
    local float LerpParam;

    if (InAngleOfAttack > InStallAngleHigh)
    {
        LiftCoefficientLowAOA = CorrectedLiftSlope * (InStallAngleHigh - InZeroLiftAOA);
    }
    else
    {
        LiftCoefficientLowAOA = CorrectedLiftSlope * (InStallAngleLow - InZeroLiftAOA);
    }
    InducedAngle = LiftCoefficientLowAOA / (PI * AspectRatio);

    if (InAngleOfAttack > InStallAngleHigh)
    {
        LerpParam = (HALFPI - FClamp(InAngleOfAttack, -HALFPI, HALFPI)) / (HALFPI - InStallAngleHigh);
    }
    else
    {
        LerpParam = (-HALFPI - FClamp(InAngleOfAttack, -HALFPI, HALFPI)) / (-HALFPI - InStallAngleLow);
    }
    InducedAngle = Lerp(0, InducedAngle, LerpParam);
    EffectiveAngle = InAngleOfAttack - InZeroLiftAOA - InducedAngle;

    NormalCoefficient = (FrictionAt90Degrees(FlapAngle) * Sin(EffectiveAngle)
        * (1 / (0.56 + 0.44 * Abs(Sin(EffectiveAngle)))
            - 0.41 * (1 - Exp(-17 / AspectRatio))));
    TangentialCoefficient = 0.5 * SkinFriction * Cos(EffectiveAngle);

    LiftCoefficient = NormalCoefficient * Cos(EffectiveAngle) - TangentialCoefficient * Sin(EffectiveAngle);
    DragCoefficient = NormalCoefficient * Sin(EffectiveAngle) + TangentialCoefficient * Cos(EffectiveAngle);
    TorqueCoefficient = -NormalCoefficient * TorqCoefficientProportion(EffectiveAngle);

    Coefficients.X = LiftCoefficient;
    Coefficients.Y = DragCoefficient;
    Coefficients.Z = TorqueCoefficient;

    return Coefficients;
}

simulated function vector CalculateCoefficientsAtLowAOA(float InAngleOfAttack,
    float CorrectedLiftSlope, float InZeroLiftAOA)
{
    local float LiftCoefficient;
    local float InducedAngle;
    local float EffectiveAngle;
    local float TangentialCoefficient;
    local float NormalCoefficient;
    local float DragCoefficient;
    local float TorqueCoefficient;
    local vector Coefficients;

    LiftCoefficient = CorrectedLiftSlope * (InAngleOfAttack - InZeroLiftAOA);
    InducedAngle = LiftCoefficient / (PI * AspectRatio);
    EffectiveAngle = InAngleOfAttack - InZeroLiftAOA - InducedAngle;

    TangentialCoefficient = SkinFriction * Cos(EffectiveAngle);

    NormalCoefficient = (LiftCoefficient + Sin(EffectiveAngle) * TangentialCoefficient) / Cos(EffectiveAngle);
    DragCoefficient = NormalCoefficient * Sin(EffectiveAngle) + TangentialCoefficient * Cos(EffectiveAngle);
    TorqueCoefficient = -NormalCoefficient * TorqCoefficientProportion(EffectiveAngle);

    Coefficients.X = LiftCoefficient;
    Coefficients.Y = DragCoefficient;
    Coefficients.Z = TorqueCoefficient;

    return Coefficients;
}

simulated function float FlapEffectivenessCorrection(float InFlapAngle)
{
    return Lerp(0.8, 0.4, (Abs(InFlapAngle) * RadToDeg - 10) / 50);
}

simulated function float LiftCoefficientMaxFraction(float InFlapFraction)
{
    return FClamp(0.0, 1.0, 1 - 0.5 * (InFlapFraction - 0.1) / 0.3);
}

simulated function float TorqCoefficientProportion(float InEffectiveAngle)
{
    return 0.25 - 0.175 * (1 - 2 * Abs(InEffectiveAngle) / PI);
}

simulated function float FrictionAt90Degrees(float InFlapAngle)
{
    return 1.98 - 0.0426 * InFlapAngle * InFlapAngle + 0.21 * InFlapAngle;
}

DefaultProperties
{
    LiftSlope=6.28
    SkinFriction=0.02
    ZeroLiftAOA=0
    StallAngleHigh=15
    StallAngleLow=-15
    FlapFraction=0
    Chord=1
    Span=1
    AspectRatio=1
    bIsControlSurface=False
    InputType=EIT_None
    InputMultiplier=1

    MaxTorque=3500000
    MaxForce=3500000
}
