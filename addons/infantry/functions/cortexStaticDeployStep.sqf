/*
 * Author: WaldoTheWarfighter
 * Purpose: Physically assemble one compatible carried static weapon during confirmed contact and give its original carrier a finite chance to occupy the real gunner seat.
 * Locality / Authority: Runs only on the current group owner from the shared group brain. It uses native backpack assembly and boarding actions on local AI actors; it never creates, teleports, rearms, repairs or force-seats a weapon.
 * A ready pair may deploy at its actual safe firing position instead of waiting for both actors to converge on one exact point.
 * Other squad members may manoeuvre beside an existing deployment; overlapping participants or withdrawal preempt it.
 * Repeat/JIP: One contact-episode record owns the exact pair, expected assembled class, position and resulting weapon. Each group-brain call advances at most one finite phase. Locality, Zeus, specialist or newer operation ownership retires WAIT markers without issuing cleanup commands over the new owner. Failed deployment is not retried during the same contact episode.
 * Arguments: 0 group <GROUP>; 1 group state <HASHMAP>; 2 known enemies <ARRAY>; 3 allow post-contact packing <BOOL, default false>.
 * Return Value: STRING - DISABLED, IDLE, MOVING, DROPPING, ASSEMBLING, MOUNTING, ACTIVE, PACK_MOVING, PACKING, TAKING, PACKED, FAILED or YIELDED.
 * Current callers: WAIT_fnc_CortexStaticSupport when no suitable existing emplacement is available, and WAIT_fnc_CortexGroupTick during SECURITY for finite recovery.
 * Example: [group player,[group player] call WAIT_fnc_CortexGroupState,[]] call WAIT_fnc_CortexStaticDeployStep;
 */

