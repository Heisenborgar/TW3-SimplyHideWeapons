// Simply Hide Weapons

function SHW_ShowWhenDrawn() : bool
{
	return true;
}

function SHW_HideDelay() : float
{
	return 1.5;
}

function SHW_SettingsRefresh() : float
{
	return 1.0;
}

function SHW_Opt(varName : name) : int
{
	return StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('SimplyHideWeapons', varName), 0);
}

// 0 = not a scabbard, 1 = steel, 2 = silver
function SHW_ScabbardKind(inv : CInventoryComponent, id : SItemUniqueId) : int
{
	var cat, nm : string;

	cat = StrLower(NameToString(inv.GetItemCategory(id)));

	if (StrContains(cat, "steel_scabbard"))
		return 1;

	if (StrContains(cat, "silver_scabbard"))
		return 2;

	nm = StrLower(NameToString(inv.GetItemName(id)));

	if (!StrContains(cat, "scabbard") && !StrContains(nm, "scabbard"))
		return 0;

	if (StrContains(nm, "silver"))
		return 2;

	return 1;
}

@addField(W3PlayerWitcher)
var shwNextSettings : float;

@addField(W3PlayerWitcher)
var shwHideSteel : bool;

@addField(W3PlayerWitcher)
var shwHideSilver : bool;

@addField(W3PlayerWitcher)
var shwHideCrossbow : bool;

@addField(W3PlayerWitcher)
var shwHideBolt : bool;

@addField(W3PlayerWitcher)
var shwHideAfter : float;

@addField(W3PlayerWitcher)
var shwBolt : W3BoltProjectile;

@wrapMethod(W3PlayerWitcher)
function OnSpawned(spawnData : SEntitySpawnData)
{
	wrappedMethod(spawnData);

	// old versions stored their state in the save
	FactsRemove('SHW_On');
	FactsRemove('SHW_Off');
	FactsRemove('SHW_Enabled');

	SHW_LoadSettings(false);
	shwNextSettings = EngineTimeToFloat(theGame.GetEngineTime()) + SHW_SettingsRefresh();

	AddTimer('SHW_Timer', 0.0, true);
}

@addMethod(W3PlayerWitcher)
function SHW_LoadSettings(apply : bool)
{
	var steel, silver, crossbow, bolt, changed : bool;

	steel = SHW_Opt('shwHideSteel') == 0;
	silver = SHW_Opt('shwHideSilver') == 0;
	crossbow = SHW_Opt('shwHideCrossbow') == 0;
	bolt = SHW_Opt('shwHideBolt') == 0;

	changed = steel != shwHideSteel || silver != shwHideSilver || crossbow != shwHideCrossbow
		|| bolt != shwHideBolt;

	shwHideSteel = steel;
	shwHideSilver = silver;
	shwHideCrossbow = crossbow;
	shwHideBolt = bolt;

	if (changed && apply)
		SHW_ShowAll();
}

@addMethod(W3PlayerWitcher)
function SHW_ShowAll()
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

		if (ent && (inv.IsItemWeapon(ids[i]) || SHW_ScabbardKind(inv, ids[i]) != 0))
			ent.SetHideInGame(false);
	}

	if (shwBolt)
	{
		shwBolt.SetVisibility(true);
		shwBolt = NULL;
	}
}

@addMethod(W3PlayerWitcher)
function SHW_UpdateItems(now : float)
{
	var ids : array<SItemUniqueId>;
	var id : SItemUniqueId;
	var ent : CItemEntity;
	var drawn, hide : bool;
	var want : EPlayerWeapon;
	var kind, i : int;

	// set as soon as a draw starts, before the sword is in hand
	want = GetCurrentMeleeWeaponType();

	inv.GetAllItems(ids);

	for (i = 0; i < ids.Size(); i += 1)
	{
		id = ids[i];

		if (!inv.IsItemMounted(id))
			continue;

		if (inv.IsItemWeapon(id))
		{
			drawn = inv.IsItemHeld(id);

			if (inv.IsItemSteelSwordUsableByPlayer(id))
			{
				hide = shwHideSteel;
				drawn = drawn || want == PW_Steel;
			}
			else if (inv.IsItemSilverSwordUsableByPlayer(id))
			{
				hide = shwHideSilver;
				drawn = drawn || want == PW_Silver;
			}
			else if (inv.IsItemCrossbow(id))
				hide = shwHideCrossbow;
			else
				continue;

			if (drawn)
				shwHideAfter = now + SHW_HideDelay();

			if (!hide)
				continue;

			ent = inv.GetItemEntityUnsafe(id);

			if (!ent)
				continue;

			// has to be visible before the draw or the runes don't show
			if (drawn)
				ent.SetHideInGame(!SHW_ShowWhenDrawn());
			else if (now >= shwHideAfter)
				ent.SetHideInGame(true);
		}
		else
		{
			kind = SHW_ScabbardKind(inv, id);

			if ((kind == 1 && shwHideSteel) || (kind == 2 && shwHideSilver))
			{
				ent = inv.GetItemEntityUnsafe(id);

				if (ent)
					ent.SetHideInGame(true);
			}
		}
	}
}

// the loaded bolt is a projectile, not an item
@addMethod(W3PlayerWitcher)
function SHW_UpdateBolt()
{
	var bolt : W3BoltProjectile;

	if (!shwHideBolt || !rangedWeapon)
		return;

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

@addMethod(W3PlayerWitcher)
timer function SHW_Timer(dt : float, id : int)
{
	var now : float;

	now = EngineTimeToFloat(theGame.GetEngineTime());

	if (now >= shwNextSettings)
	{
		shwNextSettings = now + SHW_SettingsRefresh();
		SHW_LoadSettings(true);
	}

	SHW_UpdateItems(now);
	SHW_UpdateBolt();
}
