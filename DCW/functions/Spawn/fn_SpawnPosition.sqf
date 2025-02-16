/*
  Author: 
    Bidass

  Version:
    {VERSION}

  Description:
    TODO

  Parameters:
    0: OBJECT - TODO

  Returns:
    BOOL - true 
*/

//list buildings
params["_pos","_radius"];

//list buildings
_positions = [];

//list buildings
private _buildings = nearestObjects [_pos, ["house"], _radius*1.3];
{
    if ([_x, 2] call BIS_fnc_isBuildingEnterable) then {
        _posBuilding = [_x] call BIS_fnc_buildingPositions;
        for "_uc" from 0 to 1 do {
             _rndpos = ([_posBuilding] call BIS_fnc_selectRandom) select 0;
            _posBuilding = _posBuilding - [_rndpos];
            _positions pushback _rndpos;
        };
    };
} foreach _buildings;

[_positions,_buildings];
