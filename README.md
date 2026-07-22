# s2k:Enhancements

Moduláris kiegészítő World of Warcraft 7.3.5-höz (Interface 70300). Egyedi nameplate-rendszert, quest- és Blizzard-finomhangolásokat, valamint WeakAuras- és Dominos-integrációt tartalmaz.

## Fő funkciók

- Egyedi healthbarok és castbarok általános és target megjelenéssel.
- Beállítható nameplate hitbox, közös healthbar-méret és a healthbar pozíciója a hitboxon belül.
- Örökölt frame strata a kapcsolódó castbarokhoz, overlayekhez, buffokhoz és debuffokhoz, külön overlay frame level beállításokkal.
- HP-, név-, szint-, threshold- és player-cast overlayek.
- Buff- és debuffmegjelenítés.
- Mozgatható, animált nameplate layout preview két próba-nameplate-tel.
- Castbar spellnév betűtípus-, méret-, körvonal- és színbeállítás.
- Quest reputáció- és currencyjutalmak, beleértve a Garrison és Order Resources jutalmakat.
- Automatikus questelfogadás és -leadás, questszintek, tooltip-objective állapotok és megosztott questek kezelése.
- Maximum camera distance és SpellQueueWindow beállítás latencyalapú ajánlással.
- WeakAuras nameplate-integráció és Dominos action-bar elrendezés.

## Konfiguráció

Az addon kizárólag önálló konfigurációs ablakot használ. Nem regisztrál panelt a Blizzard Interface Options rendszerébe, mert az Legion alatt taintelheti a Compact Raid Frame profilkezelését.

A beállítások megnyithatók:

- az LDB launcher vagy a minimap ikon bal gombos kattintásával;
- a /s2ke paranccsal;
- a /s2ke config, /s2ke options vagy /s2ke settings paranccsal.

A konfigurációs ablak mozgatható és átméretezhető. Mérete globálisan mentődik, a beállítások pedig modulonként elkülönített szekciókban jelennek meg.

### Szerkezet

- **General**
  - General – nyelv, minimap, Blizzard Tweaks és Quest Tweaks
  - Profiles – profilok mentése, betöltése, másolása, resetje és törlése
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
- **Debug**
  - profiler és CPU benchmark

## Nameplate layout és hitbox

A general és target healthbar közös szélességet és magasságot használ. A Blizzard nameplate kattintható hitboxának szélessége és magassága külön állítható, ahogy a healthbar középpontjának hitboxon belüli X/Y eltolása is.

A **Show nameplate layout preview** egy mozgatható próbaelrendezést jelenít meg general és target nameplate-tel, hitboxszal, borderrel, castbarral, overlayekkel, buffokkal és debuffokkal.

## Quest Tweaks

Külön kapcsolható:

- automatikus questelfogadás;
- automatikus questleadás, jutalomválasztásnál megállva;
- quest szintjének megjelenítése;
- questobjective-ok és állapotuk mob- és item-tooltipben;
- megosztott questkérelmek automatikus elfogadása;
- reputációjutalmak megjelenítése;
- minden, a Legion quest API által jelentett currencyjutalom megjelenítése.

A reputáció- és currencyjutalmak dinamikusan méretezett blokkban kerülnek a quest részleteihez és a jutalomnézethez.

## Dominos integráció

Az integráció a Dominos által létrehozott action barokat kezeli. A kijelölt sávok átmenetileg vízszintesen vagy függőlegesen rendezhetők, szükség esetén több sorba vagy oszlopba törve. A Dominos mód visszaállítja az eredeti pozíciókat, docking kapcsolatokat és Show States értékeket.

A frame strata action baronként menthető. Védett frame-ek harc közben nem módosulnak; a szükséges változtatások a harc végére halasztódnak. Az LDB vagy minimap ikon jobb gombja, illetve a /s2ke dominos parancs vált a Dominos és Editable mód között.

## WeakAuras integráció

A támogatott környezet WoW 7.3.5 és legalább WeakAuras 2.5.12. Az integráció addon-tulajdonú bridge anchorokat biztosít a target nameplate healthbarjához és castbarjához anélkül, hogy a WeakAuras csoportok felhasználói layout- és stílusbeállításait felülírná.

## Profilok és kompatibilitás

A profilok a s2k_EnhancementsDB SavedVariables adatbázisban tárolódnak. A korábbi s2k_NameplatesDB, a régi _G.s2k_Nameplates API és a korábbi slash parancsok kompatibilitási célból megmaradnak.

A konfiguráció és a profilrendszer jelenleg saját implementáció; még nem használ AceConfig, AceGUI vagy AceDB könyvtárat.

## Fő parancsok

    /s2ke
    /s2ke config
    /s2ke help
    /s2ke dominos
    /s2kemod list
    /s2keprof list

## Telepítés

1. Töröld vagy nevezd át a korábbi Interface/AddOns/s2k_Nameplates mappát.
2. Másold a release ZIP-ben található s2k_Enhancements mappát az Interface/AddOns/ könyvtárba.
3. Indítsd újra a klienst vagy használd a /reload parancsot.
4. LDB host használatakor engedélyezd az s2k:Enhancements launcher megjelenítését.

A release ZIP legfelső könyvtára mindig s2k_Enhancements.
