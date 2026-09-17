-- RollAway - Locale deDE

if GetLocale() ~= "deDE" then return end

local L = _G["RollAwayLocale"]

------------------------------------------------------------------------
-- General
------------------------------------------------------------------------
L["addon_title"]              = "RollAway"

-- Tabs
L["tab_general"]              = "Allgemein"
L["tab_dungeons"]             = "Dungeons"
L["tab_raids"]                = "Raids"
L["tab_delves"]               = "Tiefen"
L["tab_prey"]                 = "Offene Welt"
L["tab_legacy"]               = "Legacy"

-- Verzögerung Slider
L["delay_section_title"]      = "Verzögerung"
L["slider_label"]             = "Fenster schließen nach %d Sekunden"
L["slider_min"]               = "5 Sek."
L["slider_max"]               = "20 Sek."

-- Sicherheits-Timeout Slider
L["timeout_section_title"]    = "Sicherheits-Timeout"
L["timeout_slider_label"]     = "Frame zwangsweise schließen nach %d Sekunden"
L["timeout_min"]              = "30 Sek."
L["timeout_max"]              = "180 Sek."
L["lootframe_feature_disable_label"] = "Automatisches Schließen/Ausblenden komplett deaktivieren (Fenster bleibt wie im Standard immer offen)"

-- Sichtbarkeit
L["visibility_section_title"] = "Sichtbarkeit"
L["visibility_info"]          = "Steuert das Gruppen-Loot-Fenster, das während der Beuteverteilung in Raids erscheint."
L["hide_in_raid_label"]       = "Gruppen-Loot-Verlauf im Raid ausblenden"
L["hide_in_raid_info"]        = "Blendet das Gruppen-Loot-Fenster für die ausgewählten Raid-Schwierigkeiten aus. Standardmäßig sichtbar."
L["raid_diff_lfr"]            = "LFR / Welt"
L["raid_diff_normal"]         = "Normal"
L["raid_diff_heroic"]         = "Heroisch"
L["raid_diff_mythic"]         = "Mythisch"
L["reminder_label"]           = "Erinnerung anzeigen beim Betreten von Dungeons & Raids"
L["reminder_info"]            = "Zeigt ein Popup beim Betreten eines Mythic-Dungeons oder Raids und erinnert dich, deine Auto-Pass-Einstellungen zu überprüfen."
L["bonusroll_reminder_section_title"] = "Bonusroll"

-- Reminder Popup
L["reminder_dungeon"]         = "Du hast einen Mythic-Dungeon betreten. Überprüfe deine Bonus Roll Auto-Pass Einstellungen."
L["reminder_raid"]            = "Du hast einen Raid betreten. Überprüfe deine Bonus Roll Auto-Pass Einstellungen."
L["reminder_voidcore"]        = "Nebulöser Leerekern: %d  –  %s %s verfügbar."
L["reminder_roll_singular"]   = "Wurf"
L["reminder_roll_plural"]     = "Würfe"
L["reminder_btn_dungeons"]    = "Dungeons öffnen"
L["reminder_btn_raids"]       = "Raids öffnen"
L["reminder_okay"]            = "Okay"

-- Legacy
L["legacy_section_title"]     = "Legacy"
L["legacy_enable_label"]      = "Auto-Roll für Legacy-Raids aktivieren (Dragonflight & The War Within)"

-- Entwickler
L["debug_section_title"]      = "Entwickler"
L["debug_label"]              = "Debug-Ausgaben im Chat anzeigen"
L["cmd_rawtest_info"]         = "Manueller Auto-Pass Test"
L["cmd_rawreminder_info"]     = "Reminder-Popup testen"
L["cmd_rawreset_info"]        = "Reminder-Status zurücksetzen (erscheint beim nächsten Betreten wieder)"
L["cmd_rawqol_info"]          = "QoL-Reminder testen"
L["cmd_rawwhats_info"]        = "What's-New-Popup anzeigen (nur Dev/Tester)"
L["cmd_rawparagon_info"]      = "Manueller Paragon-Taschen-Quest-Check (für alle Nutzer verfügbar)"


