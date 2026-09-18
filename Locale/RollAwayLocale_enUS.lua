-- RollAway - Locale enUS (fallback)

local L = {}
_G["RollAwayLocale"] = L

------------------------------------------------------------------------
-- General
------------------------------------------------------------------------
L["addon_title"]              = "RollAway"

-- Tabs
L["tab_general"]              = "General"
L["tab_dungeons"]             = "Dungeons"
L["tab_raids"]                = "Raids"
L["tab_delves"]               = "Delves"
L["tab_prey"]                 = "Open World"
L["tab_legacy"]               = "Legacy"

-- Delay slider
L["delay_section_title"]      = "Delay"
L["slider_label"]             = "Close frame after %d seconds"
L["slider_min"]               = "5 sec."
L["slider_max"]               = "20 sec."

-- Safety Timeout slider
L["timeout_section_title"]    = "Safety Timeout"
L["timeout_slider_label"]     = "Force-close frame after %d seconds"
L["timeout_min"]              = "30 sec."
L["timeout_max"]              = "180 sec."
L["lootframe_feature_disable_label"] = "Disable auto-close/auto-hide entirely (frame always stays open, like default WoW)"

-- Visibility
L["visibility_section_title"] = "Visibility"
L["visibility_info"]          = "Controls the Group Loot History frame that appears during loot distribution in raids."
L["hide_in_raid_label"]       = "Hide Group Loot History in raids"
L["hide_in_raid_info"]        = "Hides the Group Loot History frame for the selected raid difficulties. Visible by default."
L["raid_diff_lfr"]            = "LFR / World"
L["raid_diff_normal"]         = "Normal"
L["raid_diff_heroic"]         = "Heroic"
L["raid_diff_mythic"]         = "Mythic"
L["reminder_label"]           = "Show auto-pass reminder when entering dungeons & raids"
L["reminder_info"]            = "Shows a popup when entering a Mythic dungeon or raid, reminding you to check your auto-pass settings."
L["bonusroll_reminder_section_title"] = "Bonus Roll"

-- Reminder popup
L["reminder_dungeon"]         = "You entered a Mythic dungeon. Check your Bonus Roll auto-pass settings."
L["reminder_raid"]            = "You entered a raid. Check your Bonus Roll auto-pass settings."
L["reminder_voidcore"]        = "Nebulous Voidcore: %d  –  %s %s available."
L["reminder_roll_singular"]   = "roll"
L["reminder_roll_plural"]     = "rolls"
L["reminder_btn_dungeons"]    = "Open Dungeons"
L["reminder_btn_raids"]       = "Open Raids"
L["reminder_okay"]            = "Okay"

-- Legacy
L["legacy_section_title"]     = "Legacy"
L["legacy_enable_label"]      = "Enable auto-roll for Legacy raids (Dragonflight & The War Within)"

-- Developer
L["debug_section_title"]      = "Developer"
L["debug_label"]              = "Show debug output in chat"
L["cmd_rawtest_info"]         = "Manual auto-pass test"
L["cmd_rawreminder_info"]     = "Test the reminder popup"
L["cmd_rawreset_info"]        = "Reset reminder state (shows again on next entry)"
L["cmd_rawqol_info"]          = "Test QoL reminders"
L["cmd_rawwhats_info"]        = "Show the What's New popup (dev/tester only)"
L["cmd_rawparagon_info"]      = "Manual Paragon Bag quest check (available to all users)"


