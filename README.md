# s2k:Enhancements

Moduláris kiegészítő World of Warcraft 7.3.5-höz. Egyedi nameplate-rendszert, küldetéskiegészítéseket és más addonokhoz kapcsolódó integrációkat tartalmaz.

## Kód- és teljesítményoptimalizálás (1.18.0)

A teljes addonforrás átvizsgálásra került. A működés és a profilformátum megtartása mellett csökkent a fölösleges runtime munka: a castbar frissítés csak az aktívan castoló nameplate-eket járja be, megszűnt a target cast kettős frissítése, a gyakori vizuális beállítások numerikus cache-t használnak, a nameplate-skála időzítői összevonódnak, a médiaregiszterek pedig nem épülnek újra minden késleltetett próbánál. A közös UI-, média-, frame- és CVar-segédek egységes helyre kerültek, az elavult és nem használt kód eltávolításra került.

## LDB és önálló konfigurációs ablak

Az addon `s2k:Enhancements` néven regisztrál egy **LibDataBroker-1.1 launcher** objektumot. Emiatt a konfigurációs ablak elérhető LDB host/display addonokból, például a StatBlockCore-ból.

- Az LDB blokkon vagy a minimap ikonon bal egérgombbal kattintva megnyitható és bezárható a konfiguráció.
- A `/s2ke` parancs szintén megnyitja vagy bezárja az ablakot.
- A `/s2ke config`, `/s2ke options` és `/s2ke settings` megnyitja a konfigurációt.
- Az addon többé nem regisztrál beállítási kategóriákat a Blizzard Interface Options paneljén.

A szükséges `LibStub`, `CallbackHandler-1.0` és `LibDataBroker-1.1` könyvtárak be vannak ágyazva az addonba, ezért nincs szükség külön telepített LDB könyvtár-addonra.

A konfigurációs felület ebben a változatban az addon meglévő, bevált beállításkezelő rendszerét használja egy külön mozgatható ablakban. A nameplate-runtime, a profiladatbázis és a mentett konfigurációs kulcsok nem kerültek AceDB-re át, így a korábbi profilok változatlanul használhatók.

## Konfigurációs struktúra

- **General**
  - General — globális megjelenítési beállítások és a küldetések reputációs jutalmának kijelzése
  - Profiles — profil mentése, betöltése, másolása, visszaállítása és törlése
- **Nameplates**
  - General
  - Healthbar
  - Castbar
  - Overlays
  - Buffs
  - Debuffs
- **Addons**
  - WeakAuras
  - Dominos
- **Debug** — profiler és CPU benchmark

## Custom Nameplates főkapcsoló

Kikapcsolásakor a custom healthbar, castbar, név, overlayek, buffok és debuffok egy blokkban leállnak. A változtatáshoz UI-újratöltés szükséges; a megjelenő párbeszédablakból azonnal elvégezhető a `/reload`, vagy visszavonható a változtatás.

## Kompatibilitás és profilok

A `s2k_EnhancementsDB` az első indításkor automatikusan átveszi a korábbi `s2k_NameplatesDB` profiljait. A régi globális API (`_G.s2k_Nameplates`) és a korábbi slash parancsok kompatibilitási aliasként megmaradnak.

Fő parancsok:

```text
/s2ke
/s2ke config
/s2ke help
/s2ke dominos
/s2kemod list
/s2keprof list
```

## Telepítés

1. Töröld vagy nevezd át a korábbi `Interface/AddOns/s2k_Nameplates` mappát.
2. Másold a ZIP-ben található `s2k_Enhancements` mappát az `Interface/AddOns/` könyvtárba.
3. Indítsd újra a klienst vagy használd a `/reload` parancsot.
4. StatBlockCore vagy más LDB host használatakor engedélyezd az `s2k:Enhancements` broker objektum megjelenítését.

## Resizable standalone configuration (1.16.3)

The LDB-opened configuration window can be resized with the grip in its bottom-right corner. The left navigation remains fixed-width; only the settings workspace changes size. Internal tab buttons wrap according to the available width, scrollable pages expand vertically and horizontally, long descriptions reflow, and the WeakAuras progress-group editor uses a compact two-line row layout when space is limited. The last window size is stored in the account-wide SavedVariables root. Live resizing uses a throttled, visible-panel-only layout pass, so dragging the resize grip no longer rebuilds every hidden settings page on every pixel change.


## Minimap launcher

The addon provides both an LDB launcher and a draggable minimap icon. Minimap visibility is controlled under General > General and is stored globally rather than per profile. The existing profile manager is available under General > Profiles.

## Dominos integration

Az **Addons > Dominos** panel a Dominos által ténylegesen létrehozott action barok számát olvassa ki, ezért a lista nincs fixen tíz sávra korlátozva. Minden sávnál csak azt kell megadni, hogy részt vegyen-e az ideiglenes szerkesztési elrendezésben.

- **Dominos:** a Dominos saját, normál pozíciói, docking kapcsolatai és Show States feltételei aktívak. Az s2k ebben az állapotban nem rendezi át a sávokat.
- **Editable:** a kijelölt sávok aktuális Dominos-pozíciója és Show States értéke átmenetileg elmentődik, a Show States kiürül, majd a sávok számsorrendben egymás mellé vagy egymás alá rendeződnek. Ha az egyetlen sor vagy oszlop teljes egészében elfér, a legkisebb sorszámú kijelölt sáv az eredeti helyén marad. Ha nem fér el, a vízszintes elrendezés automatikusan új sorokba, a függőleges elrendezés új oszlopokba törik; az első sáv a bal, illetve a felső képernyőszélről indul. A számítás a Dominos sávok tényleges, skálázott méretét használja.
- Dominos módba visszatérve, illetve az integráció kikapcsolásakor minden elmentett Dominos-pozíció, docking kapcsolat és Show States automatikusan visszaáll.
- Harc közben a védett action-bar frame-ek nem módosulnak; a változtatás a harc végén automatikusan lefut.
- Az integráció alapértelmezetten ki van kapcsolva, így meglévő Dominos-elrendezést nem változtat meg engedély nélkül.

Ha a Dominos integráció engedélyezve van, a Dominos kompatibilis és legalább egy action bar Anchored jelölést kapott, az LDB vagy minimap ikon jobb gombos kattintása közvetlenül vált a **Dominos** és **Editable** mód között. A tooltip kijelzi az aktuális állapotot és a következő jobb gombos műveletet. Ugyanez elérhető a `/s2ke dominos` paranccsal.
