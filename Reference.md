Template options
----------------

### Common

* admin (`true` or `false`)
* loggedIn (`true` or `false`)
* login (string or `false`)
* mail_count (number)

### Specific

#### about

None needed.

#### register

* error (`true` or `false`)
* invalidLogin (`true` or `false`)
* loginIsBusy (`true` or `false`)
* invalidPass (`true` or `false`)

#### login

* error (`true` or `false`)

#### game

* location\_name (string)
* area\_name (string)
* pic (URL string)
* description (string)
* ways (array; elements: ways\[i\].to, ways\[i\].name)
* players\_list (array; elements: players\_list\[i\].id, players\_list\[i\].name)
* monsters\_list (array; elements: monsters\_list\[i\].name)
* fight\_mode (`true` or `false`)
* autoinvolved\_fm (`true` or `false`)

#### profile

* nickname (string)
* id (string)
* isAdmin (`true` or `false`)
* level, exp, exp_max, exp\_percent (string)
* power, agility, endurance (string)
* intelligence, wisdom, volition (string)
* health, health\_max, health\_percent (string)
* mana, mana\_max, mana\_percent (string)
* effects (array; elements: effects\[i\].name, effects\[i\].description, effects\[i\].dismiss_time)
