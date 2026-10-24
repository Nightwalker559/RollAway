-- RollAway - Locale deDE

if GetLocale() ~= "deDE" then return end

local L = _G["RollAwayLocale"]

------------------------------------------------------------------------
-- Allgemein
------------------------------------------------------------------------
L["addon_title"]      = "RollAway & Tools"
L["options_nav_main"] = "Loot & Rolls"
L["main_panel_info"]  = "Loot-Verlauf, Bonusroll-Auto-Pass, Roll-Bestätigung und Würfe in Legacy-Schlachtzügen."

------------------------------------------------------------------------
-- Titel der Popup-Fenster (wofür das Popup steht)
------------------------------------------------------------------------
L["popup_title_bonusroll"]        = "Bonusroll-Erinnerung"
L["popup_title_autopass_warning"] = "Auto-Pass-Warnung"
L["popup_title_paragon"]          = "Paragon-Erinnerung"
L["popup_title_vault"]            = "Große Schatzkammer"
L["popup_title_advlog"]           = "Erweitertes Kampflog"
L["popup_title_tank"]             = "Tank markieren"
L["popup_title_teleport"]         = "Teleport-Hinweis"

------------------------------------------------------------------------
-- Reiter der Seite Loot & Rolls
------------------------------------------------------------------------
L["tab_general"]  = "Allgemein"
L["tab_dungeons"] = "Dungeons"
L["tab_raids"]    = "Schlachtzüge"
L["tab_delves"]   = "Tiefen"
L["tab_prey"]     = "Offene Welt"
L["tab_legacy"]   = "Legacy"

------------------------------------------------------------------------
-- Verzögerung Slider
------------------------------------------------------------------------
L["delay_section_title"] = "Verzögerung"
L["slider_label"]        = "Fenster schließen nach %d Sekunden"
L["slider_min"]          = "5 Sek."
L["slider_max"]          = "20 Sek."

------------------------------------------------------------------------
-- Sicherheits-Timeout Slider
------------------------------------------------------------------------
L["timeout_section_title"]           = "Sicherheits-Timeout"
L["timeout_slider_label"]            = "Fenster zwangsweise schließen nach %d Sekunden"
L["timeout_min"]                     = "30 Sek."
L["timeout_max"]                     = "180 Sek."
L["lootframe_feature_disable_label"] = "Automatisches Schließen deaktivieren (Fenster bleibt immer offen)"

------------------------------------------------------------------------
-- Beuteverteilung (Group Loot History)
------------------------------------------------------------------------
L["visibility_section_title"] = "Beuteverteilung"
L["visibility_info"]          = "Steuert das Beuteverteilungs-Fenster, das bei der Beutevergabe in Schlachtzügen erscheint."
L["hide_in_raid_label"]       = "Beuteverteilung im Schlachtzug ausblenden"
L["hide_in_raid_info"]        = "Blendet das Beuteverteilungs-Fenster für die ausgewählten Schlachtzug-Schwierigkeiten in aktuellen Schlachtzügen aus. Standardmäßig sichtbar."
L["hide_in_legacy_label"]     = "Beuteverteilung in Legacy-Schlachtzügen immer ausblenden"
L["hide_in_legacy_info"]      = "Schlachtzüge aus Dragonflight und The War Within, egal welche Schwierigkeit. Die Schwierigkeiten oben gelten dort nicht."

------------------------------------------------------------------------
-- Bonusroll-Erinnerung (Reiter Allgemein)
------------------------------------------------------------------------
L["reminder_label"]                   = "Erinnerung anzeigen beim Betreten von Dungeons & Schlachtzügen"
L["reminder_info"]                    = "Zeigt ein Popup beim Betreten eines Mythic-Dungeons oder Schlachtzugs und erinnert dich, deine Auto-Pass-Einstellungen zu überprüfen."
L["autopass_warning_label"]           = "Warnen, wenn für den betretenen Inhalt ein Auto-Pass aktiv ist"
L["autopass_warning_info"]            = "Sicherheitsnetz gegen eine vergessene Checkbox: zeigt beim Betreten eines Mythic-Dungeons oder Schlachtzugs eine kurze Warnung, aber nur wenn dort ein Bonusroll Auto-Pass aktiv ist - auch bei ausgeschaltetem Reminder darüber. Sonst bleibt es still."
L["bonusroll_reminder_section_title"] = "Bonusroll"

------------------------------------------------------------------------
-- Reminder Popup
------------------------------------------------------------------------
L["reminder_dungeon"]        = "Du hast einen Mythic-Dungeon betreten. Überprüfe deine Bonus Roll Auto-Pass Einstellungen."
L["reminder_raid"]           = "Du hast einen Schlachtzug betreten. Überprüfe deine Bonus Roll Auto-Pass Einstellungen."
L["reminder_voidcore"]       = "Nebulöser Leerekern: %d – %s %s verfügbar."
L["reminder_roll_singular"]  = "Wurf"
L["reminder_roll_plural"]    = "Würfe"
L["reminder_ap_none"]        = "Hier ist kein Bonusroll Auto-Pass aktiv."
L["reminder_ap_difficulty"]  = "Auto-Pass AKTIV: alle Bosse auf %s."
L["reminder_ap_bosses"]      = "Auto-Pass AKTIV für: %s."
L["reminder_ap_dungeon"]     = "Auto-Pass AKTIV für diesen Dungeon."
L["reminder_ap_dungeon_all"] = "Auto-Pass AKTIV für alle Dungeons."
L["reminder_btn_dungeons"]   = "Dungeons öffnen"
L["reminder_btn_raids"]      = "Schlachtzüge öffnen"
L["reminder_okay"]           = "Okay"

------------------------------------------------------------------------
-- Roll-Bestätigung
------------------------------------------------------------------------
L["confirm_roll_title"]    = "Roll-Bestätigung"
L["confirm_roll_hint"]     = "Zeigt ein Popup zur Bestätigung, bevor du auf Gruppen-Loot würfelst. Gilt für jeden Schlachtzug, aktuell oder Legacy."
L["confirm_roll_popup"]    = "%s auf %s würfeln?"
L["confirm_type_need"]     = "Bedarf"
L["confirm_type_greed"]    = "Gier"
L["confirm_type_transmog"] = "Transmog"
L["confirm_type_pass"]     = "Passen"

------------------------------------------------------------------------
-- Season-Reiter, Patches und gemeinsame Labels
------------------------------------------------------------------------
L["season1_title"]       = "Season 1"
L["season2_tab"]         = "Season 2 (12.1)"
L["season3_tab"]         = "Season 3 (12.2)"
L["season_coming_soon"]  = "Demnächst verfügbar"
L["patch_12_0"]          = "Patch 12.0"
L["patch_12_1"]          = "Patch 12.1"
L["nemesis_delve_label"] = "(Nemesis-Tiefe)"
L["label_removed"]       = "(entfernt)"
L["label_coming_soon"]   = "(demnächst)"

