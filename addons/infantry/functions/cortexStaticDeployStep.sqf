/*
 * Author: WaldoTheWarfighter
 * Purpose: Physically assemble one compatible carried static weapon during confirmed contact and give its original carrier a finite chance to occupy the real gunner seat.
 * Locality / Authority: Runs only on the current group owner from the shared group brain. It uses native backpack assembly and boarding actions on local AI actors; it never creates, teleports, rearms, repairs or force-seats a weapon.
 * Repeat/JIP: One contact-episode record owns the exact pair, expected assembled class, position and resulting weapon. Each group-brain call advances at most one finite phase. Locality, Zeus, specialist or newer operation ownership retires WAIT markers without issuing cleanup commands over the new owner. Failed deployment is not retried during the same contact episode.
 * Arguments: 0 group <GROUP>; 1 group state <HASHMAP>; 2 known enemies <ARRAY>.
 * Return Value: STRING - DISABLED, IDLE, MOVING, ASSEMBLING, MOUNTING, ACTIVE, FAILED or YIELDED.
 * Current callers: WAIT_fnc_CortexStaticSupport when no suitable existing emplacement is available.
 * Example: [group player,[group player] call WAIT_fnc_CortexGroupState,[]] call WAIT_fnc_CortexStaticDeployStep;
 */

params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_enemies",[],[[]]]];
if (isNull _group || {!local _group}) exitWith {"YIELDED"};
private _record=_group getVariable ["WAIT_Danger_StaticDeployment",[]];
private _external=[_group] call WAIT_fnc_CortexExternalTakeover;
private _clearActor={
    params ["_actor"];
    if (!isNull _actor && {local _actor}) then {
        private _move=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
        if ((_move param [0,""]) == "STATIC_DEPLOY") then {_actor setVariable ["WAIT_Cortex_ActorMove",nil]};
    };
};
private _retire={
    params ["_commandFree"];
    if (count _record >= 10) then {
        private _gunner=_record param [2,objNull,[objNull]];
        private _assistant=_record param [3,objNull,[objNull]];
        [_gunner] call _clearActor;
        [_assistant] call _clearActor;
        if (!_commandFree) then {
            private _weapon=_record param [7,objNull,[objNull]];
            if (!isNull _gunner && {local _gunner} && {!isNull _weapon}
                && {assignedVehicle _gunner == _weapon}) then {
                [_gunner] orderGetIn false;
                unassignVehicle _gunner;
                if (vehicle _gunner == _weapon) then {_gunner action ["GetOut",_weapon]};
            };
            {if (!isNull _x && {alive _x} && {local _x} && {group _x == _group}
                && {currentCommand _x in ["","MOVE","STOP","ASSEMBLE"]}) then {
                _x doFollow (leader _group);
            }} forEach [_gunner,_assistant];
        };
    };
    _group setVariable ["WAIT_Danger_StaticDeployment",nil,true];
};

private _enabled=missionNamespace getVariable ["WAIT_AIPass_Active",false]
    && {[_group,"WAIT_AIPass_StaticSupport_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
    && {[_group,"WAIT_AIPass_StaticDeploy_Enable",true] call WAIT_fnc_CortexFeatureEnabled};
private _phase=toUpperANSI (_state getOrDefault ["phase","CALM"]);
private _episode=_state getOrDefault ["phaseStart",time];
if (!_enabled || {_phase != "CONTACT"} || {_enemies isEqualTo []} || {_external}
    || {combatMode _group in ["BLUE","GREEN"]}) exitWith {
    if (count _record >= 10) then {[_external] call _retire};
    ["IDLE","YIELDED"] select _external
};

if (count _record >= 10) exitWith {
    _record params ["_recordEpisode","_status","_gunner","_assistant","_expectedClass","_deployPos","_deadline","_weapon","_gunnerBag","_assistantBag"];
    if (_recordEpisode != _episode || {isNull _gunner} || {isNull _assistant}
        || {!alive _gunner} || {!alive _assistant} || {!local _gunner} || {!local _assistant}
        || {group _gunner != _group} || {group _assistant != _group} || {isPlayer _gunner}
        || {isPlayer _assistant} || {count (_group getVariable ["WAIT_Operation",createHashMap]) > 0}) exitWith {
        [false] call _retire;
        _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"FAILED",serverTime],true];
        "FAILED"
    };
    if (_status == "MOVING") exitWith {
        if (time >= _deadline) then {
            [false] call _retire;
            _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"FAILED",serverTime],true];
            "FAILED"
        } else {
            if (_gunner distance2D _deployPos <= 3.5 && {_assistant distance2D _deployPos <= 3.5}) then {
                _gunner action ["PutBag",_assistant];
                _gunner action ["Assemble",unitBackpack _assistant];
                _record set [1,"ASSEMBLING"];
                _record set [6,time+12];
                _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
                "ASSEMBLING"
            } else {"MOVING"}
        }
    };
    if (_status == "ASSEMBLING") exitWith {
        private _matches=nearestObjects [_deployPos,[_expectedClass],8,true];
        private _assembled=_matches param [0,objNull,[objNull]];
        if (!isNull _assembled && {alive _assembled} && {simulationEnabled _assembled}) then {
            _gunner assignAsGunner _assembled;
            [_gunner] orderGetIn true;
            _gunner setVariable ["WAIT_Cortex_ActorMove",["STATIC_DEPLOY",getPosATL _assembled,time+20]];
            [_assistant] call _clearActor;
            _record set [1,"MOUNTING"];
            _record set [6,time+20];
            _record set [7,_assembled];
            _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
            "MOUNTING"
        } else {
            if (time >= _deadline) then {
                [false] call _retire;
                _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"FAILED",serverTime],true];
                "FAILED"
            } else {"ASSEMBLING"}
        }
    };
    if (_status == "MOUNTING") exitWith {
        if (!isNull _weapon && {alive _weapon} && {vehicle _gunner == _weapon} && {gunner _weapon == _gunner}) then {
            [_gunner] call _clearActor;
            _record set [1,"ACTIVE"];
            _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
            _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"ACTIVE",serverTime],true];
            "ACTIVE"
        } else {
            if (time >= _deadline || {isNull _weapon} || {!alive _weapon}) then {
                [false] call _retire;
                _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"FAILED",serverTime],true];
                "FAILED"
            } else {"MOUNTING"}
        }
    };
    if (_status == "ACTIVE") exitWith {
        if (isNull _weapon || {!alive _weapon} || {gunner _weapon != _gunner}) then {
            [false] call _retire;
            "FAILED"
        } else {"ACTIVE"}
    };
    "FAILED"
};

