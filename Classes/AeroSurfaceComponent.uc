class AeroSurfaceComponent extends PrimitiveComponent;

const HALFPI = 1.57079632679;

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

// DEBUG ONLY.
var vector CachedDragDirection;
var vector CachedLiftDirection;
var vector CachedAirVelocity;
var vector CachedForwardVector;
var float MaxTorque;
var float MaxForce;

var private float FlapAngle;

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

simulated function SetFlapAngle(float Angle)
{
    // FlapAngle = FClamp(Angle, DegToRad * -50, DegToRad * 50);
    FlapAngle = FClamp(Angle, -0.8726646259971648, 0.8726646259971648);

    // `log(name $ ": FlapAngle (rad) = " $ FlapAngle,, 'AircraftPhysics');
    // `log(name $ ": FlapAngle (deg) = " $ FlapAngle * RadToDeg,, 'AircraftPhysics');
}

simulated function CalculateForces(vector WorldAirVelocity, float AirDensity,
    vector RelativePosition, out vector OutForce, out vector OutTorque)
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

    local vector X, Y, Z;

    // RotMatrix = MakeRotationMatrix(GetRotation());
    // ForwardVector = Normal(MatrixGetAxis(RotMatrix, AXIS_X));

    GetAxes(GetRotation(), X, Y, Z);
    ForwardVector = X;

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
    // Z component of the velocity is discarded.
    // TODO: Check if these vector/matrix operations are actually correct.
    // TODO: copy UE4 InverseTransformDirection implementation.
    // AirVelocity = InverseTransformDirection(LocalToWorld /*RotMatrix*/, WorldAirVelocity);
    // AirVelocity = InverseTransformDirection(LocalToWorld /*RotMatrix*/, WorldAirVelocity);
    // AirVelocity = InverseTransformVector(LocalToWorld, WorldAirVelocity);
    AirVelocity = InverseTransformNormal(LocalToWorld, WorldAirVelocity);
    AirVelocity.Z = 0;
    DragDirection = TransformNormal(LocalToWorld /*RotMatrix*/, AirVelocity);
    // DragDirection = TransformVector(LocalToWorld, Normal(AirVelocity));
    LiftDirection = DragDirection cross ForwardVector;

    // DEBUG ONLY.
    CachedAirVelocity = AirVelocity;
    CachedDragDirection = DragDirection;
    CachedLiftDirection = LiftDirection;
    CachedForwardVector = ForwardVector;

    Area = Chord * Span;
    DynamicPressure = 0.5 * AirDensity * VSizeSq((AirVelocity * 0.02)); // TODO: are things breaking due to meters/UUs conversions?
    LocalAngleOfAttack = ATan2(AirVelocity.Y, -AirVelocity.X);

    AerodynamicCoefficients = CalculateCoefficients(
        LocalAngleOfAttack, CorrectedLiftSlope,
        LocalZeroLiftAOA, LocalStallAngleHigh, LocalStallAngleLow);

    `log(
        name
        $ ": FlapAngle = " $ FlapAngle
        $ ", Area = " $ Area
        $ ", LiftCoeff = " $ AerodynamicCoefficients.X
        $ ", DragCoeff = " $ AerodynamicCoefficients.Y
        $ ", TangentialCoeff = " $ AerodynamicCoefficients.Z
        $ ", DynamicPressure = " $ DynamicPressure,, 'AircraftPhysics');

    Lift = LiftDirection * AerodynamicCoefficients.X * DynamicPressure * Area;
    // Lift = ClampLength(Lift, MaxForce); // TODO: need for safety?
    Drag = DragDirection * AerodynamicCoefficients.Y * DynamicPressure * Area;
    // Drag = ClampLength(Drag, MaxForce); // TODO: need for safety?
    Torque = (-ForwardVector * AerodynamicCoefficients.Z * DynamicPressure * Area * Chord);
    // Torque = ClampLength(Torque, MaxTorque); // TODO: need for safety?

    LocalForce = Lift + Drag;
    // LocalForce = ClampLength(LocalForce, MaxForce);

    LocalTorque = (RelativePosition cross LocalForce) + Torque;
    // LocalTorque = ClampLength(LocalTorque, MaxTorque);

    OutForce += LocalForce;
    OutTorque += LocalTorque;

    `log(
        name
        $ ": Lift = " $ Lift
        $ ", Drag = " $ Drag
        $ ", Force = " $ LocalForce
        $ ", Torque = " $ LocalTorque
        $ ", AirVelocity = " $ AirVelocity
        $ ", WorldAirVelocity = " $ WorldAirVelocity
        $ ", RelativePosition = " $ RelativePosition
        $ ", IsAtStall = " $ !(LocalAngleOfAttack < LocalStallAngleHigh && LocalAngleOfAttack > LocalStallAngleLow),, 'AircraftPhysics');
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
    // return 1.98 * (4.26 * 10 ** -2) * FlapAngle * FlapAngle * (2.1 * 10 ** -1) * FlapAngle;
    return 1.98 - 0.0426 * InFlapAngle * InFlapAngle + 0.21 * InFlapAngle;
    // return 0.01771308 * InFlapAngle * InFlapAngle * InFlapAngle;
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
