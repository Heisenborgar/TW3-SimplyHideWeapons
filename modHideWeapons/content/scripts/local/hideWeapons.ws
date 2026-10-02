// Simply Hide Weapons - L3 hold (pad) + Period key (keyboard)

function SHW_ShowWhenDrawn() : bool
{
	return true;
}

function SHW_HideDelay() : float
{
	return 1.5;
}

function SHW_IsScabbard(inv : CInventoryComponent, id : SItemUniqueId) : bool
{
	var cat, nm : string;

	cat = StrLower(NameToString(inv.GetItemCategory(id)));
	nm = StrLower(NameToString(inv.GetItemName(id)));

	return StrContains(cat, "scabbard") || StrContains(nm, "scabbard");
}

@addField(W3PlayerWitcher)
var shwBolt : W3BoltProjectile;

@addField(W3PlayerWitcher)
var shwHideAfter : float;

@addField(W3PlayerWitcher)
var shwEnabled : bool;

@addField(W3PlayerWitcher)
var shwRestored : bool;

@addField(W3PlayerWitcher)
var shwRestoreAt : float;

@addField(W3PlayerWitcher)
var shwL3HeldSince : float;

@addField(W3PlayerWitcher)
var shwL3WasDown : bool;

@addField(W3PlayerWitcher)
var shwKeyWasDown : bool;

@wrapMethod(W3PlayerWitcher)
function OnSpawned(spawnData : SEntitySpawnData)
{
	wrappedMethod(spawnData);

	// state lives in the save file as a fact
	shwEnabled = FactsDoesExist('SHW_Enabled');
	shwRestored = false;
	shwRestoreAt = EngineTimeToFloat(theGame.GetEngineTime()) + 1.0;
	shwL3HeldSince = 0.0;
	shwL3WasDown = false;
	shwKeyWasDown = false;

	AddTimer('SHW_Timer', 0.0, true);
}

@addMethod(W3PlayerWitcher)
function SHW_ForceShowAll()
{
	var ids : array<SItemUniqueId>;
	var ent : CItemEntity;
	var i : int;

	inv.GetAllItems(ids);

	for (i = 0; i < ids.Size(); i += 1)
	{
		if (!inv.IsItemMounted(ids[i]))
			continue;

		ent = inv.GetItemEntityUnsafe(ids[i]);
		if (ent)
			ent.SetHideInGame(false);
	}

	if (shwBolt)
	{
		shwBolt.SetVisibility(true);
		shwBolt = NULL;
	}
}

@addMethod(W3PlayerWitcher)
function SHW_Toggle()
{
	shwEnabled = !shwEnabled;
	shwRestored = true;

	if (shwEnabled)
	{
		if (!FactsDoesExist('SHW_Enabled'))
			FactsAdd('SHW_Enabled');
	}
	else
	{
		if (FactsDoesExist('SHW_Enabled'))
			FactsRemove('SHW_Enabled');

		SHW_ForceShowAll();
	}
}

@addMethod(W3PlayerWitcher)
function SHW_CheckInput(now : float)
{
	var l3Down : bool;
	var keyDown : bool;

	// --- Keyboard: Period key, edge-triggered ---
	keyDown = theInput.GetActionValue('SHW_ToggleAction') > 0.0;

	if (keyDown && !shwKeyWasDown)
		SHW_Toggle();

	shwKeyWasDown = keyDown;

	// --- Gamepad: L3 held 1 second ---
	l3Down = theInput.GetActionValue('EnablePhotoMode_Step1') > 0.0;

	if (l3Down && !shwL3WasDown)
	{
		shwL3HeldSince = now;
	}
	else if (l3Down && shwL3WasDown)
	{
		if (shwL3HeldSince > 0.0 && (now - shwL3HeldSince) >= 1.0)
		{
			SHW_Toggle();
			shwL3HeldSince = 0.0;
		}
	}
	else
	{
		shwL3HeldSince = 0.0;
	}

	shwL3WasDown = l3Down;
}

@addMethod(W3PlayerWitcher)
timer function SHW_Timer(dt : float, id : int)
{
	var ids : array<SItemUniqueId>;
	var ent : CItemEntity;
	var bolt : W3BoltProjectile;
	var i : int;
	var isWeapon, isScabbard, anyHeld : bool;
	var now : float;

	now = EngineTimeToFloat(theGame.GetEngineTime());

	SHW_CheckInput(now);

	// facts may not be loaded yet at spawn, so read them once more a second later
	if (!shwRestored && now >= shwRestoreAt)
	{
		shwRestored = true;
		shwEnabled = FactsDoesExist('SHW_Enabled');
	}

	if (!shwEnabled)
		return;

	inv.GetAllItems(ids);

	for (i = 0; i < ids.Size(); i += 1)
	{
		if (inv.IsItemMounted(ids[i]) && inv.IsItemWeapon(ids[i]) && inv.IsItemHeld(ids[i]))
			anyHeld = true;
	}

	if (anyHeld)
		shwHideAfter = now + SHW_HideDelay();

	for (i = 0; i < ids.Size(); i += 1)
	{
		if (!inv.IsItemMounted(ids[i]))
			continue;

		isWeapon = inv.IsItemWeapon(ids[i]);
		isScabbard = SHW_IsScabbard(inv, ids[i]);

		if (!isWeapon && !isScabbard)
			continue;

		ent = inv.GetItemEntityUnsafe(ids[i]);
		if (!ent)
			continue;

		if (isScabbard)
			ent.SetHideInGame(true);
		else if (inv.IsItemHeld(ids[i]))
			ent.SetHideInGame(!SHW_ShowWhenDrawn());
		else if (now >= shwHideAfter)
			ent.SetHideInGame(true);
	}

	if (rangedWeapon)
	{
		bolt = (W3BoltProjectile)rangedWeapon.GetDeployedEntity();

		if (shwBolt && shwBolt != bolt)
		{
			shwBolt.SetVisibility(true);
			shwBolt = NULL;
		}

		if (bolt && bolt.IsStopped())
		{
			bolt.SetVisibility(false);
			shwBolt = bolt;
		}
	}
}
