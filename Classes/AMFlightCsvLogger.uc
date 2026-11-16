// Lightweight UnrealScript entry points for the aircraft CSV logger.
// File opening, CSV serialization, buffering, and error handling are not
// implemented yet; validate FileWriter behavior in the target game first.
class AMFlightCsvLogger extends Object;

var private FileWriter AircraftFileWriter;
var private FileWriter SurfaceFileWriter;
var private string FlightId;
var private int TickId;
var private bool bIsOpen;

simulated function StartSession(
    string InFlightId,
    string AircraftCsvPath,
    string SurfaceCsvPath)
{
    // TODO: open both text files, write stable headers, then enable logging.
}

simulated function int BeginTick(float GameTimeSeconds, float DeltaTime)
{
    if (!bIsOpen)
    {
        return -1;
    }

    ++TickId;
    // TODO: retain timing for the aircraft row and surface rows this tick.
    return TickId;
}

simulated function LogSurfaceTick(
    int SurfaceIndex,
    AeroSurfaceComponent Surface,
    vector WorldAirVelocity,
    vector RelativePosition)
{
    if (!bIsOpen)
    {
        return;
    }

    // TODO: serialize this surface's transform, airflow, coefficients, and forces.
}

simulated function LogAircraftTick(
    vector WorldPosition,
    rotator WorldRotation,
    vector WorldVelocity,
    vector WorldAngularVelocity,
    vector AeroForceBeforeScaling,
    vector AeroTorqueBeforeScaling,
    vector ThrustForce,
    vector ForceSubmitted,
    vector TorqueSubmitted)
{
    if (!bIsOpen)
    {
        return;
    }

    // TODO: serialize state, inputs, totals, and the submitted force/torque.
}

simulated function StopSession()
{
    if (!bIsOpen)
    {
        return;
    }

    // TODO: flush/close both files and clear session state.
}
