#include <sourcemod>
#include <sdkhooks>
#include <smlib>

new String:weapons_all[][] = { "weapon_357", "weapon_crossbow", "weapon_pistol", 
				"weapon_rpg", "weapon_shotgun", "weapon_smg1", 
				"weapon_frag", "weapon_slam" };
new GlobalWeaponsID[64];
new GlobalWeaponCratesID[16];
new bool:PlayerIsRespawn[MAXPLAYERS + 1];
new bool:ChoosedWeaponsID[64];
new bool:ChoosedWeaponCratesID[16];
new Float:GlobalVectors[64][2][3];
new Float:GlobalVectorsCrate[16][2][3];
new Handle:RespawnWeaponTimer;
new GetPlayerSlamID[MAXPLAYERS + 1];
new weapons_all_length = sizeof(weapons_all);
new GetPlayerSlamID_length = sizeof(GetPlayerSlamID);
new GlobalVectors_length = sizeof(GlobalVectors);
new GlobalVectorsCrate_length = sizeof(GlobalVectorsCrate);
new GlobalWeaponsID_length = sizeof(GlobalWeaponsID);
new GlobalWeaponCratesID_length = sizeof(GlobalWeaponCratesID);

public Plugin:myinfo =
{
	name = "[FoF] HL2DM",
	author = "",
	description = "Half-Life 2 Deathmatch for Fistful of Frags",
	version = "1.0.0",
	url = ""
};

public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	new count = 1;
	while (count < GetPlayerSlamID_length)
	{
		GetPlayerSlamID[count] = -1;
		PlayerIsRespawn[count] = false;
		++count;
	}
}

public OnMapStart()
{
	AddFileToDownloadsTable("custom/fof_hl2dm.vpk");
}

public OnGameFrame()
{
        ServerCommand("fof_sv_bot_slotpct 0.000000");
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
}

public Event_RoundStart(Event:event, const String:name[], bool:dontBroadcast)
{
	new whiskey  = INVALID_ENT_REFERENCE;
	new created = INVALID_ENT_REFERENCE;
	new crate = INVALID_ENT_REFERENCE;
	new Float:origin[3], Float:angles[3];
	new count = 0;
	while((whiskey = FindEntityByClassname(whiskey, "item_whiskey")) != INVALID_ENT_REFERENCE)
	{
		Entity_GetAbsOrigin(whiskey, origin);
		Entity_GetAbsAngles(whiskey, angles);
		Entity_Kill(whiskey);
		created = Weapon_Create(weapons_all[GetRandomInt(0, weapons_all_length - 1)], origin, angles);
		SetEntProp(created, Prop_Send, "m_CollisionGroup", 1);
		SetEntityMoveType(created, MOVETYPE_NONE);
		GlobalVectors[count][0] = origin;
		GlobalVectors[count][1] = angles;
		GlobalWeaponsID[count] = created;
		ChoosedWeaponsID[count] = false;
		++count;
	}
	count = 0;
	while((crate = FindEntityByClassname(crate, "fof_crate*")) != INVALID_ENT_REFERENCE)
	{
		Entity_GetAbsOrigin(crate, origin);
		Entity_GetAbsAngles(crate, angles);
		Entity_Kill(crate);
		created = Weapon_Create("item_whiskey", origin, angles);
		SetEntProp(created, Prop_Send, "m_CollisionGroup", 1);
		SetEntityMoveType(created, MOVETYPE_NONE);
		GlobalVectorsCrate[count][0] = origin;
		GlobalVectorsCrate[count][1] = angles;
		GlobalWeaponCratesID[count] = created;
		ChoosedWeaponCratesID[count] = false;
		++count;
	}
	RespawnWeaponTimer = CreateTimer(20.0, RespawnWeapon, _, TIMER_REPEAT);
}

public Event_RoundEnd(Event:event, const String:name[], bool:dontBroadcast)
{
	if (RespawnWeaponTimer != INVALID_HANDLE)
	{
		KillTimer(RespawnWeaponTimer);
		RespawnWeaponTimer = INVALID_HANDLE;
	}
}

public Event_PlayerSpawn(Event:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, GiveEquipment, client, TIMER_FLAG_NO_MAPCHANGE);

}
public Event_PlayerDeath(Event:event, const String:name[], bool:dontBroadcast)
{
	if (GetRandomInt(1, 10) > 5)
	{
		new Float:origin[3], Float:angles[3];
		new created = INVALID_ENT_REFERENCE;
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		Entity_GetAbsOrigin(client, origin);
		Entity_GetAbsAngles(client, angles);
		created = Weapon_Create("item_whiskey", origin, angles);
		SetEntProp(created, Prop_Send, "m_CollisionGroup", 1);
		SetEntityMoveType(created, MOVETYPE_VPHYSICS);
	}
}

