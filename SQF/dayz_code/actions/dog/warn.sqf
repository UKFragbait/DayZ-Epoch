private ["_array", "_handle", "_watchDog", "_dog", "_warn"];
_array = _this select 3;
_handle = _array select 0;
_watchDog = _array select 1;
_dog = _handle getFSMVariable "_dog";

player removeAction s_player_warndog;
s_player_warndog = -1;

_handle setFSMVariable ["_watchDog",_watchDog];

_warn = {
	private ["_watchDog","_dog","_nearby","_senseSkill","_handle"];
	_handle = _this select 0;
	_watchDog = _this select 1;
	_dog = _this select 2;
	while {_watchDog && alive _dog} do {
		_watchDog = _handle getFSMVariable "_watchDog";
		_senseSkill = _handle getFSMVariable "_senseSkill";
		if (_watchDog) then {
			_nearby = (getPosATL _dog) nearEntities ["CAManBase",_senseSkill];
			_nearby = _nearby - [player];
			if (count _nearby > 0) then {
				[_dog,"dog_growl",2,false] call dayz_zombieSpeak;
			};
		};
		uiSleep 2;
	};
};

if (_watchDog) then {
	_handle setFSMVariable ["_idleTime",5];
	[_handle,_watchDog,_dog] spawn _warn;
} else {
	_handle setFSMVariable ["_idleTime",1];
};