------------------------------------------------------------------------
-- Reiter Dungeons
------------------------------------------------------------------------
L["season1_hint"]               = "Hake einen Dungeon an, um den Bonus Roll nach jedem Abschluss automatisch zu passen. Nicht angehakte Dungeons sind davon nicht betroffen."
L["dungeon_autopass_all_label"] = "ALLE Dungeons automatisch passen (jede Season)"

------------------------------------------------------------------------
-- Season 1 Dungeon-Namen (= lokalisierter Rückgabewert von GetInstanceInfo)
------------------------------------------------------------------------
L["dungeon_windrunner_spire"]    = "Windläuferturm"
L["dungeon_maisara_caverns"]     = "Maisarakavernen"
L["dungeon_magisters_terrace"]   = "Terrasse der Magister"
L["dungeon_nexus_point_xenas"]   = "Nexuspunkt Xenas"
L["dungeon_algeth_ar_academy"]   = "Akademie von Algeth'ar"
L["dungeon_seat_of_triumvirate"] = "Sitz des Triumvirats"
L["dungeon_skyreach"]            = "Himmelsnadel"
L["dungeon_pit_of_saron"]        = "Grube von Saron"

------------------------------------------------------------------------
-- Season 2 Dungeon-Namen (12.1)
------------------------------------------------------------------------
L["dungeon_altar_of_fangs"]       = "Altar der Fänge"
L["dungeon_kings_rest"]           = "Königsruh"
L["dungeon_ruby_life_pools"]      = "Rubinlebensbecken"
L["dungeon_temple_of_sethraliss"] = "Tempel von Sethraliss"
L["dungeon_murder_row"]           = "Mördergasse"
L["dungeon_den_of_nalorakk"]      = "Nalorakks Bau"
L["dungeon_blinding_vale"]        = "Das blendende Tal"
L["dungeon_voidscar_arena"]       = "Arena der Leerennarbe"

------------------------------------------------------------------------
-- Legacy-Dungeon-Namen für den Reiter "Alle Dungeons" (Modules\PortalOverview.lua)
------------------------------------------------------------------------
L["dungeon_vortex_pinnacle"]            = "Der Vortexgipfel"
L["dungeon_throne_of_the_tides"]        = "Thron der Gezeiten"
L["dungeon_grim_batol"]                 = "Grim Batol"
L["dungeon_temple_of_the_jade_serpent"] = "Tempel der Jadeschlange"
L["dungeon_siege_of_niuzao"]            = "Belagerung des Niuzaotempels"
L["dungeon_scholomance"]                = "Scholomance"
L["dungeon_scarlet_monastery"]          = "Das Scharlachrote Kloster"
L["dungeon_scarlet_halls"]              = "Die Scharlachroten Hallen"
L["dungeon_gate_of_the_setting_sun"]    = "Tor der Untergehenden Sonne"
L["dungeon_mogushan_palace"]            = "Mogu'shanpalast"
L["dungeon_shado_pan_monastery"]        = "Shado-Pan-Kloster"
L["dungeon_stormstout_brewery"]         = "Brauerei Sturmbräu"
L["dungeon_shadowmoon_burial_grounds"]  = "Schattenmondgrabstätte"
L["dungeon_everbloom"]                  = "Der Immergrüne Flor"
L["dungeon_bloodmaul_slag_mines"]       = "Blutschlägermine"
L["dungeon_auchindoun"]                 = "Auchindoun"
L["dungeon_upper_blackrock_spire"]      = "Obere Schwarzfelsspitze"
L["dungeon_grimrail_depot"]             = "Grimmgleisdepot"
L["dungeon_iron_docks"]                 = "Eisendocks"
L["dungeon_darkheart_thicket"]          = "Finsterherzdickicht"
L["dungeon_black_rook_hold"]            = "Rabenwehr"
L["dungeon_halls_of_valor"]             = "Hallen der Tapferkeit"
L["dungeon_neltharions_lair"]           = "Neltharions Hort"
L["dungeon_court_of_stars"]             = "Hof der Sterne"
L["dungeon_karazhan_lower"]             = "Rückkehr nach Karazhan"
L["dungeon_atal_dazar"]                 = "Atal'Dazar"
L["dungeon_freehold"]                   = "Freihafen"
L["dungeon_waycrest_manor"]             = "Kronsteiganwesen"
L["dungeon_underrot"]                   = "Der Tiefenpfuhl"
L["dungeon_operation_mechagon"]         = "Operation: Mechagon"
L["dungeon_siege_of_boralus"]           = "Belagerung von Boralus"
L["dungeon_the_motherlode"]             = "Das RIESENFLÖZ!!"
L["dungeon_necrotic_wake"]              = "Die Nekrotische Schneise"
L["dungeon_plaguefall"]                 = "Seuchensturz"
L["dungeon_mists_of_tirna_scithe"]      = "Die Nebel von Tirna Scithe"
L["dungeon_halls_of_atonement"]         = "Hallen der Sühne"
L["dungeon_spires_of_ascension"]        = "Spitzen des Aufstiegs"
L["dungeon_theatre_of_pain"]            = "Theater der Schmerzen"
L["dungeon_de_other_side"]              = "Die Andre Seite"
L["dungeon_sanguine_depths"]            = "Die Blutigen Tiefen"
L["dungeon_tazavesh_veiled_market"]     = "Tazavesh, der Verhüllte Markt"
L["dungeon_nokhud_offensive"]           = "Angriff der Nokhud"
L["dungeon_azure_vault"]                = "Azurblaues Gewölbe"
L["dungeon_uldaman"]                    = "Uldaman: Vermächtnis von Tyr"
L["dungeon_neltharus"]                  = "Neltharus"
L["dungeon_brackenhide_hollow"]         = "Brackenfellhöhle"
L["dungeon_halls_of_infusion"]          = "Hallen der Infusion"
L["dungeon_dawn_of_the_infinite"]       = "Dämmerung des Ewigen"
L["dungeon_city_of_threads"]            = "Stadt der Fäden"
L["dungeon_ara_kara"]                   = "Ara-Kara, Stadt der Echos"
L["dungeon_stonevault"]                 = "Das Steingewölbe"
L["dungeon_dawnbreaker"]                = "Die Morgenbringer"
L["dungeon_the_rookery"]                = "Die Brutstätte"
L["dungeon_darkflame_cleft"]            = "Dunkelflammenspalt"
L["dungeon_cinderbrew_brewery"]         = "Metbrauerei Glutbräu"
L["dungeon_priory_of_the_sacred_flame"] = "Priorat der Heiligen Flamme"
L["dungeon_operation_floodgate"]        = "Operation: Schleuse"
L["dungeon_echo_dome_aldani"]           = "Biokuppel Al'dani"