private _attempt=_group getVariable ["WAIT_Danger_StaticDeployAttempt",[]];
if ((_attempt param [0,-1,[0]]) == _episode) exitWith {_attempt param [1,"IDLE",[""]]};
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0) exitWith {"IDLE"};
private _ready=(units _group) select {
    alive _x && {local _x} && {!isPlayer _x} && {vehicle _x == _x}
        && {[_x] call WAIT_fnc_CortexCombatEffective}
        && {isNull assignedVehicle _x} && {currentCommand _x in ["","STOP","MOVE","ATTACK","FIRE","SUPPRESS"]}
        && {(_x getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
};
private _gunnerIndex=_ready findIf {
    private _bag=backpack _x;
    _bag != "" && {getNumber (configFile >> "CfgVehicles" >> _bag >> "assembleInfo" >> "primary") == 1}
        && {getText (configFile >> "CfgVehicles" >> _bag >> "assembleInfo" >> "assembleTo") != ""}
};
if (_gunnerIndex < 0) exitWith {
    _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"NO_PRIMARY_BAG",serverTime],true];
    "IDLE"
};
private _gunner=_ready deleteAt _gunnerIndex;
private _gunnerBag=backpack _gunner;
private _assembleInfo=configFile >> "CfgVehicles" >> _gunnerBag >> "assembleInfo";
private _expectedClass=getText (_assembleInfo >> "assembleTo");
private _baseConfig=_assembleInfo >> "base";
private _compatibleBases=if (isText _baseConfig) then {[getText _baseConfig]} else {getArray _baseConfig};
_compatibleBases=_compatibleBases - [""];
private _assistantIndex=_ready findIf {(backpack _x) in _compatibleBases};
if (_assistantIndex < 0) exitWith {
    _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"NO_BASE_BAG",serverTime],true];
    "IDLE"
};
private _assistant=_ready select _assistantIndex;
private _assistantBag=backpack _assistant;
private _targetPos=+((_enemies select 0) param [1,[],[[]]]);
if (count _targetPos < 2) exitWith {"IDLE"};
if (count _targetPos == 2) then {_targetPos pushBack 0};
private _origin=getPosATL _gunner;
private _bearing=_origin getDir _targetPos;
private _candidateA=_origin getPos [6,_bearing-90];
private _candidateB=_origin getPos [6,_bearing+90];
private _candidates=[_candidateA,_candidateB] select {
    !surfaceIsWater _x && {(surfaceNormal _x) select 2 >= 0.92}
        && {lineIntersectsSurfaces [AGLToASL (_x vectorAdd [0,0,1.2]),AGLToASL (_targetPos vectorAdd [0,0,1.2]),objNull,objNull,true,1,"GEOM","NONE"] isEqualTo []}
};
if (_candidates isEqualTo []) exitWith {
    _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"NO_SAFE_SECTOR",serverTime],true];
    "IDLE"
};
private _deployPos=_candidates select 0;
private _deadline=time+18;
{
    _x doMove _deployPos;
    _x setVariable ["WAIT_Cortex_ActorMove",["STATIC_DEPLOY",+_deployPos,_deadline]];
} forEach [_gunner,_assistant];
_record=[_episode,"MOVING",_gunner,_assistant,_expectedClass,+_deployPos,_deadline,objNull,_gunnerBag,_assistantBag];
_group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
_group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"MOVING",serverTime],true];
"MOVING"

