--!strict

local Npc_Info = {}

export type NPC_DATA = {
	[string]:
		{
			Name: string;
			rarity_chance: number;
			rarity_name: string;
			Base_Gen: number;
			Price: number
		}
}


Npc_Info.NPCS = {
	Nikilis = {
		Name = "Nikilis";
		rarity_chance = 3; --// THESE NUMBERS ARE WEIGHTED
		rarity_name = "Common";
		Base_Gen = 10;
		Price = 250;
	};
	NewFissy = {
		Name = "NewFissy";
		rarity_chance = 10;
		rarity_name = "Common";
		Base_Gen = 15;
		Price = 550;
	};
	mygame43 = {
		Name = "mygame43";
		rarity_chance = 25;
		rarity_name = "Uncommon";
		Base_Gen = 25;
		Price = 1250;
	};
	Nosniy = {
		Name = "Nosniy";
		rarity_chance = 50;
		rarity_name = "Uncommon";
		Base_Gen = 50;
		Price = 5000;
	};
	RiccoMiller = {
		Name = "RiccoMiller";
		rarity_chance = 100;
		rarity_name = "Uncommon";
		Base_Gen = 115;
		Price = 12500;
	};
	Jandel = {
		Name = "Jandel";
		rarity_chance = 175;
		rarity_name = "Rare";
		Base_Gen = 135;
		Price = 17500;
	}
	
} :: NPC_DATA



return Npc_Info