-- QoL
L["qol_section_title"]        = "QoL"
L["qol_panel_title"]          = "Quality of Life"
L["qol_panel_info"]           = "Small improvements to your everyday gameplay experience."
L["qol_reminder_section"]     = "Reminder"
L["qol_filter_section"]       = "Filter"
L["qol_nav_misc"]             = "Misc"
L["qol_nav_lfg"]              = "LFG"
L["qol_readycheck_label"]     = "Show talent reminder on Ready Check"
L["qol_readycheck_info"]      = "Displays a 'Check Talents' notice when a ready check starts in a dungeon or raid."
L["qol_durability_label"]     = "Show durability warning"
L["qol_durability_info"]      = "Displays a warning when your lowest item durability drops to 30% or below."
L["qol_durability_warning"]   = "Low Durability: %s"
L["qol_join_reminder_label"]  = "Show instance name when joining a group"
L["qol_join_reminder_info"]   = "Displays the instance name when you join a group. Disappears after 6 seconds."
L["qol_autoaccept_label"]     = "Automatically accept invites from guild/friends"
L["qol_autoaccept_info"]      = "Accepts group invites from guild members, friends, and Battle.net friends automatically. Default UI only - ElvUI has its own option for this."
L["qol_autorepair_label"]     = "Auto Repair"
L["qol_autorepair_info"]      = "Automatically repairs at the merchant. Default UI only - ElvUI has its own option for this."
L["qol_autorepair_none"]      = "Nothing"
L["qol_autorepair_player"]    = "Player"
L["qol_autorepair_guild"]     = "Guild"
L["qol_autorepair_msg_player"] = "Auto-repaired for %s (player funds)"
L["qol_autorepair_msg_guild"]  = "Auto-repaired for %s (guild funds)"
L["qol_join_keyaddon_label"]  = "Open keystone companion addon with reminder:"
L["qol_join_keyaddon_info"]      = "Opens the selected teleport helper for Mythic+ groups. Closes on teleport, or after 20 seconds. Raids use the reminder above."
L["qol_join_keyaddon_bigwigs"]   = "BigWigs"
L["qol_join_keyaddon_details"]   = "Details!"
L["qol_join_keyaddon_teleport"]  = "RollAway Teleport Reminder"
L["qol_premade_keyaddon_label"]  = "Open companion addon for manually formed (premade) groups:"
L["qol_premade_keyaddon_info"]   = "Separate choice for manually formed Mythic+ groups (dungeon can't be detected). Closes on teleport, or after 20 seconds."
L["teleport_reminder_generic"]   = "Mythic+ group ready - portals available"
L["teleport_reminder_locked"]    = "Portal not yet unlocked"
L["qol_expansion_filter_label"] = "Auto-select 'Current Expansion Only' in Auction House & Crafting Orders"
L["qol_expansion_filter_info"]  = "Automatically enables the 'Current Expansion Only' filter when opening the Auction House or Crafting Orders."
L["qol_vault_currency_label"]   = "Show Nebulous Voidcore (Bonus Loot) in the Great Vault"
L["qol_vault_currency_info"]    = "Displays the current Nebulous Voidcore (Bonus Loot) count in the bottom right of the Great Vault frame."
L["qol_vault_currency_name"]    = "Bonus Loot"
L["qol_vendor_filter_label"]    = "Vendor Filter Light: dim already-known vendor items"
L["qol_vendor_filter_info"]     = "Dims recipes, toys, mounts, pets, tabards, illusions, and already-owned housing decor you already know. No dropdown, just passive dimming."
L["qol_vendor_filter_alpha_label"] = "Known item transparency"
L["qol_omniumfoliant_label"]    = "Hide Omniumfoliant minimap icon, show button on Character Frame instead"
L["qol_omniumfoliant_info"]     = "Hides the Omniumfoliant icon from the minimap and adds a button to the bottom-right corner of the Character Frame instead."
L["qol_vault_button_label"]     = "Show Great Vault button on Character Frame"
L["qol_vault_button_info"]      = "Adds a button next to the Omniumfoliant button to open the Great Vault directly, without using the Group Finder, a macro, or the vault near the bank."
L["qol_map_activity_label"]     = "Hide tracked-faction button on World Map (experimental)"
L["qol_map_activity_info"]      = "Hides the bottom-left button used to cycle/untrack a Major Faction's activities on the World Map. Experimental — may stop working after a Blizzard UI update."
L["qol_crafting_output_log_label"] = "Hide Crafting Results window"
L["qol_crafting_output_log_info"]  = "Hides the small popup that lists your crafted items while using a profession."
L["qol_vault_button_tooltip"]   = "Open Great Vault"