public OnWeaponSwitchPost(client, weapon)
{
	new bool:isValidWpn = false;
	new String:szWpn[64];
	new count = 0;
	GetClientWeapon(client, szWpn, sizeof(szWpn));
	while (count < weapons_all_length)
	{
		if (StrEqual(szWpn, weapons_all[count]))
		{
			isValidWpn = true;
			break;
		}
		++count;
	}
	if(!isValidWpn)
	{
		if (StrEqual(szWpn, "weapon_fists") || StrEqual(szWpn, "weapon_fists_brass") ||
			 StrEqual(szWpn, "weapon_physcannon") || StrEqual(szWpn, "weapon_crowbar") ||
			 StrEqual(szWpn, "weapon_stunstick"))
			isValidWpn = true;
		else
		{
			RemovePlayerItem(client, weapon);
			ClientCommand(client, "use weapon_fists");
		}
	}
	if(StrEqual(szWpn, "weapon_slam") && GetPlayerSlamID[client] != weapon)
	{
		GetPlayerSlamID[client] = weapon;
		GivePlayerItem(client, "weapon_dynamite_belt");
		GivePlayerItem(client, "weapon_dynamite_belt");
	}
}

public OnWeaponEquip(client, weapon)
{
	if(PlayerIsRespawn[client])
	{
		PlayerIsRespawn[client] = false;
		return;
	}
	new count = 0;
	SetEntityMoveType(weapon, MOVETYPE_VPHYSICS);
	while (count < GlobalWeaponsID_length)
	{
		if (weapon == GlobalWeaponsID[count])
		{
			ChoosedWeaponsID[count] = true;
			break;
		}
		else if(count < GlobalWeaponCratesID_length && weapon == GlobalWeaponCratesID[count])
		{
			ChoosedWeaponCratesID[count] = true;
			break;
		}
		++count;
	}
}

public Action:RespawnWeapon(Handle:timer)
{
	new Float:origin[3], Float:angles[3];
	new created = INVALID_ENT_REFERENCE;
	new ent = 0;
	while (ent < GlobalVectors_length)
	{
		if (GlobalVectors[ent][0][0] == 0.0 && GlobalVectors[ent][0][1] == 0.0 && GlobalVectors[ent][0][2] == 0.0 &&
			GlobalVectors[ent][1][0] == 0.0 && GlobalVectors[ent][1][1] == 0.0 && GlobalVectors[ent][1][2] == 0.0)
			break;
		else if (ChoosedWeaponsID[ent] == true)
		{
			origin = GlobalVectors[ent][0];
			angles = GlobalVectors[ent][1];
			created = Weapon_Create(weapons_all[GetRandomInt(0, weapons_all_length - 1)], origin, angles);
			SetEntProp(created, Prop_Send, "m_CollisionGroup", 1);
			SetEntityMoveType(created, MOVETYPE_NONE);
			GlobalWeaponsID[ent] = created;
			ChoosedWeaponsID[ent] = false;
		}
		if(ent < GlobalVectorsCrate_length)
		{
			if (GlobalVectorsCrate[ent][0][0] == 0.0 && GlobalVectorsCrate[ent][0][1] == 0.0 && GlobalVectorsCrate[ent][0][2] == 0.0 && 
				GlobalVectorsCrate[ent][1][0] == 0.0 && GlobalVectorsCrate[ent][1][1] == 0.0 && GlobalVectorsCrate[ent][1][2] == 0.0)
			{
				++ent;
				continue;
			}
			else if (ChoosedWeaponCratesID[ent] == true)
			{
				origin = GlobalVectorsCrate[ent][0];
				angles = GlobalVectorsCrate[ent][1];
				created = Weapon_Create("item_whiskey", origin, angles);
				SetEntProp(created, Prop_Send, "m_CollisionGroup", 1);
				SetEntityMoveType(created, MOVETYPE_NONE);
				GlobalWeaponCratesID[ent] = created;
				ChoosedWeaponCratesID[ent] = false;
			}
		}
		++ent;
	}
}

public Action:GiveEquipment(Handle:timer, any:client)
{
	PlayerIsRespawn[client] = true;
	GivePlayerItem(client, "weapon_physcannon");
	if (GetRandomInt(1, 10) > 5)
		GivePlayerItem(client, "weapon_stunstick");
	else
		GivePlayerItem(client, "weapon_crowbar");
	ClientCommand(client, "use weapon_physcannon");
}
