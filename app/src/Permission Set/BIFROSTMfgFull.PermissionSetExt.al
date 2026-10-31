namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>
/// Extends the Bifrost full access permission set with the Manufacturing objects,
/// so anyone already granted full Bifrost access can invoke these message types too.
/// The extension includes "BIFROST Mfg ori" instead of repeating its list, so the two always
/// grant the same objects; add a new object to "BIFROST Mfg ori" only.
/// The message types still run under the caller's own permissions on the manufacturing tables,
/// so this does not widen access to production or routing data.
/// </summary>
permissionsetextension 10077037 "BIFROST MfgFull ori" extends "BIFROST Full ori"
{
    IncludedPermissionSets = "BIFROST Mfg ori";
}