-- QoL
L["qol_section_title"]        = "QoL"
L["qol_panel_title"]          = "Quality of Life"
L["qol_panel_info"]           = "Kleine Verbesserungen für den täglichen Spielalltag."
L["qol_reminder_section"]     = "Reminder"
L["qol_filter_section"]       = "Filter"
L["qol_nav_misc"]             = "Sonstiges"
L["qol_nav_lfg"]              = "LFG"
L["qol_readycheck_label"]     = "Talent-Erinnerung beim Ready Check anzeigen"
L["qol_readycheck_info"]      = "Zeigt einen 'Talente prüfen' Hinweis, wenn ein Ready Check in einem Dungeon oder Raid gestartet wird."
L["qol_durability_label"]     = "Haltbarkeitswarnung anzeigen"
L["qol_durability_info"]      = "Zeigt eine Warnung, wenn die niedrigste Haltbarkeit deiner Ausrüstung auf 30% oder darunter fällt."
L["qol_durability_warning"]   = "Niedrige Haltbarkeit: %s"
L["qol_join_reminder_label"]  = "Instanzname beim Gruppen-Join anzeigen"
L["qol_join_reminder_info"]   = "Zeigt den Instanznamen beim Gruppenbeitritt an. Verschwindet nach 6 Sekunden."
L["qol_autoaccept_label"]     = "Einladungen von Gilde/Freunden automatisch annehmen"
L["qol_autoaccept_info"]      = "Nimmt Gruppeneinladungen von Gildenmitgliedern, Freunden und Battle.net-Freunden automatisch an. Nur Standard-UI - ElvUI hat dafür eine eigene Option."
L["qol_autorepair_label"]     = "Automatische Reparatur"
L["qol_autorepair_info"]      = "Repariert automatisch beim Händler. Nur Standard-UI - ElvUI hat dafür eine eigene Option."
L["qol_autorepair_none"]      = "Nichts"
L["qol_autorepair_player"]    = "Spieler"
L["qol_autorepair_guild"]     = "Gilde"
L["qol_autorepair_msg_player"] = "Automatisch repariert für %s (Spieler)"
L["qol_autorepair_msg_guild"]  = "Automatisch repariert für %s (Gildenbank)"
L["qol_join_keyaddon_label"]  = "Begleit-Addon für Schlüsselsteine mit Hinweis öffnen:"
L["qol_join_keyaddon_info"]      = "Öffnet die gewählte Teleport-Hilfe bei Mythisch-Plus-Gruppen. Schließt nach Teleport, spätestens nach 20 Sekunden. Raids nutzen den Hinweis oben."
L["qol_join_keyaddon_bigwigs"]   = "BigWigs"
L["qol_join_keyaddon_details"]   = "Details!"
L["qol_join_keyaddon_teleport"]  = "RollAway Teleport-Hinweis"
L["qol_premade_keyaddon_label"]  = "Begleit-Addon für manuell gebildete (Premade-) Gruppen öffnen:"
L["qol_premade_keyaddon_info"]   = "Eigene Auswahl für manuell gebildete Mythisch-Plus-Gruppen (kein Dungeon erkennbar). Schließt nach Teleport, spätestens nach 20 Sekunden."
L["teleport_reminder_generic"]   = "Mythisch-Plus-Gruppe bereit - Portale verfügbar"
L["teleport_reminder_locked"]    = "Portal noch nicht freigeschaltet"
L["qol_expansion_filter_label"] = "'Nur aktuelle Erweiterung' im Auktionshaus & Handwerksaufträgen automatisch setzen"
L["qol_expansion_filter_info"]  = "Aktiviert den Filter 'Nur aktuelle Erweiterung' automatisch beim Öffnen des Auktionshauses oder der Handwerksaufträge."
L["qol_vault_currency_label"]   = "Nebulöser Leerenkern (Bonusbeute) in der Großen Schatzkammer anzeigen"
L["qol_vault_currency_info"]    = "Zeigt den aktuellen Nebulösen Leerenkern (Bonusbeute) Stand unten rechts im Fenster der Großen Schatzkammer an."
L["qol_vault_currency_name"]    = "Bonusbeute"
L["qol_vendor_filter_label"]    = "Vendor Filter Light: bekannte Händler-Items abdunkeln"
L["qol_vendor_filter_info"]     = "Dunkelt bereits bekannte Rezepte, Toys, Mounts, Pets, Tabards, Illusionen und bereits besessene Housing-Deko beim Händler ab. Kein Dropdown, nur passives Abdunkeln."
L["qol_vendor_filter_alpha_label"] = "Transparenz bekannter Items"
L["qol_omniumfoliant_label"]    = "Omniumfoliant-Symbol auf der Minimap ausblenden, stattdessen Button am Charakterfenster anzeigen"
L["qol_omniumfoliant_info"]     = "Blendet das Omniumfoliant-Symbol auf der Minimap aus und fügt stattdessen einen Button unten rechts im Charakterfenster hinzu."
L["qol_vault_button_label"]     = "Schatzkammer-Button am Charakterfenster anzeigen"
L["qol_vault_button_info"]      = "Fügt neben dem Omniumfoliant-Button einen Button hinzu, der die Große Schatzkammer direkt öffnet — ohne Gruppensuche, Makro oder den Tresor bei der Bank."
L["qol_map_activity_label"]     = "Fraktions-Tracking-Button auf der Weltkarte ausblenden (experimentell)"
L["qol_map_activity_info"]      = "Blendet den Button unten links auf der Weltkarte aus, mit dem man zwischen Aktivitäten einer verfolgten Fraktion wechselt bzw. das Tracking beendet. Experimentell — kann nach einem Blizzard-UI-Update aufhören zu funktionieren."
L["qol_crafting_output_log_label"] = "Handwerksergebnisse-Fenster ausblenden"
L["qol_crafting_output_log_info"]  = "Blendet das kleine Popup aus, in dem deine hergestellten Gegenstände angezeigt werden, während du einen Beruf ausübst."
L["qol_vault_button_tooltip"]   = "Große Schatzkammer öffnen"

