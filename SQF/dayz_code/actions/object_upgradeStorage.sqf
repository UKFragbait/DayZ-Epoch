/*
	Simple class system to use this script.
	class Upgrade {
		requiredTools[] = {"ItemToolbox"};
		requiredParts[] = {"equip_crate","PartWoodPile"};
		create = "TentStorage1";
	};	
*/
if (dayz_actionInProgress) exitWith { localize "str_player_actionslimit" call dayz_rollingMessages; };
dayz_actionInProgress = true;

private ["_cursorTarget","_item","_classname","_requiredTools","_requiredParts","_upgrade","_upgradeConfig",
"_upgradeDisplayname","_onLadder","_isWater","_upgradeParts","_startUpgrade","_missingPartsConfig","_textMissingParts","_dis",
"_sfx","_ownerID","_objectID","_objectUID","_dir","_weapons","_magazines","_backpacks","_object",
"_objWpnTypes","_objWpnQty","_countr","_itemName","_vector","_playerNear","_finished"];

_cursorTarget = _this select 3;

//get ownerID from old tent.
_ownerID = _cursorTarget getVariable ["characterID","0"];
_objectID = _cursorTarget getVariable ["ObjectID","0"];
_objectUID = _cursorTarget getVariable ["ObjectUID","0"];

//make sure the player is still looking at something to get the cursorTarget and UID
if (isNil "_cursorTarget" or {isNull _cursorTarget} or {_objectUID == "0" && (_objectID == "0")}) exitWith {
     localize "str_cursorTargetNotFound" call dayz_rollingMessages;
	 dayz_actionInProgress = false;
};

_item = typeof _cursorTarget;
//diag_log (str(_item));

//remove action menu
player removeAction s_player_upgradestorage;
s_player_upgradestorage = -1;

//Not needed
//_itemName = getText (configFile >> "CfgVehicles" >> _item >> "displayName");
////diag_log (str(_itemName));

//Get tools needed
_classname = configFile >> "CfgVehicles" >> _item;
_requiredTools = getArray (_classname >> "Upgrade" >> "requiredTools");
//diag_log (str(_requiredTools));

//get parts needed
_requiredParts = getArray (_classname >> "Upgrade" >> "requiredParts"); 
//diag_log (str(_requiredParts));

//get item to create
_upgrade = getText (_classname >> "Upgrade" >> "create");
//diag_log (str(_upgrade));

//Display name of upgrade part
_upgradeConfig = configFile >> "CfgVehicles" >> _upgrade;
//diag_log (str(_upgradeConfig));
_upgradeDisplayname = getText (_upgradeConfig >> "displayName");
//diag_log (str(_upgradeDisplayname));
//Normal blocked stuff
_onLadder =		(getNumber (configFile >> "CfgMovesMaleSdr" >> "States" >> (animationState player) >> "onLadder")) == 1;
_isWater = 		(surfaceIsWater (getPosATL player)) or dayz_isSwimming;

_upgradeParts = [];
_startUpgrade = true;

if(_isWater or _onLadder) exitWith {dayz_actionInProgress = false; localize "str_CannotUpgrade" call dayz_rollingMessages;};

// Make sure no other players are nearby
_playerNear = {isPlayer _x} count (([_cursorTarget] call FNC_GetPos) nearEntities ["CAManBase",10]) > 1;
if (_playerNear) exitWith {dayz_actionInProgress = false; localize "str_pickup_limit_5" call dayz_rollingMessages;};

// lets check player has requiredTools for upgrade
{
	if (!(_x IN items player)) exitWith {
		_missingPartsConfig = configFile >> "CfgWeapons" >> _x;
		_textMissingParts = getText (_missingPartsConfig >> "displayName");

		format [localize "str_missing_to_do_this", _textMissingParts] call dayz_rollingMessages;
		
		_startUpgrade = false;
	};
} count _requiredTools;

// lets check player has requiredParts for upgrade
{
	if (!(_x IN magazines player)) exitWith {
		_missingPartsConfig = configFile >> "CfgMagazines" >> _x;
		_textMissingParts = getText (_missingPartsConfig >> "displayName");
				
		format [localize "str_missing_to_do_this", _textMissingParts] call dayz_rollingMessages;
		_startUpgrade = false;
	};
	if (_x IN magazines player) then {
		_upgradeParts set [count _upgradeParts, _x];
	};
} count _requiredParts;


