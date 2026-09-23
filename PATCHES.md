# Patches — every fork change that touches an upstream file

New code lives in `Sources/Search/Fork/` and never appears here. This table is only the lines in upstream's files, so a rebase knows what to protect. Update it in the same commit as the change; delete a row when its "drop when" fires.

| patch | touches | why | upstream status | drop when |
|---|---|---|---|---|
| updater-off | `Updater.swift` `checkIfDue()` guard | a Copper build must not replace itself with upstream Search | fork-only | Copper has its own feed + signing identity (then repoint, keep the guard) |
| app-identity | `Store.swift` folder + `ownContainer`, `Vault.swift` label, `build.sh` NAME/APP/bundle id | coexist with upstream Search: separate Application Support, keychain items, WebKit container | fork-only | never |