-- Auto Combat Logging
L["qol_nav_logs"]               = "Logs"
L["qol_log_enable_label"]       = "Auto-toggle combat logging for selected content:"
L["qol_log_enable_info"]        = "Flips /combatlog on and off as you enter or leave matching content, and enables Advanced Combat Logging while doing so. The file lands at Logs\\WoWCombatLog.txt in your WoW folder — upload it to a site like warcraftlogs.com, then delete it so it doesn't keep growing."
L["qol_log_scenario_label"]     = "Scenarios"
L["qol_log_dungeon_label"]      = "Dungeons (Mythic, Mythic+)"
L["qol_log_raid_mythic_label"]  = "Raid: Mythic"
L["qol_log_raid_heroic_label"]  = "Raid: Heroic"
L["qol_log_raid_normal_label"]  = "Raid: Normal"
L["qol_log_raid_lfr_label"]     = "Raid: Raid Finder"
L["qol_log_delve_label"]        = "Delves"
L["qol_log_arena_label"]        = "Arena"
L["qol_log_chatnotify_label"]   = "Show a chat message when logging starts/stops"
L["qol_log_advlog_reminder_label"] = "Remind me if Advanced Combat Logging is off (M+/Raid)"
L["advlog_reminder_msg"]        = "Advanced Combat Logging is off. Enable it in Options > Combat Log for full details on WarcraftLogs."
L["qol_log_chat_started"]       = "Combat log started."
L["qol_log_chat_stopped"]       = "Combat log stopped."

-- LFG Quick Create
L["qol_lfgqc_label"]            = "Show dungeon quick-create buttons in the Group Finder"
L["qol_lfgqc_info"]             = "Adds dungeon icon buttons below the group name field when creating a Mythic+ group. Click an icon to instantly select that dungeon and create the listing."
L["qol_lfgqc_namefirst"]        = "Please enter a group name first."
L["qol_lfgqc_autops_label"]     = "Auto-apply default playstyle when opening the Group Finder"
L["qol_lfgqc_autops_info"]      = "Sets the selected playstyle automatically. Works independently of the dungeon buttons."
L["qol_lfgqc_playstyle_label"]  = "Default Playstyle:"
L["qol_lfgqc_ps_none"]          = "Do not pre-select"
L["qol_lfgqc_ps_standard"]      = "Learning"
L["qol_lfgqc_ps_relaxed"]       = "Relaxed"
L["qol_lfgqc_ps_competitive"]   = "Competitive"
L["qol_lfgqc_ps_carry"]         = "Carry Offered"
L["qol_fontsize_label"]       = "Reminder font size"
L["qol_fontsize_value"]       = "Size: %d"
L["qol_check_talents"]        = "Check Talents"
L["combat_action_queued"]     = "Can't open the options while in combat — opening automatically once combat ends."

------------------------------------------------------------------------
-- Season 1 Dungeons
------------------------------------------------------------------------
L["season1_title"]            = "Season 1"
L["season2_tab"]              = "Season 2 (12.1)"
L["season3_tab"]              = "Season 3 (12.2)"
L["season_coming_soon"]       = "Coming soon"
L["patch_12_0"]               = "Patch 12.0"
L["patch_12_1"]               = "Patch 12.1"
L["season1_hint"]             = "Check a dungeon to automatically pass the bonus roll whenever you complete it. Unchecked dungeons are not affected."
L["dungeon_autopass_all_label"] = "Auto-pass ALL dungeons (any season)"

