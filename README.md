## Beholder WoW Addon

Install to ```/World of Warcraft/_classic_/Interface/AddOns/Beholder``` and ```/World of Warcraft/_retail_/Interface/AddOns/Beholder```

Update the keybindings file with current keybinds.

Add macros such as

```
/script Beholder:Transmit("command", "rotation-warrior-arms")
```

to trigger events in cerebrum.

Development
---

Recommended Tools:

* VSCode w/WoW Bundle Addin
* Link Shell Extension http://schinagl.priv.at/nt/hardlinkshellext/linkshellextension.html#contact

Symlink Addon folder to 

```C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\Beholder```
```C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Beholder```

Remember to turn scriptErrors on - ```/console scriptErrors 1```

or use this macro to help

```
/run if GetCVar("ScriptErrors")=="1" then SetCVar("ScriptErrors","0");print("Show LUA Errors: Off");else SetCVar("ScriptErrors","1");print("Show LUA Errors: On");end
```