params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_enemies",[],[[]]],["_allowPack",false,[false]]];
if (isNull _group || {!local _group}) exitWith {"YIELDED"};
private _record=_group getVariable ["WAIT_Danger_StaticDeployment",[]];
private _external=[_group] call WAIT_fnc_CortexExternalTakeover;
private _operation=_group getVariable ["WAIT_Operation",createHashMap];
private _operationActors=_operation getOrDefault ["participants",[]];
private _clearActor={
    params ["_actor"];
    if (!isNull _actor && {local _actor}) then {
        private _move=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
        if ((_move param [0,""]) in ["STATIC_DEPLOY","STATIC_PACK"]) then {_actor setVariable ["WAIT_Cortex_ActorMove",nil]};
    };
};
private _retire={
    params ["_commandFree"];
    // A successor operation may own only some actors. Retire bookkeeping, but restore
    // assignments/formation only for actors not claimed by that operation or an external owner.
    _commandFree=_commandFree || {[_group] call WAIT_fnc_CortexExternalTakeover}
        || {[_record param [2,objNull,[objNull]]] call WAIT_fnc_CompatibilityExternalControl}
        || {[_record param [3,objNull,[objNull]]] call WAIT_fnc_CompatibilityExternalControl};
    if (count _record >= 10) then {
        private _gunner=_record param [2,objNull,[objNull]];
        private _assistant=_record param [3,objNull,[objNull]];
        private _destination=_record param [5,[],[[]]];
        private _actors=[_gunner,_assistant] apply {
            if (isNull _x) then {[]} else {
                [netId _x,getPosATL _x,currentCommand _x,
                    if (count _destination >= 2) then {_x distance2D _destination} else {-1},
                    backpack _x,vehicle _x]
            }
        };
        _group setVariable ["WAIT_Danger_StaticDeployEnd",[serverTime,clientOwner,
            _group getVariable ["WAIT_AIPass_Epoch",0],_record select 0,_record select 1,
            _record select 6,+_destination,_actors,_commandFree]];
        private _handler=_record param [10,-1,[0]];
        if (!isNull _gunner && {local _gunner}) then {
            if (_handler >= 0) then {_gunner removeEventHandler ["WeaponDisassembled",_handler]};
            private _assemblyHandler=_record param [12,-1,[0]];
            if (_assemblyHandler >= 0) then {_gunner removeEventHandler ["WeaponAssembled",_assemblyHandler]};
            _gunner setVariable ["WAIT_Danger_StaticPackContext",nil];
        };
        [_gunner] call _clearActor;
        [_assistant] call _clearActor;
        if (!_commandFree) then {
            private _weapon=_record param [7,objNull,[objNull]];
            if (!isNull _gunner && {local _gunner} && {!isNull _weapon}
                && {assignedVehicle _gunner == _weapon} && {!(_gunner in _operationActors)}) then {
                [_gunner] orderGetIn false;
                unassignVehicle _gunner;
                if (vehicle _gunner == _weapon) then {_gunner action ["GetOut",_weapon]};
            };
            {if (!isNull _x && {alive _x} && {local _x} && {group _x == _group}
                && {!(_x in _operationActors)}
                && {currentCommand _x in ["","MOVE","STOP","ASSEMBLE","DISASSEMBLE"]}) then {
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
if (_external) exitWith {if (count _record >= 10) then {[true] call _retire}; "YIELDED"};
if (!_enabled || {combatMode _group in ["BLUE","GREEN"]}) exitWith {
    if (count _record >= 10) then {[false] call _retire};
    "IDLE"
};

if (count _record >= 10) exitWith {
    _record params ["_recordEpisode","_status","_gunner","_assistant","_expectedClass","_deployPos","_deadline","_weapon","_gunnerBag","_assistantBag"];
    private _handler=_record param [10,-1,[0]];
    private _reservedActors=if (_status in ["ASSEMBLING","MOUNTING","ACTIVE"]) then {[_gunner]} else {[_gunner,_assistant]};
    private _operationConflict=count _operation > 0 && {
        (_operation getOrDefault ["intent",""]) in ["WITHDRAW","VEHICLE_WITHDRAW"]
            || {_reservedActors findIf {_x in _operationActors} >= 0}
    };
    if (_operationConflict) exitWith {
        [false] call _retire;
        _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"YIELDED",serverTime],true];
        "YIELDED"
    };
    if ([_gunner] call WAIT_fnc_CompatibilityExternalControl
        || {[_assistant] call WAIT_fnc_CompatibilityExternalControl}) exitWith {
        [true] call _retire;
        "YIELDED"
    };
    if (_phase == "CONTACT" && {_status == "PACK_MOVING"}
        && {!isNull _gunner} && {alive _gunner} && {local _gunner}
        && {!isNull _assistant} && {alive _assistant} && {local _assistant}
        && {!isNull _weapon} && {alive _weapon}) then {
        [_gunner] call _clearActor;
        [_assistant] call _clearActor;
        _gunner assignAsGunner _weapon;
        [_gunner] orderGetIn true;
        _gunner setVariable ["WAIT_Cortex_ActorMove",["STATIC_DEPLOY",getPosATL _weapon,time+20]];
        _record set [1,"MOUNTING"];
        _record set [0,_episode];
        _record set [6,time+20];
        _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
        _recordEpisode=_episode;
        _status="MOUNTING";
        _deadline=time+20;
    };
    if (_phase == "SECURITY" && {_allowPack} && {_status == "ACTIVE"}
        && {!isNull _gunner} && {alive _gunner} && {local _gunner}
        && {!isNull _assistant} && {alive _assistant} && {local _assistant}
        && {!isNull _weapon} && {alive _weapon}
        && {gunner _weapon == _gunner || {crew _weapon isEqualTo [] && {vehicle _gunner == _gunner}}}
        && {count (_group getVariable ["WAIT_Operation",createHashMap]) == 0}) then {
        [_gunner] orderGetIn false;
        unassignVehicle _gunner;
        if (vehicle _gunner == _weapon) then {_gunner action ["GetOut",_weapon]};
        {
            _x doMove (getPosATL _weapon);
            _x setVariable ["WAIT_Cortex_ActorMove",["STATIC_PACK",getPosATL _weapon,time+15]];
        } forEach [_gunner,_assistant];
        _record set [1,"PACK_MOVING"];
        _record set [6,time+15];
        _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
        _status="PACK_MOVING";
        _deadline=time+15;
    };
    if (_phase != "CONTACT" && {!(_phase == "SECURITY" && {_allowPack})}) exitWith {
        [false] call _retire;
        "IDLE"
    };
    if (isNull _gunner || {isNull _assistant}
        || {!alive _gunner} || {!alive _assistant} || {!local _gunner} || {!local _assistant}
        || {group _gunner != _group} || {group _assistant != _group} || {isPlayer _gunner}
        || {isPlayer _assistant} || {_operationConflict}
        || {_phase == "CONTACT" && {_recordEpisode != _episode}
            && {_status in ["MOVING","DROPPING","ASSEMBLING","MOUNTING","ACTIVE"]}}) exitWith {
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
            private _pairTogether=_gunner distance _assistant <= 3;
            private _atSector=_gunner distance2D _deployPos <= 3.5
                && {_assistant distance2D _deployPos <= 3.5};
            // Native combat movement can stop a ready pair short of the requested point.
            // Accept their actual position only when it still provides the same safe firing sector.
            // This is physical arrival, not a timer-based assembly or a forced transform.
            if (!_atSector && {_pairTogether} && {vehicle _gunner == _gunner}
                && {vehicle _assistant == _assistant}) then {
                private _actual=getPosATL _gunner;
                private _sector=_record param [11,[],[[]]];
                if (count _sector >= 3 && {!surfaceIsWater _actual}
                    && {(surfaceNormal _actual) select 2 >= 0.92}
                    && {lineIntersectsSurfaces [eyePos _gunner,
                        AGLToASL (_sector vectorAdd [0,0,1.2]),_gunner,_assistant,true,1,"GEOM","NONE"] isEqualTo []}) then {
                    _deployPos=_actual;
                    _record set [5,+_actual];
                    _atSector=true;
                };
            };
            if (_atSector && {_pairTogether}) then {

                private _assemblyHandler=_gunner addEventHandler ["WeaponAssembled",{
                    params ["_actor","_assembled"];
                    private _owner=group _actor;
                    private _current=_owner getVariable ["WAIT_Danger_StaticDeployment",[]];
                    if (local _actor && {local _owner} && {local _assembled}
                        && {count _current >= 13} && {(_current select 12) == _thisEventHandler}
                        && {(_current select 1) == "ASSEMBLING"}
                        && {(_current select 2) == _actor} && {typeOf _assembled == (_current select 4)}
                        && {crew _assembled isEqualTo []}
                        && {!([_owner] call WAIT_fnc_CortexExternalTakeover)}
                        && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}) then {
                        private _sector=_current param [11,[],[[]]];
                        if (count _sector >= 2) then {_assembled setDir (_assembled getDir _sector)};
                    };
                    _actor removeEventHandler ["WeaponAssembled",_thisEventHandler];
                    if (count _current >= 13 && {(_current select 12) == _thisEventHandler}) then {
                        _current set [12,-1];
                        _owner setVariable ["WAIT_Danger_StaticDeployment",_current,true];
                    };
                }];
                _record set [12,_assemblyHandler];
                // Keep the exact support bag before native dropping changes unitBackpack.
                _record set [13,unitBackpack _assistant];
                // Native dropping may replace the attached bag object with ground cargo. Snapshot
                // nearby existing bags so continuation cannot adopt someone else's identical kit.
                private _existingBags=nearestObjects [getPosATL _assistant,[_assistantBag],5,true];
                {
                    _existingBags append ((everyBackpack _x) select [0,4]);
                } forEach ((nearestObjects [getPosATL _assistant,["GroundWeaponHolder","WeaponHolderSimulated"],5,true]) select [0,12]);
                _record set [14,_existingBags];
                _record set [15,getPosATL _assistant];
                _record set [1,"DROPPING"];
                _record set [6,time+8];
                {
                    _x setVariable ["WAIT_Cortex_ActorMove",["STATIC_DEPLOY",+_deployPos,_record select 6]];
                } forEach [_gunner,_assistant];
                _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
                _gunner action ["PutBag",_assistant];
                "DROPPING"
            } else {"MOVING"}
        }
    };
    if (_status == "DROPPING") exitWith {
        private _supportBag=_record param [13,objNull,[objNull]];
        if (isNull unitBackpack _assistant && {isNull _supportBag || {_gunner distance _supportBag > 3.5}}) then {
            private _dropPosition=_record param [15,_deployPos,[[]]];
            private _existingBags=_record param [14,[],[[]]];
            private _dropped=nearestObjects [_dropPosition,[_assistantBag],5,true];
            {
                _dropped append ((everyBackpack _x) select [0,4]);
            } forEach ((nearestObjects [_dropPosition,["GroundWeaponHolder","WeaponHolderSimulated"],5,true]) select [0,12]);
            private _bagIndex=_dropped findIf {
                typeOf _x == _assistantBag && {!(_x in _existingBags)} && {_gunner distance _x <= 3.5}
            };
            if (_bagIndex >= 0) then {
                _supportBag=_dropped select _bagIndex;
                _record set [13,_supportBag];
                _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
            };
        };
        // Observe completed physical work before its deadline: a delayed scheduler callback must
        // not turn a bag already on the ground into a failed drop solely because time has advanced.
        if (isNull unitBackpack _assistant && {!isNull _supportBag} && {_gunner distance _supportBag <= 3.5}
            && {backpack _gunner == _gunnerBag}) then {
            // The assistant's physical contribution is complete once its exact bag is down.
            // Keep only the gunner reserved; ordinary native fire and movement may resume for support.
            [_assistant] call _clearActor;
            _record set [1,"ASSEMBLING"];
            _record set [6,time+12];
            _gunner setVariable ["WAIT_Cortex_ActorMove",["STATIC_DEPLOY",+_deployPos,_record select 6]];
            _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
            _gunner action ["Assemble",_supportBag];
            "ASSEMBLING"
        } else {
            if (time >= _deadline) then {
                [false] call _retire;
                _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"FAILED",serverTime],true];
                "FAILED"
            } else {"DROPPING"}
        }
    };
    if (_status == "ASSEMBLING") exitWith {
        private _matches=nearestObjects [_deployPos,[_expectedClass],8,true];
        private _assembled=_matches param [0,objNull,[objNull]];
        if (!isNull _assembled && {alive _assembled} && {simulationEnabled _assembled} && {local _assembled}
            && {crew _assembled isEqualTo [] || {gunner _assembled == _gunner && {crew _assembled findIf {_x != _gunner} < 0}}}) then {
            // Orient the newly assembled empty emplacement once, before boarding. Native turret aiming
            // cannot compensate for a base facing outside its traverse arc. Never rotate an occupied weapon.
            private _sector=_record param [11,[],[[]]];
            if (count _sector >= 2 && {crew _assembled isEqualTo []}) then {_assembled setDir (_assembled getDir _sector)};
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
    if (_status == "PACK_MOVING") exitWith {
        if (time >= _deadline || {isNull _weapon} || {!alive _weapon}) then {
            [false] call _retire;
            "FAILED"
        } else {
            if (vehicle _gunner == _gunner && {_gunner distance2D _weapon <= 4} && {_assistant distance2D _weapon <= 4}) then {
                _gunner setVariable ["WAIT_Danger_StaticPackContext",[_group,_recordEpisode,_assistant,_gunnerBag,_assistantBag]];
                _handler=_gunner addEventHandler ["WeaponDisassembled",{
                    params ["_actor","_primaryBag","_baseBag"];
                    private _context=_actor getVariable ["WAIT_Danger_StaticPackContext",[]];
                    _context params [["_owner",grpNull,[grpNull]],["_recordEpisode",-1,[0]],["_assistant",objNull,[objNull]],["_primaryClass","",[""]],["_baseClass","",[""]]];
                    private _current=if (isNull _owner) then {[]} else {_owner getVariable ["WAIT_Danger_StaticDeployment",[]]};
                    if (local _actor && {local _owner} && {!isNull _assistant} && {local _assistant}
                        && {alive _actor} && {alive _assistant} && {!([_owner] call WAIT_fnc_CortexExternalTakeover)}
                        && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
                        && {!([_assistant] call WAIT_fnc_CompatibilityExternalControl)}
                        && {count _current >= 11} && {(_current select 0) == _recordEpisode}
                        && {(_current select 1) == "PACKING"} && {(_current select 2) == _actor}
                        && {(_current select 3) == _assistant}
                        && {typeOf _primaryBag == _primaryClass} && {typeOf _baseBag == _baseClass}) then {
                        _actor action ["TakeBag",_primaryBag];
                        _assistant action ["TakeBag",_baseBag];
                        _current set [1,"TAKING"];
                        _current set [6,time+8];
                        _current set [7,objNull];
                        _current set [10,-1];
                        _owner setVariable ["WAIT_Danger_StaticDeployment",_current,true];
                    };
                    _actor setVariable ["WAIT_Danger_StaticPackContext",nil];
                    _actor removeEventHandler ["WeaponDisassembled",_thisEventHandler];
                }];
                _record set [1,"PACKING"];
                _record set [6,time+10];
                _record set [10,_handler];
                _group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
                _gunner action ["Disassemble",_weapon];
                "PACKING"
            } else {"PACK_MOVING"}
        }
    };
    if (_status == "PACKING") exitWith {
        if (time >= _deadline) then {
            [false] call _retire;
            "FAILED"
        } else {"PACKING"}
    };
    if (_status == "TAKING") exitWith {
        if (backpack _gunner == _gunnerBag && {backpack _assistant == _assistantBag}) then {
            [false] call _retire;
            _group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"PACKED",serverTime],true];
            "PACKED"
        } else {
            if (time >= _deadline) then {[false] call _retire; "FAILED"} else {"TAKING"}
        }
    };
    "FAILED"
};

