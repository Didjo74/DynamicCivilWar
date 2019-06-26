/**
 * DYNAMIC CIVIL WAR
 * Created: 2017-11-29
 * Author: BIDASS
 * License : GNU (GPL)
 */

params ["_player"];

if (!RESPAWN_ENABLED)then {
	NUMBER_RESPAWN = 0;
	REMAINING_RESPAWN = 0;
};
 
[] spawn fnc_surrenderSystem;

RESPAWN_CHOICE = "";
REMAINING_RESPAWN = NUMBER_RESPAWN;

fnc_HandleRespawnBase = {
	params["_unit"];
	// Remove units around the player
	{ if (_unit distance _x < 120 && side _x == SIDE_ENEMY) then {_x setDamage 1;} } foreach allUnits;

	// Create a basic hidden marker on player's position (Used for blacklisting purposes)
	_pm = createMarker [format["player-marker-%1",name _unit], getPos _unit];
	_pm setMarkerShape "ELLIPSE";
	_pm setMarkerColor "ColorGreen";
	_pm setMarkerAlpha 0;
	_pm setMarkerSize [200,200];
	if (DEBUG) then {
		_pm setMarkerAlpha .3;
	};
	_unit setVariable["marker", _pm, true];

	//Default trait
	_unit setUnitTrait ["explosiveSpecialist",true];

	// Corrected player rating
	 if (rating _unit < 0) then {
		_unit addRating ((-(rating _unit)) + 1000);
	};

	//Squad leader specific
	sleep 2;


	if ((leader GROUP_PLAYERS) == _unit) then {
		RemoveAllActions _unit;
		_unit call fnc_ActionCamp;
		_unit call fnc_supportuiInit;
	};

	if (DEBUG) then {
		_unit call fnc_teleport;
	};

	// Initial score display
	[] call fnc_displayscore;

};

//Respawn handling
// Singleplayer
fnc_HandleRespawnSingleplayer =
{
	params["_unit"];

	_loadout = getUnitLoadout _unit;
	
	// Check the unit state before anything
	waitUntil{ lifestate _unit == "INCAPACITATED" };

	_unit allowDamage false;
	_unit setCaptive true;
	_unit setVariable["unit_injured",true,true] ;
	addCamShake [5,999,1.5];
	
	sleep 3;
	 
	// Create a basic hidden marker on player's position (Used for blacklisting purposes)
	/*deletemarker MARKER
	_pm = createMarker [format["player-marker-%1",random 1000], getPos _unit];
	_pm setMarkerShape "ELLIPSE";
	_pm setMarkerColor "ColorGreen";
	_pm setMarkerAlpha 0;
	_pm setMarkerSize [200,200];
	if (DEBUG) then {
		_pm setMArkerAlpha .3;
	};*/
	//_unit setVariable["marker", _pm, true];

	// Initial score display
	[] call fnc_displayscore;
	

	//count the remaining lives after death
	REMAINING_RESPAWN = REMAINING_RESPAWN - 1;
	if (REMAINING_RESPAWN == -1) exitWith { endMission "LOSER"; };

	DCW_ai_reviving_cancelled = false;
	_idA = [_unit, "Force respawn","\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_unbind_ca.paa", "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_unbind_ca.paa", "true", "true", {  }, { }, { DCW_ai_reviving_cancelled = true; }, {  }, [], 3, nil, true, true] call BIS_fnc_holdActionAdd;
	
	DCW_ai_current_medic = objNull;

	while {_unit getVariable["unit_injured",false] && !DCW_ai_reviving_cancelled} do {

		private _player = _unit;
		private _foundCloseUnit = objNull;
		private _dist = 999999;
		
		if (!isNull DCW_ai_current_medic && lifeState DCW_ai_current_medic != "HEALTHY" && lifeState DCW_ai_current_medic != "INJURED") exitWith {DCW_ai_current_medic = objNull;};

		{
			if(alive _x && (_x distance _player) < _dist && (lifeState _x == "HEALTHY" || lifeState _x == "INJURED")) then {
				_foundCloseUnit = _x;
				_dist = _x distance _player;
			};

		}foreach units GROUP_PLAYERS;

		// Check the status
		if (_dist == 999999 || isNull _foundCloseUnit) exitWith { DCW_ai_current_medic = objNull; };
		
		if (!isNull _foundCloseUnit && isNull DCW_ai_current_medic) then {
			_player setVariable ["healer", objNull, true];
			DCW_ai_current_medic = _foundCloseUnit;
			[_foundCloseUnit, _player,false] spawn fnc_firstAid;
		};
 
		hintSilent format["Medic at %1m",str round _dist];

		sleep .5;
	
	};

	hintSilent "";
	[ _unit,_idA ] call BIS_fnc_holdActionRemove;
	if ( !(_unit getVariable["unit_injured",true]) ) exitWith { };
	_unit setVariable["unit_injured",false,true];

	cutText ["Respawning...","BLACK OUT", 2];
	sleep 2;
	
	_timeSkipped = round(6 + random 12);
	cutText ["Respawning...","BLACK FADED", 999];
	sleep 2;
	cutText ["","BLACK FADED",  999];
	[] call fnc_respawndialog;
	waitUntil{ RESPAWN_CHOICE != "" };
	cutText [format["Back to %1...", RESPAWN_CHOICE], "BLACK FADED", 999];
	sleep 1;
	
	// Move the alive AI unit back to position
	private _respawnPos = if (RESPAWN_CHOICE == "base") then {START_POSITION} else {CAMP_RESPAWN_POSITION};
	RESPAWN_CHOICE = ""; // Reset
	

	if (!isMultiplayer) then {
		{ 
			if(!isPlayer _x && (leader GROUP_PLAYERS) == _unit) then{
				_x setPos ([_respawnPos, 0 ,10, 1, 0, 20, 0] call BIS_fnc_findSafePos);
				_x getVariable["DCW_marker_injured",""] setMarkerPos (getPos _x);
				if (ACE_ENABLED) then {
					[objNull, _x] call ace_medical_fnc_treatmentAdvanced_fullHealLocal;
				};
			}; 
		}foreach  units (group _unit);
	};

	sleep 1;


	//Disable chasing if not in multiplayer
	if (!isMultiplayer) then{
		CHASER_TRIGGERED = false;
		publicVariable "CHASER_TRIGGERED";
	}; 

    resetCamShake;
	_unit setPos _respawnPos;
	[_unit] call fnc_HandleRespawnBase;
	
	_unit setUnconscious false;
	_unit setDamage 0;

	if (ACE_ENABLED) then {
		[objNull, _unit] call ace_medical_fnc_treatmentAdvanced_fullHealLocal;
	};

	_unit setCaptive true;
	_unit setUnitLoadout _loadout;

	_unit switchMove "Acts_welcomeOnHUB01_PlayerWalk_6";

	//Black screen with timer...
	sleep 2;
	cutText ["","BLACK FADED", 999];
	
	BIS_DeathBlur ppEffectAdjust [0.0];
	BIS_DeathBlur ppEffectCommit 0;

	cutText ["","BLACK FADED", 999];
	
    if (!isMultiplayer) then {
		skipTime 6 + random 12;
	};
	
	sleep 5;
	[worldName, "Back to camp",format["%1 hours later...",_timeSkipped], format ["%1 live%2 left",REMAINING_RESPAWN,if (REMAINING_RESPAWN <= 1) then {""}else{"s"}]] call BIS_fnc_infoText;
	cutText ["","BLACK IN", 4];
	"dynamicBlur" ppEffectEnable true;   
	"dynamicBlur" ppEffectAdjust [6];   
	"dynamicBlur" ppEffectCommit 0;     
	"dynamicBlur" ppEffectAdjust [0.0];  
	"dynamicBlur" ppEffectCommit 5;  
	[] remoteExec ["PLAYER_KIA",2];
	
	sleep 5;
	_unit setVariable["unit_injured",false,true] ;
	_unit setCaptive false;
	_unit allowDamage true;
	GROUP_PLAYERS selectLeader _unit;
};



