#include <tier0/dbg.h>
#include <tier0/convar.h>
#include <entity2/entitysystem.h>
#include <steam/steam_gameserver.h>

#include "networkbasetypes.pb.h"

// Uses tier0, a protobuf message and the Steam API, so all of them link
extern "C" int s2sdk_manifests_test()
{
	CMsgVector vector;
	vector.set_x(1.0f);
	Msg("s2sdk-manifests test %f\n", vector.x());
	return SteamGameServer() != nullptr;
}
