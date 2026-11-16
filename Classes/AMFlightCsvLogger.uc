// Lightweight UnrealScript entry points for the aircraft CSV logger.
// FileWriter behavior is based on the UDK-Lite engine source and still needs
// verification in the target Rising Storm 2 build.
class AMFlightCsvLogger extends Info;

var private FileWriter AircraftFileWriter;
var private FileWriter SurfaceFileWriter;
var private string FlightId;
var private int TickId;
var private bool bIsOpen;

simulated function bool StartSession(string InFlightId)
{
    // TODO: spawn two FileWriter actors and open unique FWFT_Debug CSV files.
    // FileWriter.OpenFile() selects a safe engine-managed output directory;
    // it does not accept an arbitrary destination path.
    // Disable bFlushEachWrite and emit CSV lines with FileWriter.Logf().
    return false;
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