//Damage handler
if (RESPAWN_ENABLED) then{

	if (isMultiplayer) then {
		// Add tickets to the player
		if (NUMBER_RESPAWN != -1) then {
			[_player, NUMBER_RESPAWN, false] call BIS_fnc_respawnTickets;
		};
		REMAINING_RESPAWN = NUMBER_RESPAWN;

		[SIDE_FRIENDLY, getMarkerPos "marker_base","Base"] call BIS_fnc_addRespawnPosition;
		
		[_player] call fnc_HandleRespawnBase;

		_loadout = getUnitLoadout _player;
	     _player addMPEventHandler ["MPRespawn", {
			params ["_unit", "_corpse"];
			[_unit, [missionNamespace, "inventory_var"]] call BIS_fnc_loadInventory;
			_unit setVariable["marker", MARKER_PLAYER, true];
			if (NUMBER_RESPAWN != -1) then {
				REMAINING_RESPAWN = [_unit,nil,true] call BIS_fnc_respawnTickets;
				if (REMAINING_RESPAWN == -1)exitWith{  endMission "LOSER";  };
			};
			_player setUnitLoadout _loadout;
			[_unit] spawn fnc_HandleRespawnBase;
		}];

		_player addMPEventHandler ["MPKilled",{
			params ["_unit"	];
			[_unit, [missionNamespace, "inventory_var"]] call BIS_fnc_saveInventory;
			[] remoteExec ["PLAYER_KIA",2];
			// Delete the marker with a little delay
			[_unit] spawn {
				params["_unit"];
				sleep 10;
				_unit call fnc_deletemarker;
			};
		}];

	} else {
		
		// Disable team switching
		enableTeamSwitch false;

		// In Singleplayer
		[_player] call fnc_HandleRespawnBase;

		// Prevent ACE to do bullshit
		_player removeAllEventHandlers "HandleDamage";
		_player addEventHandler["HandleDamage",{
			params [
				"_unit",			// Object the event handler is assigned to.
				"_hitSelection",	// Name of the selection where the unit was damaged. "" for over-all structural damage, "?" for unknown selections.
				"_damage",			// Resulting level of damage for the selection.
				"_source",			// The source unit (shooter) that caused the damage.
				"_projectile",		// Classname of the projectile that caused inflicted the damage. ("" for unknown, such as falling damage.) (String)
				"_hitPartIndex",	// Hit part index of the hit point, -1 otherwise.
				"_instigator",		// Person who pulled the trigger. (Object)
				"_hitPoint"			// hit point Cfg name (String)
			];

			// Reducing damage with a factor of 3
			if (_damage >= .9 && lifeState _unit != "INCAPACITATED" )then{
				_unit setUnconscious true;
				_unit setVariable ["unit_injured",true,true];
				addCamShake [15, 6, 0.7];
				_damage = .9;
				_unit setDamage .9;
				[_unit] spawn fnc_HandleRespawnSinglePlayer;
				//_unit playActionNow "agonyStart";
			} else {
				if (lifeState _unit == "INCAPACITATED")then{
					_damage = .9;
					_unit setDamage .9;
				};
			};
			
			_damage;
		}];
	};
}else{
	// If nothing activated, just use the vanilla system
	_player addMPEventHandler ["MPKilled",{
		params ["_unit"];
		[] remoteExec ["PLAYER_KIA",2];
	}];
};

