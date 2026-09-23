# Patches — every fork change that touches an upstream file

New code lives in `Sources/Search/Fork/` and never appears here. This table is only the lines in upstream's files, so a rebase knows what to protect. Update it in the same commit as the change; delete a row when its "drop when" fires.

| patch | touches | why | upstream status | drop when |
|---|---|---|---|---|
| updater-off | `Updater.swift` `checkIfDue()` guard | a Copper build must not replace itself with upstream Search | fork-only | Copper has its own feed + signing identity (then repoint, keep the guard) |
| app-identity | `Store.swift` folder + `ownContainer`, `Vault.swift` label, `build.sh` NAME/APP/bundle id | coexist with upstream Search: separate Application Support, keychain items, WebKit container | fork-only | never |
| spaces-hooks | `Browser.swift` `tabs` setter opened, `prepare` opened, init restore → `Spaces.restore`, `writeSession` → `Spaces.shape`; `Session.swift` optional `space`/`active` on Entry, `spaces`/`space` on Shape; `Side.swift` `SpaceStrip` above foot; `App.swift` `SpaceCommands`; `Sleep.swift` idle set includes parked tabs; `Bench.swift` `spaces` verb; `bench` folder name + verb | Spaces (FORK-PLAN #1) | fork-only (upstream is one-row by design) | never |
| profiles-hook | `Store.swift` `websites` asks `Spaces.profileStore` first | per-space cookie jars (FORK-PLAN #2) | fork-only | never |
