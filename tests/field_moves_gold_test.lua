-- Standalone from the engine checkout:
-- luajit <mod-root>/tests/field_moves_gold_test.lua <mod-root>
-- Regression: Gen 2 tree interaction supplies a field context without data,
-- while Rock Smash supplies it explicitly. Both must honour FIELD MOVES ALL.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Game = require("src.core.Game")
local GameVersion = require("src.core.GameVersion")
local World = require("src.world.gen2.World")
local FieldMoves = require("src.world.gen2.FieldMoves")

local savedVersion = GameVersion.get()
GameVersion.set("gold")
local loadRoot = arg and arg[1]
local data = T.fixtures.fresh()
data.pokemon.FIXMON_A.tmhm = { "CUT", "ROCK_SMASH" }
data.moves.CUT = { name = "CUT" }
data.moves.ROCK_SMASH = { name = "ROCK SMASH" }
local run = T.sdk.loadMod(loadRoot and "." or "mods/qol_toggles", {
  data = data, generation = 2, root = loadRoot,
})
T.eq(run.mod and run.mod.state, "loaded", "QoL Toggles loads on Gold")
T.eq(#run.errors, 0, "Gold load has no errors")

local learner = { species = "FIXMON_A", moves = { { id = "FIX_TACKLE" } } }
local known = { species = "FIXMON_B", moves = { { id = "CUT" } } }
local save = {
  party = { learner }, inventory = { HM_CUT = 1 },
  player = { badges = { HIVE = true } },
}
local game = { data = data, save = save, mods = run.loader }
run.loader.game = game
run.loader.modOptions.qol_toggles = {
  field_moves_all = true, hm_item_required = true,
  badgeless_moves = false, rename = false,
}
local opts = run.loader.modOptions.qol_toggles

-- Gold has its own game instance. The Gen 1 singleton must not supply its
-- learnsets when the field context omits data.
local savedGameData = Game.data
Game.data = { pokemon = {} }

local world = World.new(game)
game.world = world
world.map = {
  id = "FIX_ROUTE", width = 2, height = 2,
  def = { tileset = "TILESET_JOHTO", environment = "ROUTE",
    blocks = { 0x03, 0x03, 0x03, 0x03 } },
  cellCollision = function(_, x, y)
    return x == 1 and y == 0 and 0x12 or 0x00
  end,
}
world.player = { cellX = 0, cellY = 0, facing = "right", moving = false }
world.vm = { running = function() return false end }
local shown, asked, action
world.showText = function(_, text, onDone)
  shown = text
  if onDone then onDone() end
end
world.askYesNo = function(_, onDone)
  asked = true
  onDone(true)
end
world.runFieldMove = function(_, result)
  action = result
  return true
end
local function interact()
  shown, asked, action = nil, false, nil
  T.eq(world:interact(), true, "the tree claims the A press")
end

local rows = Runtime.call("ui.party.submenu",
  function(_, items) return items end, game,
  { { id = "STATS", label = "STATS" } }, learner, { battle = false })
T.eq(rows[1].id, "CUT", "the learner has CUT in its party submenu")
T.eq(world:partyMoveUser("ROCK_SMASH"), learner,
  "Rock Smash already accepts a learner with explicit game data")
interact()
T.eq(asked, true, "FIELD MOVES ALL offers CUT when talking to the tree")
T.eq(action and action.mon, learner, "CUT selects the learnable party member")
T.eq(action and action.action, "cut", "YES runs the native cut action")
T.eq(action and action.replacement, 0x02, "CUT keeps the native block swap")
T.eq(#learner.moves, 1, "interacting does not add CUT to the moveset")
T.eq(learner.moves[1].id, "FIX_TACKLE", "the real move is unchanged")

save.inventory.HM_CUT = nil
interact()
T.eq(asked, false, "HM ITEM REQUIRED still blocks a learner without HM_CUT")
T.eq(shown, FieldMoves.TEXT.CAN_CUT, "missing HM keeps the native tree text")
opts.hm_item_required = false
interact()
T.eq(asked, true, "disabling HM ITEM REQUIRED allows the learner without it")
opts.hm_item_required = true
save.inventory.HM_CUT = 1
save.player.badges.HIVE = nil
interact()
T.eq(asked, false, "the Hive Badge is still required")
T.eq(action, nil, "a missing badge never runs CUT")
save.player.badges.HIVE = true
opts.field_moves_all = false
interact()
T.eq(asked, false, "FIELD MOVES ALL OFF requires a known CUT")

save.party = { known }
save.inventory.HM_CUT = nil
interact()
T.eq(asked, true, "a known CUT works with the toggle OFF and no HM item")
T.eq(action and action.mon, known, "the known CUT user is preserved")
opts.field_moves_all = true
save.party = { learner, known }
interact()
T.eq(action and action.mon, known, "a known CUT user wins over a learner")

save.party = { learner }
save.inventory.HM_CUT = 1
local explicitData = { pokemon = { FIXMON_A = { tmhm = {} } } }
T.eq(Runtime.call("fieldmove.eligibility", function() return nil end,
  "CUT", { save = save, data = explicitData }), nil,
  "explicit context data remains authoritative over live game data")
data.pokemon.FIXMON_A.tmhm = { "ROCK_SMASH" }
interact()
T.eq(asked, false, "a species that cannot learn CUT still cannot cut trees")

-- AUTO CUT remains a known-move-only shortcut, independent of A interaction.
data.pokemon.FIXMON_A.tmhm = { "CUT", "ROCK_SMASH" }
opts.auto_cut = true
Runtime.emit("game.ready", { game = game })
local Player = require("src.world.gen2.Player")
world.player.turnTimer = 0
world.map.inBounds = function() return true end
world.map.isWalkable = function() return false end
shown, asked, action = nil, false, nil
T.eq(Player.tryMove(world.player, "right", world.map, {}), "blocked",
  "AUTO CUT does not cut for a learner")
T.eq(asked, false, "AUTO CUT does not prompt for a learner")
save.party = { known }
T.eq(Player.tryMove(world.player, "right", world.map, {}), nil,
  "AUTO CUT still cuts for a known CUT user")
T.eq(action and action.mon, known, "AUTO CUT keeps the known CUT user")

Game.data = savedGameData
run.release()
GameVersion.set(savedVersion or "red")
T.finish("field moves gold")