-- Dungeon names (= localized return value of GetInstanceInfo)
L["dungeon_windrunner_spire"]    = "Windrunner Spire"
L["dungeon_maisara_caverns"]     = "Maisara Caverns"
L["dungeon_magisters_terrace"]   = "Magisters' Terrace"
L["dungeon_nexus_point_xenas"]   = "Nexus-Point Xenas"
L["dungeon_algeth_ar_academy"]   = "Algeth'ar Academy"
L["dungeon_seat_of_triumvirate"] = "Seat of the Triumvirate"
L["dungeon_skyreach"]            = "Skyreach"
L["dungeon_pit_of_saron"]        = "Pit of Saron"
-- Season 2 (12.1)
L["dungeon_altar_of_fangs"]       = "Altar of Fangs"
L["dungeon_kings_rest"]           = "King's Rest"
L["dungeon_ruby_life_pools"]      = "Ruby Life Pools"
L["dungeon_temple_of_sethraliss"] = "Temple of Sethraliss"
L["dungeon_murder_row"]          = "Murder Row"
L["dungeon_den_of_nalorakk"]     = "Den of Nalorakk"
L["dungeon_blinding_vale"]       = "The Blinding Vale"
L["dungeon_voidscar_arena"]      = "Voidscar Arena"

------------------------------------------------------------------------
-- Season 1 Raids
------------------------------------------------------------------------
L["raid_hint"]             = "Check a boss to automatically pass the bonus roll after every kill. Unchecked bosses are not affected."
L["confirm_roll_title"]        = "Roll Confirmation"
L["confirm_roll_hint"]         = "Shows a popup asking you to confirm before rolling on group loot. Applies to any raid, current or legacy."
L["confirm_roll_popup"]        = "Roll %s on %s?"
L["confirm_type_need"]         = "Need"
L["confirm_type_greed"]        = "Greed"
L["confirm_type_transmog"]     = "Transmog"
L["confirm_type_pass"]         = "Pass"
L["raid_diff_autopass_title"] = "Bonus Roll Auto-Pass by Difficulty"
L["raid_diff_autopass_hint"]  = "Auto-passes the bonus roll for every boss at the selected difficulty, combinable with individual boss checkboxes below."

L["raid_voidspire"]        = "The Voidspire"
L["raid_dreamrift"]        = "The Dreamrift"
L["raid_march_queldanas"]  = "March on Quel'Danas"
L["raid_sporefall"]        = "Sporefall"

L["boss_imperator_averzian"]   = "Imperator Averzian"
L["boss_vorasius"]             = "Vorasius"
L["boss_vaelgor_ezzorak"]      = "Vaelgor & Ezzorak"
L["boss_fallen_king_salhadaar"]= "Fallen King Salhadaar"
L["boss_lightblinded_vanguard"]= "Lightblinded Vanguard"
L["boss_crown_of_the_cosmos"]  = "Crown of the Cosmos"
L["boss_chimaerus"]            = "Chimaerus, the Undreamt God"
L["boss_beloren"]              = "Belo'ren, Child of Al'ar"
L["boss_midnight_falls"]       = "Midnight Falls"
L["boss_rotmire"]              = "Rotmire"

------------------------------------------------------------------------
-- Season 2 Raid (The Venomous Abyss)
------------------------------------------------------------------------
L["raid_venomous_abyss"]            = "The Venomous Abyss"

L["boss_nekzali_the_soulcoiler"]    = "Nek'zali the Soulcoiler"
L["boss_entombed_sentinels"]        = "Entombed Sentinels"
L["boss_vashnik_the_malignant"]     = "Vashnik the Malignant"
L["boss_the_lost_explorers"]        = "The Lost Explorers"
L["boss_sszorak"]                   = "Sszorak"
L["boss_the_twin_fangs"]            = "The Twin Fangs"
L["boss_the_coiled_altar"]          = "The Coiled Altar"
L["boss_ulatek"]                    = "Ula'tek"

------------------------------------------------------------------------
-- Season 1 Delves
------------------------------------------------------------------------
L["season1_delve_hint"]       = "Check a delve to automatically pass the bonus roll whenever you complete it. Unchecked delves are not affected."
L["delve_autopass_all_label"] = "Auto-pass ALL delves (any season)"

