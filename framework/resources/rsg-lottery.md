# rsg-lottery

Version 3.0.0. Lottery script for RSG Framework

A daily lottery for the RSG Framework (RedM). Players buy tickets from seller NPCs in every major town, pick their numbers, and a draw runs automatically every day. Prizes are held until the winner next visits a ticket seller, and the jackpot grows with every ticket sold until someone wins it. - **Daily automatic draw** at a configurable time. Draws missed while the server was offline run as soon 

Source: https://github.com/Rexshack-RedM/rsg-lottery

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`, `ox_target`

Has NUI (`ui_page`).

## Callbacks (lib.callback)

**server:** `rsg-lottery:server:buyTicket`, `rsg-lottery:server:collectPrizes`, `rsg-lottery:server:getJackpotInfo`, `rsg-lottery:server:getMyTickets`, `rsg-lottery:server:getPastWinners`

## Database tables

`rsg_lottery_config`, `rsg_lottery_draws`, `rsg_lottery_tickets`, `rsg_lottery_winners`