------------------------------------------------------------------------
-- Reiter Schlachtzüge
------------------------------------------------------------------------
L["raid_diff_lfr"]            = "LFR / Welt"
L["raid_diff_normal"]         = "Normal"
L["raid_diff_heroic"]         = "Heroisch"
L["raid_diff_mythic"]         = "Mythisch"
L["raid_hint"]                = "Hake einen Raidboss an, um den Bonus Roll nach jedem Kill automatisch zu passen. Nicht angehakte Bosse sind davon nicht betroffen."
L["raid_diff_autopass_title"] = "Bonusroll Auto-Pass nach Schwierigkeit"
L["raid_diff_autopass_hint"]  = "Passt den Bonus Roll für alle Bosse der gewählten Schwierigkeit automatisch, kombinierbar mit den einzelnen Boss-Checkboxen unten."

------------------------------------------------------------------------
-- Season 1 Schlachtzüge (Leerenspitze, Traumriss, Marsch auf Quel'Danas, Sporenfall)
------------------------------------------------------------------------
L["raid_voidspire"]             = "Die Leerenspitze"
L["raid_dreamrift"]             = "Der Traumriss"
L["raid_march_queldanas"]       = "Marsch auf Quel'Danas"
L["raid_sporefall"]             = "Sporenfall"
L["boss_imperator_averzian"]    = "Imperator Averzian"
L["boss_vorasius"]              = "Vorasius"
L["boss_vaelgor_ezzorak"]       = "Vaelgor & Ezzorak"
L["boss_fallen_king_salhadaar"] = "Gefallener König Salhadaar"
L["boss_lightblinded_vanguard"] = "Lichtblinde Vorhut"
L["boss_crown_of_the_cosmos"]   = "Krone des Kosmos"
L["boss_chimaerus"]             = "Chimaerus, der ungeträumte Gott"
L["boss_beloren"]               = "Belo'ren, Kind von Al'ar"
L["boss_midnight_falls"]        = "Anbruch der Mitternacht"
L["boss_rotmire"]               = "Rottmoor"

------------------------------------------------------------------------
-- Season 2 Schlachtzug: Der Giftige Abgrund
------------------------------------------------------------------------
L["raid_venomous_abyss"]         = "Der Giftige Abgrund"
L["boss_nekzali_the_soulcoiler"] = "Nek'zali die Seelenwinderin"
L["boss_entombed_sentinels"]     = "Eingeschlossene Wächter"
L["boss_vashnik_the_malignant"]  = "Vashnik der Bösartige"
L["boss_the_lost_explorers"]     = "Die verirrten Entdecker"
L["boss_sszorak"]                = "Sszorak"
L["boss_the_twin_fangs"]         = "Die Zwillingsfänge"
L["boss_the_coiled_altar"]       = "Der Gewundene Altar"
L["boss_ulatek"]                 = "Ula'tek"

------------------------------------------------------------------------
-- Season 2 Lair: Die Gezeitengebundene Grotte
------------------------------------------------------------------------
L["raid_tidebound_grotto"]    = "Die Gezeitengebundene Grotte"
L["boss_nymrissa_wavecaller"] = "Nymrissa Wellenrufer"

------------------------------------------------------------------------
-- 12.1.5 Schlachtzug: Die Entfesslung von Kith'ix
------------------------------------------------------------------------
L["raid_unbinding_of_kithix"] = "Die Entfesslung von Kith'ix" -- 12.1.5
L["boss_kithix"]              = "Kith'ix"

------------------------------------------------------------------------
-- Reiter Tiefen
------------------------------------------------------------------------
L["season1_delve_hint"]       = "Hake eine Tiefe an, um den Bonus Roll nach jedem Abschluss automatisch zu passen. Nicht angehakte Tiefen sind davon nicht betroffen."
L["delve_autopass_all_label"] = "ALLE Tiefen automatisch passen (jede Season)"

------------------------------------------------------------------------
-- Season 1 Tiefen-Namen (= lokalisierter Rückgabewert von GetInstanceInfo)
------------------------------------------------------------------------
L["delve_academic_unrest"]       = "Akademischer Aufruhr"
L["delve_shadow_enclave"]        = "Die Schattenenklave"
L["delve_parhelion_plaza"]       = "Parhelionplaza"
L["delve_grufts_twilight_blade"] = "Gruften der Zwielichtklinge"
L["delve_atal_aman"]             = "Atal'Aman"
L["delve_the_grudge_pit"]        = "Die Grollgrube"
L["delve_gulf_of_memory"]        = "Die Kluft der Erinnerung"
L["delve_sunkiller_sanctum"]     = "Sonnentötersanktum"
L["delve_torments_rise"]         = "Anhöhe der Qual"
L["delve_shadowguard_point"]     = "Schattenwachtspitze"
L["delve_the_darkway"]           = "Der Düsterweg"

------------------------------------------------------------------------
-- Season 2 Tiefen-Namen (12.1)
------------------------------------------------------------------------
L["delve_ring_of_glory"]         = "Der Ring des Ruhms"
L["delve_gnarldor_isle"]         = "Knardorinsel"
L["delve_venomfall_deeps"]       = "Giftfalltiefen"
L["delve_labyrinth_of_kindojan"] = "Das Labyrinth von Kindo'jan" -- 12.1.5

------------------------------------------------------------------------
-- Offene Welt (Beutejagd & Weltbosse)
------------------------------------------------------------------------
L["prey_title"]        = "Beutejagd"
L["prey_hint"]         = "Wenn aktiviert, wird der Bonus Roll bei Beutejagd-Begegnungen in den Midnight-Gebieten der offenen Welt automatisch gepasst."
L["prey_toggle_label"] = "Auto-Pass für Beutejagd aktivieren"

------------------------------------------------------------------------
-- Reiter Legacy-Schlachtzüge
------------------------------------------------------------------------
L["legacy_section_title"]             = "Legacy"
L["legacy_enable_label"]              = "Auto-Roll für Legacy-Schlachtzüge aktivieren (Dragonflight & The War Within)"
L["legacy_tab_title"]                 = "Legacy-Schlachtzüge"
L["legacy_tab_hint"]                  = "Hake einen Schlachtzug an, um automatisch auf alle Beute daraus zu würfeln. Aktiviere die gewünschten Würfeltypen — Bedarf hat die höchste Priorität, dann Gier, dann Transmog; alle drei können als Fallback-Kette aktiv sein. Passen passt stattdessen auf alles (die anderen drei sind dann aus). Ist nichts ausgewählt, wird nichts automatisch gewürfelt."
L["legacy_account_wide_label"]        = "Legacy-Einstellungen für alle Charaktere übernehmen"
L["legacy_roll_label"]                = "Würfeltyp wenn Beute droppt:"
L["legacy_roll_need"]                 = "Bedarf"
L["legacy_roll_greed"]                = "Gier"
L["legacy_roll_transmog"]             = "Transmog"
L["legacy_roll_pass"]                 = "Passen"
L["legacy_col_dragonflight"]          = "Dragonflight"
L["legacy_col_tww"]                   = "The War Within"
L["legacy_raid_vault_of_incarnates"]  = "Gewölbe der Inkarnationen"
L["legacy_raid_aberrus"]              = "Aberrus, Schmelztiegel der Schatten"
L["legacy_raid_amirdrassil"]          = "Amirdrassil, Hoffnung des Traums"
L["legacy_raid_nerubar_palace"]       = "Palast der Nerub'ar"
L["legacy_raid_liberation_undermine"] = "Befreiung von Lorenhall"
L["legacy_raid_manaforge_omega"]      = "Manaschmiede Omega"

------------------------------------------------------------------------
-- Erweiterungsnamen
------------------------------------------------------------------------
L["expansion_tbc"]          = "The Burning Crusade"
L["expansion_wrath"]        = "Wrath of the Lich King"
L["expansion_cataclysm"]    = "Cataclysm"
L["expansion_mop"]          = "Mists of Pandaria"
L["expansion_wod"]          = "Warlords of Draenor"
L["expansion_legion"]       = "Legion"
L["expansion_bfa"]          = "Battle for Azeroth"
L["expansion_shadowlands"]  = "Shadowlands"
L["expansion_dragonflight"] = "Dragonflight"
L["expansion_tww"]          = "The War Within"
L["expansion_midnight"]     = "Midnight"

------------------------------------------------------------------------
-- Portalübersicht (/rat) und Teleport-Hinweis
------------------------------------------------------------------------
L["portal_overview_title"]          = "RollAway Portale"
L["portal_overview_tab_season"]     = "Aktuelle Season"
L["portal_overview_tab_dungeons"]   = "Alle Dungeons"
L["portal_overview_tab_settings"]   = "Optionen"
L["portal_cfg_labels"]              = "Kurznamen der Dungeons anzeigen"
L["portal_cfg_iconsize"]            = "Symbolgröße: %d"
L["portal_cfg_gap"]                 = "Abstand zwischen Symbolen: %d px"
L["portal_cfg_perrow"]              = "Symbole pro Reihe: %d"
L["portal_cfg_labelsize"]           = "Größe der Kurznamen: %d"
L["portal_cfg_default"]             = "Standard"
L["portal_overview_empty"]          = "Noch keine Portale erlernt"
L["portal_overview_current_season"] = "Season %d"
L["teleport_reminder_generic"]      = "Mythisch-Plus-Gruppe bereit - Portale verfügbar"
L["teleport_reminder_locked"]       = "Portal noch nicht freigeschaltet"

------------------------------------------------------------------------
-- Automatisches Kampflog
------------------------------------------------------------------------
L["qol_nav_logs"]                  = "Logs"
L["qol_log_enable_label"]          = "Automatisches Kampflog für ausgewählte Inhalte:"
L["qol_log_enable_info"]           = "Schaltet /combatlog beim Betreten/Verlassen passender Inhalte automatisch um und aktiviert dabei das Erweiterte Kampflog. Datei liegt danach unter Logs\\WoWCombatLog.txt in deinem WoW-Ordner, hochladbar auf Seiten wie warcraftlogs.com – nach dem Hochladen ruhig löschen, sonst wächst sie mit der Zeit."
L["qol_log_scenario_label"]        = "Szenarien & Tiefen"
L["qol_log_dungeon_label"]         = "Dungeons (Mythisch, Mythisch+)"
L["qol_log_raid_mythic_label"]     = "Schlachtzug: Mythisch"
L["qol_log_raid_heroic_label"]     = "Schlachtzug: Heroisch"
L["qol_log_raid_normal_label"]     = "Schlachtzug: Normal"
L["qol_log_raid_lfr_label"]        = "Schlachtzug: Schlachtzugsbrowser"
L["qol_log_raid_current_label"]    = "Schlachtzüge: nur aktuelle Season (alle anderen Schlachtzüge auslassen)"
L["qol_log_chatnotify_label"]      = "Chat-Meldung beim Start/Stop des Kampflogs"
L["qol_log_advlog_reminder_label"] = "Erinnern, falls das Erweiterte Kampflog aus ist (M+/Schlachtzug)"
L["advlog_reminder_msg"]           = "Das Erweiterte Kampflog ist aus. Aktivierbar unter Optionen > Kampflog für volle Details auf WarcraftLogs."
L["qol_log_chat_started"]          = "Kampflog gestartet."
L["qol_log_chat_stopped"]          = "Kampflog gestoppt."

------------------------------------------------------------------------
-- LFG Quick Create
------------------------------------------------------------------------
L["qol_lfgqc_label"]           = "Dungeon-Schnellauswahl in der Gruppensuche anzeigen"
L["qol_lfgqc_info"]            = "Fügt Dungeon-Icon-Buttons unterhalb des Gruppennamens ein, wenn du eine Mythisch+-Gruppe erstellst. Klick auf ein Icon wählt den Dungeon direkt aus und erstellt die Gruppe."
L["qol_lfgqc_automplus_label"] = "Schwierigkeit Mythisch+ vorwählen"
L["qol_lfgqc_automplus_info"]  = "Stellt die Schwierigkeit der erstellten Gruppe auf Mythisch+ statt auf das Standard-Mythisch, beim Öffnen des Formulars und nach der Dungeon-Auswahl. Eine von Hand gewählte andere Schwierigkeit bleibt möglich. Das Dropdown zeigt evtl. weiter Mythisch an."
L["qol_lfgqc_namefirst"]       = "Bitte zuerst einen Gruppennamen eingeben."
L["qol_lfgqc_autops_label"]    = "Standard-Spielstil in der Gruppensuche automatisch setzen"
L["qol_lfgqc_autops_info"]     = "Setzt den ausgewählten Spielstil automatisch. Funktioniert unabhängig von den Dungeon-Buttons."
L["qol_lfgqc_playstyle_label"] = "Standard-Spielstil:"
L["qol_lfgqc_ps_none"]         = "Nicht vorauswählen"
L["qol_lfgqc_ps_standard"]     = "Lernen"
L["qol_lfgqc_ps_relaxed"]      = "Entspannt"
L["qol_lfgqc_ps_competitive"]  = "Kompetitiv"
L["qol_lfgqc_ps_carry"]        = "Beförderung angeboten"

------------------------------------------------------------------------
-- Handwerk (Salvage-Slot)
------------------------------------------------------------------------
L["qol_salvage_slot_label"]   = "Handwerk: Verwerten-Slot automatisch füllen"
L["qol_salvage_slot_info"]    = "Bei Verwerten-Rezepten wie Fisch zu Filet in Kochkunst: legt den ersten Gegenstand, den du hast, in den Slot – in der Reihenfolge der Spiel-Liste, sobald der Stapel groß genug ist. Füllt neu, wenn der Stapel aufgebraucht ist. Es werden nur Gegenstände benutzt, die du in der Liste anhakst (roten Text im Berufe-Fenster anklicken); eine Checkbox dort schaltet es an und aus. |cffff4040Benutzung auf eigene Gefahr: Mit Pech werden auch teure Materialien (z. B. teurer frischer Fisch) verbraucht.|r"
L["qol_salvage_slot_warning"] = "RollAway: Auto-Slot – Material wählen (%d)"
L["salvage_panel_title"]      = "Auto-Slot: Materialien"
L["salvage_panel_hint"]       = "Nur angehakte Gegenstände werden automatisch eingelegt. Vorsicht bei teuren Materialien!"
L["salvage_panel_tip"]        = "Klick: erlauben / sperren"
L["salvage_panel_link_tip"]   = "Klick: Materialien wählen, die benutzt werden dürfen"
L["salvage_panel_all"]        = "Alle"
L["salvage_panel_none"]       = "Keine"

------------------------------------------------------------------------
-- Minimap-Button
------------------------------------------------------------------------
L["feat_mm_left"]              = "Linksklick: Funktionsübersicht"
L["feat_mm_right"]             = "Rechtsklick: Optionen"
L["feat_mm_drag"]              = "Ziehen: Button verschieben"
L["qol_hide_minimapbtn_label"] = "RollAway-Minimap-Button ausblenden"
L["qol_hide_minimapbtn_info"]  = "Der Button öffnet die Funktionsübersicht (Linksklick) und die Optionen (Rechtsklick). /raw features geht auch ohne ihn."

------------------------------------------------------------------------
-- QoL
------------------------------------------------------------------------
L["qol_section_title"]             = "QoL"
L["qol_panel_title"]               = "Quality of Life"
L["qol_panel_info"]                = "Kleine Verbesserungen für den täglichen Spielalltag."
L["qol_reminder_section"]          = "Hinweise"
L["qol_nav_group"]                 = "Gruppe"
L["qol_nav_craft"]                 = "Handwerk & Händler"
L["qol_nav_quests"]                = "Quests"
L["qol_nav_character"]             = "Charakter"
L["qol_nav_class"]                 = "Klasse"
L["qol_nav_hide"]                  = "Ausblenden"
L["qol_hide_talkinghead_label"]    = "Talking Head ausblenden"
L["qol_hide_talkinghead_info"]     = "Blendet das vertonte Dialogfenster am oberen Bildschirmrand aus. Die Questtexte bleiben im Questlog lesbar."
L["qol_hide_bossbanner_label"]     = "Boss-Banner ausblenden"
L["qol_hide_bossbanner_info"]      = "Blendet das Banner mit der Beuteliste nach einem Bosskill aus. Die Beute landet trotzdem im Inventar und im Chat."
L["qol_hide_eventtoasts_label"]    = "Event-Hinweise und Bonusziel-Banner ausblenden"
L["qol_hide_eventtoasts_info"]     = "Blendet die Einblendungen am oberen Bildschirmrand aus, z. B. \"Neuer Inhalt freigeschaltet\", sowie das Banner, das beim Betreten eines Bonusziels oder beim Start einer Weltquest erscheint. Das Ziel erscheint trotzdem im Tracker."
L["qol_hide_alerts_label"]         = "Benachrichtigungen ausblenden"
L["qol_hide_alerts_info"]          = "Blendet die Hinweisfenster für erhaltene Beute (\"Ihr habt erhalten: ...\"), Erfolge, neue Reittiere, Haustiere und Spielzeuge, Dungeon-Belohnungen und Ähnliches aus. Die Gegenstände erhältst du trotzdem."
L["qol_hide_errors_label"]         = "Rote Fehlermeldungen ausblenden"
L["qol_hide_errors_info"]          = "Blendet den roten Fehlertext in der Bildschirmmitte aus (z. B. \"Zauber noch nicht bereit\"). Meldungen, die erklären, warum eine Aktion nicht klappt, bleiben sichtbar: volle Taschen oder volles Questlog, Probleme bei der Questabgabe, Beute, Ablehnungen bei Händler, Post und Handel, Abstimmungs-Kick, Tod."
L["qol_hide_infomsg_label"]        = "Auch gelbe Meldungen ausblenden (Questfortschritt usw.)"
L["qol_quests_accept_label"]       = "Automatisch annehmen:"
L["qol_quests_regular_label"]      = "Normale Quests"
L["qol_quests_daily_label"]        = "Tägliche Quests"
L["qol_quests_weekly_label"]       = "Wöchentliche Quests"
L["qol_quests_turnin_label"]       = "Abgeschlossene Quests automatisch abgeben"
L["qol_quests_turnin_info"]        = "Gibt fertige Quests beim Ansprechen des NPCs ab. Nur wenn höchstens eine Belohnung zur Auswahl steht und nie bei Quests, die Gold oder Währung kosten."
L["qol_quests_modifier_label"]     = "Nur mit gedrückter Zusatztaste automatisieren"
L["qol_quests_modifier_info"]      = "Aus: Die gedrückte Taste pausiert die Automatik. An: Quests werden nur automatisiert, solange die Taste gehalten wird."
L["qol_quests_modkey_label"]       = "Zusatztaste:"
L["qol_readycheck_label"]          = "Talent-Erinnerung beim Ready Check anzeigen"
L["qol_readycheck_info"]           = "Zeigt einen 'Talente prüfen' Hinweis, wenn ein Ready Check in einem Dungeon oder Schlachtzug gestartet wird."
L["qol_readycheck_showspec_label"] = "Aktive Talent-Skillung anzeigen"
L["qol_lock_position_label"]       = "Erinnerungs-Position fixieren (Talente, Haltbarkeit, Beitritt)"
L["qol_reset_position_button"]     = "Position zurücksetzen"
L["qol_durability_label"]          = "Haltbarkeitswarnung anzeigen"
L["qol_durability_info"]           = "Zeigt eine Warnung, wenn die niedrigste Haltbarkeit deiner Ausrüstung auf 30% oder darunter fällt."
L["qol_durability_warning"]        = "Niedrige Haltbarkeit: %s"
L["qol_join_reminder_label"]       = "Instanzname beim Gruppen-Join anzeigen"
L["qol_join_reminder_info"]        = "Zeigt den Instanznamen beim Gruppenbeitritt an. Verschwindet nach 6 Sekunden."
L["qol_autoaccept_label"]          = "Einladungen von Gilde/Freunden automatisch annehmen"
L["qol_autoaccept_info"]           = "Nimmt Gruppeneinladungen von Gildenmitgliedern, Freunden und Battle.net-Freunden automatisch an."
L["qol_autorepair_label"]          = "Automatische Reparatur"
L["qol_autorepair_info"]           = "Repariert automatisch beim Händler."
L["qol_tankmark_label"]            = "Anbieten, den Tank zu markieren"
L["qol_tankmark_info"]             = "Zeigt in einem Mythic-Dungeon der aktuellen Season ein Popup mit Markieren-Button für den Tank deiner Gruppe. Der Klick ist nötig, weil Addons selbst keine Markierungen setzen dürfen. /rawtank testet es überall."
L["qol_tankmark_icon_label"]       = "Markierung für den Tank"
L["tankmark_button"]               = "Markieren"
L["tankmark_msg"]                  = "Tank %s mit %s markieren?"
L["qol_autorepair_none"]           = "Nichts"
L["qol_autorepair_player"]         = "Spieler"
L["qol_autorepair_guild"]          = "Gilde"
L["qol_autorepair_msg_player"]     = "Automatisch repariert für %s (Spieler)"
L["qol_autorepair_msg_guild"]      = "Automatisch repariert für %s (Gildenbank)"
L["qol_join_keyaddon_label"]       = "Begleit-Addon für Schlüsselsteine mit Hinweis öffnen:"
L["qol_join_keyaddon_info"]        = "Öffnet die gewählte Teleport-Hilfe bei Mythisch-Plus-Gruppen. Schließt nach Teleport, spätestens nach 20 Sekunden. Schlachtzüge nutzen den Hinweis oben."
L["qol_join_keyaddon_bigwigs"]     = "BigWigs"
L["qol_join_keyaddon_details"]     = "Details!"
L["qol_join_keyaddon_teleport"]    = "RollAway Teleport-Hinweis"
L["qol_expansion_filter_label"]    = "'Nur aktuelle Erweiterung' automatisch setzen (AH und Handwerk)"
L["qol_expansion_filter_info"]     = "Aktiviert den Filter 'Nur aktuelle Erweiterung' automatisch beim Öffnen des Auktionshauses oder der Handwerksaufträge."
L["qol_vault_currency_label"]      = "Leerenkern-Anzahl in der Großen Schatzkammer anzeigen"
L["qol_vault_currency_info"]       = "Zeigt den aktuellen Nebulösen Leerenkern (Bonusbeute) Stand unten rechts im Fenster der Großen Schatzkammer an."
L["qol_vault_currency_name"]       = "Bonusbeute"
L["qol_vendor_filter_label"]       = "Vendor Filter Light: bekannte Händler-Items abdunkeln"
L["qol_vendor_filter_info"]        = "Dunkelt bereits bekannte Rezepte, Toys, Mounts, Erbstücke und besessene Housing-Deko beim Händler ab, Pets erst bei der Höchstanzahl, außerdem jedes Item, dessen Aussehen du schon hast (auch normale Rüstung, Tabards und Illusionen). Kein Dropdown, nur passives Abdunkeln."
L["qol_vendor_filter_alpha_label"] = "Transparenz bekannter Items"
L["qol_omniumfoliant_label"]       = "Omniumfoliant-Symbol auf der Minimap ausblenden"
L["qol_omniumfoliant_info"]        = "Blendet das Omniumfoliant-Symbol auf der Minimap aus und fügt stattdessen einen Button unten rechts im Charakterfenster hinzu."
L["qol_vault_button_label"]        = "Schatzkammer-Button am Charakterfenster anzeigen"
L["qol_vault_button_info"]         = "Fügt neben dem Omniumfoliant-Button einen Button hinzu, der die Große Schatzkammer direkt öffnet — ohne Gruppensuche, Makro oder den Tresor bei der Bank."
L["qol_map_activity_label"]        = "Bounty-Board, Fraktions-Button und Auge der Karte ausblenden"
L["qol_map_activity_info"]         = "Blendet das Bounty-Board, den Button zum Wechseln bzw. Beenden der Aktivitäten einer verfolgten Fraktion und das N'Zoth-Auge unten links auf der Weltkarte aus. Experimentell — kann nach einem Blizzard-UI-Update aufhören zu funktionieren."
L["qol_crafting_output_log_label"] = "Handwerksergebnisse-Fenster ausblenden"
L["qol_crafting_output_log_info"]  = "Blendet das kleine Popup aus, in dem deine hergestellten Gegenstände angezeigt werden, während du einen Beruf ausübst."
L["qol_vault_button_tooltip"]      = "Große Schatzkammer öffnen"
L["qol_fontsize_label"]            = "Schriftgröße"
L["qol_check_talents"]             = "Talente prüfen"
L["qol_pet_reminder_label"]        = "Pet-Erinnerung in Dungeons und Schlachtzügen"
L["qol_pet_reminder_info"]         = "Zeigt beim Betreten eines aktuellen Dungeons oder Schlachtzugs kurz den Hinweis „Pet neu beschwören.“ – als Absicherung gegen den Pet-Bug nach dem Tod des Pets (wiederbeleben, freilassen und neu beschwören). Erscheint bei jedem Betreten, egal ob dein Pet gerade lebt."
L["qol_pet_reminder_text"]         = "Pet neu beschwören."
L["qol_check_talents_fmt"]         = "Talente prüfen (%s)"

------------------------------------------------------------------------
-- Profil-Migration (3.0.1)
------------------------------------------------------------------------
L["profile_migration_popup_text"] = "RollAway-Einstellungen sind jetzt charakterspezifisch. Aktuelle Einstellungen für diesen Charakter übernehmen, oder auf Standard zurücksetzen?"
L["profile_migration_keep"]       = "Aktuelle Einstellungen übernehmen"
L["profile_migration_default"]    = "Auf Standard zurücksetzen"

------------------------------------------------------------------------
-- Profil-Seite
------------------------------------------------------------------------
L["profile_section_title"]      = "Profil"
L["profile_panel_title"]        = "Profil"
L["profile_panel_info"]         = "Einstellungen sind standardmäßig charakterspezifisch. Nutze Profile, um Einstellungen zwischen Charakteren zu teilen, oder behalte separate Setups pro Charakter/Spec. Bonus-Roll-Auswahlen (Dungeons/Schlachtzüge/Tiefen/Offene Welt) sind immer charakterspezifisch und nie Teil eines Profils."
L["profile_active_label"]       = "Aktives Profil:"
L["profile_other_label"]        = "Anderes Profil:"
L["profile_new_button"]         = "Neu"
L["profile_copy_button"]        = "Kopieren von"
L["profile_delete_button"]      = "Löschen"
L["profile_export_button"]      = "Exportieren"
L["profile_import_button"]      = "Importieren"
L["profile_export_info"]        = "Exportiert wird das aktive Profil:"
L["profile_none_available"]     = "Keine anderen Profile"
L["profile_reset_button"]       = "Profil zurücksetzen"
L["profile_new_prompt"]         = "Namen für das neue Profil eingeben:"
L["profile_delete_confirm"]     = "Profil '%s' löschen? Das kann nicht rückgängig gemacht werden."
L["profile_reset_confirm"]      = "Aktuelles Profil auf Standardeinstellungen zurücksetzen? Das kann nicht rückgängig gemacht werden."
L["profile_export_prompt"]      = "Export-Code des aktiven Profils (Strg+C zum Kopieren):"
L["profile_export_failed"]      = "RollAway: Profil-Export fehlgeschlagen."
L["profile_import_prompt"]      = "Export-Code einfügen (Strg+V):"
L["profile_import_invalid"]     = "RollAway: Ungültiger oder beschädigter Export-Code."
L["profile_import_name_prompt"] = "Namen für das importierte Profil eingeben:"
L["profile_reload_prompt"]      = "Profil geändert. UI jetzt neu laden, um es überall anzuwenden?"
L["profile_reload_now"]         = "UI neu laden"

------------------------------------------------------------------------
-- Paragon
------------------------------------------------------------------------
L["paragon_alert_label"]              = "Benachrichtigen wenn Paragon-Taschen-Quests verfügbar sind"
L["paragon_alert_info"]               = "Zeigt beim Login ein Popup, wenn Paragon-Taschen-Quests im Questlog vorhanden sind, und wenn eine neue angenommen wird. Mit /rawparagon manuell prüfen."
L["paragon_count_one"]                = "%d Paragon Tasche bereit:"
L["paragon_count_many"]               = "%d Paragon Taschen bereit:"
L["paragon_location"]                 = " |cff999999(%s — %s)|r"
L["paragon_none"]                     = "Keine Paragon-Taschen verfügbar."
L["paragon_faction_slayers_duellum"]  = "Schlächterduellum"
L["paragon_faction_singularity"]      = "Die Singularität"
L["paragon_faction_silvermoon_court"] = "Hof in Silbermond"
L["paragon_faction_ritual_sites"]     = "Ritualstätten"
L["paragon_faction_harati"]           = "Hara'ti"
L["paragon_faction_amani_tribe"]      = "Amanistamm"
L["paragon_faction_zuljarras_forces"] = "Zul'jarras Streitkräfte"

------------------------------------------------------------------------
-- Paragon: Abgabe-NPC + Zone pro Quest (verifiziert, Patch 12.0.7)
------------------------------------------------------------------------
L["paragon_npc_94492"]  = "Thraxadar"
L["paragon_zone_94492"] = "Hort der Meister"
L["paragon_npc_89032"]  = "Leerenforscher Anomander"
L["paragon_zone_89032"] = "Heulender Grat"
L["paragon_npc_93811"]  = "Caeris Morgenlicht"
L["paragon_zone_93811"] = "Saltherils Hafen"
L["paragon_npc_95391"]  = "Lady Dunkeltal"
L["paragon_zone_95391"] = "Silbermond"
L["paragon_npc_89035"]  = "Naynar"
L["paragon_zone_89035"] = "Die Höhle"
L["paragon_npc_93566"]  = "Magovu"
L["paragon_zone_93566"] = "Amani'zar"

------------------------------------------------------------------------
-- Great Vault
------------------------------------------------------------------------
L["greatvault_alert_label"] = "Hinweis bei offenen Belohnungen der Großen Schatzkammer"
L["greatvault_alert_info"]  = "Zeigt beim Login ein Popup, wenn unabgeholte Belohnungen in der Großen Schatzkammer vorhanden sind. Erscheint bei jedem Login, bis die Belohnungen abgeholt sind. Mit /rawvault manuell prüfen."
L["greatvault_alert_msg"]   = "Du hast unabgeholte Belohnungen in der Großen Schatzkammer!"
L["greatvault_none"]        = "Keine unabgeholten Belohnungen in der Großen Schatzkammer."

------------------------------------------------------------------------
-- What's New
------------------------------------------------------------------------
L["whatsnew_portal_title"]      = "Portalübersicht: Kurznamen und Optionen"
L["whatsnew_portal_desc"]       = "Die Portal-Buttons zeigen den Kurznamen des Dungeons (z.B. WS, AOF). Ein neuer Reiter Optionen stellt Symbolgröße, Abstand, Symbole pro Reihe und die Kurznamen ein; mit Standard setzt du alles zurück."
L["whatsnew_portal_location"]   = "Portalübersicht (/rat) > Optionen"
L["whatsnew_salvage_title"]     = "Zahl in der Verwerten-Liste"
L["whatsnew_salvage_desc"]      = "Die Zahl in Klammern neben einem Verwerten-Rezept in der Rezeptliste zählt jetzt nur die Materialien, die du angehakt hast, auch die in deiner Kriegsmeutenbank."
L["whatsnew_salvage_location"]  = "Berufe-Fenster"
L["whatsnew_options_label"]     = "Optionen:"

------------------------------------------------------------------------
-- Funktionsübersicht (/raw features)
------------------------------------------------------------------------
L["feat_title"]              = "RollAway & Tools - Funktionen"
L["feat_hint"]               = "Häkchen schaltet die Funktion, Klick auf die Zeile öffnet ihre Einstellungen."
L["feat_on"]                 = "An"
L["feat_off"]                = "Aus"
L["feat_section_loot"]       = "Beute"
L["feat_section_bonusroll"]  = "Bonusroll"
L["feat_section_commands"]   = "Befehle"
L["feat_legacy"]             = "Würfelt automatisch auf Beute aus älteren Schlachtzügen (Dragonflight, The War Within) mit den gewählten Würfeltypen."
L["feat_name_dungeons"]      = "Auto-Pass: Dungeons"
L["feat_dungeons"]           = "Passt den Bonusroll nach jedem angehakten Dungeon."
L["feat_name_raids"]         = "Auto-Pass: Schlachtzüge"
L["feat_raids"]              = "Passt den Bonusroll nach jedem angehakten Schlachtzugsboss oder Schlachtzug-Schwierigkeitsgrad."
L["feat_name_delves"]        = "Auto-Pass: Tiefen"
L["feat_delves"]             = "Passt den Bonusroll nach jeder angehakten Tiefe."
L["feat_name_prey"]          = "Auto-Pass: Beutejagd"
L["feat_prey"]               = "Passt den Bonusroll bei Beutejagd-Begegnungen in der offenen Welt."
L["feat_name_reminder"]      = "Bonusroll-Erinnerung"
L["feat_name_warning"]       = "Auto-Pass-Warnung"
L["feat_name_quests_accept"] = "Quests automatisch annehmen"
L["feat_quests_accept"]      = "Nimmt normale, tägliche und wöchentliche Quests an, je nach Auswahl."
L["cmd_rawfeatures_info"]    = "Diese Funktionsübersicht öffnen"
L["feat_button"]             = "Funktionen"
L["feat_combat"]             = "Im Kampf nicht möglich."

------------------------------------------------------------------------
-- Entwickler
------------------------------------------------------------------------
L["debug_label"]             = "Debug-Modus (Ausgabe im Debug-Log-Fenster)"
L["debug_errors_only_label"] = "Nur Self-Heal-Fehler loggen (ohne volle Debug-Ausgabe)"

------------------------------------------------------------------------
-- Entwickler-Befehle
------------------------------------------------------------------------
L["cmd_rawtest_info"]         = "Manueller Auto-Pass Test"
L["cmd_rawreminder_info"]     = "Reminder-Popup testen"
L["cmd_rawreset_info"]        = "Reminder-Status zurücksetzen (erscheint beim nächsten Betreten wieder)"
L["cmd_rawqol_info"]          = "QoL-Reminder testen"
L["cmd_rawwhats_info"]        = "What's-New-Popup anzeigen (nur Dev/Tester)"
L["cmd_rawparagon_info"]      = "Manueller Paragon-Taschen-Quest-Check (für alle Nutzer verfügbar)"
L["cmd_raw_info"]             = "Optionen öffnen"
L["cmd_rat_info"]             = "Portal-Übersicht ein-/ausblenden"
L["cmd_rawvault_info"]        = "Große Schatzkammer manuell prüfen"
L["cmd_rawtank_info"]         = "Tank-Markierungs-Popup sofort zeigen"
L["cmd_rawlog_info"]          = "Debug-Log-Fenster öffnen / schließen"
L["cmd_rawdump_info"]         = "Instanz-Infos ins Log schreiben"
L["cmd_rawraids_info"]        = "Encounter-Journal-Tiers und ihre Schlachtzüge ins Log"
L["cmd_rawraids_done"]        = "Schlachtzug-Tiers ins Debug-Log geschrieben (/rawlog)."
L["cmd_rawdungeons_info"]     = "Encounter-Journal-Tiers, Dungeons und M+-Pool ins Log"
L["cmd_rawdungeons_done"]     = "Dungeon-Tiers ins Debug-Log geschrieben (/rawlog)."
L["cmd_rawbosses_info"]       = "[Tier|all]: Schlachtzugsbosse mit Encounter-IDs ins Log"
L["cmd_rawbosses_done"]       = "Schlachtzugsbosse ins Debug-Log geschrieben (/rawlog)."
L["cmd_rawnames_info"]        = "Die Namen des Spiels für Dungeons, Schlachtzüge, Bosse, Tiefen und Erweiterungen ins Log (für den Locale-Check)"
L["cmd_rawnames_done"]        = "Namen ins Debug-Log geschrieben (/rawlog)."
L["cmd_rawseason_info"]       = "Fertiges Lua für die laufende Season (Dungeons und Schlachtzugsbosse) ins Log"
L["cmd_rawseason_done"]       = "Season-Daten ins Debug-Log geschrieben (/rawlog)."
L["cmd_rawcharbtn_info"]      = "Zustand der Charakterfenster-Buttons ins Log schreiben"
L["cmd_rawchonkyoffset_info"] = "<Pixel>: Button-Abstand neben Chonky Character Sheet live einstellen"
L["cmd_rawtanktest_info"]     = "Tank-Marker-Testmodus an / aus"

------------------------------------------------------------------------
-- Entwickler-Einstellungen
------------------------------------------------------------------------
L["dev_section_title"]      = "Entwickler"
L["dev_panel_title"]        = "Entwickler-Werkzeuge"
L["dev_panel_info"]         = "Debug-Modus, Tests, Werkzeuge und Befehlsliste. Nur auf Entwickler-Charakteren sichtbar."
L["dev_nav_log"]            = "Protokoll"
L["dev_nav_tests"]          = "Tests"
L["dev_nav_tools"]          = "Werkzeuge"
L["dev_nav_commands"]       = "Befehle"
L["dev_debug_info"]         = "Schreibt die Diagnose des Addons ins Debug-Log-Fenster. Zeigt außerdem die anderen Seasons und die Bonusroll-Tabs unter Maximalstufe. Alle Dev-Befehle, das Log-Fenster und die Testschalter funktionieren nur damit."
L["dev_errors_only_info"]   = "Nur Self-Heal- und Watchdog-Fehler, ohne den Rest."
L["dev_log_window_label"]   = "Debug-Log-Fenster"
L["dev_log_open"]           = "Öffnen / schließen"
L["dev_log_clear"]          = "Leeren"
L["dev_log_select_all"]     = "Alles auswählen"
L["dev_log_title"]          = "Debug-Log"
L["dev_log_paused"]         = "(pausiert beim Markieren - Esc drücken)"
L["dev_log_reset"]          = "Größe und Position zurücksetzen"
L["dev_log_hint"]           = "Das Fenster lässt sich unten rechts in der Größe ändern; Größe und Position werden gemerkt."
L["dev_test_autopass"]      = "Auto-Pass-Test"
L["dev_test_reminder"]      = "Reminder-Popups"
L["dev_test_qol"]           = "QoL-Reminder"
L["dev_test_whatsnew"]      = "What's-New-Popup"
L["dev_test_reset"]         = "Reminder-Status zurücksetzen"
L["dev_tank_test_label"]    = "Tank-Marker-Testmodus (bis /reload)"
L["dev_tank_test_info"]     = "Geht auch solo und schreibt ins Debug-Log, warum das Tank-Popup erscheint oder nicht."
L["dev_oldraid_test_label"] = "Bonusroll-Auto-Pass in alten Schlachtzügen (bis /reload)"
L["dev_oldraid_test_info"]  = "Ordnet die 10/25-Spieler- und LFR-Schwierigkeiten alter Schlachtzüge (z. B. Mists of Pandaria) Normal, Heroisch und LFR zu, damit der Auto-Pass für eine ganze Schwierigkeit (Reiter Schlachtzüge) auch dort greift."
L["dev_filter_title"]       = "Log-Filter"
L["dev_filter_info"]        = "Welche Arten von Zeilen das Debug-Log anzeigt. Gilt nur für das volle Debug-Log; Fehlerzeilen und Tool-Ausgaben werden immer angezeigt."
L["dev_filter_all"]         = "Alle"
L["dev_filter_none"]        = "Keine"
L["dev_filter_zone"]        = "Zone und Instanz"
L["dev_filter_loot"]        = "Beuteverteilung und Würfe"
L["dev_filter_autopass"]    = "Bonusroll-Auto-Pass"
L["dev_filter_roll"]        = "Legacy-Würfeln und Bestätigung"
L["dev_filter_reminder"]    = "Reminder"
L["dev_filter_logs"]        = "Kampflog (Auto-Log)"
L["dev_filter_lfg"]         = "Gruppensuche-Schnellerstellung"
L["dev_filter_tank"]        = "Tank-Marker"
L["dev_filter_qol"]         = "Quality of Life"
L["dev_filter_events"]      = "Spiel-Events"
L["dev_filter_other"]       = "Sonstiges"
L["dev_tool_dump"]          = "Instanz-Info-Dump"
L["dev_tool_charbtn"]       = "Charakterfenster-Buttons"
L["dev_tool_chonky_hint"]   = "Chonky-Button-Abstand: /rawchonkyoffset <Pixel> (siehe Befehle)."
L["dev_commands_public"]    = "Für alle"
L["dev_commands_dev"]       = "Entwickler-Charaktere"
L["dev_commands_note"]      = "Alle Entwickler-Befehle (und die Schaltflächen und Testschalter hier) funktionieren nur mit Debug-Modus."