-- Auto Combat Logging
L["qol_nav_logs"]               = "Logs"
L["qol_log_enable_label"]       = "Automatisches Kampflog für ausgewählte Inhalte:"
L["qol_log_enable_info"]        = "Schaltet /combatlog beim Betreten/Verlassen passender Inhalte automatisch um und aktiviert dabei Advanced Combat Logging. Datei liegt danach unter Logs\\WoWCombatLog.txt in deinem WoW-Ordner, hochladbar auf Seiten wie warcraftlogs.com – nach dem Hochladen ruhig löschen, sonst wächst sie mit der Zeit."
L["qol_log_scenario_label"]     = "Szenarien"
L["qol_log_dungeon_label"]      = "Dungeons (Mythisch, Mythisch+)"
L["qol_log_raid_mythic_label"]  = "Schlachtzug: Mythisch"
L["qol_log_raid_heroic_label"]  = "Schlachtzug: Heroisch"
L["qol_log_raid_normal_label"]  = "Schlachtzug: Normal"
L["qol_log_raid_lfr_label"]     = "Schlachtzug: Schlachtzugsbrowser"
L["qol_log_delve_label"]        = "Tiefen"
L["qol_log_arena_label"]        = "Arena"
L["qol_log_chatnotify_label"]   = "Chat-Meldung beim Start/Stop des Kampflogs"
L["qol_log_advlog_reminder_label"] = "Erinnern, falls Advanced Combat Logging aus ist (M+/Raid)"
L["advlog_reminder_msg"]        = "Advanced Combat Logging ist aus. Aktivierbar unter Optionen > Kampflog für volle Details auf WarcraftLogs."
L["qol_log_chat_started"]       = "Kampflog gestartet."
L["qol_log_chat_stopped"]       = "Kampflog gestoppt."