-- Delve names (= localized return value of GetInstanceInfo)
L["delve_academic_unrest"]       = "Academic Calamity"
L["delve_shadow_enclave"]        = "Shadow Enclave"
L["delve_parhelion_plaza"]       = "Parhelion Plaza"
L["delve_grufts_twilight_blade"] = "Twilight Crypts"
L["delve_atal_aman"]             = "Atal'Aman"
L["delve_the_grudge_pit"]        = "The Howling Maw"
L["delve_gulf_of_memory"]        = "Gulf of Memories"
L["delve_sunkiller_sanctum"]     = "Sunreaver's Sanctum"
L["delve_torments_rise"]         = "Ascension of Agony"
L["delve_shadowguard_point"]     = "Shadowguard Point"
L["delve_the_darkway"]           = "The Dark Path"

------------------------------------------------------------------------
-- Season 2 Delves (12.1)
------------------------------------------------------------------------
L["delve_ring_of_glory"]      = "The Ring of Glory"
L["delve_gnarldor_isle"]      = "Gnarldor Isle"
L["delve_venomfall_deeps"]    = "Venomfall Deeps" -- Nemesis Delve
L["delve_labyrinth_of_kindojan"] = "Labyrinth of Kindo'jan" -- 12.1.5

L["nemesis_delve_label"]      = "(Nemesis Delve)"

------------------------------------------------------------------------
-- Open World (Prey & World Bosses)
------------------------------------------------------------------------
L["prey_title"]               = "Prey"
L["prey_hint"]                = "When enabled, the bonus roll is automatically passed for Prey encounters in the open world."
L["prey_toggle_label"]        = "Enable auto-pass for Prey"

L["raid_tidebound_grotto"]    = "Tidebound Grotto"
L["boss_nymrissa_wavecaller"] = "Nymrissa Wavecaller"
L["raid_unbinding_of_kithix"] = "The Unbinding of Kith'ix" -- 12.1.5
L["boss_kithix"]              = "Kith'ix"

------------------------------------------------------------------------
-- Legacy Raids
------------------------------------------------------------------------
L["legacy_tab_title"]         = "Legacy Raids"
L["legacy_tab_hint"]          = "Check a raid to automatically roll on all loot from that raid. Enable the roll types you want — Need has highest priority, then Greed, then Transmog. All three can be active simultaneously as a fallback chain."
L["legacy_account_wide_label"] = "Apply Legacy settings to all characters"
L["legacy_roll_label"]        = "Roll type when loot drops:"
L["legacy_roll_need"]         = "Need"
L["legacy_roll_greed"]        = "Greed"
L["legacy_roll_transmog"]     = "Transmog"

------------------------------------------------------------------------
-- Profile migration (3.0.1)
------------------------------------------------------------------------
L["profile_migration_popup_text"] = "RollAway settings are now per-character. Keep this character's current settings, or start fresh on defaults?"
L["profile_migration_keep"]       = "Keep current settings"
L["profile_migration_default"]    = "Reset to defaults"

------------------------------------------------------------------------
-- Profile subcategory (3.0.1)
------------------------------------------------------------------------
L["profile_section_title"]     = "Profile"
L["profile_panel_title"]       = "Profile"
L["profile_panel_info"]        = "Settings are character-specific by default. Use profiles to share settings between characters, or keep separate setups per character/spec. Bonus Roll selections (Dungeons/Raids/Delves/Prey) are always per-character, never part of a profile."
L["profile_active_label"]      = "Active profile:"
L["profile_other_label"]       = "Other profile:"
L["profile_none_available"]    = "No other profiles"
L["profile_new_button"]        = "New"
L["profile_copy_button"]       = "Copy From"
L["profile_delete_button"]     = "Delete"
L["profile_export_button"]     = "Export"
L["profile_import_button"]     = "Import"
L["profile_export_info"]       = "Exporting the active profile:"
L["profile_reset_button"]      = "Reset Profile"
L["profile_new_prompt"]        = "Enter a name for the new profile:"
L["profile_delete_confirm"]    = "Delete profile '%s'? This cannot be undone."
L["profile_reset_confirm"]     = "Reset the current profile to default settings? This cannot be undone."
L["profile_export_prompt"]     = "Export code for the active profile (Ctrl+C to copy):"
L["profile_export_failed"]     = "RollAway: Profile export failed."
L["profile_import_prompt"]     = "Paste export code (Ctrl+V):"
L["profile_import_invalid"]    = "RollAway: Invalid or corrupted export code."
L["profile_import_name_prompt"] = "Enter a name for the imported profile:"
L["profile_reload_prompt"]     = "Profile changed. Reload the UI now to apply it everywhere?"
L["profile_reload_now"]        = "Reload UI"