//Does object have a upgrade option.
if ((_startUpgrade) AND (isClass(_upgradeConfig))) then {
	_dis = 20;
	_sfx = "tentpack";
	[player,_sfx,0,false,_dis] call dayz_zombieSpeak;
	[player,_dis,true,(getPosATL player)] call player_alertZombies;
	
	_finished = ["Medic",1] call fn_loopAction;
	//Double check player did not drop required parts
	if (!_finished or (isNull _cursorTarget) or ({!(_x in magazines player)} count _upgradeParts > 0)) exitWith {};
	
	// Added Nutrition-Factor for work
	["Working",0,[100,15,5,0]] call dayz_NutritionSystem;

	//Get location and direction of old item
	_dir = round getDir _cursorTarget;
	_vector = [vectorDir _cursorTarget,vectorUp _cursorTarget];
	
	//reset orientation before measuring position, otherwise the new object will be placed incorrectly. -foxy
	_cursorTarget setDir 0;
	_pos = getPosATL _cursorTarget;
	
	//diag_log [ "dir/angle/pos", _dir, _vector, _pos];
	if (abs(((_vector select 1) select 2) - 1) > 0.001) then { _pos set [2,0]; };
	//diag_log [ "dir/angle/pos - reset elevation if angle is straight", _dir, _vector, _pos];

	//get contents
	_weapons = getWeaponCargo _cursorTarget;
	_magazines = getMagazineCargo _cursorTarget;
	_backpacks = getBackpackCargo _cursorTarget;
	
	//remove old tent
	PVDZ_obj_Destroy = [_objectID,_objectUID,player];
	publicVariableServer "PVDZ_obj_Destroy";
	deleteVehicle _cursorTarget;
	
	// remove parts from players inventory before creation of new tent.
	{
		player removeMagazine _x;
		_upgradeParts = _upgradeParts - [_x];
	} count _upgradeParts;
	
	//create new tent
    _object = createVehicle [_upgrade, getMarkerpos "respawn_west", [], 0, "CAN_COLLIDE"];
	
	//reseting orientation to make sure the object goes where it's supposed to -foxy
	_object setDir 0;
	_object setPosATL _pos;
	_object setVectorDirAndUp _vector;
	
	//set ownerID from old tent.
	_object setVariable ["characterID",_ownerID];
	
	//Make sure player knows about the new object
	player reveal _object;
	
	//Add contents back
	//Add Weapons
	_objWpnTypes = _weapons select 0;
	_objWpnQty = _weapons select 1;
	_countr = 0;
	{
		_object addweaponcargoGlobal [_x,(_objWpnQty select _countr)];
		_countr = _countr + 1;
	} count _objWpnTypes;

	//Add Magazines
	_objWpnTypes = _magazines select 0;
	_objWpnQty = _magazines select 1;
	_countr = 0;
	{
		_object addmagazinecargoGlobal [_x,(_objWpnQty select _countr)];
		_countr = _countr + 1;
	} count _objWpnTypes;

	//Add Backpacks
	_objWpnTypes = _backpacks select 0;
	_objWpnQty = _backpacks select 1;
	_countr = 0;
	{
		_object addbackpackcargoGlobal [_x,(_objWpnQty select _countr)];
		_countr = _countr + 1;
	} count _objWpnTypes;
	
	//publish new tent	
	if (DZE_permanentPlot) then {
		_object setVariable ["ownerPUID",dayz_playerUID,true];
		PVDZ_obj_Publish = [dayz_characterID,_object,[_dir, _pos, dayz_playerUID],[_weapons,_magazines,_backpacks]];
	} else {
		PVDZ_obj_Publish = [dayz_characterID,_object,[_dir, _pos],[_weapons,_magazines,_backpacks]];
	};
	publicVariableServer "PVDZ_obj_Publish";
    diag_log [diag_ticktime, __FILE__, "New Networked object, request to save to hive. PVDZ_obj_Publish:", PVDZ_obj_Publish];

	localize "str_upgradeDone" call dayz_rollingMessages;
/*
} else {
	localize "str_upgradeNoOption" call dayz_rollingMessages;
*/
};

dayz_actionInProgress = false;