-- LFG Quick Create
L["qol_lfgqc_label"]            = "Dungeon-Schnellauswahl-Buttons im Gruppensuche-Fenster anzeigen"
L["qol_lfgqc_info"]             = "Fügt Dungeon-Icon-Buttons unterhalb des Gruppennamens ein, wenn du eine Mythisch+-Gruppe erstellst. Klick auf ein Icon wählt den Dungeon direkt aus und erstellt die Gruppe."
L["qol_lfgqc_namefirst"]        = "Bitte zuerst einen Gruppennamen eingeben."
L["qol_lfgqc_autops_label"]     = "Standard-Spielstil beim Öffnen der Gruppensuche automatisch anwenden"
L["qol_lfgqc_autops_info"]      = "Setzt den ausgewählten Spielstil automatisch. Funktioniert unabhängig von den Dungeon-Buttons."
L["qol_lfgqc_playstyle_label"]  = "Standard-Spielstil:"
L["qol_lfgqc_ps_none"]          = "Nicht vorauswählen"
L["qol_lfgqc_ps_standard"]      = "Lernen"
L["qol_lfgqc_ps_relaxed"]       = "Entspannt"
L["qol_lfgqc_ps_competitive"]   = "Kompetitiv"
L["qol_lfgqc_ps_carry"]         = "Beförderung angeboten"
L["qol_fontsize_label"]       = "Schriftgröße"
L["qol_fontsize_value"]       = "Größe: %d"
L["qol_check_talents"]        = "Talente prüfen"
L["combat_action_queued"]     = "Optionen können im Kampf nicht geöffnet werden – öffnet automatisch, sobald der Kampf vorbei ist."

------------------------------------------------------------------------
-- Season 1 Dungeons
------------------------------------------------------------------------
L["season1_title"]            = "Season 1"
L["season2_tab"]              = "Season 2 (12.1)"
L["season3_tab"]              = "Season 3 (12.2)"
L["season_coming_soon"]       = "Coming soon"
L["patch_12_0"]               = "Patch 12.0"
L["patch_12_1"]               = "Patch 12.1"
L["season1_hint"]             = "Hake einen Dungeon an, um den Bonus Roll nach jedem Abschluss automatisch zu passen. Nicht angehakte Dungeons sind davon nicht betroffen."
L["dungeon_autopass_all_label"] = "ALLE Dungeons automatisch passen (jede Season)"

-- Dungeon-Namen (= lokalisierter Rückgabewert von GetInstanceInfo)
L["dungeon_windrunner_spire"]    = "Windläuferturm"
L["dungeon_maisara_caverns"]     = "Maisarakavernen"
L["dungeon_magisters_terrace"]   = "Terrasse der Magister"
L["dungeon_nexus_point_xenas"]   = "Nexuspunkt Xenas"
L["dungeon_algeth_ar_academy"]   = "Akademie von Algeth'ar"
L["dungeon_seat_of_triumvirate"] = "Sitz des Triumvirats"
L["dungeon_skyreach"]            = "Himmelsnadel"
L["dungeon_pit_of_saron"]        = "Die Grube von Saron"
-- Season 2 (12.1)
L["dungeon_altar_of_fangs"]       = "Altar der Fänge"
L["dungeon_kings_rest"]           = "Die Königsruh"
L["dungeon_ruby_life_pools"]      = "Rubinlebensbecken"
L["dungeon_temple_of_sethraliss"] = "Tempel von Sethraliss"
L["dungeon_murder_row"]          = "Mördergasse"
L["dungeon_den_of_nalorakk"]     = "Nalorakks Bau"
L["dungeon_blinding_vale"]       = "Das blendende Tal"
L["dungeon_voidscar_arena"]      = "Arena der Leerennarbe"

------------------------------------------------------------------------
-- Season 1 Raids
------------------------------------------------------------------------
L["raid_hint"]             = "Hake einen Raidboss an, um den Bonus Roll nach jedem Kill automatisch zu passen. Nicht angehakte Bosse sind davon nicht betroffen."
L["confirm_roll_title"]        = "Roll-Bestätigung"
L["confirm_roll_hint"]         = "Zeigt ein Popup zur Bestätigung, bevor du auf Gruppen-Loot würfelst. Gilt für jeden Raid, aktuell oder Legacy."
L["confirm_roll_popup"]        = "%s auf %s würfeln?"
L["confirm_type_need"]         = "Bedarf"
L["confirm_type_greed"]        = "Gier"
L["confirm_type_transmog"]     = "Transmog"
L["confirm_type_pass"]         = "Passen"
L["raid_diff_autopass_title"] = "Bonusroll Auto-Pass nach Schwierigkeit"
L["raid_diff_autopass_hint"]  = "Passt den Bonus Roll für alle Bosse der gewählten Schwierigkeit automatisch, kombinierbar mit den einzelnen Boss-Checkboxen unten."