L["legacy_col_dragonflight"]           = "Dragonflight"
L["legacy_col_tww"]                    = "The War Within"

L["legacy_raid_vault_of_incarnates"]   = "Vault of the Incarnates"
L["legacy_raid_aberrus"]               = "Aberrus, the Shadowed Crucible"
L["legacy_raid_amirdrassil"]           = "Amirdrassil, the Dream's Hope"
L["legacy_raid_nerubar_palace"]        = "Nerub-ar Palace"
L["legacy_raid_liberation_undermine"]  = "Liberation of Undermine"
L["legacy_raid_manaforge_omega"]       = "Manaforge Omega"

------------------------------------------------------------------------
-- Paragon
------------------------------------------------------------------------
L["paragon_alert_label"]           = "Notify when Paragon Bag quests are available"
L["paragon_alert_info"]            = "Shows a popup on login if Paragon Bag quests are in your log, and when you accept a new one. Use /rawparagon to check manually."
L["paragon_count_one"]             = "%d Paragon Bag ready:"
L["paragon_count_many"]            = "%d Paragon Bags ready:"
L["paragon_location"]              = "  |cff999999(%s — %s)|r"
L["paragon_none"]                  = "No Paragon Bags available."
L["paragon_faction_slayers_duellum"]   = "Slayer's Duellum"
L["paragon_faction_singularity"]       = "The Singularity"
L["paragon_faction_silvermoon_court"]  = "Silvermoon Court"
L["paragon_faction_ritual_sites"]      = "Ritual Sites"
L["paragon_faction_harati"]            = "Hara'ti"
L["paragon_faction_amani_tribe"]       = "Amani Tribe"
L["paragon_faction_zuljarras_forces"]  = "Zul'jarra's Forces"

-- Turn-in NPC + zone per quest (verified, Patch 12.0.7)
L["paragon_npc_94492"]        = "Thraxadar"
L["paragon_zone_94492"]       = "Masters' Perch"
L["paragon_npc_89032"]        = "Void Researcher Anomander"
L["paragon_zone_89032"]       = "Howling Ridge"
L["paragon_npc_93811"]        = "Caeris Fairdawn"
L["paragon_zone_93811"]       = "Saltheril's Haven"
L["paragon_npc_95391"]        = "Lady Darkglen"
L["paragon_zone_95391"]       = "Silvermoon City"
L["paragon_npc_89035"]        = "Naynar"
L["paragon_zone_89035"]       = "The Den"
L["paragon_npc_93566"]        = "Magovu"
L["paragon_zone_93566"]       = "Amani'Zar Village"

------------------------------------------------------------------------
-- Great Vault
------------------------------------------------------------------------
L["greatvault_alert_label"]        = "Notify when Great Vault rewards are unclaimed"
L["greatvault_alert_info"]         = "Shows a popup on login if you have unclaimed Great Vault rewards. Only shown once per weekly reset. Use /rawvault to check manually."
L["greatvault_alert_msg"]          = "You have unclaimed rewards in your Great Vault!"
L["greatvault_none"]               = "No unclaimed Great Vault rewards."

------------------------------------------------------------------------
-- What's New (3.0.1)
------------------------------------------------------------------------
L["whatsnew_autoaccept_title"]     = "Auto-Accept Guild/Friend Invites"
L["whatsnew_autoaccept_desc"]      = "Automatically accepts group invites from guild members, friends, and Battle.net friends. Default UI only."
L["whatsnew_autoaccept_location"]  = "QoL > Misc"
L["whatsnew_autorepair_title"]     = "Auto Repair"
L["whatsnew_autorepair_desc"]      = "Automatically repairs at the merchant using player or guild bank funds. Default UI only."
L["whatsnew_autorepair_location"]  = "QoL > Misc"