if (_phase != "CONTACT" || {_enemies isEqualTo []}) exitWith {"IDLE"};

private _attempt=_group getVariable ["WAIT_Danger_StaticDeployAttempt",[]];
if ((_attempt param [0,-1,[0]]) == _episode
    && {(_attempt param [1,"IDLE",[""]]) != "YIELDED"}) exitWith {_attempt param [1,"IDLE",[""]]};
if (count (_group getVariable ["WAIT_Operation",createHashMap]) > 0) exitWith {"IDLE"};
private _ready=(units _group) select {
    alive _x && {local _x} && {!isPlayer _x} && {vehicle _x == _x}
        && {[_x] call WAIT_fnc_CortexCombatEffective}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
        && {isNull assignedVehicle _x}
        && {!(toUpperANSI (currentCommand _x) in ["GET IN","ACTION","HEAL","REARM","JOIN"])}
        && {(_x getVariable ["WAIT_Cortex_ActorMove",[]]) isEqualTo []}
};
private _gunnerIndex=_ready findIf {
    private _bag=backpack _x;
    _bag != "" && {getNumber (configFile >> "CfgVehicles" >> _bag >> "assembleInfo" >> "primary") == 1}
        && {getText (configFile >> "CfgVehicles" >> _bag >> "assembleInfo" >> "assembleTo") != ""}
};
if (_gunnerIndex < 0) exitWith {
    // A real primary carrier may be temporarily covering, boarding or acting. Do not
    // turn that transient reservation into NO_PRIMARY_BAG for the entire engagement.
    private _carrierPresent=(units _group) findIf {
        alive _x && {local _x} && {getNumber (configFile >> "CfgVehicles" >> backpack _x >> "assembleInfo" >> "primary") == 1}
    } >= 0;
    if (_carrierPresent) exitWith {"IDLE"};
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
    if ((units _group) findIf {alive _x && {local _x} && {(backpack _x) in _compatibleBases}} >= 0) exitWith {"IDLE"};
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
// Use the current firing position first: a static team need not relocate on open safe terrain.
private _candidates=[_origin,_candidateA,_candidateB] select {
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
// Hold only the primary carrier at an already valid sector. This is the finite deployment
// task, not a group stop; native targets/fire remain available and failure cleanup resumes follow.
if (_gunner distance2D _deployPos <= 0.5) then {doStop _gunner};
_record=[_episode,"MOVING",_gunner,_assistant,_expectedClass,+_deployPos,_deadline,objNull,_gunnerBag,_assistantBag,-1,+_targetPos,-1];
_group setVariable ["WAIT_Danger_StaticDeployment",_record,true];
_group setVariable ["WAIT_Danger_StaticDeployAttempt",[_episode,"MOVING",serverTime],true];
"MOVING"