L["raid_voidspire"]        = "Die Leerenspitze"
L["raid_dreamrift"]        = "Der Traumriss"
L["raid_march_queldanas"]  = "Marsch auf Quel'Danas"
L["raid_sporefall"]        = "Sporenfall"

L["boss_imperator_averzian"]   = "Imperator Averzian"
L["boss_vorasius"]             = "Vorasius"
L["boss_vaelgor_ezzorak"]      = "Vaelgor & Ezzorak"
L["boss_fallen_king_salhadaar"]= "Gefallener König Salhadaar"
L["boss_lightblinded_vanguard"]= "Lichtblinde Vorhut"
L["boss_crown_of_the_cosmos"]  = "Krone des Kosmos"
L["boss_chimaerus"]            = "Chimaerus, der ungeträumte Gott"
L["boss_beloren"]              = "Belo'ren, Kind von Al'ar"
L["boss_midnight_falls"]       = "Anbruch der Mitternacht"
L["boss_rotmire"]              = "Rottmoor"

------------------------------------------------------------------------
-- Season 2 Raid (Der Giftige Abgrund)
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
-- Season 1 Tiefen
------------------------------------------------------------------------
L["season1_delve_hint"]       = "Hake eine Tiefe an, um den Bonus Roll nach jedem Abschluss automatisch zu passen. Nicht angehakte Tiefen sind davon nicht betroffen."
L["delve_autopass_all_label"] = "ALLE Tiefen automatisch passen (jede Season)"

-- Tiefen-Namen (= lokalisierter Rückgabewert von GetInstanceInfo)
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
-- Season 2 Tiefen (12.1)
------------------------------------------------------------------------
L["delve_ring_of_glory"]         = "Ring des Ruhms"
L["delve_gnarldor_isle"]         = "Knardorinsel"
L["delve_venomfall_deeps"]      = "Giftfalltiefen"
L["delve_labyrinth_of_kindojan"] = "Das Labyrinth von Kindo'Jan" -- 12.1.5

L["nemesis_delve_label"]         = "(Nemesis-Tiefe)"

------------------------------------------------------------------------
-- Offene Welt (Beutejagd & Weltbosse)
------------------------------------------------------------------------
L["prey_title"]               = "Beutejagd"
L["prey_hint"]                = "Wenn aktiviert, wird der Bonus Roll bei Beutejagd-Begegnungen in der offenen Welt automatisch gepasst."
L["prey_toggle_label"]        = "Auto-Pass für Beutejagd aktivieren"

L["raid_tidebound_grotto"]    = "Die Gezeitengebundene Grotte"
L["boss_nymrissa_wavecaller"] = "Nymrissa Wellenruferin"
L["raid_unbinding_of_kithix"] = "Die Entfesselung von Kith'ix" -- 12.1.5
L["boss_kithix"]              = "Kith'ix"

------------------------------------------------------------------------
-- Legacy-Raids
------------------------------------------------------------------------
L["legacy_tab_title"]         = "Legacy-Raids"
L["legacy_tab_hint"]          = "Hake einen Raid an, um automatisch auf alle Beute daraus zu würfeln. Aktiviere die gewünschten Würfeltypen — Bedarf hat die höchste Priorität, dann Gier, dann Transmog. Alle drei können gleichzeitig aktiv sein und dienen als Fallback-Kette."
L["legacy_account_wide_label"] = "Legacy-Einstellungen für alle Charaktere übernehmen"
L["legacy_roll_label"]        = "Würfeltyp wenn Beute droppt:"
L["legacy_roll_need"]         = "Bedarf"
L["legacy_roll_greed"]        = "Gier"
L["legacy_roll_transmog"]     = "Transmog"

------------------------------------------------------------------------
-- Profil-Migration (3.0.1)
------------------------------------------------------------------------
L["profile_migration_popup_text"] = "RollAway-Einstellungen sind jetzt charakterspezifisch. Aktuelle Einstellungen für diesen Charakter übernehmen, oder auf Standard zurücksetzen?"
L["profile_migration_keep"]       = "Aktuelle Einstellungen übernehmen"
L["profile_migration_default"]    = "Auf Standard zurücksetzen"

------------------------------------------------------------------------
-- Profil-Unterkategorie (3.0.1)
------------------------------------------------------------------------
L["profile_section_title"]     = "Profil"
L["profile_panel_title"]       = "Profil"
L["profile_panel_info"]        = "Einstellungen sind standardmäßig charakterspezifisch. Nutze Profile, um Einstellungen zwischen Charakteren zu teilen, oder behalte separate Setups pro Charakter/Spec."
L["profile_active_label"]      = "Aktives Profil:"
L["profile_other_label"]       = "Anderes Profil:"
L["profile_new_button"]        = "Neu"
L["profile_copy_button"]       = "Kopieren von"
L["profile_delete_button"]     = "Löschen"
L["profile_export_button"]     = "Exportieren"
L["profile_import_button"]     = "Importieren"
L["profile_export_info"]       = "Exportiert wird das aktive Profil:"
L["profile_none_available"]    = "Keine anderen Profile"
L["profile_reset_button"]      = "Profil zurücksetzen"
L["profile_new_prompt"]        = "Namen für das neue Profil eingeben:"
L["profile_delete_confirm"]    = "Profil '%s' löschen? Das kann nicht rückgängig gemacht werden."
L["profile_reset_confirm"]     = "Aktuelles Profil auf Standardeinstellungen zurücksetzen? Das kann nicht rückgängig gemacht werden."
L["profile_export_prompt"]     = "Export-Code des aktiven Profils (Strg+C zum Kopieren):"
L["profile_export_failed"]     = "RollAway: Profil-Export fehlgeschlagen."
L["profile_import_prompt"]     = "Export-Code einfügen (Strg+V):"
L["profile_import_invalid"]    = "RollAway: Ungültiger oder beschädigter Export-Code."
L["profile_import_name_prompt"] = "Namen für das importierte Profil eingeben:"
L["profile_reload_prompt"]     = "Profil geändert. UI jetzt neu laden, um es überall anzuwenden?"
L["profile_reload_now"]        = "UI neu laden"

L["legacy_col_dragonflight"]           = "Dragonflight"
L["legacy_col_tww"]                    = "The War Within"

L["legacy_raid_vault_of_incarnates"]   = "Gewölbe der Inkarnate"
L["legacy_raid_aberrus"]               = "Aberrus, die Schattenschmiede"
L["legacy_raid_amirdrassil"]           = "Amirdrassil, die Hoffnung des Traums"
L["legacy_raid_nerubar_palace"]        = "Nerub-ar-Palast"
L["legacy_raid_liberation_undermine"]  = "Befreiung von Untermeins"
L["legacy_raid_manaforge_omega"]       = "Manaschmiede Omega"

------------------------------------------------------------------------
-- Paragon
------------------------------------------------------------------------
L["paragon_alert_label"]           = "Benachrichtigen wenn Paragon-Taschen-Quests verfügbar sind"
L["paragon_alert_info"]            = "Zeigt beim Login ein Popup, wenn Paragon-Taschen-Quests im Questlog vorhanden sind, und wenn eine neue angenommen wird. Mit /rawparagon manuell prüfen."
L["paragon_count_one"]             = "%d Paragon Tasche bereit:"
L["paragon_count_many"]            = "%d Paragon Taschen bereit:"
L["paragon_location"]              = "  |cff999999(%s — %s)|r"
L["paragon_none"]                  = "Keine Paragon-Taschen verfügbar."
L["paragon_faction_slayers_duellum"]   = "Schlächterduellum"
L["paragon_faction_singularity"]       = "Die Singularität"
L["paragon_faction_silvermoon_court"]  = "Hof in Silbermond"
L["paragon_faction_ritual_sites"]      = "Ritualstätten"
L["paragon_faction_harati"]            = "Hara'ti"
L["paragon_faction_amani_tribe"]       = "Amanistamm"
L["paragon_faction_zuljarras_forces"]  = "Zul'jarras Streitkräfte"

-- Turn-in-NPC + Zone pro Quest (verifiziert, Patch 12.0.7)
L["paragon_npc_94492"]        = "Thraxadar"
L["paragon_zone_94492"]       = "Hort der Meister"
L["paragon_npc_89032"]        = "Leerenforscher Anomander"
L["paragon_zone_89032"]       = "Heulender Grat"
L["paragon_npc_93811"]        = "Caeris Morgenlicht"
L["paragon_zone_93811"]       = "Saltherils Hafen"
L["paragon_npc_95391"]        = "Lady Dunkeltal"
L["paragon_zone_95391"]       = "Silbermond"
L["paragon_npc_89035"]        = "Naynar"
L["paragon_zone_89035"]       = "Die Höhle"
L["paragon_npc_93566"]        = "Magovu"
L["paragon_zone_93566"]       = "Amani'zar"

------------------------------------------------------------------------
-- Great Vault
------------------------------------------------------------------------
L["greatvault_alert_label"]        = "Benachrichtigen wenn Belohnungen in der Großen Schatzkammer verfügbar sind"
L["greatvault_alert_info"]         = "Zeigt beim Login ein Popup, wenn unabgeholte Belohnungen in der Großen Schatzkammer vorhanden sind. Wird nur einmal pro wöchentlichem Reset angezeigt. Mit /rawvault manuell prüfen."
L["greatvault_alert_msg"]          = "Du hast unabgeholte Belohnungen in der Großen Schatzkammer!"
L["greatvault_none"]               = "Keine unabgeholten Belohnungen in der Großen Schatzkammer."
------------------------------------------------------------------------
-- Was ist neu (3.0.1)
------------------------------------------------------------------------
L["whatsnew_profiles_title"]       = "Charakterspezifische Profile"
L["whatsnew_profiles_desc"]        = "Einstellungen sind jetzt charakterspezifisch. Profile wechseln, erstellen, kopieren, löschen und zurücksetzen unter Profil. Neue Profile starten komplett deaktiviert."
L["whatsnew_profiles_location"]    = "Profil"
L["whatsnew_premade_title"]        = "Begleit-Addon für manuelle Gruppen"
L["whatsnew_premade_desc"]         = "Wähle BigWigs oder Details! Keystones separat für manuell gebildete (Premade) Gruppen, unabhängig von der Gruppensuche-Einstellung."
L["whatsnew_premade_location"]     = "QoL > Reminder"
L["whatsnew_chonky_title"]         = "Chonky Character Sheet Unterstützung"
L["whatsnew_chonky_desc"]          = "Die Omnium- und Große-Schatzkammer-Buttons werden mit Chonky Character Sheet jetzt korrekt angezeigt."
L["whatsnew_chonky_location"]      = "QoL > Filter"
L["whatsnew_1215preview_title"]    = "Patch 12.1.5 Vorschau"
L["whatsnew_1215preview_desc"]     = "Labyrinth von Kindo'jan und der Kith'ix-Raid sind vor dem Release als \"demnächst verfügbar\" gelistet."
L["whatsnew_1215preview_location"] = "Tiefen / Raids"
L["whatsnew_autoaccept_title"]     = "Einladungen von Gilde/Freunden automatisch annehmen"
L["whatsnew_autoaccept_desc"]      = "Nimmt Gruppeneinladungen von Gildenmitgliedern, Freunden und Battle.net-Freunden automatisch an. Nur Standard-UI."
L["whatsnew_autoaccept_location"]  = "QoL > Sonstiges"
L["whatsnew_autorepair_title"]     = "Automatische Reparatur"
L["whatsnew_autorepair_desc"]      = "Repariert automatisch beim Händler mit Spieler- oder Gildenbank-Gold. Nur Standard-UI."
L["whatsnew_autorepair_location"]  = "QoL > Sonstiges"
